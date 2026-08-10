
local M = {}
local dkjson = require("libs/dkjson")
local inference_config = require("libs/inference-server-config")
local text_chunking = require("libs/text-chunking")

-- Issue 10-050: bounds on how much work rides in ONE /v1/embeddings request.
-- IMPORTANT: with llama-server's default --parallel 1 there is a single slot, so
-- an array request is processed as N SEQUENTIAL tasks, not one fused forward
-- pass. So the win from batching is fewer HTTP/curl round trips, not GPU
-- parallelism — which means a request must be bounded by total WORK, not just
-- item count. A flat "16 items" is wrong: 16 tiny words is trivial, but 16
-- max-size chunks is ~16× a single chunk's load and can outrun the client
-- timeout (this is exactly what stalled the giant-poem tail of the corpus).
--
-- So we bound each request by BOTH a token budget and a hard item cap, and pack
-- chunks greedily up to whichever comes first.
M.REQUEST_TOKEN_BUDGET = 4000  -- est. tokens packed into one request
M.BATCH_SIZE = 16              -- hard cap on array length per request

-- Process-unique counter for temp filenames. os.time() alone collides under
-- batching (it only ticks once per second, but we fire many requests per
-- second), which would let two concurrent requests clobber each other's
-- request/response files. Bumping a counter per call makes each name unique.
local request_counter = 0
local function unique_tmp_path(label)
   request_counter = request_counter + 1
   return string.format("/tmp/%s_%d_%d.json", label, os.time(), request_counter)
end

