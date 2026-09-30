--[[
Tests for map pathing and combat (Issue 519). Headless, on a real map's
terrain (Daow4.4) with hand-placed casts of units.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local w3e = require("parsers.w3e")
local map_scene = require("demo.wc3map.scene")
local game_mod = require("demo.wc3map.game")
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

local function near(a, b, tol) return math.abs(a - b) <= (tol or 1e-6) end
-- }}}

local scene = map_scene.load(DIR .. "/assets/Daow4.4.w3x")
local game = game_mod.new(scene, { player = 0, minimap = false })
local P = game.pathing
local t = scene.terrain

-- {{{ The pathing grid
test_section("Pathing grid on Daow4.4")

local deep_walkable, dry_open_blocked = 0, 0
for j = 1, t.height - 2 do
    for i = 1, t.width - 2 do
        local tp = t:get_tile(i, j)
        local depth = w3e.is_wet(tp) and (w3e.water_z(tp) - w3e.ground_z(tp)) or 0
        if depth > 64 and P:walkable(i, j) then deep_walkable = deep_walkable + 1 end
        if depth == 0 and not (tp.is_boundary or tp.boundary) then
            local level_edge = false
            for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                if t:get_tile(i + d[1], j + d[2]).layer_height ~= tp.layer_height then level_edge = true end
            end
            if not level_edge and not P:walkable(i, j) then dry_open_blocked = dry_open_blocked + 1 end
        end
    end
end
test("deep water is never walkable", deep_walkable == 0, deep_walkable .. " cells")
test("dry ground away from cliff edges is always walkable", dry_open_blocked == 0, dry_open_blocked .. " cells")
test("regions labelled", P.regions > 1)
-- }}}

