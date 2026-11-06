#!/usr/bin/env luajit
-- test_unit_visuals.lua - each unit type's art fields from object data (issue 503b)
--
-- Runs the real stock_rows.load and merge over a stand-in chain of small
-- hand-written SLK tables (a metadata table naming each field's table and
-- column, and UnitUI/UnitData rows), so nothing needs the player's install:
-- a stock type's model, scale, tint and selection come from its row; a map's
-- changes win and are marked as the map's; a field kept in a profile file
-- is found there; the placeholder shape follows building, flyer and size;
-- unknown types and fields the metadata lacks are reported.
--
-- When the Frozen Throne install and the 1.29.2 layer are present, a few
-- stock types are also read through the real chain.
--
-- Run: luajit src/tests/test_unit_visuals.lua [DIR]
-- Issue: issues/503b-unit-visual-mappings.md

-- {{{ Setup
-- The project folder: the argument, else the one this file sits in (so the
-- test runner, which passes none, tests its own checkout), else the default.
local DIR = arg[1] or (arg[0] or ""):match("^(.*)/src/tests/[^/]*$")
    or ((arg[0] or ""):match("^src/tests/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local stock_rows = require("gamedata.stock_rows")
local unit_visuals = require("gamedata.unit_visuals")
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
        print("  [FAIL] " .. name .. (msg and ": " .. tostring(msg) or ""))
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

-- {{{ Stand-ins
-- An SLK table from a header and rows (each a list of values; strings are
-- quoted, numbers not).
local function sheet(header, rows)
    local lines = { "ID;PWXL;N;E" }
    local function cell(x, y, v)
        local k = type(v) == "number" and tostring(v) or ('"' .. tostring(v) .. '"')
        lines[#lines + 1] = string.format("C;Y%d;X%d;K%s", y, x, k)
    end
    for x, name in ipairs(header) do cell(x, 1, name) end
    for y, row in ipairs(rows) do
        for x, v in ipairs(row) do cell(x, y + 1, v) end
    end
    lines[#lines + 1] = "E"
    return table.concat(lines, "\n")
end

local META_HEADER = { "ID", "field", "slk", "index", "repeat", "data", "type" }
local function metadata(model_table, model_field)
    return sheet(META_HEADER, {
        { "umdl", model_field, model_table, 0, 0, 0, "model" },
        { "usca", "modelScale", "UnitUI", 0, 0, 0, "unreal" },
        { "uclr", "red", "UnitUI", 0, 0, 0, "int" },
        { "uclg", "green", "UnitUI", 0, 0, 0, "int" },
        { "uclb", "blue", "UnitUI", 0, 0, 0, "int" },
        { "ussc", "scale", "UnitUI", 0, 0, 0, "unreal" },
        { "ubdg", "isbldg", "UnitUI", 0, 0, 0, "bool" },
        { "umvt", "movetp", "UnitData", 0, 0, 0, "moveType" },
        { "unam", "Name", "Profile", 0, 0, 0, "string" },
    })
end

local UNIT_UI = sheet({ "unitUIID", "file", "modelScale", "red", "green", "blue", "scale", "isbldg" }, {
    { "hfoo", "units\\human\\Footman\\Footman", 1, 255, 255, 255, 1, 0 },
    { "hbar", "buildings\\human\\HumanBarracks\\HumanBarracks", 1, 255, 255, 255, 4, 1 },
    { "hgry", "units\\human\\GryphonRider\\GryphonRider", 1.1, 255, 255, 255, 2.25, 0 },
    { "otau", "units\\orc\\Tauren\\Tauren", 1.2, 255, 255, 255, 1.75, 0 },
    { "nblk", "_", 1, 255, 255, 255, 1, 0 },
})
local UNIT_DATA = sheet({ "unitID", "movetp" }, {
    { "hfoo", "foot" }, { "hbar", "_" }, { "hgry", "fly" }, { "otau", "foot" }, { "nblk", "foot" },
})

local function fake_chain(files)
    local c = { files = files, layer = "test" }
    function c:find(path)
        if self.files[path] then return "layer test", path end
        return nil
    end
    function c:read(path)
        local text = self.files[path]
        if not text then error("nothing has " .. path) end
        return text, "layer test"
    end
    return c
end

local function files_with(meta)
    local empty = sheet({ "unitID" }, {})
    return {
        ["Units\\UnitMetaData.slk"] = meta,
        ["Units\\UnitUI.slk"] = UNIT_UI,
        ["Units\\UnitData.slk"] = UNIT_DATA,
        ["Units\\UnitBalance.slk"] = sheet({ "unitBalanceID" }, {}),
        ["Units\\UnitWeapons.slk"] = sheet({ "unitWeapID" }, {}),
        ["Units\\UnitAbilities.slk"] = sheet({ "unitAbilID" }, {}),
        _ = empty,
    }
end

-- A parsed war3map.w3u: h000 is a custom footman, rescaled and tinted red;
-- hfoo itself has its model changed in place.
local PARSED = {
    custom = {
        h000 = { original_id = "hfoo", modifications = {
            { field_id = "usca", value = 2.5 },
            { field_id = "uclg", value = 0 },
            { field_id = "uclb", value = 0 },
        } },
        h001 = { original_id = "hgry", modifications = { { field_id = "umvt", value = "foot" } } },
    },
    original = {
        otau = { modifications = { { field_id = "umdl", value = "war3mapImported\\BigTauren.mdx" } } },
    },
}
-- }}}

-- {{{ Stock types and the map's changes
test_section("rows from the stock tables, the map's changes on top")
do
    local stock = stock_rows.load(fake_chain(files_with(metadata("UnitUI", "file"))), "units")
    local merged = stock_rows.merge(stock, PARSED)
    local result = unit_visuals.for_types(stock, merged, { "hfoo", "hbar", "hgry", "h000", "h001", "otau", "hfoo", "nblk" })
    local r = result.rows

    test("a stock type's model path comes from its row", r.hfoo and r.hfoo.model == "units\\human\\Footman\\Footman",
        r.hfoo and r.hfoo.model)
    test("its scale, tint and selection too", r.hfoo and r.hfoo.scale == 1 and r.hfoo.tint.r == 255
        and r.hfoo.tint.g == 255 and r.hfoo.tint.b == 255 and r.hfoo.selection == 1)
    test("a stock type changed by nothing is marked as nobody's change", r.hfoo and next(r.hfoo.from_map) == nil)
    test("its parent is itself", r.hfoo and r.hfoo.parent == "hfoo")

    test("a custom type has its parent's model", r.h000 and r.h000.model == "units\\human\\Footman\\Footman")
    test("and the map's scale", r.h000 and r.h000.scale == 2.5, r.h000 and r.h000.scale)
    test("and the map's tint", r.h000 and r.h000.tint.r == 255 and r.h000.tint.g == 0 and r.h000.tint.b == 0)
    test("the changed fields are marked as the map's", r.h000 and r.h000.from_map.scale and r.h000.from_map.green
        and r.h000.from_map.blue and not r.h000.from_map.red and not r.h000.from_map.model)
    test("its parent is named", r.h000 and r.h000.parent == "hfoo")

    test("a stock type changed in place has the map's model", r.otau and r.otau.model == "war3mapImported\\BigTauren.mdx")
    test("marked as the map's", r.otau and r.otau.from_map.model == true)

    test("a building is a building", r.hbar and r.hbar.building == true and r.hfoo.building == false)
    test("a flyer flies", r.hgry and r.hgry.flyer == true and r.hgry.move_type == "fly")
    test("a type the map grounds doesn't", r.h001 and r.h001.flyer == false and r.h001.move_type == "foot")
    test("a building's empty move type reads as none", r.hbar and r.hbar.move_type == "")
    test("an empty model path ('_') reads as none", r.nblk and r.nblk.model == nil)

    test("the shapes: building cube", r.hbar and r.hbar.shape == "cube")
    test("flyer triangle", r.hgry and r.hgry.shape == "triangle")
    test("large ground unit cylinder", r.otau and r.otau.shape == "cylinder")
    test("small ground unit circle", r.hfoo and r.hfoo.shape == "circle")
    test("a grounded copy of a flyer is sized, not flying", r.h001 and r.h001.shape == "cylinder")

    test("each type is read once", result.counts.types == 7, result.counts.types)
    test("three types carry the map's changes", result.counts.from_map == 3, result.counts.from_map)
    test("no problems", #result.problems == 0, #result.problems)
end
-- }}}

-- {{{ The model in a profile file
test_section("a version that keeps the model path in a profile file")
do
    local files = files_with(metadata("Profile", "file"))
    files["Units\\HumanUnitFunc.txt"] = "[hfoo]\nfile=units\\human\\Footman\\Footman_V2\n"
    local stock = stock_rows.load(fake_chain(files), "units")
    local row = unit_visuals.of(stock, { rows = {} }, "hfoo")
    test("the model comes from the profile entry", row and row.model == "units\\human\\Footman\\Footman_V2",
        row and row.model)
    local plain = unit_visuals.of(stock, nil, "hbar")
    test("a type no profile names has no model", plain and plain.model == nil)
end
-- }}}

-- {{{ Problems
test_section("problems are reported, not skipped")
do
    local stock = stock_rows.load(fake_chain(files_with(metadata("UnitUI", "file"))), "units")
    local result = unit_visuals.for_types(stock, { rows = {} }, { "zzzz", "hfoo", "zzzz" })
    test("an unknown type is a problem, reported once", #result.problems == 1 and result.problems[1].kind == "unknown_type"
        and result.problems[1].id == "zzzz" and result.counts.unknown == 1, #result.problems)
    test("it has no row", result.rows.zzzz == nil)
    test("the known type still has its row", result.rows.hfoo ~= nil)
    local row, problem = unit_visuals.of(stock, nil, "zzzz")
    test("of gives nil and the problem", row == nil and problem and problem.problem:find("zzzz", 1, true))

    local thin = sheet(META_HEADER, {
        { "umdl", "file", "UnitUI", 0, 0, 0, "model" },
        { "ubdg", "isbldg", "UnitUI", 0, 0, 0, "bool" },
    })
    local stock2 = stock_rows.load(fake_chain(files_with(thin)), "units")
    local r2 = unit_visuals.for_types(stock2, { rows = {} }, { "hfoo", "otau", "hbar" })
    test("fields the metadata lacks fall back to defaults", r2.rows.otau and r2.rows.otau.scale == 1
        and r2.rows.otau.selection == 1 and r2.rows.otau.tint.r == 255 and r2.rows.otau.tint.g == 255
        and r2.rows.otau.tint.b == 255 and r2.rows.otau.move_type == "" and r2.rows.otau.flyer == false)
    test("and are listed on the row", r2.rows.otau and #r2.rows.otau.no_metadata == 6, r2.rows.otau and #r2.rows.otau.no_metadata)
    test("one problem per missing code, not per type", #r2.problems == 6, #r2.problems)
    test("in field order", r2.problems[1] and r2.problems[1].code == "usca" and r2.problems[6].code == "umvt"
        and r2.problems[1].kind == "no_metadata")
    test("fields it has still read", r2.rows.hbar and r2.rows.hbar.building == true
        and r2.rows.hbar.model == "buildings\\human\\HumanBarracks\\HumanBarracks")
end
-- }}}

-- {{{ The placeholder rule alone
test_section("the placeholder rule")
do
    local p = unit_visuals.placeholder
    test("building wins over flying", p({ building = true, flyer = true, selection = 9 }) == "cube")
    test("flying wins over size", p({ building = false, flyer = true, selection = 9 }) == "triangle")
    test("at the threshold, a cylinder", p({ selection = unit_visuals.LARGE_SELECTION }) == "cylinder")
    test("just under it, a circle", p({ selection = unit_visuals.LARGE_SELECTION - 0.01 }) == "circle")
    test("no size at all, a circle", p({}) == "circle")
    test("the threshold is 1.5", unit_visuals.LARGE_SELECTION == 1.5)
end
-- }}}

-- {{{ Values written in other forms
test_section("values written in other forms")
do
    local stock = { metadata = { rows = {
        ubdg = { slk = "UnitUI", field = "isbldg" }, ussc = { slk = "UnitUI", field = "scale" },
        usca = { slk = "UnitUI", field = "modelScale" }, umvt = { slk = "UnitData", field = "movetp" },
        umdl = { slk = "UnitUI", field = "file" }, uclr = { slk = "UnitUI", field = "red" },
        uclg = { slk = "UnitUI", field = "green" }, uclb = { slk = "UnitUI", field = "blue" },
    } }, tables = {} }
    local function row_of(ui, data)
        return unit_visuals.of(stock, { rows = { x = { id = "x", parent = "p", fields = { UnitUI = ui, UnitData = data } } } }, "x")
    end
    test("a building flag written as text", row_of({ isbldg = "1" }, {}).building == true)
    test("a building flag written true", row_of({ isbldg = true }, {}).building == true)
    test("zero as text isn't a building", row_of({ isbldg = "0" }, {}).building == false)
    test("a number written as text", row_of({ modelScale = "0.75", scale = "2" }, {}).scale == 0.75)
    test("an unreadable number falls back", row_of({ modelScale = "big" }, {}).scale == 1)
    test("a zero tint stays zero", row_of({ red = 0 }, {}).tint.r == 0)
    test("an empty model path reads as none", row_of({ file = "" }, {}).model == nil)
    test("a model path that isn't text reads as none", row_of({ file = 5 }, {}).model == nil)
    test("a move type that isn't text reads as none", row_of({}, { movetp = 0 }).move_type == "")
    test("a merged row without labels has nothing from the map", next(row_of({ red = 3 }, {}).from_map) == nil)
end
-- }}}

-- {{{ The real chain
test_section("the real chain (needs the install)")
do
    local INSTALL = DIR .. "/wc3-installs/frozen-throne"
    local LAYERS = DIR .. "/wc3-installs/patch-layers"
    local probe = io.open(LAYERS .. "/1.29.2/manifest.lua", "r")
    local mpq_probe = io.open(INSTALL .. "/War3x.mpq", "rb")
    if not probe or not mpq_probe then
        skip("stock types through the real chain", "needs the Frozen Throne install and the 1.29.2 layer")
    else
        probe:close(); mpq_probe:close()
        local chain = require("gamedata.chain")
        local c = chain.open({ install = INSTALL, layers = LAYERS, layer = "1.29.2",
            w3i = { version = 25, editor_version = 0, game_data_set = 1, flags = { melee_map = false } } })
        local stock = stock_rows.load(c, "units")
        local result = unit_visuals.for_types(stock, { rows = {} }, { "hfoo", "hbar", "hgry" })
        test("the footman has a model path", result.rows.hfoo and type(result.rows.hfoo.model) == "string")
        test("the barracks is a building", result.rows.hbar and result.rows.hbar.shape == "cube")
        test("the gryphon rider flies", result.rows.hgry and result.rows.hgry.shape == "triangle")
        test("no problems", #result.problems == 0, #result.problems)
        c:close()
    end
end
-- }}}

print(string.format("\n%d tests: %d passed, %d failed, %d skipped", test_count, pass_count, fail_count, skip_count))
if fail_count > 0 then os.exit(1) end