-- {{{ function M.sanitize_utf8(s)
-- Strip invalid UTF-8 byte sequences from a string, returning (clean, removed).
-- Why this is mandatory: llama-server serializes responses with nlohmann::json,
-- which THROWS on an invalid UTF-8 byte — and the exception is uncaught, so a
-- single bad byte (e.g. a lone 0xB5 from a PDF mis-saved as a .txt note)
-- terminates the entire server process. We cannot fix llama.cpp, so we guarantee
-- never to send it malformed text. This walks the bytes, keeps only well-formed
-- ASCII / 2-/3-/4-byte sequences, and drops anything else.
function M.sanitize_utf8(s)
   if type(s) ~= "string" then
       return s, 0
   end
   local out, removed = {}, 0
   local i, n = 1, #s
   while i <= n do
       local c = s:byte(i)
       -- len, plus the allowed range (lo2..hi2) for the FIRST continuation byte.
       -- That first-byte range is what enforces STRICT UTF-8 — rejecting overlong
       -- encodings, UTF-16 surrogates, and code points above U+10FFFF. A merely
       -- "structural" check (any 0x80-0xBF continuation) is NOT enough: nlohmann
       -- (and the server) reject those, and a binary blob is full of them.
       local len, lo2, hi2
       if c < 0x80 then len = 1
       elseif c >= 0xC2 and c <= 0xDF then len, lo2, hi2 = 2, 0x80, 0xBF
       elseif c == 0xE0 then           len, lo2, hi2 = 3, 0xA0, 0xBF  -- no overlong
       elseif c >= 0xE1 and c <= 0xEC then len, lo2, hi2 = 3, 0x80, 0xBF
       elseif c == 0xED then           len, lo2, hi2 = 3, 0x80, 0x9F  -- no surrogates
       elseif c >= 0xEE and c <= 0xEF then len, lo2, hi2 = 3, 0x80, 0xBF
       elseif c == 0xF0 then           len, lo2, hi2 = 4, 0x90, 0xBF  -- no overlong
       elseif c >= 0xF1 and c <= 0xF3 then len, lo2, hi2 = 4, 0x80, 0xBF
       elseif c == 0xF4 then           len, lo2, hi2 = 4, 0x80, 0x8F  -- <= U+10FFFF
       else len = 0 end  -- invalid lead (0x80-0xC1 incl. overlong 2-byte, 0xF5-0xFF)

       local valid = false
       if len == 1 then
           valid = true
       elseif len and len > 1 and (i + len - 1 <= n) then
           local b2 = s:byte(i + 1)
           if b2 >= lo2 and b2 <= hi2 then
               valid = true
               for k = 2, len - 1 do
                   local cc = s:byte(i + k)
                   if cc < 0x80 or cc > 0xBF then valid = false; break end
               end
           end
       end

       if valid then
           out[#out + 1] = string.sub(s, i, i + len - 1)
           i = i + len
       else
           removed = removed + 1
           i = i + 1  -- drop one bad byte, resync on the next
       end
   end
   return table.concat(out), removed
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
   -- Issue 10-017: Use build_host_url() instead of deprecated OLLAMA_ENDPOINT
   local curl_cmd = string.format(
       "curl -s -X POST %s/api/chat -H 'Content-Type: application/json' -d @%s > %s",
       inference_config.build_host_url(), input_file, output_file
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

-- Embedding via the configured inference server's OpenAI-compatible
-- /v1/embeddings endpoint. Issue 10-049: migrated from Ollama's
-- /api/embeddings shape, which used "prompt" in the request and
-- returned the vector directly under "embedding". The OpenAI shape
-- uses "input" and nests the vector under data[N].embedding.
--
-- Issue 10-050: the OpenAI shape also accepts an ARRAY of inputs in one
-- request, embedded in one GPU forward pass and returned as data[0..N-1].
-- get_embeddings_batch sends N inputs per round trip instead of one — an
-- order-of-magnitude throughput win over the old one-at-a-time loop. Each
-- input still gets the per-item task prefix (the prefix is per-item, not
-- per-batch).
-- endpoint and format_fn are optional. They exist so a caller that maintains
-- its OWN inference-server-config instance (e.g. src/similarity-engine.lua,
-- which requires the module under a different key and thus a different state
-- object) can pass its already-resolved endpoint URL and prompt-prefix function
-- through, rather than relying on THIS module's separate config state. Omitting
-- them falls back to this module's instance, which is what the simpler call
-- sites (colors, words) want.
function M.get_embeddings_batch(texts, model, endpoint, format_fn) -- {{{
   if type(texts) ~= "table" or #texts == 0 then
       return {}, nil
   end

   endpoint = endpoint or inference_config.build_host_url()
   format_fn = format_fn or inference_config.format_embedding_prompt

   -- Prefix every input individually (e.g. "clustering: " for nomic v1.5+), after
   -- stripping any invalid UTF-8 (which would crash the server — see
   -- M.sanitize_utf8). Warn once per batch if anything was stripped, so corrupt /
   -- binary poem content (e.g. a PDF mis-saved as a .txt) is visible, not silent.
   local prefixed = {}
   local removed_total = 0
   for i = 1, #texts do
       local clean, removed = M.sanitize_utf8(texts[i])
       removed_total = removed_total + removed
       prefixed[i] = format_fn(clean)
   end
   if removed_total > 0 then
       io.stderr:write(string.format(
           "[WARN] sanitize_utf8: stripped %d invalid UTF-8 byte(s) from this "
           .. "embedding batch (corrupt/binary poem content)\n", removed_total))
   end

   local request_body = { model = model, input = prefixed }
   local json_data = dkjson.encode(request_body)

   local input_file = unique_tmp_path("embedding_batch_request")
   local output_file = unique_tmp_path("embedding_batch_response")

   local f = io.open(input_file, "w")
   if not f then
       return nil, "file_error"
   end
   f:write(json_data)
   f:close()

   -- --max-time 180s headroom: with --parallel 1 a request's inputs run as
   -- sequential tasks, so a (now token-bounded) batch should finish well inside
   -- this. If it ever doesn't, the caller bisects rather than just failing.
   local curl_cmd = string.format(
       "curl -s --connect-timeout 10 --max-time 180 -X POST %s/v1/embeddings " ..
       "-H 'Content-Type: application/json' -d @%s > %s",
       endpoint, input_file, output_file
   )
   os.execute(curl_cmd)

   local response_file = io.open(output_file, "r")
   if not response_file then
       os.remove(input_file)
       return nil, "no_response"
   end
   local response_text = response_file:read("*all")
   response_file:close()
   os.remove(input_file)
   os.remove(output_file)

   local response = dkjson.decode(response_text)
   if not (response and response.data) then
       -- Surface the server's own error text (e.g. a 422 "input too large")
       -- truncated, so the caller can decide whether to bisect/chunk and retry.
       return nil, "parse_error: " .. (tostring(response_text):sub(1, 200))
   end

   -- Place each returned vector at the slot its .index names. OpenAI's index is
   -- 0-based and the server is free to return data out of order, so we trust
   -- .index rather than array position; we fall back to sequential order only
   -- if the field is absent. Result is aligned 1:1 with `texts` (nil where a
   -- vector is missing, so the caller can single-retry just that slot).
   local out = {}
   local next_slot = 1
   for _, item in ipairs(response.data) do
       local slot
       if item.index ~= nil then
           slot = item.index + 1
       else
           slot = next_slot
       end
       out[slot] = item.embedding
       next_slot = next_slot + 1
   end
   return out, nil
end -- }}}

-- get_embedding: single-input convenience shim over get_embeddings_batch.
-- Issue 10-050 collapsed the old standalone implementation into this one-liner
-- so there is exactly one code path to the embedding endpoint. Returns the bare
-- vector (or nil) to preserve the original call contract.
function M.get_embedding(text, model) -- {{{
   local vectors = M.get_embeddings_batch({ text }, model)
   return vectors and vectors[1] or nil
end -- }}}

-- {{{ function M.tokenize_count(text, endpoint)
-- Exact token count of `text` under the loaded model's tokenizer, via
-- llama-server's POST /tokenize ({"content": ...} -> {"tokens": [...]}). Returns
-- the token count, or nil on any failure (server down, parse error) so the
-- caller can fall back. Issue 10-050: used to chunk by real tokens instead of a
-- char heuristic, eliminating truncation risk on dense/non-English text.
function M.tokenize_count(text, endpoint)
   endpoint = endpoint or inference_config.build_host_url()
   -- Never let a malformed byte reach the server (it would crash it); see
   -- M.sanitize_utf8. Silent here — get_embeddings_batch emits the warning so we
   -- do not spam one per chunk per poem.
   text = M.sanitize_utf8(text)
   local input_file = unique_tmp_path("tokenize_request")
   local output_file = unique_tmp_path("tokenize_response")

   local f = io.open(input_file, "w")
   if not f then
       return nil
   end
   f:write(dkjson.encode({ content = text }))
   f:close()

   local cmd = string.format(
       "curl -s --connect-timeout 10 --max-time 60 -X POST %s/tokenize " ..
       "-H 'Content-Type: application/json' -d @%s > %s",
       endpoint, input_file, output_file)
   os.execute(cmd)

   local rf = io.open(output_file, "r")
   if not rf then
       os.remove(input_file)
       return nil
   end
   local resp = rf:read("*a")
   rf:close()
   os.remove(input_file)
   os.remove(output_file)

   local parsed = dkjson.decode(resp)
   if parsed and type(parsed.tokens) == "table" then
       return #parsed.tokens
   end
   return nil
end
-- }}}

-- The embedding model's hard limits, used to compute an EXACT per-chunk token
-- budget (no guessed headroom). nomic-embed-text v1.5 was trained at 2048
-- tokens; beyond that the model truncates. BERT wraps every input as
-- [CLS] ... [SEP], so 2 tokens of every request are structural specials. These
-- are model-specific; a model swap means regenerating embeddings anyway.
M.MODEL_CONTEXT_TOKENS = 2048
M.EMBED_SPECIAL_TOKENS = 2

-- {{{ function M.make_token_counter(endpoint)
-- Returns a count_fn(string)->token_count bound to `endpoint`, for the chunker.
-- It raises rather than returning nil if /tokenize is unreachable: there is no
-- safe way to size a chunk without the real count, and a fallback estimate would
-- only mask the failure (the embed call would fail next anyway). Fail loud.
function M.make_token_counter(endpoint)
   return function(s)
       local n = M.tokenize_count(s, endpoint)
       if not n then
           error("make_token_counter: /tokenize unreachable at "
               .. tostring(endpoint or inference_config.build_host_url())
               .. " — cannot size chunks safely")
       end
       return n
   end
end
-- }}}

-- {{{ function M.embedding_chunk_budget(endpoint, format_fn)
-- The EXACT per-chunk token budget: model context, minus the 2 BERT specials,
-- minus the per-input task prefix tokenized once (format_fn('') yields just the
-- prefix). A chunk sized to this budget, once prefixed and wrapped in specials,
-- lands exactly on the model's context limit — no truncation, no guesswork.
function M.embedding_chunk_budget(endpoint, format_fn)
   local prefix = (format_fn and format_fn("")) or ""
   local prefix_tokens = 0
   if #prefix > 0 then
       prefix_tokens = M.tokenize_count(prefix, endpoint)
       if not prefix_tokens then
           error("embedding_chunk_budget: /tokenize unreachable at "
               .. tostring(endpoint or inference_config.build_host_url())
               .. " — cannot size chunks safely")
       end
   end
   return M.MODEL_CONTEXT_TOKENS - M.EMBED_SPECIAL_TOKENS - prefix_tokens
end
-- }}}

-- {{{ function M._embed_with_chunking_impl(texts, batch_fn, count_fn, max_tokens, strategy)
-- Pure orchestration core for "one vector per input text, even when a text is
-- too long for the model". Separated from the network call (batch_fn) ON PURPOSE
-- so it can be unit-tested offline with a mock embedder — this is the part with
-- the fiddly index bookkeeping, and the part a silent bug would hide in.
--
-- Pipeline: chunk every text → FLATTEN all chunks into one list (remembering
-- which chunks belong to which text) → pack the flat list into requests bounded
-- by a TOKEN budget (not a flat item count) → embed each request → gather each
-- text's chunk vectors back and RECOMBINE them (length-weighted by chunk char
-- length) into one vector.
--
-- The token budget is what keeps each request light enough to succeed; a failed
-- request just leaves its slots nil (the caller single-retries those items),
-- rather than splitting the request further.
--
--   texts     : array of strings (assumed non-empty; callers handle empties)
--   batch_fn  : function(sub_texts) -> (vectors_aligned, err). Returns nil on a
--               request failure (timeout, server down, rejected input).
--   count_fn  : function(string) -> exact token count (drives chunk sizing).
--   max_tokens: per-chunk token ceiling passed to chunk_text_by_tokens.
--   returns  : (out, err). out[i] is text i's combined vector, or nil if its
--              chunks could not be embedded (caller may single-retry that one).
--              If NOTHING embedded at all (every request failed — i.e. the
--              server looks down), returns (nil, "all_requests_failed") so the
--              caller's network-backoff/threshold logic still triggers.
--   on_progress: OPTIONAL function(done_chunks, total_chunks), called after each
--              request completes. Added last and optional so every existing
--              five-argument caller -- including all of
--              libs/embed-chunking-test.lua -- keeps working untouched.
--              Progress counts CHUNKS, not input texts, because chunks are what
--              the requests are made of. A caller embedding single words gets
--              one chunk per word, so for them the two are the same number.
function M._embed_with_chunking_impl(texts, batch_fn, count_fn, max_tokens, strategy, on_progress)
   -- 1. chunk each text and flatten, recording each text's slice of the flat list.
   --    chunk_text_by_tokens hands back the EXACT token count of every chunk, so
   --    request packing below never has to estimate — one source of truth.
   local flat = {}
   local flat_tokens = {}  -- exact token count of each flat chunk
   local slices = {}  -- slices[i] = { start = , count = , weights = {char lengths} }
   for i = 1, #texts do
       local chunks, counts = text_chunking.chunk_text_by_tokens(texts[i], count_fn, max_tokens)
       local start_pos = #flat + 1
       local weights = {}
       for j = 1, #chunks do
           flat[#flat + 1] = chunks[j]
           flat_tokens[#flat_tokens + 1] = counts[j]
           weights[#weights + 1] = #chunks[j]
       end
       slices[i] = { start = start_pos, count = #chunks, weights = weights }
   end

   -- 2. pack the flat chunk list into requests bounded by BOTH a token budget
   --    and a hard item cap, then embed each request (one request per group).
   --    Packing by tokens (not a fixed count) keeps a request's work bounded
   --    regardless of whether its chunks are tiny words or near-max chunks.
   local flat_vectors = {}
   local idx = 1
   while idx <= #flat do
       local sub = {}
       local sub_start = idx
       local budget = 0
       while idx <= #flat and #sub < M.BATCH_SIZE do
           local tok = flat_tokens[idx]  -- exact count from chunking, not an estimate
           -- Always take at least one item, even if it alone exceeds the budget
           -- (a single max chunk is still a legal request — it fits the model).
           if #sub > 0 and (budget + tok) > M.REQUEST_TOKEN_BUDGET then
               break
           end
           sub[#sub + 1] = flat[idx]
           budget = budget + tok
           idx = idx + 1
       end
       -- On failure, leave these slots nil and move on. The distribution step
       -- marks the affected poem(s) nil, and similarity-engine single-retries
       -- just those poems (whose chunks then go out as their own small,
       -- token-bounded requests). The token budget — not per-request splitting —
       -- is what keeps requests light enough to succeed.
       local vectors = batch_fn(sub)
       if vectors then
           for k = 1, #sub do
               flat_vectors[sub_start + k - 1] = vectors[k]
           end
       end
       -- Report after each request rather than after each chunk: a request is
       -- the unit of waiting here (one network round trip covering up to
       -- BATCH_SIZE chunks), so it is also the only moment at which anything
       -- has actually changed. Reported even when the request FAILED, because
       -- those chunks are done being attempted and a bar that stalls on failure
       -- tells the operator the wrong thing.
       if on_progress then
           on_progress(idx - 1, #flat)
       end
   end

   -- 3. gather each text's chunk vectors and recombine into one vector
   local out = {}
   local any_success = false
   for i = 1, #texts do
       local s = slices[i]
       if s.count == 0 then
           out[i] = nil  -- empty/whitespace text produced no chunks
       else
           local chunk_vecs = {}
           local complete = true
           for k = 0, s.count - 1 do
               local v = flat_vectors[s.start + k]
               if type(v) ~= "table" or #v == 0 then
                   complete = false
                   break
               end
               chunk_vecs[#chunk_vecs + 1] = v
           end
           if complete then
               out[i] = text_chunking.combine_chunk_vectors(chunk_vecs, s.weights, strategy)
               any_success = true
           else
               out[i] = nil  -- a chunk is missing; let the caller decide to retry
           end
       end
   end

   -- If not a single text embedded, the server is almost certainly unreachable
   -- (a content problem would fail only specific items). Signal a whole-batch
   -- failure so the caller backs off / counts it toward its error threshold,
   -- rather than silently recording every poem as a permanent error.
   if not any_success and #texts > 0 then
       return nil, "all_requests_failed"
   end
   return out, nil
end
-- }}}

-- {{{ function M.embed_texts_with_chunking(texts, model, opts)
-- Production entry point: same as the impl above but wired to the real
-- /v1/embeddings batch call. Returns one vector per input text (nil where a
-- text's embedding could not be produced), or (nil, err) on a transport-level
-- batch failure so the caller can apply retry/backoff.
--
-- opts (all optional): { endpoint=, format_fn=, count_fn=, max_tokens=, strategy= }.
-- endpoint/format_fn are threaded to get_embeddings_batch so a caller with its
-- own config instance stays the single source of truth (see that function).
-- count_fn defaults to the EXACT /tokenize-backed counter, and max_tokens to the
-- exact computed budget. There is NO estimate fallback: if /tokenize is down the
-- embed call is down too, so we fail loudly rather than mask it (Issue 10-050).
function M.embed_texts_with_chunking(texts, model, opts)
   opts = opts or {}
   local endpoint = opts.endpoint
   local count_fn = opts.count_fn or M.make_token_counter(endpoint)
   local max_tokens = opts.max_tokens or M.embedding_chunk_budget(endpoint, opts.format_fn)
   return M._embed_with_chunking_impl(
       texts,
       function(sub)
           return M.get_embeddings_batch(sub, model, endpoint, opts.format_fn)
       end,
       count_fn,
       max_tokens,
       opts.strategy,
       -- Issue 10-065: opts.on_progress lets a caller draw a bar while a long
       -- batch runs. Optional; without it this behaves exactly as before.
       opts.on_progress)
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
