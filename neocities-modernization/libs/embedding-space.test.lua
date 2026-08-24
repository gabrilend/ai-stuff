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
-- Usage: luajit libs/embedding-space.test.lua [DIR]
-- }}}

local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
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
