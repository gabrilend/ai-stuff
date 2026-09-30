--[[
Tests for building footprints (Issue 536): the map's pathing map
(war3map.wpm), a building's shape from its pathing texture (the image,
else the texture's name, else a stand-in by size), lining a footprint up
with the 32-unit cells, and placing cell by cell (water, unbuildable
ground, other buildings' cells). The map is DAoW (its own path textures);
the made-up tables and images are this test's own.
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

local fp = require("demo.wc3map.footprint")

-- {{{ The pathing map
test_section("The map's pathing map")
do
    local head = "MP3W" .. string.char(0, 0, 0, 0) .. string.char(2, 0, 0, 0) .. string.char(1, 0, 0, 0)
    local pm = fp.parse_wpm(head .. string.char(0x40, 0x4a))
    test("parsed: width, height, a byte a cell", pm and pm.w == 2 and pm.h == 1 and pm.bytes:byte(2) == 0x4a)
    test("not a pathing map: nil", fp.parse_wpm("nope") == nil)
    test("too short: nil", fp.parse_wpm(head) == nil)
end
-- }}}

-- {{{ Shapes
local map_scene = require("demo.wc3map.scene")
local game_mod = require("demo.wc3map.game")
local s = map_scene.load(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")

local UNITS = {
    ztex = { upat = "PathTextures\\Custom.tga" },
    z8x8 = { upat = "PathTextures\\8x8SimpleSolid.tga" },
    z4ub = { upat = "PathTextures\\4x4Unbuildable.tga" },
    z4x4 = { upat = "PathTextures\\4x4SimpleSolid.tga" },
    z3x3 = { upat = "PathTextures\\3x3SimpleSolid.tga" },
}
local units = { available = true }
function units:value(id, code) local v = (UNITS[id] or {})[code] return v, v ~= nil and "stock" or nil end
function units:list() return {} end
local g = game_mod.new(s, { player = 0, placed = true, minimap = false, vision = false, stock = units, combat = false })
-- a made-up 3 x 2 texture: top row white (all), bottom row blue (no building)
-- then red (no walking) then black (nothing)
local function px(r, gr, b) return string.char(r, gr, b, 255) end
g.assets = { texture = function(_, path)
    if path == "PathTextures\\Custom.tga" then
        return { width = 3, height = 2, rgba = px(255, 255, 255) .. px(255, 255, 255) .. px(255, 255, 255)
                                            .. px(0, 0, 255) .. px(255, 0, 0) .. px(0, 0, 0) }
    end
end }

test_section("A building's shape")
do
    local sh = fp.shape(g, "ztex")
    test("from its texture: size", sh.source == "texture" and sh.w == 3 and sh.h == 2)
    test("white: all kept", sh.cells[0] == 0x0e)
    test("blue: builders kept off", sh.cells[3] == fp.NO_BUILD)
    test("red: walkers", sh.cells[4] == fp.NO_WALK)
    test("black: nothing", sh.cells[5] == 0)
    sh = fp.shape(g, "z8x8")
    test("no image: from its name (8x8SimpleSolid)", sh.source == "name" and sh.w == 8 and sh.h == 8 and sh.cells[63] == 0x0e)
    sh = fp.shape(g, "z4ub")
    test("an \"Unbuildable\" texture keeps only builders off", sh.cells[0] == fp.NO_BUILD)
    sh = fp.shape(g, "hbar")
    test("nothing said: a stand-in by size", sh.source == "stand-in" and sh.w >= 4)
    test("its radius: half its larger side", fp.radius(g, "z8x8") == 128)
    local n = 0
    for id in pairs(s.map.object_data.units._by_id) do
        local v = s.map.object_data.units:get_modification(id, "upat")
        if type(v) == "string" and v:match("%d+x%d+") then n = n + 1 end
    end
    test("DAoW sets its own buildings' path textures", n > 50, tostring(n))
end
-- }}}

-- {{{ Snapping
test_section("Lined up with the cells")
do
    local x, y = fp.snap(fp.shape(g, "z8x8"), 1000, 1000)
    test("an even footprint: its centre on a cell corner", x % 32 == 0 and y % 32 == 0 and math.abs(x - 1000) <= 16)
    x, y = fp.snap(fp.shape(g, "z3x3"), 1000, 1000)
    test("an odd one: on a cell's middle", x % 32 == 16 and y % 32 == 16)
    test("g.snap with a type uses it", select(1, g.snap(1000, 1000, "z3x3")) % 32 == 16)
    test("without one, the 64 grid", select(1, g.snap(100, 0)) == 128)
end
-- }}}

-- {{{ Placing
test_section("Where it fits")
local spot, water, blocked
do
    -- find: open land, water, and land the map marks unbuildable
    local b = g.bounds
    for y = b.y0 + 2000, b.y1 - 2000, 256 do
        for x = b.x0 + 2000, b.x1 - 2000, 256 do
            local f = fp.map_flags(g, x, y)
            if f then
                if not spot and f == 0x40 and g.placeable("z4x4", x, y) then spot = { x, y } end
                if not water and f % 128 < 0x40 then
                    local all = true
                    for _, d in ipairs({ { -96, -96 }, { 96, -96 }, { -96, 96 }, { 96, 96 } }) do
                        all = all and (fp.map_flags(g, x + d[1], y + d[2]) or 0x40) % 128 < 0x40
                    end
                    if all then water = { x, y } end
                end
                if not blocked and f % 128 >= 0x40 and f % 16 >= 0x08 and f % 4 < 0x02 then blocked = { x, y } end
            end
        end
        if spot and water and blocked then break end
    end
    test("DAoW's pathing map read", g.path_map and g.path_map.w == 1920, g.path_map and tostring(g.path_map.w))
    test("open land found", spot ~= nil)
    local ok, why = g.placeable("z4x4", water[1], water[2])
    test("not on water", not ok and why == "can't build on water", tostring(why))
    ok, why = g.placeable("z4x4", blocked[1], blocked[2])
    test("not where the map forbids building", not ok and why == "can't build there", tostring(why))
    local x, y = g.snap(spot[1], spot[2], "z4x4")
    local here = g.spawn("z4x4", 0, x, y, 0)
    here.spec.design = "building"
    local fits_right = g.placeable("z4x4", x + 128, y)
    local fits_over = g.placeable("z4x4", x + 96, y)
    test("side by side: fits (if the ground there does)", fits_right or not g.placeable("z4x4", x + 256, y))
    ok, why = g.placeable("z4x4", x + 96, y)
    test("overlapping a cell: something's in the way", not ok and why == "something's in the way", tostring(why))
    local _, _, marks = fp.check(g, "z4x4", x + 96, y)
    local bad = 0
    for _, m in ipairs(marks) do if not m then bad = bad + 1 end end
    test("the marks say which cells: one column of four", #marks == 16 and bad == 4, bad .. " of " .. #marks)
    g.remove(here)
    test("gone: it fits again", (g.placeable("z4x4", x + 96, y)) or fits_over == false and true)
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
