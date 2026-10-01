--[[
Tests for buildings blocking movement (Issue 541): a building's cells
kept from walkers, route cells closed when half covered, routes round
buildings (every leg clear of their cells), walking into a building
stopping at its edge, units under a new building pushed out, a wall with
a gap walked through and, closed, the far side unreachable, hidden and
removed buildings not blocking, walks re-planned when a building cuts
across them, and reach measured from a footprint's edge. Made-up tables
are this test's own; the ground is DAoW's.
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

-- {{{ The game, with made-up tables
local map_scene = require("demo.wc3map.scene")
local game_mod = require("demo.wc3map.game")
local fp = require("demo.wc3map.footprint")
local s = map_scene.load(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")
local UNITS = {
    zbig = { upat = "PathTextures\\8x8SimpleSolid.tga" },
    zsml = { upat = "PathTextures\\4x4SimpleSolid.tga" },
}
local units = { available = true }
function units:value(id, code) local v = (UNITS[id] or {})[code] return v, v ~= nil and "stock" or nil end
function units:list() return {} end
local g = game_mod.new(s, { player = 0, placed = false, minimap = false, vision = false, stock = units, combat = false })
local P = g.pathing
local function run(sec) for _ = 1, math.floor(sec * 30 + 0.5) do g.tick(1 / 30) end end
local function building(id, x, y, player)
    local b = g.spawn(id, player or 0, x, y, 0)
    b.spec.design = "building"
    return b
end
local function walker(x, y)
    local u = g.spawn("hfoo", 0, x, y, 0)
    u.spec.design, u.speed = "unit", 400
    return u
end
-- a clear square of open ground, 1600 across, with no buildings
local X, Y
local b = g.bounds
for y = b.y0 + 3000, b.y1 - 3000, 256 do
    for x = b.x0 + 3000, b.x1 - 3000, 256 do
        if not X then
            local ok = true
            for dy = -800, 800, 64 do
                for dx = -800, 800, 64 do
                    local i, j = P:cell(x + dx, y + dy)
                    if ok and not P:ground_walkable(i, j) then ok = false end
                end
            end
            if ok then X, Y = fp.snap(fp.shape(g, "zbig"), x, y) end
        end
    end
end
local function legs_clear(u)
    local px, py = u.x, u.y
    for _, p in ipairs(u.route or {}) do
        if not P:fine_clear(px, py, p.x, p.y) then return false end
        px, py = p.x, p.y
    end
    return true
end
-- }}}

-- {{{ Cells
test_section("A building's cells")
local big
do
    test("open ground found", X ~= nil)
    big = building("zbig", X, Y)
    g.update_blockers(true)
    test("its cells keep walkers out", P:blocked(X, Y) and P:blocked(X + 120, Y - 120))
    test("not past its edge", not P:blocked(X + 140, Y) and not P:blocked(X, Y - 140))
    local i, j = P:cell(X, Y)
    test("a route cell it covers is closed", not P:walkable(i, j) and P:ground_walkable(i, j))
    test("its body: half its side", big.body == 128)
    test("reach from its edge", fp.gap(g, big, X + 128 + 30, Y) == 30 and fp.gap(g, big, X, Y) == 0)
end
-- }}}

-- {{{ Walking round
test_section("Walking round it")
do
    local u = walker(X - 500, Y + 10)
    g.order({ u }, "move", X + 500, Y + 10)
    test("the route goes round: no leg crosses its cells", u.route and legs_clear(u))
    run(4)
    test("and gets there", (u.x - X - 500) ^ 2 + (u.y - Y - 10) ^ 2 < 40 ^ 2,
        string.format("at %.0f, %.0f", u.x - X, u.y - Y))
    local ever_inside = false
    g.order({ u }, "move", X - 500, Y - 10)
    for _ = 1, 120 do g.tick(1 / 30); if P:blocked(u.x, u.y) then ever_inside = true end end
    test("never inside on the way back", not ever_inside)
    -- a move onto it: it stops at its edge, and the order ends
    g.order({ u }, "move", X, Y)
    run(4)
    test("a move onto a building stops beside it", not P:blocked(u.x, u.y) and fp.gap(g, big, u.x, u.y) < 60,
        string.format("%.0f from its edge", fp.gap(g, big, u.x, u.y)))
    test("and the order is done", u.order == nil and u.route == nil)
    g.remove(u)
end
-- }}}

-- {{{ Put down on units
test_section("Put down where units stand")
do
    local u = walker(X + 600, Y + 600)
    local small = building("zsml", X + 608, Y + 608)
    g.update_blockers(true)
    test("they step out to the nearest open ground", not P:blocked(u.x, u.y) and fp.gap(g, small, u.x, u.y) < 40)
    g.remove(small)
    g.remove(u)
end
-- }}}

-- {{{ A ring
test_section("A ring of buildings with a gap")
do
    g.remove(big)
    -- eight big buildings round a middle square, the east one left out
    local ring = {}
    for dy = -1, 1 do
        for dx = -1, 1 do
            if (dx ~= 0 or dy ~= 0) and not (dx == 1 and dy == 0) then
                ring[#ring + 1] = building("zbig", X + dx * 256, Y + dy * 256)
            end
        end
    end
    local u = walker(X, Y)
    g.update_blockers(true)
    g.order({ u }, "move", X - 700, Y)
    test("out through the gap", u.route and legs_clear(u) and u.route[1].x > X)
    run(6)
    test("it gets out", u.x < X - 600, string.format("at %.0f, %.0f", u.x - X, u.y - Y))
    g.order({ u }, "move", X, Y)
    run(6)
    test("and back in", (u.x - X) ^ 2 + (u.y - Y) ^ 2 < 60 ^ 2, string.format("at %.0f, %.0f", u.x - X, u.y - Y))
    local plug = building("zbig", X + 256, Y)
    g.update_blockers(true)
    local here, there = P:region_at(P:cell(u.x, u.y)), P:region_at(P:cell(X - 700, Y))
    test("the gap closed: outside is another region", here ~= nil and there ~= nil and here ~= there,
        tostring(here) .. " " .. tostring(there))
    g.order({ u }, "move", X - 700, Y)
    run(2)
    test("walled in, it stays in", math.abs(u.x - X) < 128 and math.abs(u.y - Y) < 128)
    -- hidden: no longer in the way
    plug.hidden = true
    g.blockers_stale = true
    g.update_blockers()
    test("a hidden building doesn't block", not P:blocked(X + 256, Y))
    plug.hidden = nil
    g.remove(plug)
    g.update_blockers()
    test("a removed one doesn't either", not P:blocked(X + 256, Y))
    for _, r in ipairs(ring) do g.remove(r) end
    g.remove(u)
end
-- }}}

-- {{{ Re-planning
test_section("Walks a new building cuts across")
do
    local u = walker(X - 600, Y - 400)
    g.order({ u }, "move", X + 600, Y - 400)
    local before = u.route and #u.route
    local cut = building("zbig", X, Y - 400)
    g.blockers_stale = true
    g.tick(1 / 30)
    test("are planned again round it", u.route and legs_clear(u), tostring(before))
    run(5)
    test("and get there", (u.x - X - 600) ^ 2 + (u.y - Y + 400) ^ 2 < 40 ^ 2)
    g.remove(cut)
    g.remove(u)
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