-- {{{ Routes
test_section("Routes")

-- a big region, and cells in it
local count = {}
for _, r in pairs(P.region) do count[r] = (count[r] or 0) + 1 end
local big, big_n = nil, 0
for r, n in pairs(count) do if n > big_n then big, big_n = r, n end end
local cells = {}
for k, r in pairs(P.region) do if r == big then cells[#cells + 1] = k end end
table.sort(cells)

local function cell_point(k)
    return P:world(k % P.w, math.floor(k / P.w))
end

local crossed, tried, arrived_exact = 0, 0, 0
local step = math.max(1, math.floor(#cells / 23))
for n = 1, 20 do
    local x0, y0 = cell_point(cells[(n * step) % #cells + 1])
    local x1, y1 = cell_point(cells[(n * step * 7 + 11) % #cells + 1])
    local route = P:route(x0, y0, x1, y1)
    if route then
        tried = tried + 1
        local px, py = x0, y0
        for _, wp in ipairs(route) do
            local len = math.sqrt((wp.x - px) ^ 2 + (wp.y - py) ^ 2)
            for s = 0, math.floor(len / 32) do
                local f = len > 0 and s * 32 / len or 0
                local ci, cj = P:cell(px + (wp.x - px) * f, py + (wp.y - py) * f)
                if not P:walkable(ci, cj) then crossed = crossed + 1 end
            end
            px, py = wp.x, wp.y
        end
        if route[#route].x == x1 and route[#route].y == y1 then arrived_exact = arrived_exact + 1 end
    end
end
test("routes found between points of one region", tried == 20, tried .. " of 20")
test("routes never cross blocked ground", crossed == 0, crossed .. " samples")
test("reachable targets are the route's end", arrived_exact == tried)

-- a target in the sea: the route ends on the unit's own ground
local sea
for j = 0, t.height - 1, 7 do
    for i = 0, t.width - 1, 7 do
        if not sea and P.region[j * P.w + i] == nil and w3e.is_wet(t:get_tile(i, j)) then sea = { i, j } end
    end
end
local sx, sy = cell_point(cells[1])
local wx, wy = P:world(sea[1], sea[2])
local r = P:route(sx, sy, wx, wy)
local li, lj
if r then li, lj = P:cell(r[#r].x, r[#r].y) end
test("an unreachable target: as close as it can get", r and P:region_at(li, lj) == big)
-- }}}

-- {{{ A cast on open ground
-- Units cloned from the map's own (so their stats are the real ones),
-- placed on open ground in the big region
local function open_spot()
    for _, k in ipairs(cells) do
        local i, j = k % P.w, math.floor(k / P.w)
        local ok = true
        for dj = -4, 4 do for di = -4, 4 do ok = ok and P:walkable(i + di, j + dj) end end
        if ok then return P:world(i, j) end
    end
end
local ox, oy = open_spot()

local function prototype(test_fn)
    for _, u in ipairs(game.units) do if test_fn(u) then return u end end
end
local function clone(proto, player, dx, dy)
    local u = {}
    for k, v in pairs(proto) do u[k] = v end
    u.player, u.x, u.y = player, ox + dx, oy + dy
    u.z = scene.sample.ground_at(u.x, u.y)
    u.order, u.route, u.target, u.mover, u.swing = nil, nil, nil, nil, nil
    u.facing = 0
    return u
end
local function cast(list)
    game.units = list
    combat.init(game)
    game.time, game.strikes, game.deaths = 0, 0, 0
end
local function run(seconds)
    for _ = 1, math.floor(seconds / 0.02 + 0.5) do game.tick(0.02) end
end

local melee = prototype(function(u) return u.spec.design == "unit" and u.spec.archetype == "infantry" and not u.spec.hero end)
local ranged = prototype(function(u) return u.spec.design == "unit" and u.spec.archetype == "ranged" end)
local building = prototype(function(u) return u.spec.design == "building" end)
local enemy = game.team_of(0) == game.team_of(1) and 2 or 1
-- }}}

-- {{{ Combat rules
test_section("Combat")

test("armour 0 takes full damage", near(combat.reduce(100, 0), 100))
test("armour 5 takes 1/(1+0.3) less", near(combat.reduce(100, 5), 100 * (1 - 0.3 / 1.3)))
test("negative armour takes more", combat.reduce(100, -3) > 100)

local fake = { team_of = function(p) return ({ [0] = 1, [1] = 1, [2] = 2 })[p] or p end }
local function who(p) return { player = p } end
test("allies aren't hostile", not combat.hostile(fake, who(0), who(1)))
test("other sides are", combat.hostile(fake, who(0), who(2)))
test("neutral hostile fights everyone", combat.hostile(fake, who(12), who(0)))
test("neutral passive fights no one", not combat.hostile(fake, who(15), who(12)) and not combat.hostile(fake, who(0), who(15)))

-- a duel
local a, b = clone(melee, 0, 0, 0), clone(melee, enemy, 150, 0)
cast({ a, b })
local first_hit
for step = 1, 3000 do
    game.tick(0.02)
    if not first_hit and (a.hp < a.hp_max or b.hp < b.hp_max) then first_hit = step * 0.02 end
    if not a.alive or not b.alive then break end
end
test("melee duel: they close and strike", first_hit ~= nil)
test("not before turning and winding up", first_hit and first_hit >= a.weapon.attack_point,
    first_hit and string.format("%.2fs", first_hit))
test("one falls", (not a.alive) ~= (not b.alive))
local fallen = a.alive and b or a
test("the fallen stays for a while", #game.units == 2)
run(combat.CORPSE_TIME + 0.5)
test("then goes", #game.units == 1 and game.units[1] ~= fallen)

-- strikes come once per cooldown
a, b = clone(melee, 0, 0, 0), clone(melee, enemy, 60, 0)
b.hp_max, b.weapon = 1e9, nil
cast({ a, b })
b.hp = 1e9
run(3)
local s0 = game.strikes
run(a.weapon.cooldown * 4)
test("one strike per cooldown", game.strikes - s0 >= 3 and game.strikes - s0 <= 5,
    (game.strikes - s0) .. " strikes in 4 cooldowns")

-- ranged: the damage flies
if ranged then
    a, b = clone(ranged, 0, 0, 0), clone(melee, enemy, 400, 0)
    b.weapon = nil
    cast({ a, b })
    local in_flight = false
    for _ = 1, 400 do
        game.tick(0.02)
        if #game.volley.arrows > 0 and b.hp == b.hp_max then in_flight = true end
        if b.hp < b.hp_max then break end
    end
    test("ranged attacks fly before they hit", in_flight and b.hp < b.hp_max)
end

-- a move order walks past an enemy
a, b = clone(melee, 0, 0, 0), clone(melee, enemy, 300, 300)
b.weapon = nil
cast({ a, b })
game.order({ a }, "move", ox + 500, oy)
local engaged, moving_ticks = false, 0
for _ = 1, 150 do
    game.tick(0.02)
    if a.order and a.order.kind == "move" then
        moving_ticks = moving_ticks + 1
        engaged = engaged or a.target ~= nil
    end
end
test("a move order ignores enemies (while it lasts)", moving_ticks > 20 and not engaged)

-- holding position: no chase
a, b = clone(melee, 0, 0, 0), clone(melee, enemy, 350, 0)
b.weapon = nil
cast({ a, b })
game.order({ a }, "hold")
run(3)
test("hold position doesn't chase", near(a.x, ox) and near(a.y, oy))

-- attack-move stops to fight
a, b = clone(melee, 0, 0, 0), clone(melee, enemy, 400, 0)
b.weapon = nil
cast({ a, b })
game.order({ a }, "attack", ox + 900, oy)
run(8)
test("attack-move fights what it meets", b.hp < b.hp_max)

-- creeps defend their camp, then go home
a, b = clone(melee, 12, 0, 0), clone(melee, 0, 200, 0)
b.weapon = nil
b.speed = 400
cast({ a, b })
run(1.5)
test("a creep attacks what comes near", a.target == b)
game.order({ b }, "move", ox + 4000, oy)
run(20)
test("but gives up the chase far from home",
    a.target == nil and math.sqrt((a.x - ox) ^ 2 + (a.y - oy) ^ 2) < combat.LEASH + 200)

-- a building falls
a, b = clone(melee, 0, 0, 0), clone(building, enemy, 250, 0)
cast({ a, b })
b.hp = 30
game.buildings_changed = false
run(10)
test("buildings can be destroyed", not b.alive and game.buildings_changed)
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
