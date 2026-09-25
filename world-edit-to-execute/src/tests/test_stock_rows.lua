#!/usr/bin/env luajit
-- test_stock_rows.lua - Route A: stock rows merged with each map's objects
--
-- One custom ability checked field by field (the map's changes on top, the
-- rest from its stock parent, every column labelled by whose it is), then every object of
-- every map in assets/ merged, with problems only of the kinds understood so
-- far. Needs the Frozen Throne install and the 1.21b layer; skipped with a
-- loud notice without them.
--
-- Run: luajit src/tests/test_stock_rows.lua [DIR]
-- Issue: issues/completed/112c-route-a-stock-rows-merged-with-map-objects.md

-- {{{ Setup
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local INSTALL = DIR .. "/wc3-installs/frozen-throne"
local LAYERS = DIR .. "/wc3-installs/patch-layers"
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

local probe = io.open(LAYERS .. "/1.21b/manifest.lua", "r")
if not probe or not io.open(INSTALL .. "/War3x.mpq", "rb") then
    skip("stock rows", "needs the Frozen Throne install and the 1.21b layer")
else
    probe:close()
    local chain = require("gamedata.chain")
    local stock_rows = require("gamedata.stock_rows")
    local mpq = require("mpq")
    local objectdata = require("parsers.objectdata")

    local c = chain.open({ install = INSTALL, layers = LAYERS, w3i = { version = 25, editor_version = 0, game_data_set = 1, flags = { melee_map = false } },
        layer = "1.21b" })
    local stocks = {
        abilities = stock_rows.load(c, "abilities"),
        units = stock_rows.load(c, "units"),
        items = stock_rows.load(c, "items"),
    }

    -- {{{ One ability, field by field
    test_section("DAoW-2.1: custom Animate Dead (A003, copied from AUan)")
    local a = assert(mpq.open(DIR .. "/assets/DAoW-2.1.w3x"))
    local parsed = objectdata.parse(a:extract("war3map.w3a"), { has_level_column = true })
    a:close()
    local result = stock_rows.merge(stocks.abilities, parsed)
    test("all 315 abilities merged", result.counts.objects == 315 and #result.problems == 0,
        result.counts.objects .. " objects, " .. #result.problems .. " problems")
    local row = result.rows.A003
    local d = row.fields.AbilityData
    test("parent recorded", row.parent == "AUan")
    test("the map's level count (alev -> levels)", d.levels == 2, tostring(d.levels))
    test("the map's data A per level (Uan1 -> DataA1, DataA2)", d.DataA1 == 50 and d.DataA2 == 100)
    test("the map's level-2 cooldown (acdn -> Cool2)", d.Cool2 == 1, tostring(d.Cool2))
    test("an unchanged stock value kept (Cool1 = 180, from AUan)", d.Cool1 == 180, tostring(d.Cool1))
    test("the base ability code always kept", d.code == "AUan")
    local p, o = row.fields.Profile, row.origin.Profile
    test("the order string copied, labelled fact", p.Order == "animatedead" and o.Order == "fact",
        tostring(p.Order) .. " " .. tostring(o.Order))
    test("the icon path copied, labelled borrowed", type(p.Art) == "string" and o.Art == "borrowed",
        tostring(p.Art) .. " " .. tostring(o.Art))
    test("a name copied, labelled borrowed or map", p.Name ~= nil and (o.Name == "borrowed" or o.Name == "map"),
        tostring(p.Name) .. " " .. tostring(o.Name))
    -- Tooltips are level-dependent fields kept under their bare name in the
    -- profile files; they once came out labelled "editor" because only the
    -- name-plus-level form (Tip1) was looked up.
    test("the tooltips copied, labelled borrowed", p.Tip ~= nil and o.Tip == "borrowed" and o.Ubertip == "borrowed",
        tostring(o.Tip) .. " " .. tostring(o.Ubertip))
    test("the map's cooldown change labelled map", row.origin.AbilityData.Cool2 == "map")
    test("an untouched stock number labelled fact", row.origin.AbilityData.Cool1 == "fact")
    test("borrowed columns counted", result.counts.borrowed > 0, tostring(result.counts.borrowed))
    -- }}}

    -- {{{ A map that ships its own ability table
    test_section("DAoW-5.2: an ability defined only in the map's own table (A008)")
    local m52 = DIR .. "/assets/DAoW-5.2.w3x"
    local c52 = chain.open({ install = INSTALL, layers = LAYERS, w3i = { version = 25, editor_version = 0, game_data_set = 1, flags = { melee_map = false } },
        layer = "1.21b", map = m52 })
    local _, source = c52:read("Units\\AbilityData.slk")
    test("the map's own ability table beats the stock one", source == "map: Units\\AbilityData.slk", source)
    local _, beneath = c52:read("Units\\AbilityData.slk", { below_map = true })
    test("the stock copy beneath is still reachable", beneath:match("^layer ") or beneath:match("mpq"), beneath)
    local a52 = assert(mpq.open(m52))
    local r52 = stock_rows.merge(stock_rows.load(c52, "abilities"),
        objectdata.parse(a52:extract("war3map.w3a"), { has_level_column = true }))
    a52:close()
    c52:close()
    local a008 = r52.rows.A008
    test("A008 merges (its changes apply over the map's own row)", a008 ~= nil and a008.origin.AbilityData.Cool4 == "map",
        a008 and tostring(a008.origin.AbilityData.Cool4) or "no row")
    test("A008 keeps its base ability code from the map's table", a008 and type(a008.fields.AbilityData.code) == "string")
    test("no orphans in DAoW-5.2", (r52.counts.orphan or 0) == 0, tostring(r52.counts.orphan))
    -- }}}

    -- {{{ A three-letter field code
    test_section("DaoW-(HvA)-7.5: Curse's chance to miss (field code Crs, stored Crs\\0)")
    local m75 = DIR .. "/assets/DaoW-(HvA)-7.5.w3x"
    local c75 = chain.open({ install = INSTALL, layers = LAYERS, w3i = { version = 25, editor_version = 0, game_data_set = 1, flags = { melee_map = false } },
        layer = "1.21b", map = m75 })
    local a75 = assert(mpq.open(m75))
    local r75 = stock_rows.merge(stock_rows.load(c75, "abilities"),
        objectdata.parse(a75:extract("war3map.w3a"), { has_level_column = true }))
    a75:close()
    c75:close()
    local curse = r75.rows.Acrs
    test("stock Curse changed in place: miss chance 0.35 at level 1",
        curse and math.abs(curse.fields.AbilityData.DataA1 - 0.35) < 1e-6 and curse.origin.AbilityData.DataA1 == "map",
        curse and tostring(curse.fields.AbilityData.DataA1))
    test("no unknown codes in this map", (r75.counts.unknown_code or 0) == 0, tostring(r75.counts.unknown_code))
    -- }}}

    -- {{{ Every map
    test_section("Every object of every map in assets/")
    local kinds = { abilities = { "war3map.w3a", true }, units = { "war3map.w3u", false }, items = { "war3map.w3t", false } }
    local totals, other = { objects = 0, applied = 0 }, {}
    local by_kind = { orphan = 0, unknown_parent = 0, unknown_code = 0 }
    -- Each map gets its own chain with the map's archive on top: some maps
    -- (DAoW-5.2, 5.3) ship their own object tables and define abilities only
    -- there. Before the map was part of the chain, their changes to those
    -- abilities showed up as 369 "orphan" change sets.
    local listing = io.popen("ls '" .. DIR .. "/assets'")
    local w3i_parser = require("parsers.w3i")
    local layers_used = {}
    totals.map_table_only = 0
    for name in listing:lines() do
        if name:match("%.w3[xm]$") then
            local archive = assert(mpq.open(DIR .. "/assets/" .. name))
            -- Each map on its own game version: its editor build picks the
            -- layer (gamedata/editor_versions.lua); a build with no layer is
            -- an error, so every test map's build must be covered.
            local info = w3i_parser.parse(archive:extract("war3map.w3i"))
            local mc = chain.open({ install = INSTALL, layers = LAYERS, w3i = info, map = DIR .. "/assets/" .. name })
            layers_used[mc.layer] = (layers_used[mc.layer] or 0) + 1
            for kind, spec in pairs(kinds) do
                local data = archive:extract(spec[1])
                if data then
                    local r = stock_rows.merge(stock_rows.load(mc, kind), objectdata.parse(data, { has_level_column = spec[2] }))
                    totals.map_table_only = totals.map_table_only + (r.counts.map_table_only or 0)
                    totals.objects = totals.objects + r.counts.objects
                    totals.applied = totals.applied + r.counts.applied
                    for _, p in ipairs(r.problems) do
                        by_kind[p.kind] = (by_kind[p.kind] or 0) + 1
                        if p.kind == "unknown_code" then
                            other[#other + 1] = name .. " " .. p.object .. " " .. tostring(p.code)
                        elseif p.kind ~= "orphan" then
                            other[#other + 1] = name .. " " .. p.object .. " parent " .. p.problem
                        end
                    end
                end
            end
            mc:close()
            archive:close()
        end
    end
    listing:close()
    print(string.format("  objects %d (%d defined only in a map's own table), changes applied %d, orphans %d, unknown codes %d, unknown parents %d",
        totals.objects, totals.map_table_only, totals.applied, by_kind.orphan, by_kind.unknown_code, by_kind.unknown_parent))
    local used = {}
    for layer, n in pairs(layers_used) do used[#used + 1] = layer .. "×" .. n end
    table.sort(used)
    print("  layers used: " .. table.concat(used, " "))
    test("maps saved by editor 6052 load 1.21b, 6057 load 1.22a, 6059 load 1.27b, 6060 load 1.29.2",
        (layers_used["1.21b"] or 0) >= 12 and (layers_used["1.22a"] or 0) >= 1 and (layers_used["1.27b"] or 0) >= 2
        and (layers_used["1.29.2"] or 0) >= 1)
    test("tens of thousands of objects merged", totals.objects > 20000, tostring(totals.objects))
    test("no orphan change sets once the map's own tables are in the chain", by_kind.orphan == 0, tostring(by_kind.orphan))
    test("objects defined only in a map's own table get rows", totals.map_table_only > 0, tostring(totals.map_table_only))
    -- Curse's chance-to-miss field is "Crs" in the metadata and "Crs\0" in
    -- map files; 31 changes went unmatched until the reader trimmed the padding.
    test("no unknown field codes", by_kind.unknown_code == 0, tostring(by_kind.unknown_code))
    test("no other problems", #other == 0, other[1])
    -- }}}

    c:close()
end

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
