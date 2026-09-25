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
-- Issue: issues/112c-route-a-stock-rows-merged-with-map-objects.md

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

    local c = chain.open({ install = INSTALL, layers = LAYERS, w3i = { version = 25, editor_version = 0 },
        editor_versions = {} })
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

    -- {{{ Every map
    test_section("Every object of every map in assets/")
    local kinds = { abilities = { "war3map.w3a", true }, units = { "war3map.w3u", false }, items = { "war3map.w3t", false } }
    local totals, other = { objects = 0, applied = 0 }, {}
    local by_kind = { orphan = 0, unknown_parent = 0, unknown_code = 0 }
    local listing = io.popen("ls '" .. DIR .. "/assets'")
    for name in listing:lines() do
        if name:match("%.w3[xm]$") then
            local archive = assert(mpq.open(DIR .. "/assets/" .. name))
            for kind, spec in pairs(kinds) do
                local data = archive:extract(spec[1])
                if data then
                    local r = stock_rows.merge(stocks[kind], objectdata.parse(data, { has_level_column = spec[2] }))
                    totals.objects = totals.objects + r.counts.objects
                    totals.applied = totals.applied + r.counts.applied
                    for _, p in ipairs(r.problems) do
                        by_kind[p.kind] = (by_kind[p.kind] or 0) + 1
                        if p.kind == "unknown_code" and p.code ~= "0x43727300" then
                            other[#other + 1] = name .. " " .. p.object .. " " .. tostring(p.code)
                        elseif p.kind == "unknown_parent" then
                            other[#other + 1] = name .. " " .. p.object .. " parent " .. p.problem
                        end
                    end
                end
            end
            archive:close()
        end
    end
    listing:close()
    print(string.format("  objects %d, changes applied %d, orphans %d, unknown codes %d, unknown parents %d",
        totals.objects, totals.applied, by_kind.orphan, by_kind.unknown_code, by_kind.unknown_parent))
    test("tens of thousands of objects merged", totals.objects > 20000, tostring(totals.objects))
    test("no problems beyond the two understood kinds (orphan change sets; the Crs\\0 code)",
        #other == 0, other[1])
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
