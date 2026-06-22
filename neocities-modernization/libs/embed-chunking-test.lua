-- {{{ embed-chunking-test.lua
-- Issue 10-050: offline tests for fuzzy-computing's chunk+batch+recombine core
-- (M._embed_with_chunking_impl). Uses a MOCK embedder AND a mock token counter,
-- so no inference server is needed — this exercises the index bookkeeping that a
-- live test cannot isolate.
--   luajit libs/embed-chunking-test.lua
--
-- The mock counter `count_chars` returns one token per character, which makes
-- the token-based chunker behave identically to a char limit of the same number
-- — so a max_tokens of 7200 here splits exactly where a 7200-char limit would.
-- }}}

package.path = "libs/?.lua;./?.lua;" .. package.path
local fuzzy = require("fuzzy-computing")
local chunk = require("text-chunking")

local failures, tests = 0, 0
-- {{{ local function check(name, cond, detail)
local function check(name, cond, detail)
    tests = tests + 1
    if cond then
        print("  ok   " .. name)
    else
        failures = failures + 1
        print("  FAIL " .. name .. (detail and ("  -> " .. detail) or ""))
    end
end
-- }}}

-- count_chars: exact "tokenizer" of 1 token per character (deterministic mock).
local count_chars = function(s) return #s end

-- {{{ mock embedder: returns a deterministic 2-D vector per input
-- vector = { length_of_text, first_byte }. This lets a test predict exactly
-- what a recombined vector should be. Also records how many sub-batches it saw
-- and the largest sub-batch size, to verify BATCH_SIZE chunking of requests.
local function make_mock()
    local state = { calls = 0, max_sub = 0 }
    local fn = function(sub)
        state.calls = state.calls + 1
        if #sub > state.max_sub then state.max_sub = #sub end
        local out = {}
        for i = 1, #sub do
            out[i] = { #sub[i], string.byte(sub[i]) or 0 }
        end
        return out, nil
    end
    return fn, state
end
-- }}}

-- {{{ short texts: one chunk each, vectors come back in input order
local fn, st = make_mock()
local out = fuzzy._embed_with_chunking_impl({ "aaa", "bbbb" }, fn, count_chars, 7200, "length_weighted_mean")
check("two short texts -> two vectors", out and #out == 2)
check("text 1 vector reflects its length/first-byte",
    out[1][1] == 3 and out[1][2] == string.byte("a"))
check("text 2 vector reflects its length/first-byte",
    out[2][1] == 4 and out[2][2] == string.byte("b"))
-- }}}

-- {{{ a long text is chunked, embedded, and recombined into ONE vector
local fn2 = make_mock()
local long = string.rep("word ", 4000)  -- 20000 chars -> multiple chunks at 7200
local chunks = chunk.chunk_text_by_tokens(long, count_chars, 7200)
check("sanity: long text splits into >1 chunk", #chunks > 1, "chunks=" .. #chunks)
local out2 = fuzzy._embed_with_chunking_impl({ long }, fn2, count_chars, 7200, "length_weighted_mean")
check("long text -> exactly one combined vector", out2 and #out2 == 1 and type(out2[1]) == "table")
-- The combined dim-1 value is the length-weighted mean of each chunk's length,
-- weighted by that same length: sum(len^2)/sum(len). Compute the expectation.
local num, den = 0, 0
for _, c in ipairs(chunks) do num = num + #c * #c; den = den + #c end
check("recombined value matches length-weighted-mean formula",
    math.abs(out2[1][1] - (num / den)) < 1e-6,
    string.format("got %.4f want %.4f", out2[1][1], num / den))
-- }}}

-- {{{ mixed batch: short + long together, flat order preserved across the seam
local fn3, st3 = make_mock()
local out3 = fuzzy._embed_with_chunking_impl({ "short", long, "tiny" }, fn3, count_chars, 7200, "mean")
check("mixed batch -> 3 vectors", out3 and #out3 == 3)
check("short text before the long one is intact", out3[1][1] == 5)
check("short text after the long one is intact", out3[3][1] == 4)
-- }}}

-- {{{ BATCH_SIZE bounds the per-request size
-- 40 single-chunk texts with BATCH_SIZE 16 -> ceil(40/16)=3 calls, max sub 16.
fuzzy.BATCH_SIZE = 16
local fn4, st4 = make_mock()
local many = {}
for i = 1, 40 do many[i] = "t" .. i end
fuzzy._embed_with_chunking_impl(many, fn4, count_chars, 7200, "mean")
check("40 inputs split into 3 sub-batches", st4.calls == 3, "calls=" .. st4.calls)
check("no sub-batch exceeds BATCH_SIZE", st4.max_sub <= 16, "max=" .. st4.max_sub)
-- }}}

-- {{{ total failure (server down): EVERY request fails -> (nil, all_requests_failed)
local failing = function(_) return nil, "no_response" end
local out5, err5 = fuzzy._embed_with_chunking_impl({ "a", "b" }, failing, count_chars, 7200, "mean")
check("total failure -> nil + all_requests_failed",
    out5 == nil and err5 == "all_requests_failed", "err=" .. tostring(err5))
-- }}}

-- {{{ a failed REQUEST isolates to its own items; sibling requests still embed
-- Big inputs (~3000 est tokens each) each land in their own token-budgeted
-- request; the mock fails only the request containing "BAD". Isolation is at
-- request granularity: only that item goes nil, siblings embed.
local req_isolate = function(sub)
    for i = 1, #sub do if sub[i]:find("BAD") then return nil, "rejected" end end
    local o = {}
    for i = 1, #sub do o[i] = { #sub[i] } end
    return o, nil
end
local g = string.rep("x", 12000)  -- one chunk; ~3000 est tokens -> its own request
local outR = fuzzy._embed_with_chunking_impl({ g, g .. "BAD", g }, req_isolate, count_chars, 99999, "mean")
check("failed request -> its item nil, sibling requests still embed",
    outR and outR[1] ~= nil and outR[2] == nil and outR[3] ~= nil)
-- }}}

-- {{{ token-budget packing: a few big chunks split into multiple requests
-- Packing uses the EXACT per-chunk token counts (count_chars -> 12000 each here).
-- With REQUEST_TOKEN_BUDGET=4000, three 12000-token inputs each take their own
-- request -> >1 request.
local pack_calls = 0
local count_calls = function(sub)
    pack_calls = pack_calls + 1
    local o = {}
    for i = 1, #sub do o[i] = { 1 } end
    return o, nil
end
local big = string.rep("x", 12000)  -- one chunk at max_tokens=99999
fuzzy._embed_with_chunking_impl({ big, big, big }, count_calls, count_chars, 99999, "mean")
check("token budget splits heavy inputs across requests", pack_calls >= 2,
    "requests=" .. pack_calls)
-- }}}

-- {{{ a single missing chunk vector -> that text is nil, others survive
local picky = function(sub)
    local o = {}
    for i = 1, #sub do
        if sub[i]:find("DROP") then o[i] = nil else o[i] = { 1, 1 } end
    end
    return o, nil
end
local out6 = fuzzy._embed_with_chunking_impl({ "ok one", "DROP me", "ok two" }, picky, count_chars, 7200, "mean")
check("missing-vector text -> nil", out6[2] == nil)
check("neighbours of a missing-vector text still embed",
    type(out6[1]) == "table" and type(out6[3]) == "table")
-- }}}

-- {{{ sanitize_utf8: drops bad bytes, keeps valid text, always yields valid UTF-8
-- A STRICT validator (the kind nlohmann/the server enforces): rejects overlong
-- encodings, UTF-16 surrogates, and code points > U+10FFFF, via per-lead-byte
-- first-continuation ranges. A merely-structural check would give false
-- confidence (it did, earlier — that is the bug this guards against).
local function is_valid_utf8(s)
    local i, n = 1, #s
    while i <= n do
        local c = s:byte(i)
        local len, lo2, hi2
        if c < 0x80 then len = 1
        elseif c >= 0xC2 and c <= 0xDF then len, lo2, hi2 = 2, 0x80, 0xBF
        elseif c == 0xE0 then len, lo2, hi2 = 3, 0xA0, 0xBF
        elseif c >= 0xE1 and c <= 0xEC then len, lo2, hi2 = 3, 0x80, 0xBF
        elseif c == 0xED then len, lo2, hi2 = 3, 0x80, 0x9F
        elseif c >= 0xEE and c <= 0xEF then len, lo2, hi2 = 3, 0x80, 0xBF
        elseif c == 0xF0 then len, lo2, hi2 = 4, 0x90, 0xBF
        elseif c >= 0xF1 and c <= 0xF3 then len, lo2, hi2 = 4, 0x80, 0xBF
        elseif c == 0xF4 then len, lo2, hi2 = 4, 0x80, 0x8F
        else return false end
        if len > 1 then
            if i + len - 1 > n then return false end
            local b2 = s:byte(i + 1)
            if b2 < lo2 or b2 > hi2 then return false end
            for k = 2, len - 1 do
                local cc = s:byte(i + k)
                if cc < 0x80 or cc > 0xBF then return false end
            end
        end
        i = i + len
    end
    return true
end

local clean_ascii, r0 = fuzzy.sanitize_utf8("plain ascii poem")
check("sanitize: clean ASCII unchanged", clean_ascii == "plain ascii poem" and r0 == 0)

local mu = "micro \xC2\xB5 sign"  -- µ properly encoded as 0xC2 0xB5
local clean_mu, r1 = fuzzy.sanitize_utf8(mu)
check("sanitize: valid 2-byte UTF-8 preserved", clean_mu == mu and r1 == 0)

local lone, r2 = fuzzy.sanitize_utf8("bad \xB5 byte")  -- lone 0xB5 = invalid
check("sanitize: lone 0xB5 stripped", lone == "bad  byte" and r2 == 1)

-- the actual poison: a PDF header like poem 8169's first bytes
local pdf = "%PDF-1.5\n%\xB5\xED\xAE\xFB\n4 0 obj"
local clean_pdf, r3 = fuzzy.sanitize_utf8(pdf)
check("sanitize: PDF binary header -> valid UTF-8, bytes removed",
    is_valid_utf8(clean_pdf) and r3 > 0, "removed=" .. r3)

-- strict cases a lenient check would WRONGLY accept:
local overlong, ro = fuzzy.sanitize_utf8("x\xE0\x9A\xB1y")  -- E0 9A = overlong (the real 8169 byte)
check("sanitize: overlong 3-byte stripped", is_valid_utf8(overlong) and ro > 0, "got " .. overlong)
local surrogate, rs = fuzzy.sanitize_utf8("x\xED\xA0\x80y")  -- U+D800 surrogate
check("sanitize: UTF-16 surrogate stripped", is_valid_utf8(surrogate) and rs > 0)
local oob, rb = fuzzy.sanitize_utf8("x\xF4\x90\x80\x80y")    -- > U+10FFFF
check("sanitize: out-of-range 4-byte stripped", is_valid_utf8(oob) and rb > 0)
-- valid 3- and 4-byte survive untouched
local valid3 = "snowman \xE2\x98\x83 emoji \xF0\x9F\x98\x80"  -- ☃ and 😀
check("sanitize: valid 3- and 4-byte preserved", select(1, fuzzy.sanitize_utf8(valid3)) == valid3)
-- }}}

print(string.format("\n%d/%d checks passed", tests - failures, tests))
os.exit(failures == 0 and 0 or 1)

-- vim: set foldmethod=marker:
