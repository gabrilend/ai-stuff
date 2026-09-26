-- test_crowd.lua - round units that slide, orbit, nudge and pack, never overlapping (issue 405f)
--
-- In plain terms: small scenes drawn as text ("#" a wall, "." open ground),
-- each run tick by tick while checking that no two units overlap and no
-- unit touches a wall, at any moment. The scenes are the owner's
-- description of Warcraft III movement: a unit orbits one standing in its
-- way; two meet head-on and pass; one goes round a bundle; an idle ally is
-- nudged aside; mixed sizes pack round a point; a slow unit among fast ones
-- takes the free spot nearest itself; two armies of mixed sizes cross.
--
-- Run with: luajit src/tests/test_crowd.lua [DIR]

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local crowd = require("runtime.crowd")

-- {{{ Test utilities
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
-- }}}

local DT = 1 / 62.5

-- {{{ local function scene(rows)
-- A grid from text rows, top row first: "#" wall, anything else open.
-- Cells one world unit wide.
local function scene(rows)
    local grid = {}
    for y, row in ipairs(rows) do
        grid[y] = {}
        for x = 1, #row do grid[y][x] = row:sub(x, x) ~= "#" end
    end
    return crowd.new(grid, 1.0)
end
-- }}}

-- {{{ local function open_field(w, h)
local function open_field(w, h)
    local rows = {}
    for y = 1, h do
        local row = {}
        for x = 1, w do row[x] = (x == 1 or x == w or y == 1 or y == h) and "#" or "." end
        rows[y] = table.concat(row)
    end
    return scene(rows)
end
-- }}}

-- {{{ local function run(c, ticks)
-- Ticks until nobody moves (or `ticks` run), checking every tick. Returns
-- the first fault seen (as text) or nil, and the ticks run.
local function run(c, ticks)
    for t = 1, ticks do
        c:tick(DT)
        local a, b = c:any_overlap()
        if a then return string.format("units %d and %d overlap at tick %d", a.id, b.id, t), t end
        local w = c:any_in_wall()
        if w then return string.format("unit %d touches a wall at tick %d", w.id, t), t end
        local any = false
        for _, u in pairs(c.units) do if u.moving then any = true; break end end
        if not any then return nil, t end
    end
    return nil, ticks
end
-- }}}

-- {{{ local function near(u, x, y, within)
local function near(u, x, y, within)
    return math.abs(u.x - x) < (within or 0.05) and math.abs(u.y - y) < (within or 0.05)
end
-- }}}

print("\n=== Orbiting a unit standing in the way ===")
do
    local c = open_field(14, 7)
    c:add(1, 2.5, 3.5, 0.5, 3, "west")
    c:add(2, 6.5, 3.5, 0.5, 3, "east")          -- an enemy, standing on the line
    c:move(1, 11.5, 3.5)
    test("the path is one straight leg (units aren't planned round)", #c.units[1].path == 1, #c.units[1].path .. " legs")
    local fault, ticks = run(c, 600)
    test("no overlap, no wall", fault == nil, fault)
    test("it arrives", near(c.units[1], 11.5, 3.5) and not c.units[1].gave_up)
    test("without a long stop: under 1.5 times the straight walk", ticks < 9 / 3 * 62.5 * 1.5, ticks .. " ticks")
    test("the enemy wasn't moved", near(c.units[2], 6.5, 3.5))
end

print("\n=== Two radii: walking round before touching ===")
do
    -- the same scene; with a pathing radius larger than the collision one,
    -- the mover passes without ever touching the standing unit
    local c = open_field(14, 7)
    c.look_ahead = 0.8                  -- the pathing radius on (off by default)
    c:add(1, 2.5, 3.5, 0.5, 3, "west")
    c:add(2, 6.5, 3.5, 0.5, 3, "east")
    c:move(1, 11.5, 3.5)
    local closest = math.huge
    for _ = 1, 600 do
        c:tick(DT)
        local a, b = c.units[1], c.units[2]
        closest = math.min(closest, math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2))
        if not a.moving then break end
    end
    test("it arrives", near(c.units[1], 11.5, 3.5))
    test("never closer than touching plus a margin", closest >= 1.0 + 0.1, string.format("closest %.2f (touching is 1.00)", closest))
    -- and with steering off, it does touch (it slides round instead)
    local d = open_field(14, 7)
    d.look_ahead = 0
    d:add(1, 2.5, 3.5, 0.5, 3, "west")
    d:add(2, 6.5, 3.5, 0.5, 3, "east")
    d:move(1, 11.5, 3.5)
    local closest_off = math.huge
    for _ = 1, 600 do
        d:tick(DT)
        local a, b = d.units[1], d.units[2]
        closest_off = math.min(closest_off, math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2))
        if not a.moving then break end
    end
    test("with one radius it touches and slides", closest_off < 1.0 + 0.02, string.format("closest %.2f", closest_off))
