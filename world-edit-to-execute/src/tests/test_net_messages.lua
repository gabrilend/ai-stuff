-- test_net_messages.lua - every gameplay message survives the trip to bytes and back (issue 803)
--
-- In plain terms: the server and its clients only ever exchange bytes. This
-- checks that each kind of message comes back from its bytes exactly as it
-- was, that encoding it again gives the same bytes, and that damaged or
-- impossible messages are refused with a reason instead of guessed at.
--
-- Run with: luajit src/tests/test_net_messages.lua [DIR]

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local messages = require("net.messages")

-- {{{ Test utilities
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

-- {{{ local function same(a, b)
-- Deep equality of two decoded tables.
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
-- }}}

-- {{{ local function refused(fn, ...)
-- Whether the call raised an error, and its text.
local function refused(fn, ...)
    local ok, why = pcall(fn, ...)
    return not ok, tostring(why)
end
-- }}}
-- }}}

-- One example of every message, shared with the C unpacker's test.
local examples = require("net.message_examples")

print("\n=== Every message, to bytes and back ===")
for _, name in ipairs(messages.names) do
    local example = examples[name]
    if not example then
        test(name .. " has an example", false, "add one to this test")
    else
        local bytes = messages.encode(name, example)
        local back_name, back = messages.decode(bytes)
        test(name .. " comes back whole", back_name == name and same(back, example))
        test(name .. " encodes to the same bytes again", messages.encode(back_name, back) == bytes)
    end
end

print("\n=== Sizes, as they would cross a network ===")
local one_unit = messages.encode("unit_states", { tick = 1, units = { examples.unit_states.units[1] } })
local no_unit = messages.encode("unit_states", { tick = 1, units = {} })
test("a unit record is 43 bytes", #one_unit - #no_unit == 43, tostring(#one_unit - #no_unit))
test("a heard beat is 5 bytes", #messages.encode("heard", { tick = 1 }) == 5)

print("\n=== Floats come back as 32-bit floats ===")
local third = { tick = 1, units = { { id = 1, x = 1 / 3, y = 0, z = 0, vx = 0, vy = 0, vz = 0, facing = 0, anim = 0, anim_phase = 0, radius = 0.5, team = 0 } } }
local _, back = messages.decode(messages.encode("unit_states", third))
test("a third comes back as the nearest 32-bit float", back.units[1].x == messages.f32(1 / 3) and back.units[1].x ~= 1 / 3)

print("\n=== Refusals, with a reason ===")
local r, why
r, why = refused(messages.encode, "shout", {})
test("an unknown message name", r and why:find("no message is called shout"), why)
r, why = refused(messages.encode, "heard", {})
test("a missing field", r and why:find("heard.tick is missing"), why)
r, why = refused(messages.encode, "drop_vote", { player = 256 })
test("a number too big for its field", r and why:find("does not fit a u8"), why)
r, why = refused(messages.encode, "heard", { tick = 1.5 })
test("a fraction in a whole-number field", r and why:find("does not fit a u32"), why)
r, why = refused(messages.encode, "heard", { tick = -1 })
test("a negative number", r and why:find("does not fit"), why)
r, why = refused(messages.encode, "order", { order_id = 1, given_tick = 1, kind = 1, target_x = 0, target_y = 0, target_unit = 0, units = { {} } })
test("a missing field inside a list names its place", r and why:find("order.units%[1%].id is missing"), why)
r, why = refused(messages.decode, "")
test("empty bytes", r and why:find("empty"), why)
r, why = refused(messages.decode, string.char(99))
test("an unknown type byte", r and why:find("no message has type 99"), why)
local heard = messages.encode("heard", { tick = 905 })
r, why = refused(messages.decode, heard:sub(1, 3))
test("a message cut short", r and why:find("ends early"), why)
r, why = refused(messages.decode, heard .. "x")
test("bytes left over", r and why:find("1 bytes left over"), why)

print(string.format("\n%d/%d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
