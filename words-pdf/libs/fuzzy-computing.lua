
local M = {}
local dkjson = require("libs/dkjson")
local inference_config = require("libs/inference-server-config")

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
-- let 14k llama-server calls happen on every run with no warning.
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
   -- Posts a chat completion against the configured chat server.
   -- Kept around because a couple of legacy callers still reach for it;
   -- new code should use M.get_embedding directly. The body and response
   -- shape are llama-server's OpenAI-compatible /v1/chat/completions
   -- (issue 025), not Ollama's old /api/chat.
   local request_body = {
       model    = model,
       messages = context,
   }
   local json_data = dkjson.encode(request_body)

   -- os.tmpname returns a unique path each call. The previous os.time()
   -- form gave one-second resolution, which caused back-to-back requests
   -- (~30k/run on a cold cache) to share a temp file — one curl would
   -- read the other's half-written body and the server saw mid-UTF-8 cuts.
   local input_file = os.tmpname()
   local output_file = os.tmpname()

   local f = io.open(input_file, "w")
   f:write(json_data)
   f:close()

   local curl_cmd = string.format(
       "curl -s -X POST %s/v1/chat/completions -H 'Content-Type: application/json' -d @%s > %s",
       inference_config.CHAT_ENDPOINT, input_file, output_file
   )

   os.execute(curl_cmd)

   local response_file = io.open(output_file, "r")
   if not response_file then
       os.remove(input_file)
       return nil
   end

   local response_text = response_file:read("*all")
   response_file:close()

   os.remove(input_file)
   os.remove(output_file)

   local response = dkjson.decode(response_text)
   if response and response.choices and response.choices[1]
       and response.choices[1].message then
       return response.choices[1].message.content
   end

   return nil
end -- }}}

