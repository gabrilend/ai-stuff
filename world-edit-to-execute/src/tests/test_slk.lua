#!/usr/bin/env luajit
-- test_slk.lua - SLK spreadsheet and profile text parsers
--
-- Small hand-made files cover the format's rules; then the real stock tables
-- are read through a map's game data chain when the install is present
-- (skipped with a loud notice otherwise).
--
-- Run: luajit src/tests/test_slk.lua [DIR]
-- Issue: issues/completed/112c-route-a-stock-rows-merged-with-map-objects.md

-- {{{ Setup
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local slk = require("parsers.slk")
local profile = require("parsers.profile_txt")
-- }}}

-- {{{ Test utilities
local test_count, pass_count, fail_count, skip_count = 0, 0, 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        fail_count = fail_count + 1
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

local function skip(name, reason)
    skip_count = skip_count + 1
    print("  [SKIP] " .. name .. " -- " .. reason .. " --")
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end
-- }}}

-- {{{ Tests: SLK rules
test_section("SLK format rules")
local sample = table.concat({
    'ID;PWXL;N;E',
    'B;X3;Y4;D0',
    'C;X1;Y1;K"alias"',
    'C;X2;K"levels"',
    'C;X3;K"note"',
    'C;X1;Y2;K"AHbz"',
    'C;X2;K3',
    'C;X3;K"a;;b"',
    'F;P0;FG0G;X1',
    'C;Y3;X1;K"AHmt"',
    'C;X2;K1.5',
    'C;X1;Y4;K"AHtb"',
    'E',
}, "\r\n")
local sheet = slk.parse(sample)
test("column names from row 1", sheet.columns[1] == "alias" and sheet.columns[2] == "levels")
test("rows keyed by column 1", sheet.rows.AHbz ~= nil and sheet.rows.AHmt ~= nil)
test("a cell leaving out Y stays on the row", sheet.rows.AHbz.levels == 3)
test("an unquoted value is a number", type(sheet.rows.AHmt.levels) == "number" and sheet.rows.AHmt.levels == 1.5)
test("fields may come in any order (Y before X)", sheet.rows.AHmt.alias == "AHmt")
test('";;" inside a quoted value is ";"', sheet.rows.AHbz.note == "a;b", tostring(sheet.rows.AHbz.note))
test("formatting records are skipped", sheet.rows.AHbz.alias == "AHbz")
test("row order kept", table.concat(sheet.order, ",") == "AHbz,AHmt,AHtb")
test("a file without the ID header is refused", not pcall(slk.parse, "C;X1;Y1;K1\r\n"))
-- }}}

-- {{{ Tests: profile text rules
test_section("Profile text rules")
local objects = profile.parse(table.concat({
    "// comment",
    "[hfoo]",
    "Missilespeed=900",
    "Buttonpos=0,0",
    "",
    "[hkni]",
    "Name=Knight",
}, "\r\n"))
test("sections and keys", objects.hfoo.Missilespeed == "900" and objects.hkni.Name == "Knight")
test("lists stay as text", objects.hfoo.Buttonpos == "0,0")
profile.parse("[hfoo]\r\nMissilespeed=1000\r\nArt=x.blp\r\n", objects)
test("a later file adds keys and overrides values", objects.hfoo.Missilespeed == "1000" and objects.hfoo.Art == "x.blp"
    and objects.hfoo.Buttonpos == "0,0")
-- }}}

-- {{{ Tests: the real stock tables through a chain
test_section("Real stock tables (1.21b, Frozen Throne custom data set)")
local INSTALL = DIR .. "/wc3-installs/frozen-throne"
local probe = io.open(INSTALL .. "/War3x.mpq", "rb")
if not probe then
    skip("real stock tables", "no Frozen Throne install at " .. INSTALL)
else
    probe:close()
    local chain = require("gamedata.chain")
    local c = chain.open({ install = INSTALL, layers = DIR .. "/wc3-installs/patch-layers",
        w3i = { version = 25, editor_version = 0, game_data_set = 1, flags = { melee_map = false } }, layer = "1.21b" })
    local abilities = slk.parse((c:read("Units\\AbilityData.slk")))
    test("AbilityData.slk has hundreds of abilities", #abilities.order > 500, tostring(#abilities.order))
    local bolt = abilities.rows.AHtb
    test("Storm Bolt (AHtb) has 3 levels", bolt and bolt.levels == 3, bolt and tostring(bolt.levels))
    test("Storm Bolt level 1 cooldown is 9 seconds", bolt and bolt.Cool1 == 9, bolt and tostring(bolt.Cool1))
    local meta = slk.parse((c:read("Units\\AbilityMetaData.slk")))
    test("ability metadata maps acdn to the Cool field", meta.rows.acdn and meta.rows.acdn.field == "Cool",
        meta.rows.acdn and tostring(meta.rows.acdn.field))
    local func = profile.parse((c:read("Units\\HumanUnitFunc.txt")))
    test("HumanUnitFunc.txt has a footman section", func.hfoo ~= nil)
    c:close()
end
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed, %d total (%d skipped)",
    pass_count, fail_count, test_count, skip_count))
if fail_count > 0 then
    print("SOME TESTS FAILED")
    os.exit(1)
else
    print("ALL TESTS PASSED")
    os.exit(0)
end
-- }}}
