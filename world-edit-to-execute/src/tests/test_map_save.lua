--[[
Tests for writing maps back (Issue 911a): little-endian writing, the
terrain, doodad and placed-unit files written back byte for byte on every
test map, a copy saved with changed and added files (in place in the
map's own archive, protected maps included, every other file the same),
the map read never written, and the rebuilt copy when patching can't be
done.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
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

local mpq = require("mpq")
local stormlib = require("mpq.stormlib")
local w3e = require("parsers.w3e")
local doo = require("parsers.doo")
local unitsdoo = require("parsers.unitsdoo")
local bw = require("parsers.binwrite")
local TMP = os.tmpname()
os.remove(TMP)

-- {{{ Writing values
test_section("Little-endian values")
do
    local b = bw.new():str("W3E!"):i32(11):i32(-2):f32(1.5):i16(-3):u16(65535):u8(7):done()
    local compat = require("compat")
    test("each as the readers read it", b:sub(1, 4) == "W3E!" and compat.unpack_int32(b, 5) == 11
        and compat.unpack_int32(b, 9) == -2 and compat.unpack_float(b, 13) == 1.5
        and compat.unpack_int16(b, 17) == -3 and compat.unpack_uint16(b, 19) == 65535 and b:byte(21) == 7 and #b == 21)
end
-- }}}

-- {{{ Round trips
test_section("Every test map's files written back byte for byte")
local maps = {}
for f in io.popen('ls "' .. DIR .. '"/assets/*.w3x 2>/dev/null'):lines() do maps[#maps + 1] = f end
do
    local ok_w3e, ok_doo, ok_units, n_units = 0, 0, 0, 0
    for _, f in ipairs(maps) do
        local a = mpq.open(f)
        local d = a:extract("war3map.w3e")
        if d and w3e.write(w3e.parse(d)) == d then ok_w3e = ok_w3e + 1 end
        d = a:extract("war3map.doo")
        local p = d and doo.parse(d)
        if p and doo.write(p) == d then ok_doo = ok_doo + 1 end
        d = a:extract("war3mapUnits.doo")
        if d then
            n_units = n_units + 1
            p = unitsdoo.parse(d)
            if p and unitsdoo.write(p) == d then ok_units = ok_units + 1 end
        end
        a:close()
    end
    test("terrain (war3map.w3e)", ok_w3e == #maps and #maps >= 10, ok_w3e .. " of " .. #maps)
    test("doodads (war3map.doo)", ok_doo == #maps, ok_doo .. " of " .. #maps)
    test("placed units (war3mapUnits.doo)", ok_units == n_units and n_units > 0, ok_units .. " of " .. n_units)
end
do
    -- an edited terrain: what's changed reads back changed, the rest as it was
    local a = mpq.open(DIR .. "/assets/Daow4.4.w3x")
    local t = w3e.parse(a:extract("war3map.w3e"))
    local p = unitsdoo.parse(a:extract("war3mapUnits.doo"))
    a:close()
    local tp = t.tilepoints[50][60]
    tp.height, tp.ground_texture, tp.has_water, tp.water_level = tp.height + 64, 3, true, tp.height + 100
    local back = w3e.parse(w3e.write(t))
    local bp = back.tilepoints[50][60]
    test("an edited tilepoint reads back as edited", bp.height == tp.height and bp.ground_texture == 3
        and bp.has_water and bp.water_level == tp.water_level)
    test("its neighbours as they were", back.tilepoints[50][61].height == t.tilepoints[50][61].height)
    -- a unit moved, and a new one copied from its kind
    p.units[1].position.x = p.units[1].position.x + 128
    p.units[#p.units + 1] = { id = "hfoo", variation = 0, position = { x = 1, y = 2, z = 3 }, angle = 1,
                              scale = { x = 1, y = 1, z = 1 }, flags = 2, player = 0, creation_number = 999 }
    local ok, bytes = pcall(unitsdoo.write, p)
    local q = ok and unitsdoo.parse(bytes)
    test("units: moved and added, read back", q and #q.units == #p.units and q.units[1].position.x == p.units[1].position.x
        and q.units[#q.units].id == "hfoo" and q.units[#q.units].creation_number == 999, tostring(bytes))
end
-- }}}

-- {{{ Saving a copy
test_section("Saving a copy")
local function every_file(path)
    local a = stormlib.open(path)
    local out = {}
    for _, e in ipairs(a:list("*")) do
        local ok, b = pcall(a.read, a, e.name)
        out[e.name] = ok and b or false
    end
    a:close()
    return out
end
for _, name in ipairs({ "DAoW-5.4b-PUBLIC-TEST.w3x", "Daow4.4.w3x" }) do
    local src = DIR .. "/assets/" .. name
    local a = mpq.open(src)
    local t = w3e.parse(a:extract("war3map.w3e"))
    a:close()
    t.tilepoints[20][20].height = t.tilepoints[20][20].height + 128
    local new_w3e = w3e.write(t)
    local ok, rep = mpq.save_copy(src, TMP, { ["war3map.w3e"] = new_w3e, ["war3mapEditor.txt"] = "hello" })
    test(name .. ": saved, in place", ok and rep.how == "patched" and rep.replaced == 1 and rep.added == 1,
        type(rep) == "table" and rep.how or tostring(rep))
    local before, after = every_file(src), every_file(TMP)
    -- by content: the copy holds every file the map held, but the
    -- terrain and listfile replaced, plus the one added
    local count = {}
    for _, b in pairs(after) do if b then count[b] = (count[b] or 0) + 1 end end
    local a0 = mpq.open(src)
    local old_w3e, old_list = a0:extract("war3map.w3e"), a0:extract("(listfile)")
    a0:close()
    local missing = 0
    for n, b in pairs(before) do
        if b and b ~= old_w3e and b ~= old_list then
            if (count[b] or 0) > 0 then count[b] = count[b] - 1 else missing = missing + 1 end
        end
    end
    test(name .. ": every other file there, the same", missing == 0, missing .. " missing")
    test(name .. ": the changed and added files read back", after["war3map.w3e"] == new_w3e and after["war3mapEditor.txt"] == "hello")
    local s = require("demo.wc3map.scene").load(TMP)
    test(name .. ": the copy loads as a map", s.terrain:get_tile(20, 20).height == t.tilepoints[20][20].height)
    os.remove(TMP)
end
do
    local src = DIR .. "/assets/Daow4.4.w3x"
    local ok, why = mpq.save_copy(src, src, {})
    test("never over the map it read", not ok and why:find("won't write over") ~= nil)
    local ok2, rep = mpq.rebuild_copy(src, TMP, { ["war3mapEditor.txt"] = "rebuilt" })
    local after = ok2 and every_file(TMP) or {}
    test("the rebuilt copy: named files carried over, the added one in", ok2 and rep.how == "rebuilt"
        and after["war3mapEditor.txt"] == "rebuilt" and after["war3map.w3e"] ~= nil and after["war3map.j"] ~= nil
            or after["scripts\\war3map.j"] ~= nil, type(rep) == "table" and rep.how or tostring(rep))
    local f = io.open(TMP, "rb")
    test("with the map's header in front", f and f:read(4) == "HM3W")
    if f then f:close() end
    os.remove(TMP)
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
