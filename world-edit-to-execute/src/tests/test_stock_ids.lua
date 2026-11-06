#!/usr/bin/env luajit
-- test_stock_ids.lua - base-game ids looked up in the map's stock tables (issue 112)
--
-- The validator meets ids a map uses but doesn't define, and asks
-- gamedata/stock_ids.lua whether the game defines them. Here the chain is a
-- stand-in holding small hand-written SLK tables, so nothing needs the
-- player's install: listed ids are valid, unlisted ones are errors naming
-- the id and the layer searched, a table the chain lacks leaves the id
-- unchecked with a warning naming the table, and random placeholders are
-- never looked up. Without a lookup the old behaviour stands (assumed
-- valid), with one warning that counts them.
--
-- When the Frozen Throne install and the 1.29.2 layer are present, a few
-- known ids are also looked up through the real chain.
--
-- Run: luajit src/tests/test_stock_ids.lua [DIR]
-- Issue: issues/112-stock-object-tables-by-two-routes.md

-- {{{ Setup
-- The project folder: the argument, else the one this file sits in (so the
-- test runner, which passes none, tests its own checkout), else the default.
local DIR = arg[1] or (arg[0] or ""):match("^(.*)/src/tests/[^/]*$")
    or ((arg[0] or ""):match("^src/tests/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local stock_ids = require("gamedata.stock_ids")
local validation = require("validation")
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

-- {{{ Stand-ins
-- An SLK table whose first column lists the given ids.
local function sheet(column, ids)
    local lines = { "ID;PWXL;N;E", 'C;Y1;X1;K"' .. column .. '"', 'C;X2;K"comment"' }
    for i, id in ipairs(ids) do
        lines[#lines + 1] = string.format('C;Y%d;X1;K"%s"', i + 1, id)
        lines[#lines + 1] = 'C;X2;K"x"'
    end
    lines[#lines + 1] = "E"
    return table.concat(lines, "\n")
end

-- A chain holding the given files (path -> text), counting reads. Its
-- layer and data set are what a real chain carries.
local function fake_chain(files, layer, data_set)
    local c = { files = files, reads = 0, finds = 0, layer = layer, data_set = data_set }
    function c:find(path)
        self.finds = self.finds + 1
        if self.files[path] then return "layer " .. tostring(self.layer), path end
        return nil
    end
    function c:read(path)
        self.reads = self.reads + 1
        local text = self.files[path]
        if not text then error("nothing has " .. path) end
        return text, "layer " .. tostring(self.layer)
    end
    return c
end

local FILES = {
    ["Units\\UnitData.slk"] = sheet("unitID", { "hfoo", "hpea", "Hpal", "sloc" }),
    ["Units\\ItemData.slk"] = sheet("itemID", { "ratc", "phea" }),
    ["Units\\AbilityData.slk"] = sheet("alias", { "AHbz", "Aatk" }),
    ["Units\\DestructableData.slk"] = sheet("DestructableID", { "LTlt", "ATtr" }),
    ["Doodads\\Doodads.slk"] = sheet("doodID", { "APms" }),
}

local function copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

local function empty_db()
    return { has = function() return false end, get_type = function() return nil end }
end

local function map_with(config)
    return {
        object_data = empty_db(),
        registry = {
            units = config.units or {},
            doodads = config.doodads or {},
            regions = {},
            sounds = {},
        },
    }
end

local function find_message(list, pattern)
    for _, entry in ipairs(list) do
        if entry.message:find(pattern) then return entry end
    end
    return nil
end
-- }}}

-- {{{ The lookup
test_section("stock_ids over a chain")
do
    local c = fake_chain(copy(FILES), "1.29.2", "Custom_V1")
    local stock = stock_ids.from_chain(c)
    test("nothing is read until a kind is asked about", c.reads == 0, tostring(c.reads))
    test("a listed unit is found", stock:has("unit", "hfoo") == true)
    test("an unlisted unit is not", stock:has("unit", "hxxx") == false)
    test("the column's header is not an id", stock:has("unit", "unitID") == false)
    test("each table is read once", (function()
        stock:has("unit", "hpea"); stock:has("unit", "zzzz")
        return c.reads == 1
    end)(), tostring(c.reads))
    test("ids are kept exactly (case counts)", stock:has("unit", "HFOO") == false and stock:has("unit", "Hpal") == true)
    test("what was searched names the layer and the data set",
        stock.searched == "patch layer 1.29.2, data set Custom_V1", stock.searched)
    test("find gives the first kind that lists it", stock:find({ "unit", "item" }, "ratc") == "item")
    test("find prefers the first kind", stock:find({ "unit", "item" }, "hfoo") == "unit")
    test("find gives false when every table was read", stock:find({ "unit", "item" }, "qqqq") == false)
    test("an unknown kind is refused", not pcall(stock.has, stock, "upgrade", "Rhme"))
    test("no table is missing", stock:missing("unit") == nil and stock:missing("doodad") == nil)
end

do
    local files = copy(FILES)
    files["Doodads\\Doodads.slk"] = nil
    local c = fake_chain(files, nil, nil)
    local stock = stock_ids.from_chain(c)
    test("an unpatched chain says so", stock.searched == "no patch layer, the plain melee tables", stock.searched)
    test("a table the chain lacks gives nil, not false", stock:has("doodad", "APms") == nil)
    test("and names the missing table", stock:missing("doodad") == "Doodads\\Doodads.slk")
    test("find over a missing table and a read one gives the read one's answer",
        stock:find({ "doodad", "destructible" }, "LTlt") == "destructible")
    test("find gives nil when the answer isn't known", stock:find({ "doodad", "destructible" }, "qqqq") == nil)
    test("a missing table is asked about only once", (function()
        local reads, finds = c.reads, c.finds
        stock:has("doodad", "APms"); stock:has("doodad", "XXXX"); stock:missing("doodad")
        return c.reads == reads and c.finds == finds
    end)())
end

do
    test("from_chain refuses something that isn't a chain", not pcall(stock_ids.from_chain, {}))
    test("from_chain refuses a chain that can't read", not pcall(stock_ids.from_chain, { find = function() end }))
    test("from_chain refuses a chain that can't find", not pcall(stock_ids.from_chain, { read = function() end }))
    local stock = stock_ids.from_sets({ unit = { hfoo = true } }, "a hand-made list")
    test("from_sets answers from its sets", stock:has("unit", "hfoo") == true and stock:has("unit", "hpea") == false)
    test("from_sets treats a kind left out as missing", stock:has("item", "ratc") == nil
        and stock:missing("item") == "Units\\ItemData.slk")
    test("from_sets keeps its description", stock.searched == "a hand-made list")
end

do
    local p = stock_ids.is_random_placeholder
    test("random placeholders are recognised",
        p("YYU1") and p("YYIA") and p("uDNR") and p("bDNR") and p("iDNR"))
    test("real ids are not placeholders", not p("hfoo") and not p("YYYY") and not p("Hpal") and not p("YYU") and not p(nil))
end
-- }}}

-- {{{ The validator with stock tables
test_section("the validator looks base-game ids up")
do
    local stock = stock_ids.from_chain(fake_chain(copy(FILES), "1.29.2", "Custom_V1"))
    local map = map_with({
        units = {
            { id = "hfoo", creation_number = 1, position = { x = 0, y = 0 } },
            { id = "ratc", creation_number = 2, position = { x = 64, y = 0 } },            -- an item on the ground
            { id = "hxyz", creation_number = 3, position = { x = 128, y = 0 }, player = 0 }, -- in no table
            { id = "YYU3", creation_number = 4, position = { x = 0, y = 64 } },            -- a random unit
            { id = "Hpal", creation_number = 5, position = { x = 0, y = 128 },
              abilities = { { id = "AHbz", level = 1 }, { id = "AHzz", level = 1 } },
              item_drops = { sets = { { items = { { id = "phea" }, { id = "pzzz" }, { id = "iDNR" } } } } } },
        },
        doodads = {
            { id = "LTlt", creation_number = 6, position = { x = 0, y = 0 } },   -- a destructable
            { id = "APms", creation_number = 7, position = { x = 0, y = 0 } },   -- a doodad
            { id = "ZZzz", creation_number = 8, position = { x = 0, y = 0 } },   -- neither
        },
    })
    local report = validation.validate_map(map, { stock = stock })
    test("four ids missing from every table are errors", #report.errors == 4, tostring(#report.errors))
    local unit_err = find_message(report.errors, "'hxyz'")
    test("the unit's error names the id and the layer",
        unit_err and unit_err.category == "unit_placement" and unit_err.message:find("1.29.2", 1, true)
        and unit_err.message:find("not found", 1, true)
        and unit_err.details.searched == stock.searched, unit_err and unit_err.message)
    test("the doodad's error is a doodad placement", (find_message(report.errors, "'ZZzz'") or {}).category == "doodad_placement")
    test("the ability's error is an ability reference", (find_message(report.errors, "'AHzz'") or {}).category == "ability_reference")
    test("the dropped item's error is an item drop", (find_message(report.errors, "'pzzz'") or {}).category == "item_drop")
    test("an item placed on the ground is valid", not find_message(report.errors, "'ratc'"))
    test("a destructable placed as a doodad is valid", not find_message(report.errors, "'LTlt'"))
    test("random placeholders are valid without a lookup",
        not find_message(report.errors, "YYU3") and not find_message(report.errors, "iDNR"))
    test("no warnings when every table was there", #report.warnings == 0, tostring(#report.warnings))
    test("nothing was assumed", report.stats.stock_assumed == 0)
    -- hfoo, ratc, YYU3, Hpal, AHbz, phea, iDNR, LTlt, APms
    test("the rest count as valid", report.stats.valid == 9, tostring(report.stats.valid))
    test("the report is failed", not report:is_valid())
    local text = validation.format_report(report)
    test("the printed report says where ids were looked up",
        text:find("Region sounds: 0\n  Stock ids looked up in: patch layer 1.29.2, data set Custom_V1\n\n", 1, true) ~= nil, text)
end

do
    local files = copy(FILES)
    files["Doodads\\Doodads.slk"] = nil
    local stock = stock_ids.from_chain(fake_chain(files, "1.21b", "Custom_V1"))
    local map = map_with({ doodads = {
        { id = "LTlt", creation_number = 1, position = { x = 0, y = 0 } },
        { id = "APms", creation_number = 2, position = { x = 0, y = 0 } },
    } })
    local report = validation.validate_map(map, { stock = stock })
    test("an id a missing table might hold is not an error", #report.errors == 0, tostring(#report.errors))
    local warn = find_message(report.warnings, "'APms'")
    test("it is a warning naming the missing table and the layer",
        warn and warn.message:find("Doodads\\Doodads.slk", 1, true) and warn.message:find("1.21b", 1, true)
        and warn.message:find("not checked", 1, true)
        and warn.details.missing_tables == "Doodads\\Doodads.slk", warn and warn.message)
    test("and is counted as assumed", report.stats.stock_assumed == 1, tostring(report.stats.stock_assumed))
    test("no 'no stock tables' warning when tables were given", not find_message(report.warnings, "No stock tables"))
end
-- }}}

-- {{{ The validator without stock tables
test_section("without stock tables, base-game ids are assumed valid as before")
do
    local map = map_with({ units = {
        { id = "hfoo", creation_number = 1, position = { x = 0, y = 0 } },
        { id = "hxyz", creation_number = 2, position = { x = 0, y = 0 } },
        { id = "YYI2", creation_number = 3, position = { x = 0, y = 0 } },
    } })
    local report = validation.validate_map(map)
    test("no errors", #report.errors == 0)
    test("two assumed", report.stats.stock_assumed == 2, tostring(report.stats.stock_assumed))
    test("each warned about, as before", find_message(report.warnings, "Base game unit ID 'hfoo' not in custom object data") ~= nil)
    local summary = find_message(report.warnings, "No stock tables given")
    test("one warning counts them", summary and summary.category == "stock_tables" and summary.message:find("2 base", 1, true),
        summary and summary.message)
    local text = validation.format_report(report)
    test("the printed report says they weren't looked up",
        text:find("Stock ids: not looked up", 1, true) and text:find("Stock ids assumed valid: 2", 1, true))

    test("the lines before them are kept",
        text:find("Region sounds: 0\n  Stock ids: not looked up (no stock tables given)\n  Stock ids assumed valid: 2\n", 1, true) ~= nil, text)

    local one = validation.validate_map(map_with({ units = { { id = "hfoo", creation_number = 1 } } }))
    local one_text = validation.format_report(one)
    test("a single assumed id is counted too", find_message(one.warnings, "No stock tables given: 1 base") ~= nil
        and one_text:find("Stock ids assumed valid: 1", 1, true) ~= nil)

    local quiet = validation.validate_map(map_with({}))
    test("no count is printed when nothing was assumed",
        not validation.format_report(quiet):find("assumed valid", 1, true))
    test("no counting warning when nothing was assumed", not find_message(quiet.warnings, "No stock tables"))

    local data_ok, data = pcall(require, "data")
    if data_ok then
        local seen
        local fake_map = setmetatable({ registry = map.registry, object_data = map.object_data }, { __index = data.Map })
        if data.Map and data.Map.validate then
            local r = data.Map.validate(fake_map, { stock = stock_ids.from_sets({ unit = { hfoo = true }, item = {} }) })
            seen = r and #r.errors
            test("Map:validate passes its options on", seen == 1, tostring(seen))
        else
            skip("Map:validate passes its options on", "data.Map is not exported")
        end
    else
        skip("Map:validate passes its options on", "the data module didn't load: " .. tostring(data))
    end
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
        skip("known ids through the real chain", "needs the Frozen Throne install and the 1.29.2 layer")
    else
        probe:close(); mpq_probe:close()
        local chain = require("gamedata.chain")
        local c = chain.open({ install = INSTALL, layers = LAYERS, layer = "1.29.2",
            w3i = { version = 25, editor_version = 0, game_data_set = 1, flags = { melee_map = false } } })
        local stock = stock_ids.from_chain(c)
        test("the footman is a stock unit", stock:has("unit", "hfoo") == true)
        test("Claws of Attack +15 is a stock item", stock:has("item", "ratc") == true)
        test("Blizzard is a stock ability", stock:has("ability", "AHbz") == true)
        test("the summer tree wall is a stock destructable", stock:has("destructible", "LTlt") == true)
        test("a made-up id is not", stock:has("unit", "hq9z") == false)
        c:close()
    end
end
-- }}}

print(string.format("\n%d tests: %d passed, %d failed, %d skipped", test_count, pass_count, fail_count, skip_count))
if fail_count > 0 then os.exit(1) end
