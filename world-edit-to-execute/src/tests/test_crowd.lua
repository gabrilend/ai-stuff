-- test_crowd.lua - units path around each other and never overlap (issue 405f)
--
-- In plain terms: small scenes drawn as text ("#" a wall, "." open ground),
-- each run tick by tick while checking that no two units overlap at any
-- moment. A unit walks around one standing in its way; two walk past each
-- other in a corridor; one re-plans around a unit that stopped in front of
-- it; one gives up on a goal it can't reach; two armies swap sides through
-- a gap.
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
-- Returns the crowd, with cells one world unit wide.
local function scene(rows)
    local grid = {}
    for y, row in ipairs(rows) do
        grid[y] = {}
        for x = 1, #row do grid[y][x] = row:sub(x, x) ~= "#" end
    end
    return crowd.new(grid, 1.0)
end
-- }}}

-- {{{ local function run(c, ticks, until_still)
-- Ticks the crowd, checking for overlap every tick. Stops early once no
-- unit is moving when `until_still`. Returns the first overlap seen (as
-- text) or nil, and the ticks run.
local function run(c, ticks, until_still)
    for t = 1, ticks do
        c:tick(DT)
        local a, b = c:any_overlap()
        if a then return string.format("units %d and %d overlap at tick %d", a.id, b.id, t), t end
        if until_still then
            local any = false
            for _, u in pairs(c.units) do if u.moving then any = true end end
            if not any then return nil, t end
        end
    end
    return nil, ticks
end
-- }}}

-- {{{ local function near(u, x, y)
local function near(u, x, y)
    return math.abs(u.x - x) < 0.05 and math.abs(u.y - y) < 0.05
end
-- }}}

print("\n=== Around a unit standing in the way ===")
do
    local c = scene({
        "#########",
        "#.......#",
        "#.......#",
        "#.......#",
        "#########",
    })
    c:add(1, 1.5, 2.5, 0.4, 3)
    c:add(2, 4.5, 2.5, 0.4, 3)          -- standing in the middle of the row
    c:move(1, 7.5, 2.5)
    local planned_through = false
    for _, p in ipairs(c.units[1].path) do if p.x == 4.5 and p.y == 2.5 then planned_through = true end end
    test("the path avoids the standing unit's cell", not planned_through)
    local overlap = run(c, 400, true)
    test("no overlap at any tick", overlap == nil, overlap)
    test("it arrives", near(c.units[1], 7.5, 2.5) and not c.units[1].gave_up)
    test("the standing unit was never moved", near(c.units[2], 4.5, 2.5))
end

print("\n=== Two walking head-on in a corridor ===")
do
    local c = scene({
        "############",
        "#..........#",
        "#..........#",
        "#..........#",
        "############",
    })
    c:add(1, 1.5, 2.5, 0.4, 3)
    c:add(2, 10.5, 2.5, 0.4, 3)
    c:move(1, 10.5, 2.5)
    c:move(2, 1.5, 2.5)
    local overlap, ticks = run(c, 1000, true)
    test("no overlap at any tick", overlap == nil, overlap)
    test("both arrive", near(c.units[1], 10.5, 2.5) and near(c.units[2], 1.5, 2.5),
        string.format("1 at %.2f,%.2f; 2 at %.2f,%.2f after %d ticks", c.units[1].x, c.units[1].y, c.units[2].x, c.units[2].y, ticks))
end

print("\n=== A unit that stops in front of another ===")
do
    local c = scene({
        "##########",
        "#........#",
        "#........#",
        "#........#",
        "##########",
    })
    c:add(1, 1.5, 2.5, 0.4, 3)
    c:add(2, 2.5, 2.5, 0.4, 1)     -- slow, walking the same way, stops at 5.5
    c:move(2, 5.5, 2.5)
    c:move(1, 8.5, 2.5)
    local overlap = run(c, 800, true)
    test("no overlap at any tick", overlap == nil, overlap)
    test("the fast one gets past and arrives", near(c.units[1], 8.5, 2.5))
    test("the slow one arrives where it was sent", near(c.units[2], 5.5, 2.5))
end

