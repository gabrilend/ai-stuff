--[[
Tests for the binary readers in compat.lua (Issue 118).

In plain terms: each reader (int32, uint32, int16, uint16, float, double)
reads known bytes to the right value, reads the last bytes of the data,
and, given data one byte too short, fails with an error that says the
data is truncated, where, and which parser line asked. LuaJIT and Lua 5.3+
take different paths through compat.lua, so when run under LuaJIT this
test also runs itself under lua5.4 (when installed) and passes only if
both do.

Usage: luajit src/tests/test_compat.lua [DIR]
       lua5.4 src/tests/test_compat.lua [DIR]
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local compat = require("compat")
-- }}}

-- {{{ Test infrastructure
local test_count, pass_count = 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end
-- }}}

-- {{{ The readers and known bytes
-- name, width, the bytes, the value they hold
local CASES = {
    { "int32", 4, "\254\255\255\255", -2 },
    { "uint32", 4, "\254\255\255\255", 4294967294 },
    { "int16", 2, "\0\128", -32768 },
    { "uint16", 2, "\52\18", 0x1234 },
    { "float", 4, "\0\0\96\192", -3.5 },
    { "double", 8, "\0\0\0\0\0\0\8\64", 3.0 },
}
-- }}}

test_section("Readers on " .. (type(jit) == "table" and "LuaJIT" or _VERSION))

for _, c in ipairs(CASES) do
    local name, width, bytes, value = c[1], c[2], c[3], c[4]
    local read = compat["unpack_" .. name]

    -- the value, and the position after it, from the middle of the data
    local v, next_pos = read("xx" .. bytes .. "yy", 3)
    test(name .. ": reads " .. tostring(value), v == value and next_pos == 3 + width,
        tostring(v) .. ", next " .. tostring(next_pos))

    -- the last bytes of the data, and the default position
    local last = read("abc" .. bytes, 4)
    test(name .. ": reads the data's last " .. width .. " bytes", last == value and read(bytes) == value)

    -- one byte short: an error naming the reader, the byte and the length
    local data = "abc" .. bytes:sub(1, width - 1)
    -- (not a tail call, as in a parser: a tail call leaves no line to name)
    local ok, err = pcall(function() local got = read(data, 4) return got end)
    err = tostring(err)
    test(name .. ": one byte short is named as truncated",
        not ok and err:find("truncated data", 1, true) and err:find(" " .. name .. " at byte 4 needs " .. width .. " bytes", 1, true)
        and err:find("the data is " .. (width + 2) .. " bytes long", 1, true), err)
    test(name .. ": the error points at the line that asked", not ok and err:find("test_compat.lua:%d+:") ~= nil, err)

    -- past the end entirely
    ok, err = pcall(read, bytes, #bytes + 1)
    test(name .. ": reading past the end fails the same way", not ok and tostring(err):find("truncated data", 1, true), tostring(err))
end

-- {{{ The other Lua
if type(jit) == "table" and arg[2] ~= "--child" then
    test_section("The same test under lua5.4")
    local found = os.execute("command -v lua5.4 > /dev/null 2>&1")
    if found == true or found == 0 then
        local script = DIR .. "/src/tests/test_compat.lua"
        local p = io.popen('lua5.4 "' .. script .. '" "' .. DIR .. '" --child 2>&1; echo "exit:$?"')
        local out = p:read("*a")
        p:close()
        local passed = out:match("exit:0%s*$") ~= nil
        if not passed then print(out) end
        test("lua5.4 (string.unpack) passes every reader test", passed)
    else
        print("  SKIPPED: lua5.4 isn't installed; the Lua 5.3+ path is untested here")
    end
end
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed", pass_count, test_count - pass_count))
if pass_count == test_count then
    print("ALL TESTS PASSED")
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}