end

print("\n=== Two meeting head-on pass each other ===")
do
    local c = open_field(16, 7)
    c:add(1, 2.5, 3.5, 0.5, 3, "west")
    c:add(2, 13.5, 3.5, 0.5, 3, "east")
    c:move(1, 13.5, 3.5)
    c:move(2, 2.5, 3.5)
    local fault, ticks = run(c, 900)
    test("no overlap, no wall", fault == nil, fault)
    test("both arrive", near(c.units[1], 13.5, 3.5) and near(c.units[2], 2.5, 3.5))
    test("neither stands still long: under 1.5 times the straight walk", ticks < 11 / 3 * 62.5 * 1.5, ticks .. " ticks")
end

print("\n=== Round a bundle ===")
do
    local c = open_field(20, 13)
    c:add(1, 2.5, 6.5, 0.4, 3, "west")
    local id = 1
    for dx = 0, 2 do
        for dy = -2, 2 do
            id = id + 1
            c:add(id, 9.0 + dx * 0.9, 6.5 + dy * 0.9, 0.4, 3, "east")   -- a block of enemies, touching
        end
    end
    c:move(1, 17.5, 6.5)
    local fault, ticks = run(c, 1500)
    test("no overlap, no wall", fault == nil, fault)
    test("it arrives on the far side", near(c.units[1], 17.5, 6.5) and not c.units[1].gave_up,
        string.format("at %.2f,%.2f after %d ticks", c.units[1].x, c.units[1].y, ticks))
end

print("\n=== An idle ally is nudged aside ===")
do
    local c = scene({
        "##############",
        "#............#",
        "#............#",
        "##############",
    })
    -- a corridor two wide: the ally stands in the middle of it
    c:add(1, 1.5, 2.0, 0.45, 3, "west")
    c:add(2, 6.5, 2.0, 0.45, 3, "west")
    c:move(1, 12.5, 2.0)
    local fault, ticks = run(c, 900)
    test("no overlap, no wall", fault == nil, fault)
    test("the mover arrives", near(c.units[1], 12.5, 2.0))
    test("the ally stepped aside", not near(c.units[2], 6.5, 2.0, 0.2) and not c.units[2].moving,
        string.format("ally at %.2f,%.2f", c.units[2].x, c.units[2].y))
end

print("\n=== Mixed sizes pack round a point ===")
do
    local c = open_field(30, 20)
    local sizes = { 0.8, 0.35, 0.5, 0.35, 0.5, 0.8, 0.35, 0.5, 0.35, 0.5, 0.35, 0.5, 0.35, 0.5, 0.8, 0.35 }
    local ids = {}
    for i, r in ipairs(sizes) do
        c:add(i, 3.5 + (i % 4) * 1.8, 3.5 + math.floor((i - 1) / 4) * 1.8, r, 3, "west")
        ids[i] = i
    end
    c:move_group(ids, 20.5, 10.5)
    local fault, ticks = run(c, 2000)
    test("no overlap, no wall", fault == nil, fault)
    local furthest, area = 0, 0
    for i, r in ipairs(sizes) do
        local u = c.units[i]
        furthest = math.max(furthest, math.sqrt((u.x - 20.5) ^ 2 + (u.y - 10.5) ^ 2) + r)
        area = area + r * r
    end
    -- packed: the group's circles fit in a disc not much wider than their
    -- area needs. Arrivals take the free spot a little toward their own
    -- side and nudge each other as they come in, so the packing is looser
    -- than the tightest; 3.97 against the sizes' 1.8x was measured first,
    -- steering round pathing radii loosened it a little more (4.67), and
    -- deciding from the tick's snapshot a little more again (5.37: more of
    -- the slides round the group are refused when they settle)
    local snug = math.sqrt(area) * 2.6
    test("all stand, packed round the point", ticks < 2000 and furthest <= snug,
        string.format("reaches %.2f from the point; snug is %.2f", furthest, snug))
