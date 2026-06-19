
local M = {}
local dkjson = require("libs/dkjson")
local ollama_config = require("libs/ollama-config")

-- {{{ djb2_hash(s)
-- Pure-Lua hash for cache keys. 32-bit output is sufficient since at the
-- scale of this project (~14k embeddings per book) collision probability is
-- negligible, and a collision only triggers one re-fetch — not a correctness
-- issue. Pure-Lua avoids fork overhead per cache lookup.
local function djb2_hash(s)
    local hash = 5381
    for i = 1, #s do
        hash = (hash * 33 + s:byte(i)) % 2147483648
    end
    return hash
end
-- }}}

-- {{{ embedding_cache_path(text, model)
-- Returns the on-disk path where a (text, model) pair's embedding would be
-- cached. Joining with a null byte ensures the model+text concatenation has
-- no ambiguity around the boundary.
local function embedding_cache_path(text, model)
    local key = model .. "\0" .. text
    return string.format("tmp/embeddings/%08x.lua", djb2_hash(key))
end
-- }}}

-- {{{ embedding_cache_read(text, model)
-- Tries to load a cached embedding from disk; returns nil on miss. The cache
-- file is a Lua source file that returns the embedding table, so dofile
-- handles parsing.
local function embedding_cache_read(text, model)
    local path = embedding_cache_path(text, model)
    local f = io.open(path, "r")
    if not f then return nil end
    f:close()
    return dofile(path)
end
-- }}}

-- {{{ embedding_cache_write(text, model, embedding)
-- Writes an embedding to disk. Raises an error if the write fails — per the
-- project's "prefer errors over fallbacks" rule, silently failing here would
-- let 14k Ollama calls happen on every run with no warning.
local function embedding_cache_write(text, model, embedding)
    local path = embedding_cache_path(text, model)
    local f, err = io.open(path, "w")
    if not f then
        error("Embedding cache write failed at " .. path .. ": " ..
              (err or "unknown") ..
              "\nEnsure tmp/embeddings/ exists (the ./run script creates it).")
    end
    f:write("return {")
    for i, v in ipairs(embedding) do
        f:write(string.format("%.17g", v))
        if i < #embedding then f:write(",") end
    end
    f:write("}\n")
    f:close()
end
-- }}}

function M.generate(context, model) -- {{{ (DEPRECATED - use M.get_embedding instead)
   local request_body = {
       model  = model,
       messages = context,
       stream   = false
   }
   local json_data = dkjson.encode(request_body)
   
   -- Create temporary files for curl communication
   local input_file = "/tmp/llm_request_" .. os.time() .. ".json"
   local output_file = "/tmp/llm_response_" .. os.time() .. ".json"
   
   -- Write request to file
   local f = io.open(input_file, "w")
   f:write(json_data)
   f:close()
   
   -- Make curl request
   local curl_cmd = string.format(
       "curl -s -X POST %s/api/chat -H 'Content-Type: application/json' -d @%s > %s",
       ollama_config.OLLAMA_ENDPOINT, input_file, output_file
   )
   
   os.execute(curl_cmd)
   
   -- Read response
   local response_file = io.open(output_file, "r")
   if not response_file then
       -- Cleanup
       os.remove(input_file)
       return nil
   end
   
   local response_text = response_file:read("*all")
   response_file:close()
   
   -- Cleanup
   os.remove(input_file)
   os.remove(output_file)
   
   local response = dkjson.decode(response_text)
   if response and response.message then
       return response.message.content
   end
   
   return nil
end -- }}}

