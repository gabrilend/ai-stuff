-- {{{ text-chunking-test.lua
-- Issue 10-050: unit tests for libs/text-chunking.lua.
--
-- Pure-function tests — no inference server, no files. Run directly:
--   luajit libs/text-chunking-test.lua
-- Exits non-zero on failure so it can gate a build/deploy step.
--
-- Sizing is token-exact via an injected counter. `count_chars` (1 token per
-- character) is a perfectly additive mock, so a max_tokens of N behaves like an
-- N-character limit AND the returned per-chunk counts equal the chunk lengths.
-- }}}

package.path = "libs/?.lua;" .. package.path
local chunk = require("text-chunking")

local failures = 0
local tests = 0

-- {{{ local function check(name, condition, detail)
local function check(name, condition, detail)
    tests = tests + 1
    if condition then
        print(string.format("  ok   %s", name))
    else
        failures = failures + 1
        print(string.format("  FAIL %s%s", name, detail and ("  -> " .. detail) or ""))
    end
end
-- }}}

local count_chars = function(s) return #s end

-- {{{ short text is returned whole
local single = chunk.chunk_text_by_tokens("a short poem", count_chars, 7200)
check("short text -> single chunk", #single == 1 and single[1] == "a short poem")
-- }}}

-- {{{ empty / whitespace -> no chunks
check("empty string -> {}", #chunk.chunk_text_by_tokens("", count_chars, 7200) == 0)
check("whitespace -> {}", #chunk.chunk_text_by_tokens("   \n\t ", count_chars, 7200) == 0)
-- }}}

-- {{{ max_tokens is required (no guessed default)
local ok_req = pcall(function() return chunk.chunk_text_by_tokens("hi", count_chars, nil) end)
check("max_tokens is required (errors when nil)", ok_req == false)
-- }}}

-- {{{ splitting is LOSSLESS and counts are EXACT
-- The most important invariant: chunking must never drop or alter a character.
local parts = {}
for i = 1, 60 do
    parts[#parts + 1] = "Paragraph number " .. i .. " has several words in it. "
        .. "It also has a second sentence to give the splitter something to chew on."
end
local long_text = table.concat(parts, "\n\n")
local chunks, counts = chunk.chunk_text_by_tokens(long_text, count_chars, 500)
check("long text actually split into many chunks", #chunks > 1, "got " .. #chunks)
check("lossless: concat(chunks) == original", table.concat(chunks) == long_text)
-- With an additive counter, every returned count must equal the chunk's length.
local counts_exact = (#counts == #chunks)
for i = 1, #chunks do
    if counts[i] ~= #chunks[i] then counts_exact = false end
end
check("returned per-chunk counts are exact (additive counter)", counts_exact)
-- }}}

-- {{{ every chunk respects the max size
local all_within = true
for _, c in ipairs(chunks) do
    if #c > 500 then all_within = false end
end
check("every chunk <= max_tokens", all_within)
-- }}}

-- {{{ degenerate input: one giant unbreakable token -> hard split, still lossless
local giant = string.rep("x", 1730)  -- no separators at all
local giant_chunks = chunk.chunk_text_by_tokens(giant, count_chars, 500)
local giant_ok = (#giant_chunks == 4) and (table.concat(giant_chunks) == giant)
check("giant unbreakable token hard-splits losslessly", giant_ok,
    "chunks=" .. #giant_chunks)
-- }}}

-- {{{ counter drives splitting with a NON-char token ratio
-- tok4 reports 1 token per 4 chars (ceil). Verify splitting respects the TOKEN
-- limit, not the char length, and stays lossless.
local function tok4(s) return math.ceil(#s / 4) end
local parts2 = {}
for i = 1, 50 do parts2[#parts2 + 1] = "Sentence number " .. i .. " has a handful of words." end
local body = table.concat(parts2, "\n\n")
local tchunks = chunk.chunk_text_by_tokens(body, tok4, 30)  -- ~120 chars/chunk ceiling
check("token chunk: long text splits into many", #tchunks > 1, "chunks=" .. #tchunks)
check("token chunk: lossless (concat == original)", table.concat(tchunks) == body)
local all_under = true
for _, c in ipairs(tchunks) do if tok4(c) > 30 then all_under = false end end
check("token chunk: every chunk <= max_tokens by the counter", all_under)
-- }}}

-- {{{ token chunking: no-separator blob hard-splits by tokens, losslessly
local blob = string.rep("z", 250)  -- no separators of any kind
local bchunks = chunk.chunk_text_by_tokens(blob, count_chars, 60)
local blossless = (table.concat(bchunks) == blob)
local bunder = true
for _, c in ipairs(bchunks) do if #c > 60 then bunder = false end end
check("token chunk: no-separator blob hard-splits losslessly",
    blossless and bunder and #bchunks == 5, "chunks=" .. #bchunks)
-- }}}

-- {{{ combine: single vector returned as-is
local one = chunk.combine_chunk_vectors({ {1, 2, 3} })
check("combine single vector -> identity", one[1] == 1 and one[2] == 2 and one[3] == 3)
-- }}}

-- {{{ combine: plain mean
local mean = chunk.combine_chunk_vectors({ {0, 0}, {2, 4} }, nil, "mean")
check("mean of (0,0),(2,4) = (1,2)", mean[1] == 1 and mean[2] == 2)
-- }}}

-- {{{ combine: length-weighted mean favours the longer chunk
-- weights 1 and 3: (1*[0,0] + 3*[4,8]) / 4 = [3,6]
local lwm = chunk.combine_chunk_vectors({ {0, 0}, {4, 8} }, { 1, 3 }, "length_weighted_mean")
check("length-weighted mean tilts toward heavier chunk", lwm[1] == 3 and lwm[2] == 6)
-- }}}

-- {{{ combine: first_only drops the tail
local first = chunk.combine_chunk_vectors({ {9, 9}, {0, 0} }, nil, "first_only")
check("first_only keeps only chunk 1", first[1] == 9 and first[2] == 9)
-- }}}

-- {{{ combine: dimension mismatch errors loudly (no silent garbage)
local ok_err = pcall(function()
    chunk.combine_chunk_vectors({ {1, 2, 3}, {1, 2} }, nil, "mean")
end)
check("dimension mismatch raises an error", ok_err == false)
-- }}}

-- {{{ summary
print(string.format("\n%d/%d checks passed", tests - failures, tests))
if failures > 0 then
    os.exit(1)
end
-- }}}

-- vim: set foldmethod=marker:
