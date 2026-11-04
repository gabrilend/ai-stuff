#!/usr/bin/env luajit
-- {{{ embedding-space.test.lua
-- Tests for the module that decides how vectors are prepared before comparison.
--
-- The behaviours worth pinning down here are the ones whose failure is SILENT.
-- A wrong mean does not crash; it produces a complete, ordered, plausible set of
-- neighbours that happens to be the wrong set. So the tests care most about the
-- two guards: that a mixed-dimension file is refused rather than averaged past,
-- and that an unmarked cache directory reads as stale rather than as fine.
--
-- Usage: luajit libs/embedding-space.test.lua [--dir PATH]
-- }}}

-- The project folder from --dir PATH, or nil when it was not given (the
-- default below is then used); a stray word on the command line stops the
-- program, named (libs/project-dir.lua, Issue 10-076).
local PROJECT_DIR_ARG = (function()
    local own = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
    local dir = dofile(own .. "../libs/project-dir.lua").read(arg, "")
    if dir == "" then return nil end
    return dir
end)()

local DIR = PROJECT_DIR_ARG or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
package.path = DIR .. "/libs/?.lua;" .. package.path

local es = require("embedding-space")

local passed, failed = 0, 0

-- {{{ local function check
local function check(name, ok, detail)
    if ok then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name .. (detail and ("  -- " .. detail) or ""))
    end
end
-- }}}

-- {{{ local function close
-- Float comparison with a tolerance, because a mean is a division.
local function close(a, b)
    return math.abs(a - b) < 1e-9
end
-- }}}

print("corpus_mean")
do
    local m, n = es.corpus_mean({
        { embedding = { 1, 2, 3 } },
        { embedding = { 3, 4, 5 } },
        { embedding = { 5, 6, 7 } },
    })
    check("averages each dimension independently",
        m and close(m[1], 3) and close(m[2], 4) and close(m[3], 5),
        m and table.concat(m, ",") or "nil")
    check("reports how many vectors it averaged", n == 3, tostring(n))
end

do
    -- Entries with no usable embedding are skipped, not counted -- otherwise the
    -- divisor is too large and every centred vector is pulled toward zero.
    local m, n = es.corpus_mean({
        { embedding = { 2, 4 } },
        { embedding = {} },
        { },
        { embedding = { 4, 8 } },
    })
    check("skips entries with no usable vector",
        m and close(m[1], 3) and close(m[2], 6), m and table.concat(m, ",") or "nil")
    check("does not count skipped entries in the divisor", n == 2, tostring(n))
end

do
    local m, err = es.corpus_mean({
        { embedding = { 1, 2, 3 } },
        { embedding = { 1, 2 } },
    })
    check("refuses a mixed-dimension set", m == nil)
    check("says why it refused",
        type(err) == "string" and err:find("dimension mismatch") ~= nil, tostring(err))
end

do
    local m, err = es.corpus_mean({})
    check("refuses an empty set", m == nil, tostring(err))
end

print("centered")
do
    local mean = { 1, 1, 1 }
    local v = { 4, 5, 6 }
    local c = es.centered(v, mean)
    check("subtracts the mean", close(c[1], 3) and close(c[2], 4) and close(c[3], 5))
    check("leaves the caller's vector untouched",
        close(v[1], 4) and close(v[2], 5) and close(v[3], 6))
end

do
    -- A nil mean must return the vector as-is: degrading to the previous
    -- behaviour is recoverable, degrading to zeros is not.
    local v = { 1, 2 }
    check("passes the vector through when there is no mean", es.centered(v, nil) == v)
    check("passes through on a dimension mismatch", es.centered(v, { 1, 2, 3 }) == v)
end