-- {{{ split_text_into_chunks(text, char_limit)
-- Splits text into chunks no larger than char_limit characters, preferring
-- paragraph boundaries (double-newline) in the last 20% of the window,
-- falling back to sentence boundaries in the last 30%, and finally to a
-- hard cut if neither is available.
--
-- nomic-embed-text v1.5 was trained at a 2048-token context. English
-- averages ~4 chars per token, so 6000 chars ≈ 1500 tokens — a safe
-- margin under the training cap that also leaves room for the per-chunk
-- task prefix (e.g. "clustering: ").
local function split_text_into_chunks(text, char_limit)
    if #text <= char_limit then
        return { text }
    end
    local chunks = {}
    local pos = 1
    while pos <= #text do
        local hard_end = math.min(pos + char_limit - 1, #text)
        local cut = hard_end
        if hard_end < #text then
            local window = text:sub(pos, hard_end)
            local para = window:find("\n\n[^\n]*$")
            if para and para > math.floor(char_limit * 0.8) then
                cut = pos + para - 1
            else
                local sent_start = math.floor(char_limit * 0.7)
                local _, e = window:find("[%.%!%?]%s", sent_start)
                if e then
                    cut = pos + e - 1
                end
            end
        end
        table.insert(chunks, text:sub(pos, cut))
        pos = cut + 1
    end
    return chunks
end
-- }}}

-- {{{ mean_pool_embeddings(embeddings)
-- Element-wise mean of a list of vectors. nomic-embed-text already mean-
-- pools token embeddings internally, so chunking a long document and
-- mean-pooling its chunk embeddings approximates what the model would
-- have done with a long-enough context. Imperfect — chunks can't attend
-- across boundaries — but defensible for document-level clustering and
-- theme classification, which only need a coarse "what this poem is
-- about" signal.
local function mean_pool_embeddings(embeddings)
    if #embeddings == 1 then return embeddings[1] end
    local dim = #embeddings[1]
    local mean = {}
    for i = 1, dim do
        local sum = 0
        for j = 1, #embeddings do
            sum = sum + embeddings[j][i]
        end
        mean[i] = sum / #embeddings
    end
    return mean
end
-- }}}

-- {{{ sanitize_utf8(s)
-- Replaces invalid UTF-8 byte sequences with U+FFFD (the standard
-- replacement character, 0xEF 0xBF 0xBD). The embedding server's JSON
-- parser rejects ill-formed UTF-8 with HTTP 500, so we can't pass raw
-- bytes through; sanitizing lets a poem containing a couple of corrupt
-- bytes still produce a usable embedding. The substitution is lossy
-- but localized — the rest of the string is unaffected.
--
-- Common cause in this project: input/compiled.txt was produced by a
-- tool that line-wrapped through the middle of multi-byte sequences
-- (the ╭──╮ box-drawing borders around dividers are the usual victims).
-- Running `iconv -f UTF-8 -t UTF-8//IGNORE` over the source file would
-- fix it upstream; this function exists so the pipeline doesn't halt
-- when the operator hasn't done that cleanup yet.
local function sanitize_utf8(s)
    local out = {}
    local i = 1
    local n = #s
    while i <= n do
        local b = s:byte(i)
        local seq_len, valid = 0, true
        if b < 0x80 then
            seq_len = 1
        elseif b < 0xC0 then
            -- bare continuation byte at start position: invalid
            valid = false
        elseif b < 0xE0 then
            seq_len = 2
        elseif b < 0xF0 then
            seq_len = 3
        elseif b < 0xF8 then
            seq_len = 4
        else
            valid = false
        end
        if valid and seq_len > 1 then
            -- continuation bytes must be 10xxxxxx (0x80–0xBF)
            for j = 1, seq_len - 1 do
                if i + j > n then valid = false; break end
                local cb = s:byte(i + j)
                if cb < 0x80 or cb >= 0xC0 then valid = false; break end
            end
        end
        if valid then
            out[#out + 1] = s:sub(i, i + seq_len - 1)
            i = i + seq_len
        else
            out[#out + 1] = "\xEF\xBF\xBD"
            i = i + 1
        end
    end
    return table.concat(out)
end
-- }}}

-- {{{ embed_single_chunk(text, model)
-- Posts one chunk to /v1/embeddings and returns the vector. Hard-errors
-- on every failure path. Per project policy (CLAUDE.md: "prefer errors
-- over fallbacks"), a silent nil here would let the caller produce
-- "neutral" theme assignments that quietly corrupt the artifact. A
-- re-run with the fix is cheaper than salvaging a wrong-themed PDF.
local function embed_single_chunk(text, model)
    -- Some inputs from compiled.txt contain broken UTF-8 (truncated multi-
    -- byte sequences from upstream tooling). The server's JSON parser
    -- rejects those with HTTP 500; sanitize_utf8 swaps the bad bytes for
    -- U+FFFD so the request stays well-formed and the pipeline doesn't
    -- halt on every dividing-border poem.
    text = sanitize_utf8(text)
    local request_body = { model = model, input = text }
    local json_data = dkjson.encode(request_body)

    -- os.tmpname returns a unique path per call. Earlier one-second-
    -- precision (os.time()) caused back-to-back requests to share a
    -- temp file and curl picked up half-overwritten bodies (truncated
    -- mid-UTF-8 → server 500s).
    local input_file = os.tmpname()
    local output_file = os.tmpname()

    local f, write_err = io.open(input_file, "w")
    if not f then
        error("embed_single_chunk: cannot open temp input " .. input_file
            .. ": " .. tostring(write_err))
    end
    f:write(json_data)
    f:close()

    -- curl bounded at 60s so a stuck server can't wedge the pipeline.
    local curl_cmd = string.format(
        "curl -sS --max-time 60 -X POST %s/v1/embeddings "
        .. "-H 'Content-Type: application/json' -d @%s > %s",
        inference_config.EMBEDDING_ENDPOINT, input_file, output_file
    )
    -- Lua 5.2 os.execute returns (true|nil, "exit"|"signal", code). Treat
    -- a SIGINT (signal 2) as an explicit interrupt so Ctrl+C escapes
    -- thousands-of-iterations PDF passes instead of being absorbed.
    local ok, reason, code = os.execute(curl_cmd)
    if reason == "signal" and code == 2 then
        os.remove(input_file); os.remove(output_file)
        error("embed_single_chunk: interrupted by user (SIGINT)")
    end
    if not ok then
        os.remove(input_file); os.remove(output_file)
        error("embed_single_chunk: curl failed (exit " .. tostring(code) .. ")")
    end

    local response_file = io.open(output_file, "r")
    if not response_file then
        os.remove(input_file)
        error("embed_single_chunk: no response file at " .. output_file)
    end
    local response_text = response_file:read("*all")
    response_file:close()
    os.remove(input_file)
    os.remove(output_file)

    local response = dkjson.decode(response_text)
    if not response then
        error("embed_single_chunk: response was not valid JSON\n"
            .. "First 200 bytes: " .. response_text:sub(1, 200))
    end
    if response.error then
        local err_msg = type(response.error) == "table"
            and (response.error.message or dkjson.encode(response.error))
            or tostring(response.error)
        error("embed_single_chunk: server returned error: " .. err_msg)
    end
    if not (response.data and response.data[1] and response.data[1].embedding) then
        error("embed_single_chunk: response missing data[0].embedding\n"
            .. "First 200 bytes: " .. response_text:sub(1, 200))
    end
    return response.data[1].embedding
end
-- }}}

-- {{{ M.get_embedding(text, model, prefix)
-- Returns an embedding vector for `text`, optionally prepending `prefix`
-- to every chunk. Task-prefixed models like nomic-embed-text v1.5 need
-- the prefix on each independently-embedded input to route through the
-- correct internal weights, so callers pass the prefix here instead of
-- concatenating it themselves — long inputs that get split into chunks
-- would otherwise have the prefix only on the first chunk.
--
-- Inputs longer than the chunk threshold are split, embedded one chunk
-- at a time, and mean-pooled into one vector. Inputs short enough fit
-- in one chunk and the pool collapses to identity.
--
-- The cache key is (prefix .. text, model), so a re-run with the same
-- caller args hits the same cache entry whether or not chunking happened
-- internally.
--
-- Hard-errors on any failure path. Callers do NOT need an "if not embedding"
-- check — a returned value is always a valid vector.
function M.get_embedding(text, model, prefix)
    prefix = prefix or ""
    local cache_key = prefix .. text
    local cached = embedding_cache_read(cache_key, model)
    if cached then return cached end

    local CHUNK_CHAR_LIMIT = 6000
    local chunks = split_text_into_chunks(text, CHUNK_CHAR_LIMIT)
    local chunk_embeddings = {}
    for _, chunk in ipairs(chunks) do
        table.insert(chunk_embeddings, embed_single_chunk(prefix .. chunk, model))
    end

    local final = mean_pool_embeddings(chunk_embeddings)
    embedding_cache_write(cache_key, model, final)
    return final
end
-- }}}

-- {{{ M.embedding_cache_status()
-- Counts how many embeddings are currently cached on disk. Compile scripts
-- call this at startup so the user can see at a glance whether the cache is
-- warm ("8423 entries") or cold ("0 entries — full embedding-server pass ahead").
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

-- Find the most similar theme with frequency-based weighting.
-- Soft decay version: the diversity boost asymptotically approaches zero
-- but never reaches it, so a heavily-picked theme can still win if its raw
-- similarity advantage outweighs the penalty. Avoids the "hard cliff" bug
-- where a locked-out theme with score 0 would still beat themes with
-- negative weighted_score values.
-- After N picks, boost = 1/(1 + N/10): 1 → 0.91 → 0.50 → 0.33 → 0.09 (at 100).
function M.find_most_similar_theme_weighted(text_embedding, theme_embeddings, frequency_weights) -- {{{
   local best_theme = nil
   local best_weighted_score = -math.huge
   local best_raw_similarity = -math.huge

   for theme, theme_embedding in pairs(theme_embeddings) do
       local raw_similarity = M.cosine_similarity(text_embedding, theme_embedding)
       local frequency_penalty = frequency_weights[theme] or 0
       local diversity_boost = 1.0 / (1.0 + frequency_penalty * 0.1)
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