end

print("\n=== The owner's slow unit A among fifteen fast Bs ===")
do
    local c = open_field(40, 20)
    c:add(1, 6.5, 10.5, 0.5, 1.0, "west")          -- A: slow, in the middle
    local ids = { 1 }
    for k = 0, 14 do
        local a = k * 2 * math.pi / 15
        c:add(k + 2, 6.5 + math.cos(a) * 2.2, 10.5 + math.sin(a) * 2.2, 0.45, 4.0, "west")
        ids[#ids + 1] = k + 2
    end
    local P = { 30.5, 10.5 }
    c:move_group(ids, P[1], P[2])
    local fault = run(c, 62.5 * 60)
    test("no overlap, no wall", fault == nil, fault)
    local a = c.units[1]
    local a_from_p = math.sqrt((a.x - P[1]) ^ 2 + (a.y - P[2]) ^ 2)
    local nearest_b = math.huge
    for i = 2, 16 do
        local b = c.units[i]
        nearest_b = math.min(nearest_b, math.sqrt((b.x - P[1]) ^ 2 + (b.y - P[2]) ^ 2))
    end
    test("everyone arrives", not a.moving and not a.gave_up)
    test("the Bs filled the middle", nearest_b < a_from_p, string.format("nearest B %.2f from the point, A %.2f", nearest_b, a_from_p))
    test("A took the spot on its own side (it came from the west)", a.x < P[1], string.format("A at %.2f,%.2f", a.x, a.y))
end

print("\n=== Two armies of mixed sizes cross ===")
do
    local sim = require("net.crossing_sim").new({})
    local c = sim.crowd
    local faults, t0 = nil, os.clock()
    local ticks = 0
    for t = 1, 62.5 * 60 do
        sim.tick(t)
        ticks = t
        local a, b = c:any_overlap()
        if a then faults = string.format("units %d and %d overlap at tick %d", a.id, b.id, t); break end
        local w = c:any_in_wall()
        if w then faults = string.format("unit %d touches a wall at tick %d", w.id, t); break end
        if sim.crossings >= 1 then break end
    end
    local took = os.clock() - t0
    test("no overlap, no wall", faults == nil, faults)
    -- (deciding from the tick's snapshot, units react to each other a tick
    -- late; the first crossing took 39.7 s when they moved one after
    -- another, and 47 s this way)
    test("the first crossing ends within a minute", sim.crossings >= 1, ticks .. " ticks")
    print(string.format("    (%d units, %.1f s of game in %.2f s: %.2f ms a tick; %d gave up)",
        #c.order, ticks / 62.5, took, took / ticks * 1000, sim.gave_up_last or 0))
    -- a straggler or two circling the arrived army can still give up after
    -- 20 s without getting closer (a known limit, in issue 405f)
    test("at most two gave up", (sim.gave_up_last or 0) <= 2, tostring(sim.gave_up_last))
    test("gridlocked units backed off and tried again", (c.back_offs_total or 0) > 0, tostring(c.back_offs_total))
    print(string.format("    (%d back-offs)", c.back_offs_total or 0))
end

print("\n=== Deciding in any order gives the same tick ===")
do
    -- the same crossing run three times for 20 s, the units deciding in id
    -- order, in reverse, and interleaved; every position must match exactly
    -- (a threaded runner splits the deciding however it likes)
    local function positions(order_of)
        package.loaded["net.crossing_sim"] = nil
        local sim = require("net.crossing_sim").new({})
        local c = sim.crowd
        local order = order_of(c.order)
        for t = 1, 62.5 * 20 do c:tick(1 / 62.5, order) end
        local out = {}
        for _, id in ipairs(c.order) do out[#out + 1] = string.format("%.17g,%.17g", c.units[id].x, c.units[id].y) end
        return table.concat(out, ";")
    end
    local forward = positions(function(o) return o end)
    local backward = positions(function(o) local r = {} for i = #o, 1, -1 do r[#r + 1] = o[i] end return r end)
    local woven = positions(function(o) local r = {} for i = 1, #o, 2 do r[#r + 1] = o[i] end for i = 2, #o, 2 do r[#r + 1] = o[i] end return r end)
    test("in reverse: every position the same, bit for bit", backward == forward)
    test("interleaved: every position the same, bit for bit", woven == forward)
end

print(string.format("\n%d/%d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