print("cosine_across_populations")
do
    -- Two populations, each parked at its own offset. Words live near (0,0,10)
    -- -- every word shares that big third component, like a lone word's
    -- "short text" habit -- and poems near (0,0,0). Word A means "x", word B
    -- means "y"; poem X means "x", poem Y means "y", and poem S is a "short"
    -- post that shares the words' offset but means nothing.
    local word_a = { 1, 0, 10 }
    local word_b = { 0, 1, 10 }
    local poem_x = { 1, 0, 0 }
    local poem_y = { 0, 1, 0 }
    local poem_s = { 0, 0, 3 }
    local words = { { embedding = word_a }, { embedding = word_b } }
    local poems = { { embedding = poem_x }, { embedding = poem_y }, { embedding = poem_s } }
    local word_mean = es.corpus_mean(words)
    local poem_mean = es.corpus_mean(poems)

    -- {{{ local function best_poem
    local function best_poem(word, score)
        local names = { "x", "y", "s" }
        local best, best_s = nil, -2
        for i, p in ipairs({ poem_x, poem_y, poem_s }) do
            local s = score(word, p)
            if s > best_s then best, best_s = names[i], s end
        end
        return best
    end
    -- }}}

    -- The old rule: both sides centred on the POEM average. The words' offset
    -- survives, and both words pick the same "short" poem -- the bug seen on
    -- the live site, where every word page led with the same short posts.
    local old_rule = function(w, p)
        local a, b = es.centered(w, poem_mean), es.centered(p, poem_mean)
        return es.cosine_across_populations(a, { 0, 0, 0 }, b, { 0, 0, 0 })
    end
    check("one shared average sends both words to the same short poem",
        best_poem(word_a, old_rule) == "s" and best_poem(word_b, old_rule) == "s",
        best_poem(word_a, old_rule) .. "," .. best_poem(word_b, old_rule))

    -- The new rule: each side centred on its own population's average.
    local new_rule = function(w, p)
        return es.cosine_across_populations(w, word_mean, p, poem_mean)
    end
    check("own averages send word x to poem x", best_poem(word_a, new_rule) == "x",
        best_poem(word_a, new_rule))
    check("own averages send word y to poem y", best_poem(word_b, new_rule) == "y",
        best_poem(word_b, new_rule))

    check("a missing average is refused, not silently ignored",
        not pcall(es.cosine_across_populations, word_a, nil, poem_x, poem_mean))
    check("mixed dimensions are refused",
        not pcall(es.cosine_across_populations, { 1, 2 }, { 0, 0 }, poem_x, poem_mean))
    check("a vector equal to its average scores 0, not NaN",
        es.cosine_across_populations(word_mean, word_mean, poem_x, poem_mean) == 0)
end

print("centre once, compare many (Issue 10-035)")
do
    -- fixed pseudo-random vectors (a small LCG, the same on every machine)
    local x = 12345
    local function rnd()
        x = (x * 1103515245 + 12345) % 2147483648
        return x / 2147483648 - 0.5
    end
    local function vec(n) local v = {} for j = 1, n do v[j] = rnd() end return v end
    local dim = 64
    local a_mean, b_mean = vec(dim), vec(dim)
    local same, total = 0, 0
    for _ = 1, 50 do
        local a, b = vec(dim), vec(dim)
        local slow = es.cosine_across_populations(a, a_mean, b, b_mean)
        local fast = es.cosine_centred(es.centre_once(a, a_mean), es.centre_once(b, b_mean))
        total = total + 1
        if slow == fast then same = same + 1 end
    end
    check("the prepared score equals the one-step score to the last bit (50 pairs)", same == total,
        string.format("%d of %d equal", same, total))
    local flat = es.centre_once(a_mean, a_mean)
    check("a vector equal to its average scores 0", es.cosine_centred(flat, es.centre_once(vec(dim), b_mean)) == 0)
    check("a missing average is an error", not pcall(es.centre_once, vec(dim), nil))
    check("vectors of two lengths are an error", not pcall(es.centre_once, vec(dim), vec(dim + 1)))
end

print("fingerprint")
do
    local dir = "/tmp/embedding-space-test-" .. tostring(os.time())
    os.execute("mkdir -p " .. dir)

    check("an unmarked directory is NOT current", es.is_current(dir) == false)
    check("an unmarked directory reads back nil", es.read_fingerprint(dir) == nil)

    local ok, err = es.write_fingerprint(dir)
    check("stamping succeeds", ok == true, tostring(err))
    check("stamped directory reads back the version",
        es.read_fingerprint(dir) == es.SPACE_VERSION, tostring(es.read_fingerprint(dir)))
    check("stamped directory is current", es.is_current(dir) == true)

    -- A directory stamped with some OTHER version must read as stale. This is the
    -- case that matters when SPACE_VERSION is next changed.
    local f = io.open(es.fingerprint_path(dir), "w")
    f:write("some-older-space\n")
    f:close()
    check("a differently-stamped directory is NOT current", es.is_current(dir) == false)
    check("...and reports what it found", es.read_fingerprint(dir) == "some-older-space")

    os.execute("rm -rf " .. dir)
end

print("")
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
