--[[
Tests for the geometry kit, WC3 locomotion, behaviours and the fort scene
(Issue 516). Headless: painting goes to a recorder, not a window.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local kit = require("geometry.kit")
local figures = require("geometry.figures")
local loco = require("runtime.locomotion")
local behaviors = require("runtime.behaviors")
local fort = require("demo.fort.scene")
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

local function near(a, b, tol)
    return math.abs(a - b) <= (tol or 1e-6)
end
-- }}}

-- {{{ Kit: standing on things
test_section("Kit surfaces")

local w = kit.new()
w:slab(0, 0, 1000, 1000, 32, 0)
w:rampart(-400, 0, 400, 0, { z = 32, height = 288, thickness = 160 })
w:ramp(0, -400, 32, 0, -200, 320, 128)

test("ground beyond everything is 0", w:height_at(2000, 2000, 0) == 0)
test("slab top", w:height_at(300, 300, 0) == 32)
test("ramp halfway up", near(w:height_at(0, -300, 170), 176))
test("walkway on the wall", w:height_at(0, 0, 320) == 320)
test("a wall can't be stepped onto from the ground",
    w:height_at(0, 0, 32) == 32, "got " .. w:height_at(0, 0, 32))
test("without a height, the top surface", w:height_at(0, 0) == 320)
test("one step up is allowed", w:height_at(0, -390, 32) > 32)

local st = kit.new()
st:stairs(0, 0, 0, 320, 0, 256, 100, 8)
test("stairs: 8 blocks", #st.prims == 8)
test("stairs walked as a slope", near(st:height_at(160, 0, 128), 128))
-- }}}

-- {{{ Kit: painting
test_section("Kit painting")

local calls = {}
local recorder = {
    geo_box = function(...) calls[#calls + 1] = { "box", ... } return #calls end,
    geo_wedge = function(...) calls[#calls + 1] = { "wedge", ... } return #calls end,
    geo_quad = function(...) calls[#calls + 1] = { "quad", ... } return #calls end,
}
local p = kit.new()
p:box(256, 128, 64, 128, 64, 32, 0.5, { 1, 2, 3 })
p:quad({ { 0, 128, 0 }, { 128, 128, 0 }, { 128, 256, 0 }, { 0, 256, 0 } }, { 4, 5, 6 })
test("every primitive painted", p:emit(recorder, 0.05) == 2)
local b = calls[1]
test("x scaled to tiles", b[2] == 2)
test("height lifted by the ground", near(b[3], 0.5 + 0.05))
test("north maps to -z", b[4] == -1)
test("box size: length, height, width", b[5] == 1 and b[6] == 0.25 and b[7] == 0.5)
test("facing turns the other way in render space", b[8] == -0.5)
test("colour passed through", b[9] == 1 and b[10] == 2 and b[11] == 3)
test("static layer", b[12] == false)
test("quad corner mapped", calls[2][2] == 0 and calls[2][4] == -1)

local fig = figures.bowman(0, 0, 0, 0, { stride = 16, draw = 1 })
test("bowman is made of boxes", #fig > 5 and fig[1].kind == "box")
local tallest = 0
for _, prim in ipairs(fig) do tallest = math.max(tallest, prim.z + prim.hgt) end
test("bowman stands about 90 tall", tallest > 80 and tallest < 100, "top " .. tallest)
test("ring has its segments", #figures.ring(0, 0, 0, 500, { 1, 1, 1 }, 32) == 32)
-- }}}

-- {{{ Locomotion
test_section("Locomotion (WC3 rules)")

local archer = loco.UNIT_TYPES.archer
local u = loco.new(archer, 0, 0, 0, 0)
local dt = 0.02

-- a target straight behind: turns in place first, moving not at all
loco.step(u, -1000, 0, dt)
test("target behind: turns without walking", u.x == 0 and u.y == 0 and not u.walking)
test("...at its turn speed", near(u.facing, loco.turn_speed(archer.turn_rate) * dt, 1e-9))

local ticks = 0
while not u.walking and ticks < 1000 do
    loco.step(u, -1000, 0, dt)
    ticks = ticks + 1
end
local off = math.abs(loco.angle_diff(u.facing, math.pi))
test("walks once inside the propulsion window",
    u.walking and off <= math.rad(archer.propwin), string.format("%.1f deg off", math.deg(off)))

-- constant speed: every walking tick covers speed * dt, no ramp-up
local v = loco.new(archer, 0, 0, 0, 0)
local x0 = v.x
loco.step(v, 1000, 0, dt)
test("full speed from the first step", near(v.x - x0, archer.speed * dt, 1e-9))
for _ = 1, 10 do loco.step(v, 1000, 0, dt) end
test("still exactly speed * dt per tick", near(v.x, archer.speed * dt * 11, 1e-9))

-- arrives exactly, never overshoots
local a2 = loco.new(archer, 0, 0, 0, 0)
local done = false
for _ = 1, 200 do
    done = loco.step(a2, 100, 0, dt)
    if done then break end
end
test("arrives exactly on the target", done and a2.x == 100 and a2.y == 0)

-- a sharp turn is a turn in place then an arc, not a slide sideways
local r = loco.new(archer, 0, 0, 0, 0)
loco.set_route(r, { { x = 200, y = 0 }, { x = 200, y = 200 } })
local worst = 0
for _ = 1, 400 do
    local px, py = r.x, r.y
    if loco.follow(r, nil, dt) then break end
    if r.walking then
        local mx, my = r.x - px, r.y - py
        local heading = math.atan2(my, mx)
        worst = math.max(worst, math.abs(loco.angle_diff(r.facing, heading)))
    end
end
test("walks along its facing", worst < 1e-6, string.format("%.3f rad off", worst))
test("route finished at its end", r.x == 200 and r.y == 200)
-- }}}

-- {{{ Walk graph
test_section("Walk graph")

local g = behaviors.nav()
g:lane({ { 0, 0 }, { 1000, 0 }, { 1000, 1000 } })
g:lane({ { 0, 0 }, { 0, 1000 }, { 1000, 1000 } })
g:lane({ { 0, 0 }, { 400, 400 }, { 1000, 1000 } })
local route = g:route_between(0, 0, 1000, 1000)
test("shortest of three lanes", #route == 3 and route[2].x == 400)
test("lanes join at shared points", #g.nodes == 5)
local apart = behaviors.nav()
apart:lane({ { 0, 0 }, { 100, 0 } })
apart:lane({ { 500, 500 }, { 600, 500 } })
test("no route between lanes that never meet", apart:route_between(0, 0, 600, 500) == nil)
-- }}}

-- {{{ Garrison and volley
test_section("Garrison")

local gu = loco.new(archer, 0, 0, 0, math.pi / 2)
local gb = behaviors.garrison(gu, { { x = 0, y = 0 } }, { x = 0, y = 0, facing = math.pi / 2 })
local target = { x = -300, y = 0, z = 0 }
local volley = behaviors.volley()
local world = { targets = { target }, volley = volley }

gb:update(dt, world)      -- march ends: already at the post
gb:update(dt, world)      -- hold: acquires the target
test("acquires a target within acquisition range", gb.target == target and gb.state == "aim")

local t, first_shot = 0, nil
while t < 10 and not first_shot do
    gb:update(dt, world)
    t = t + dt
    if (gb.shots or 0) > 0 then first_shot = t end
end
-- it faced north; the target is west: a quarter turn, then the windup
local turn_time = (math.pi / 2 - math.rad(archer.face_tolerance)) / loco.turn_speed(archer.turn_rate)
test("turns to face before loosing",
    first_shot and first_shot >= turn_time + archer.attack_point - 2 * dt,
    string.format("shot at %.2fs, turn+windup %.2fs", first_shot or -1, turn_time + archer.attack_point))

local shots_at = {}
local last = gb.shots
for _ = 1, 500 do
    gb:update(dt, world)
    t = t + dt
    if gb.shots ~= last then shots_at[#shots_at + 1] = t; last = gb.shots end
end
test("shoots once per cooldown",
    #shots_at >= 2 and near(shots_at[2] - shots_at[1], archer.cooldown, 2 * dt),
    #shots_at >= 2 and string.format("%.2fs apart", shots_at[2] - shots_at[1]) or "too few shots")

local hits = 0
for _ = 1, 200 do hits = hits + #volley:update(dt) end
test("arrows reach their target", hits > 0)

target.x = -2000
for _ = 1, 100 do gb:update(dt, world) end
test("lets a target go when it leaves range", gb.target == nil and gb.state == "hold")
-- }}}

-- {{{ The fort
test_section("Fort scene")

local s = fort.build()
test("25 posts", #s.posts == 25)
local unreachable = 0
for _, post in ipairs(s.posts) do if not post.route then unreachable = unreachable + 1 end end
test("every post has a route", unreachable == 0)

local tick = 0.02
local worst_climb, inside_wall = 0, 0
local last_z = {}
for _ = 1, 1500 do
    fort.update(s, tick)
    for i, bm in ipairs(s.bowmen) do
        local u2 = bm.unit
        if last_z[i] then worst_climb = math.max(worst_climb, u2.z - last_z[i]) end
        last_z[i] = u2.z
        -- standing inside a solid? the top surface there is far above its
        -- feet and it isn't in the gate's opening
        local top = s.world:height_at(u2.x, u2.y)
        local in_gate = math.abs(u2.x) < 128 and u2.y < -560 and u2.y > -820
        if top > u2.z + kit.MAX_STEP and not in_gate then inside_wall = inside_wall + 1 end
    end
end

test("never climbs more than a step at a time", worst_climb <= kit.MAX_STEP,
    string.format("%.1f", worst_climb))
test("never inside a wall", inside_wall == 0, inside_wall .. " unit-ticks")
test("every post manned within 30 s", fort.manned(s) == 25, fort.status(s))

local misplaced = {}
for _, bm in ipairs(s.bowmen) do
    local u2, post = bm.unit, bm.post
    local want = s.world:height_at(post.x, post.y)
    if loco.distance(u2, post) > 0.5 or not near(u2.z, want, 0.5) then
        misplaced[#misplaced + 1] = post.where
    end
end
test("each stands on its post at its height", #misplaced == 0, table.concat(misplaced, ", "))

local belfry = 0
for _, bm in ipairs(s.bowmen) do
    if bm.post.where == "belfry" and near(bm.unit.z, s.measures.floor) then belfry = belfry + 1 end
end
test("four up in the belfry", belfry == 4)
test("the garrison shoots and hits", s.shots > 0 and s.hits > 0, fort.status(s))

local painted = fort.paint(s, recorder)
test("a frame paints its units", painted > 25 * 5)
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
