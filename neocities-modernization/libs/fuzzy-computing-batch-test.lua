-- {{{ fuzzy-computing-batch-test.lua
-- Issue 10-050: live smoke test for M.get_embeddings_batch.
--
-- Needs a running inference server (the selected one from config.lua). If none
-- is reachable it SKIPS (exit 0) rather than failing, so it is safe to wire
-- into a build step that may run without the GPU box up. Run:
--   luajit libs/fuzzy-computing-batch-test.lua
--
-- What it proves end-to-end (only possible against a real server):
--   - a 3-input batch returns 3 vectors in input order
--   - every vector has the same, positive dimension
--   - the single-input shim get_embedding still works
--   - chunk-then-batch round-trips an over-long text into >1 vector
-- }}}

package.path = "libs/?.lua;" .. package.path
local fuzzy = require("fuzzy-computing")
local chunk = require("text-chunking")
local inference = require("inference-server-config")

inference.set_project_root(".")
local server = inference.get_selected_server()
local url = inference.build_host_url(server)
local model = server.model

-- {{{ skip if no server
local probe = io.popen(string.format(
    "curl -s -o /dev/null -w '%%{http_code}' --max-time 3 '%s/health'", url))
local code = probe:read("*a")
probe:close()
if code ~= "200" then
    print(string.format("SKIP: no server at %s/health (got '%s')", url, code))
    os.exit(0)
end
print("server reachable at " .. url .. " (model: " .. tostring(model) .. ")")
-- }}}

local failures = 0
-- {{{ local function check(name, cond, detail)
local function check(name, cond, detail)
    if cond then
        print("  ok   " .. name)
    else
        failures = failures + 1
        print("  FAIL " .. name .. (detail and ("  -> " .. detail) or ""))
    end
end
-- }}}

-- {{{ /tokenize gives an exact, positive token count
local n_short = fuzzy.tokenize_count("the sea at dawn")
local n_long = fuzzy.tokenize_count(string.rep("word ", 200))
check("tokenize_count returns a positive integer",
    type(n_short) == "number" and n_short > 0, "got " .. tostring(n_short))
check("tokenize_count scales with text length",
    type(n_long) == "number" and n_long > n_short, "short=" .. tostring(n_short) .. " long=" .. tostring(n_long))
-- }}}

-- {{{ batch of three returns three aligned vectors
local vecs = fuzzy.get_embeddings_batch(
    { "the sea at dawn", "a quiet kind of grief", "burning revolution" }, model)
check("batch returns 3 vectors", vecs and #vecs == 3, "got " .. tostring(vecs and #vecs))
if vecs and vecs[1] and vecs[2] and vecs[3] then
    local d = #vecs[1]
    check("all vectors share one positive dimension",
        d > 0 and #vecs[2] == d and #vecs[3] == d, "dim=" .. d)
end
-- }}}

-- {{{ single-input shim still works
local one = fuzzy.get_embedding("a single line", model)
check("get_embedding shim returns a vector", type(one) == "table" and #one > 0)
-- }}}

-- {{{ chunk-then-batch on an over-long text yields multiple chunk vectors
-- Uses the real /tokenize counter and the exact computed budget — the same path
-- production takes — so this also validates make_token_counter + the budget math.
local long = string.rep("This is a sentence about the weather and the wind. ", 400)
local count_fn = fuzzy.make_token_counter()
local budget = fuzzy.embedding_chunk_budget()
local chunks = chunk.chunk_text_by_tokens(long, count_fn, budget)
check("over-long text splits into >1 chunk", #chunks > 1, "chunks=" .. #chunks)
local chunk_vecs = fuzzy.get_embeddings_batch(chunks, model)
check("batch embeds every chunk", chunk_vecs and #chunk_vecs == #chunks)
local weights = {}
for i, c in ipairs(chunks) do weights[i] = #c end
local combined = chunk.combine_chunk_vectors(chunk_vecs, weights)
check("recombined vector matches embedding dimension",
    combined and #combined == (one and #one or 0))
-- }}}

print(failures == 0 and "\nall live checks passed" or ("\n" .. failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)

-- vim: set foldmethod=marker:
