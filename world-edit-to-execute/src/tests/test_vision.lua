--[[
Tests for fog of war (Issue 524): sight circles, cliffs and trees in the
way, memory of explored ground, sharing, day and night, units that die or
go, the script's fog modifiers and switches, and combat that only picks
what it can see. The small cases run on a made-up flat grid; the last on
DAoW 5.4b with its script running.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local vision = require("demo.wc3map.vision")
local combat = require("demo.wc3map.combat")
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

-- {{{ A made-up world: 64 x 64 cells from (0, 0), level 2, with a raised
-- block (level 3) at cells 40-44 x 30-34 and a tree at cell (20, 10)
local function world(opts)
    opts = opts or {}
    local terrain = { width = 64, height = 64, offset_x = 0, offset_y = 0 }
    function terrain:get_tile(i, j)
        local high = i >= 40 and i <= 44 and j >= 30 and j <= 34
        return { layer_height = high and 3 or 2 }
    end
    local g = { player = 0, units = {}, time = 0, scene = { terrain = terrain, doodads = {
        { spec = { design = "tree" }, x = 20 * 128, y = 10 * 128 } } } }
    g.time_of_day = function() return opts.hour or 12 end
    g.shares_vision = function(a, b) return a == b or (opts.share and opts.share[a] and opts.share[a][b]) or false end
    return g
end

local function unit(player, x, y, spec)
    return { player = player, x = x, y = y, alive = true, spec = spec or { design = "unit" } }
end
-- }}}

-- {{{ Sight
test_section("Sight")
do
    local g = world()
    local u = unit(0, 10 * 128, 10 * 128)
    u.sight_day, u.sight_night = 1024, 512            -- 8 cells, 4 at night
    g.units = { u }
    local V = vision.new(g)
    V:update(0, true)
    test("a unit sees its own cell", V:state(0, u.x, u.y) == 2)
    test("and 7 cells away", V:state(0, u.x + 7 * 128, u.y) == 2)
    test("not 10 cells away: never seen, black", V:state(0, u.x + 10 * 128, u.y) == 0)
    test("another player sees nothing of it", V:state(1, u.x, u.y) == 0)
    -- moving on leaves the ground explored behind it
    u.x = 30 * 128
    V:update(0, true)
    test("where it was is fogged now", V:state(0, 10 * 128, 10 * 128) == 1)
    test("where it is, visible", V:state(0, 30 * 128, 10 * 128) == 2)
    test("a move within its cell costs nothing", (function()
        u.x = u.x + 10
        return V:update(0, true) == 0
    end)())
    -- night
    g.time_of_day = function() return 23 end
    V:update(0, true)
    test("at night it sees less (6 cells: not)", V:state(0, u.x + 6 * 128, u.y) ~= 2)
    test("but still 3", V:state(0, u.x + 3 * 128, u.y) == 2)
end
-- }}}

-- {{{ In the way
test_section("Cliffs and trees")
do
    local g = world()
    local low = unit(0, 42 * 128, 26 * 128)            -- 4 cells south of the raised block
    low.sight_day = 1280
    g.units = { low }
    local V = vision.new(g)
    V:update(0, true)
    test("ground below a higher cliff doesn't see onto it", V:state(0, 42 * 128, 31 * 128) == 0)
    test("nor past it", V:state(0, 42 * 128, 36 * 128) == 0)
    test("but round it", V:state(0, 37 * 128, 29 * 128) == 2)
    local flyer = unit(1, 42 * 128, 26 * 128, { design = "unit", archetype = "flyer" })
    flyer.sight_day = 1280
    g.units[2] = flyer
    V:update(0, true)
    test("a flyer sees onto it", V:state(1, 42 * 128, 31 * 128) == 2)
    local high = unit(2, 42 * 128, 32 * 128)
    high.sight_day = 1280
    g.units[3] = high
    V:update(0, true)
    test("the high ground sees down", V:state(2, 42 * 128, 26 * 128) == 2)
    local woods = unit(3, 16 * 128, 10 * 128)          -- 4 cells west of the tree
    woods.sight_day = 1280
    g.units[4] = woods
    V:update(0, true)
    test("a tree is seen", V:state(3, 20 * 128, 10 * 128) == 2)
    test("what's behind it isn't", V:state(3, 23 * 128, 10 * 128) == 0)
end
-- }}}

-- {{{ Sharing and seeing units
test_section("Sharing, and seeing units")
do
    local g = world({ share = { [1] = { [0] = true } } })
    local mine = unit(0, 10 * 128, 10 * 128)
    local ally = unit(1, 40 * 128, 10 * 128)
    local foe = unit(2, 12 * 128, 10 * 128)
    local far = unit(2, 60 * 128, 60 * 128)
    local fort = unit(2, 44 * 128, 12 * 128, { design = "building" })
    for _, u in ipairs({ mine, ally, foe, far, fort }) do u.sight_day = 1024 end
    g.units = { mine, ally, foe, far, fort }
    local V = vision.new(g)
    V:update(0, true)
    test("an ally sharing vision: its ground is seen", V:state(0, 40 * 128, 10 * 128) == 2)
    test("but not the other way", V:state(1, 10 * 128, 10 * 128) == 0)
    test("a foe close by is seen", V:sees(0, foe))
    test("a foe far off isn't", not V:sees(0, far))
    test("an ally's units are always seen", V:sees(0, ally))
    test("a building seen once...", fort.seen == true and V:sees(0, fort))
    ally.x = 20 * 128                                  -- the ally leaves; the fort is in the fog
    V:update(0, true)
    test("...is remembered in the fog", V:sees(0, fort) and not V:sees(0, fort, true))
    foe.invisible = true
    test("an invisible foe isn't seen", not V:sees(0, foe))
    mine.alive = false
    V:update(0, true)
    test("the dead give no sight", V:state(0, 10 * 128, 10 * 128) == 1)
    g.units = { ally }
    V:update(0, true)
    test("units gone from the game take their sight", next(V.stamped) == ally and V:state(0, 60 * 128, 60 * 128) == 0)
    local m = V:mask(0)
    test("the mask: a byte per cell", #m == 64 * 64)
    test("with the three shades", m:byte(10 * 64 + 20 + 1) == 255 and m:byte(10 * 64 + 10 + 1) == 110 and m:byte(63 * 64 + 63 + 1) == 0)
end
-- }}}

-- {{{ Modifiers and switches
test_section("The script's fog controls")
do
    local g = world()
    local u = unit(0, 10 * 128, 10 * 128)
    u.sight_day = 1024
    g.units = { u }
    local V = vision.new(g)
    V:update(0, true)
    local reveal = V:modifier(0, "visible", { x = 50 * 128, y = 50 * 128, r = 512 })
    test("a modifier does nothing until started", V:state(0, 50 * 128, 50 * 128) == 0)
    V:start(reveal)
    test("a visible modifier reveals", V:state(0, 50 * 128, 50 * 128) == 2)
    V:stop(reveal)
    test("stopped, what it showed is fogged", V:state(0, 50 * 128, 50 * 128) == 1)
    local cover = V:modifier(0, "fogged", { x0 = 8 * 128, y0 = 8 * 128, x1 = 12 * 128, y1 = 12 * 128 }, true)
    V:start(cover)
    test("a fogged modifier after units covers their sight", V:state(0, 10 * 128, 10 * 128) == 1)
    V:destroy(cover)
    test("destroyed, the unit sees again", V:state(0, 10 * 128, 10 * 128) == 2)
    local under = V:modifier(0, "masked", { x0 = 8 * 128, y0 = 8 * 128, x1 = 30 * 128, y1 = 12 * 128 }, false)
    V:start(under)
    test("a masked modifier before units: they still see", V:state(0, 10 * 128, 10 * 128) == 2)
    test("and it blacks out the rest", V:state(0, 25 * 128, 10 * 128) == 0)
    V:destroy(under)
    V:set_state(0, "fogged", { x0 = 0, y0 = 60 * 128, x1 = 5 * 128, y1 = 63 * 128 })
    test("SetFogState fogged: explored at once", V:state(0, 2 * 128, 62 * 128) == 1)
    V:set_state(0, "masked", { x0 = 0, y0 = 60 * 128, x1 = 5 * 128, y1 = 63 * 128 })
    test("masked: forgotten", V:state(0, 2 * 128, 62 * 128) == 0)
    V:enable_mask(false)
    test("no black mask: unexplored is fogged", V:state(0, 60 * 128, 2 * 128) == 1)
    V:enable(false)
    test("no fog: all visible", V:state(0, 60 * 128, 2 * 128) == 2 and V:sees(0, unit(3, 1, 1)))
    test("and the mask all clear", not V:mask(0):find("[^\255]"))
end
-- }}}

-- {{{ On a real map, with its script
test_section("DAoW 5.4b with its script")
do
    local map_scene = require("demo.wc3map.scene")
    local game_mod = require("demo.wc3map.game")
    local s = map_scene.load(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")
    local g = game_mod.new(s, { player = 0, placed = false, minimap = false })
    local VM = g.run_script({ ai = "none" })
    local N = VM.natives
    local t0 = os.clock()
    g.vision:update(0, true)
    local first = os.clock() - t0
    print(string.format("  first update %.3fs, %d sight sources", first, g.vision.changed))
    local own, foe
    for _, u in ipairs(g.units) do
        if u.alive and u.player == 0 and u.weapon and u.spec.design == "unit" then own = own or u end
    end
    test("the player's own units are seen", own and g.shown(own) and N.IsUnitVisible(own, N.Player(0)))
    test("its ground is visible", N.IsVisibleToPlayer(own.x, own.y, N.Player(0)))
    local hidden = 0
    for _, u in ipairs(g.units) do if not g.shown(u) then hidden = hidden + 1 end end
    test("most of the map's units are out of sight at the start", hidden > #g.units / 2, hidden .. " of " .. #g.units)
    -- a creep next to the unit: seen, and fought
    foe = g.spawn("nwlt", 12, own.x + 250, own.y, 0)
    g.vision:update(0, true)
    test("a creep beside it is seen", N.IsUnitVisible(foe, N.Player(0)))
    -- covered by a fog modifier over the units' sight: unseen, not picked
    local mod = N.CreateFogModifierRadius(N.Player(0), 2, foe.x, foe.y, 200, true, true)
    N.FogModifierStart(mod)
    test("fogged by the script: not seen", not N.IsUnitVisible(foe, N.Player(0)) and N.IsUnitFogged(foe, N.Player(0)))
    own.target, own.next_scan = nil, 0
    own.weapon.acquire = 600
    combat.update(g, 0.05)
    test("and not picked as a target", own.target ~= foe)
    N.DestroyFogModifier(mod)
    own.next_scan = 0
    combat.update(g, 0.05)
    test("seen again, it is", own.target == foe)
    N.FogEnable(false)
    test("FogEnable(false): everything seen", not N.IsFogEnabled() and N.IsVisibleToPlayer(-30000, -30000, N.Player(0)))
    N.FogEnable(true)
    N.FogMaskEnable(false)
    test("FogMaskEnable(false): nothing black", N.IsFoggedToPlayer(-20000, -20000, N.Player(0)))
    N.FogMaskEnable(true)
    test("the fog natives are real, not no-ops", not VM.noop.FogEnable and not VM.noop.CreateFogModifierRect)
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