print("\n=== A goal that can't be reached ===")
do
    local c = scene({
        "#######",
        "#..#..#",
        "#..#..#",
        "#######",
    })
    c:add(1, 1.5, 1.5, 0.4, 3)
    c:move(1, 5.5, 1.5)            -- across a wall with no gap
    local overlap, ticks = run(c, 400, true)
    test("it goes as close as it can and stands", not c.units[1].moving and not c.units[1].gave_up and near(c.units[1], 2.5, 1.5),
        string.format("at %.2f,%.2f after %d ticks", c.units[1].x, c.units[1].y, ticks))
end

print("\n=== Boxed in: gives up ===")
do
    local c = scene({
        "#########",
        "#.......#",
        "#.......#",
        "#.......#",
        "#########",
    })
    -- unit 1 walled in by eight units standing around it; its goal is open
    -- and far away, so there is nowhere closer to go
    c:add(1, 2.5, 2.5, 0.4, 3)
    local id = 1
    for _, p in ipairs({ { 1.5, 1.5 }, { 2.5, 1.5 }, { 3.5, 1.5 }, { 1.5, 2.5 }, { 3.5, 2.5 }, { 1.5, 3.5 }, { 2.5, 3.5 }, { 3.5, 3.5 } }) do
        id = id + 1
        c:add(id, p[1], p[2], 0.4, 3)
    end
    c:move(1, 7.5, 2.5)
    local overlap, ticks = run(c, 400, true)
    test("no way out: it gives up after about five seconds", c.units[1].gave_up
        and ticks >= crowd.GIVE_UP_TICKS and ticks <= crowd.GIVE_UP_TICKS + crowd.RETRY_TICKS + 1, ticks .. " ticks")
end

print("\n=== The goal cell taken ===")
do
    local c = scene({
        "########",
        "#......#",
        "#......#",
        "########",
    })
    c:add(1, 1.5, 1.5, 0.4, 3)
    c:add(2, 5.5, 1.5, 0.4, 3)     -- standing on the goal
    c:move(1, 5.5, 1.5)
    local overlap = run(c, 400, true)
    test("no overlap", overlap == nil, overlap)
    test("it stops at a free cell beside the goal", not c.units[1].gave_up
        and math.abs(c.units[1].x - 5.5) <= 1.01 and math.abs(c.units[1].y - 1.5) <= 1.01 and not near(c.units[1], 5.5, 1.5))
end

print("\n=== Two armies swap sides through a gap ===")
do
    local rows = {}
    for y = 1, 24 do
        local row = {}
        for x = 1, 40 do
            local wall = x == 1 or x == 40 or y == 1 or y == 24
            -- a wall with a twelve-cell gap; an eight-cell gap, exactly the
            -- armies' depth, jams for good (see crowd.lua's known limit)
            if x == 20 and (y < 7 or y > 18) then wall = true end
            row[x] = wall and "#" or "."
        end
        rows[y] = table.concat(row)
    end
    local c = scene(rows)
    local id = 0
    local goals = {}
    for col = 0, 4 do
        for r = 0, 7 do
            id = id + 1
            c:add(id, 3.5 + col, 8.5 + r, 0.4, 3)                -- west army
            goals[id] = { 36.5 - col, 8.5 + r }
            id = id + 1
            c:add(id, 36.5 - col, 8.5 + r, 0.4, 3)               -- east army
            goals[id] = { 3.5 + col, 8.5 + r }
        end
    end
    local orders = {}
    for i = 1, id do orders[i] = { i, goals[i][1], goals[i][2] } end
    c:move_group(orders)
    local t0 = os.clock()
    local overlap, ticks = run(c, 62.5 * 60, true)
    local took = os.clock() - t0
    local arrived, gave_up = 0, 0
    for i = 1, id do
        local u = c.units[i]
        if u.gave_up then gave_up = gave_up + 1
        elseif math.abs(u.x - goals[i][1]) <= 1.5 and math.abs(u.y - goals[i][2]) <= 1.5 then arrived = arrived + 1 end
    end
    test("no overlap at any tick", overlap == nil, overlap)
    test("everyone stops moving within a minute", ticks < 62.5 * 60, ticks .. " ticks")
    test("most arrive (at or beside their goal)", arrived >= id * 0.8, string.format("%d of %d arrived, %d gave up", arrived, id, gave_up))
    print(string.format("    (%d units, %.1f s of game in %.2f s: %.2f ms a tick; %d arrived, %d gave up)",
        id, ticks / 62.5, took, took / ticks * 1000, arrived, gave_up))
end

print(string.format("\n%d/%d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
