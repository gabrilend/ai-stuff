-- test_net_messages_c.lua - the C unpacker reads every message exactly as Lua wrote it (issue 804)
--
-- In plain terms: the renderer reads the server's messages in C, through a
-- header generated from the Lua message descriptions. This generates that
-- header, then writes a small C program holding the bytes of one example of
-- every message (as Lua encodes them) and every value Lua says is in them,
-- compiles it, and runs it. The C side must read every value back exactly
-- (floats bit for bit), and refuse a message cut short and a list with too
-- little room.
--
-- Run with: luajit src/tests/test_net_messages_c.lua [DIR]
-- Builds in DIR/tmp/net/.

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local ffi = require("ffi")
local messages = require("net.messages")
local examples = require("net.message_examples")

local BUILD = DIR .. "/tmp/net"
-- {{{ local function run(command)
-- os.execute answers 0 on success, or true where LuaJIT was built with
-- Lua 5.2's conventions; either counts.
local function run(command)
    local ok = os.execute(command)
    if ok ~= 0 and ok ~= true then error("failed: " .. command, 0) end
end
-- }}}

run("mkdir -p " .. BUILD)

run(string.format("luajit %s/src/net/messages-c.lua %s > %s/net-messages.h", DIR, DIR, BUILD))

local bits = ffi.new("union { float f; uint32_t u; }")
local out = {}
-- {{{ local function w(...)
local function w(...) out[#out + 1] = string.format(...) end
-- }}}

w('#include <stdio.h>')
w('#include "net-messages.h"')
w('static int failures = 0;')
w('static void expect(int ok, const char *what) { printf("%%s  %%s\\n", ok ? "pass" : "FAIL", what); if (!ok) failures++; }')
w('static uint32_t bits_of(float f) { uint32_t u; memcpy(&u, &f, 4); return u; }')
w('int main(void)')
w('{')

-- {{{ local function check(target, kind, value)
-- The C condition that `target` holds `value` exactly.
local function check(target, kind, value)
    if kind == "f32" then
        bits.f = value
        return string.format("bits_of(%s) == 0x%08xu", target, tonumber(bits.u))
    end
    return string.format("%s == %.0fu", target, value)
end
-- }}}

local by_name = {}
for _, d in ipairs(messages.descriptions) do by_name[d[2]] = d end

for _, name in ipairs(messages.names) do
    local d = by_name[name]
    local bytes = messages.encode(name, examples[name])
    local list = {}
    for i = 1, #bytes do list[i] = tostring(bytes:byte(i)) end
    w('    {')
    w('        static const uint8_t b[] = { %s };', table.concat(list, ", "))
    w('        net_%s m;', name)
    w('        memset(&m, 0, sizeof m);')
    for _, f in ipairs(d[3]) do
        if f[2] == "list" then
            w('        net_%s_%s %s_records[8];', name, f[1], f[1])
            w('        m.%s = %s_records; m.%s_room = 8;', f[1], f[1], f[1])
        end
    end
    w('        const char *why = net_decode_%s(b, sizeof b, &m);', name)
    w('        expect(why == NULL, "%s is read without refusal");', name)
    local conditions = {}
    for _, f in ipairs(d[3]) do
        local value = examples[name][f[1]]
        if f[2] == "list" then
            conditions[#conditions + 1] = string.format("m.%s_count == %d", f[1], #value)
            for i, record in ipairs(value) do
                for _, rf in ipairs(f[3]) do
                    conditions[#conditions + 1] = check(string.format("m.%s[%d].%s", f[1], i - 1, rf[1]), rf[2], record[rf[1]])
                end
            end
        else
            conditions[#conditions + 1] = check("m." .. f[1], f[2], value)
        end
    end
    w('        expect(why == NULL && %s, "%s: every value as Lua wrote it");', table.concat(conditions, " && "), name)
    w('    }')
end

-- refusals, on the unit states example
do
    local bytes = messages.encode("unit_states", examples.unit_states)
    local list = {}
    for i = 1, #bytes do list[i] = tostring(bytes:byte(i)) end
    w('    {')
    w('        static const uint8_t b[] = { %s };', table.concat(list, ", "))
    w('        net_unit_states_units r[8];')
    w('        net_unit_states m = { .units = r, .units_room = 8 };')
    w('        const char *why = net_decode_unit_states(b, sizeof b - 1, &m);')
    w('        expect(why && strstr(why, "ends early"), "a message cut short is refused");')
    w('        m.units_room = 1;')
    w('        why = net_decode_unit_states(b, sizeof b, &m);')
    w('        expect(why && strstr(why, "more records than room"), "a list with too little room is refused");')
    w('        m.units_room = 8;')
    w('        why = net_decode_heard(b, sizeof b, (net_heard *)&m);')
    w('        expect(why && strstr(why, "not this message"), "another message\'s bytes are refused");')
    w('    }')
end
w('    return failures ? 1 : 0;')
w('}')

local f = assert(io.open(BUILD .. "/test-net-messages.c", "w"))
f:write(table.concat(out, "\n"), "\n")
f:close()
run(string.format("cc -std=gnu11 -O1 -Wall -Wextra -Werror -I%s %s/test-net-messages.c -o %s/test-net-messages", BUILD, BUILD, BUILD))
local result = io.popen(BUILD .. "/test-net-messages")
local text = result:read("*a")
local ok = result:close()
io.write(text)
local passed, total = 0, 0
for line in text:gmatch("[^\n]+") do
    total = total + 1
    if line:match("^pass") then passed = passed + 1 end
end
print(string.format("\n%d/%d passed", passed, total))
os.exit((passed == total and total > 0) and 0 or 1)