-- New embedding functions
function M.get_embedding(text, model) -- {{{
   -- Check disk cache first — avoids the Ollama round-trip on warm runs.
   -- Same (text, model) pair always hashes to the same key, so iterating on
   -- visual code without changing poem content reads everything from disk.
   local cached = embedding_cache_read(text, model)
   if cached then return cached end

   local request_body = {
       model = model,
       prompt = text
   }
   local json_data = dkjson.encode(request_body)

   -- Create temporary files for curl communication
   local input_file = "/tmp/embedding_request_" .. os.time() .. ".json"
   local output_file = "/tmp/embedding_response_" .. os.time() .. ".json"

   -- Write request to file
   local f = io.open(input_file, "w")
   f:write(json_data)
   f:close()

   -- Make curl request to embeddings endpoint
   local curl_cmd = string.format(
       "curl -s -X POST %s/api/embeddings -H 'Content-Type: application/json' -d @%s > %s",
       ollama_config.OLLAMA_ENDPOINT, input_file, output_file
   )

   os.execute(curl_cmd)

   -- Read response
   local response_file = io.open(output_file, "r")
   if not response_file then
       -- Cleanup
       os.remove(input_file)
       return nil
   end

   local response_text = response_file:read("*all")
   response_file:close()

   -- Cleanup
   os.remove(input_file)
   os.remove(output_file)

   local response = dkjson.decode(response_text)
   if response and response.embedding then
       embedding_cache_write(text, model, response.embedding)
       return response.embedding
   end

   return nil
end -- }}}

-- {{{ M.embedding_cache_status()
-- Counts how many embeddings are currently cached on disk. Compile scripts
-- call this at startup so the user can see at a glance whether the cache is
-- warm ("8423 entries") or cold ("0 entries — full Ollama pass ahead").
function M.embedding_cache_status()
    local handle = io.popen("ls -1 tmp/embeddings/ 2>/dev/null | wc -l")
    if not handle then return 0 end
    local count = handle:read("*all")
    handle:close()
    return tonumber(count) or 0
end
-- }}}

-- Calculate cosine similarity between two embedding vectors
function M.cosine_similarity(vec1, vec2) -- {{{
   if not vec1 or not vec2 or #vec1 ~= #vec2 then
       return 0
   end
   
   local dot_product = 0
   local magnitude1 = 0
   local magnitude2 = 0
   
   for i = 1, #vec1 do
       dot_product = dot_product + (vec1[i] * vec2[i])
       magnitude1 = magnitude1 + (vec1[i] * vec1[i])
       magnitude2 = magnitude2 + (vec2[i] * vec2[i])
   end
   
   magnitude1 = math.sqrt(magnitude1)
   magnitude2 = math.sqrt(magnitude2)
   
   if magnitude1 == 0 or magnitude2 == 0 then
       return 0
   end
   
   return dot_product / (magnitude1 * magnitude2)
end -- }}}

-- Find the most similar theme from a list of theme embeddings
function M.find_most_similar_theme(text_embedding, theme_embeddings) -- {{{
   local best_theme = "neutral"
   local best_similarity = -1
   
   for theme, theme_embedding in pairs(theme_embeddings) do
       local similarity = M.cosine_similarity(text_embedding, theme_embedding)
       if similarity > best_similarity then
           best_similarity = similarity
           best_theme = theme
       end
   end
   
   return best_theme, best_similarity
end -- }}}

-- Find the most similar theme with frequency-based weighting
function M.find_most_similar_theme_weighted(text_embedding, theme_embeddings, frequency_weights) -- {{{
   local best_theme = "neutral"
   local best_weighted_score = -1
   local best_raw_similarity = -1
   
   for theme, theme_embedding in pairs(theme_embeddings) do
       local raw_similarity = M.cosine_similarity(text_embedding, theme_embedding)
       
       -- Apply frequency-based weighting
       local frequency_penalty = frequency_weights[theme] or 0
       local diversity_boost = math.max(0, 1.0 - (frequency_penalty * 0.1)) -- Reduce by 10% per use
       local weighted_score = raw_similarity * diversity_boost
       
       if weighted_score > best_weighted_score then
           best_weighted_score = weighted_score
           best_raw_similarity = raw_similarity
           best_theme = theme
       end
   end
   
   return best_theme, best_raw_similarity, best_weighted_score
end -- }}}

return M
