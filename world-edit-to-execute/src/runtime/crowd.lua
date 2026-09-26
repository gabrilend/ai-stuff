--[[
crowd.lua - units that path around each other and never overlap (issue 405f)

What this is: ground units moving the way Warcraft III's do. The owner
(2026-09-25): "units path around each other and don't walk into the same
area that another unit is in"; and a unit meeting a friendly unit standing
still "paths around."

It stands alone (no global entity system), so the server's own thread can
run one: a grid of walkable cells, and round units on it.

The rules, each tick, in unit id order:
  - a moving unit steps toward its next waypoint only if the step ends
    clear of every other unit and of every wall; nobody is ever pushed;
  - otherwise it is blocked this tick:
      blocked by a unit that isn't getting anywhere (standing, or moving
        but stalled for a few ticks) -> it plans again around it, a few
        ticks apart (standing and stalled units are obstacles to planning,
        and this one stopped after the path was made);
      blocked by a unit that is moving -> it waits a few ticks (the other
        is probably moving on), then plans again with that unit as an
        obstacle too; the wait is a little longer for higher ids, so two
        units blocking each other don't both step aside at once, the same
        way;
  - a goal it can't reach: it goes as close as it can and stands there;
  - no path at all (it can't even leave its cell): it waits, tries again
    now and then, and after a while gives up and stands where it is (then
    it is an obstacle to others); so does a unit that has come no closer to
    its goal for that long (in a crowd a unit can step, be blocked, re-plan
    and step again forever without getting anywhere; the first version
    counted only blocked ticks in a row, and some units shuffled for over a
    minute);
  - a unit whose goal is taken aims for the nearest free cell instead, and
    looks again when it gets there: the goal may have been freed.

A group ordered together (move_group) is all marked moving before anyone
plans, so a group doesn't weave around its own members' starting places.

A known limit: two groups meeting head-on in a gap no wider than
themselves jam for good. Each front stalls against the other, the stalled
fronts wall off the gap, nobody behind can plan a path, and after five
seconds everyone gives up. A 12-cell gap passes two 8-deep armies; an
8-cell gap doesn't. A "keep right" planning cost was tried and removed: it
only acts on paths that already bend, not straight-across ones, and
Warcraft III is not known to do it.

Why stalled units count as standing: in a crowd, a unit blocked by a
"moving" unit that is itself waiting would wait on it forever; the first
version gridlocked two armies of 40 this way within a second.

Planning is A* over cells, eight directions, with no diagonal step past a
wall's corner (a round unit would clip it; the project's general A*,
runtime/pathfinding/astar.lua, allows those, so this has its own). A cell
is blocked for a unit when it isn't walkable, or when a standing unit (or
an extra obstacle) is close enough to its centre that this unit, standing
there, would overlap it.

Same orders, same result: nothing here reads a clock or draws a random
number, and units are always visited in id order.
]]

local crowd = {}
crowd.__index = crowd

-- {{{ The numbers (changes go in docs/balance-updates.md)
crowd.WAIT_TICKS = 8          -- blocked by a moving unit: ticks before planning around it
crowd.STALL_TICKS = 4         -- a moving unit that hasn't moved this long counts as standing
crowd.REPLAN_TICKS = 4        -- blocked by a standing or stalled unit: ticks between re-plans
crowd.RETRY_TICKS = 16        -- no path: ticks between tries
crowd.GIVE_UP_TICKS = 312     -- pathless this long (5 s at 62.5/s): stand
crowd.NO_PROGRESS_TICKS = 1250 -- no closer to the goal this long (20 s): give up; a unit queued in a
                              -- jam can wait long, and 5 or 10 s gave up on half of two crossing armies
crowd.PROGRESS = 0.25         -- getting this much (world units) closer to the goal counts as progress
crowd.ARRIVE_EPSILON = 0.02   -- this close to a waypoint counts as there
crowd.PLAN_MARGIN = 0.15      -- planning keeps this much (in cells) further from obstacles than touching:
                              -- a unit sets off from off-centre, so a cell whose centre is just clear
                              -- could still have a blocked first step. Kept under 0.2 so that, with
                              -- units of 0.4 cells, a standing unit doesn't also close the cells
                              -- beside it
-- }}}

-- {{{ function crowd.new(grid, cell_size)
-- `grid`: rows of booleans, grid[y][x], true where ground units may walk
-- (x, y from 1). `cell_size`: world units a cell spans. Cell (x, y) covers
-- world x from (x-1)*cell_size to x*cell_size, and likewise y.
function crowd.new(grid, cell_size)
    local c = setmetatable({
        grid = grid, cell = cell_size, h = #grid, w = #grid[1],
        units = {}, order = {},      -- by id; ids in ascending order
        tick_count = 0,
        bucket_size = 2 * cell_size, buckets = {},
    }, crowd)
    return c
end
-- }}}

-- {{{ function crowd:add(id, x, y, radius, speed)
-- A standing unit. `speed` in world units a second.
function crowd:add(id, x, y, radius, speed)
    if self.units[id] then error("unit " .. id .. " is already in the crowd", 0) end
    self.units[id] = {
        id = id, x = x, y = y, radius = radius, speed = speed,
        moving = false, path = nil, step = 0, goal_x = x, goal_y = y,
        blocked = 0, pathless = 0, retry = 0, stalled = 0, vx = 0, vy = 0, facing = 0,
        closest = math.huge, no_progress = 0,
        exact = true,
        gave_up = false, path_changed = false,
    }
    self.order[#self.order + 1] = id
    table.sort(self.order)
end
-- }}}

-- {{{ Cells and the world
-- {{{ function crowd:cell_of(x, y)
function crowd:cell_of(x, y)
    return math.floor(x / self.cell) + 1, math.floor(y / self.cell) + 1
end
-- }}}

-- {{{ function crowd:centre_of(cx, cy)
function crowd:centre_of(cx, cy)
    return (cx - 0.5) * self.cell, (cy - 0.5) * self.cell
end
-- }}}

-- {{{ function crowd:walkable(cx, cy)
function crowd:walkable(cx, cy)
    local row = self.grid[cy]
    return row ~= nil and row[cx] == true
end
-- }}}

-- {{{ function crowd:clear_of_walls(x, y, r)
-- Whether a circle at (x, y) touches only walkable cells: the cells under
-- its four extreme points and its centre (units are smaller than a cell).
function crowd:clear_of_walls(x, y, r)
    return self:walkable(self:cell_of(x, y))
        and self:walkable(self:cell_of(x - r, y)) and self:walkable(self:cell_of(x + r, y))
        and self:walkable(self:cell_of(x, y - r)) and self:walkable(self:cell_of(x, y + r))
end
-- }}}
-- }}}

-- {{{ The spatial hash
-- Units by square buckets twice a cell wide, rebuilt each tick and kept up
-- as units step. Neighbours of a point: the 3x3 buckets around it.

-- {{{ local function bucket_key(c, x, y)
local function bucket_key(c, x, y)
    return math.floor(x / c.bucket_size) * 65536 + math.floor(y / c.bucket_size)
end
-- }}}

-- {{{ function crowd:rehash()
function crowd:rehash()
    self.buckets = {}
    for _, id in ipairs(self.order) do
        local u = self.units[id]
        local k = bucket_key(self, u.x, u.y)
        local b = self.buckets[k]
        if not b then b = {}; self.buckets[k] = b end
        b[#b + 1] = u
        u.bucket = k
    end
end
-- }}}

-- {{{ function crowd:move_in_hash(u)
function crowd:move_in_hash(u)
    local k = bucket_key(self, u.x, u.y)
    if k == u.bucket then return end
    local old = self.buckets[u.bucket]
    for i = 1, #old do if old[i] == u then table.remove(old, i); break end end
    local b = self.buckets[k]
    if not b then b = {}; self.buckets[k] = b end
    b[#b + 1] = u
    u.bucket = k
end
-- }}}

-- {{{ function crowd:overlapping(u, x, y)
-- The first unit (lowest id) a circle of u's radius at (x, y) would
-- overlap, other than u itself; nil when clear.
function crowd:overlapping(u, x, y)
    local bx, by = math.floor(x / self.bucket_size), math.floor(y / self.bucket_size)
    local found
    for dx = -1, 1 do
        for dy = -1, 1 do
            local b = self.buckets[(bx + dx) * 65536 + (by + dy)]
            if b then
                for _, o in ipairs(b) do
                    if o ~= u then
                        local reach = u.radius + o.radius
                        local ox, oy = o.x - x, o.y - y
                        if ox * ox + oy * oy < reach * reach - 1e-9 and (not found or o.id < found.id) then found = o end
                    end
                end
            end
        end
    end
    return found
end
-- }}}
-- }}}

-- {{{ Planning
-- {{{ local function heap_push(heap, node, f)
-- A binary heap of {node, f}, smallest f on top.
local function heap_push(heap, node, f)
    local n = #heap + 1
    heap[n] = { node, f }
    while n > 1 do
        local parent = math.floor(n / 2)
        if heap[parent][2] <= heap[n][2] then break end
        heap[parent], heap[n] = heap[n], heap[parent]
        n = parent
    end
end
-- }}}

-- {{{ local function heap_pop(heap)
local function heap_pop(heap)
    local top = heap[1]
    local last = table.remove(heap)
    if #heap > 0 then
        heap[1] = last
        local n = 1
        while true do
            local l, r, small = 2 * n, 2 * n + 1, n
            if heap[l] and heap[l][2] < heap[small][2] then small = l end
            if heap[r] and heap[r][2] < heap[small][2] then small = r end
            if small == n then break end
            heap[small], heap[n] = heap[n], heap[small]
            n = small
        end
    end
    return top[1]
end
-- }}}

local STEPS = { { 1, 0, 1 }, { -1, 0, 1 }, { 0, 1, 1 }, { 0, -1, 1 },
                { 1, 1, 1.41421356 }, { 1, -1, 1.41421356 }, { -1, 1, 1.41421356 }, { -1, -1, 1.41421356 } }

-- {{{ function crowd:in_the_way(o)
-- Whether o is an obstacle to planning: standing, or moving but stalled.
function crowd:in_the_way(o)
    return not o.moving or o.stalled >= crowd.STALL_TICKS
end
-- }}}

-- {{{ function crowd:blocked_cells(u, extra)
-- The cells u may not plan through because a standing or stalled unit (or
-- one of the `extra` units) is too close to their centre. A set keyed
-- x*65536+y.
function crowd:blocked_cells(u, extra)
    local blocked = {}
    -- {{{ local function block_around(o)
    local function block_around(o)
        local reach = u.radius + o.radius + crowd.PLAN_MARGIN * self.cell
        local x1, y1 = self:cell_of(o.x - reach, o.y - reach)
        local x2, y2 = self:cell_of(o.x + reach, o.y + reach)
        for cy = y1, y2 do
            for cx = x1, x2 do
                local mx, my = self:centre_of(cx, cy)
                local dx, dy = mx - o.x, my - o.y
                if dx * dx + dy * dy < reach * reach then blocked[cx * 65536 + cy] = true end
            end
        end
    end
    -- }}}
    for _, id in ipairs(self.order) do
        local o = self.units[id]
        if o ~= u and self:in_the_way(o) then block_around(o) end
    end
    for _, o in ipairs(extra or {}) do block_around(o) end
    return blocked
end
-- }}}

-- {{{ function crowd:plan(u, extra)
-- A path (world points, cell centres, ending at the goal point or the
-- nearest free cell to it) for u, or nil when there is none; and whether
-- it ends at the goal itself. The cell u is
-- in is always usable: it is already there.
function crowd:plan(u, extra)
    local blocked = self:blocked_cells(u, extra)
    local sx, sy = self:cell_of(u.x, u.y)
    -- {{{ local function open(cx, cy)
    local function open(cx, cy)
        if cx == sx and cy == sy then return true end
        return self:walkable(cx, cy) and not blocked[cx * 65536 + cy]
    end
    -- }}}
    -- the goal, or the nearest open cell to it (rings outward, lowest cost first)
    local gx, gy = self:cell_of(u.goal_x, u.goal_y)
    local exact = open(gx, gy)
    if not exact then
        local best, best_d
        for ring = 1, math.max(self.w, self.h) do
            for cy = gy - ring, gy + ring do
                for cx = gx - ring, gx + ring do
                    if (math.abs(cx - gx) == ring or math.abs(cy - gy) == ring) and open(cx, cy) then
                        local d = (cx - gx) ^ 2 + (cy - gy) ^ 2
                        if not best_d or d < best_d then best, best_d = { cx, cy }, d end
                    end
                end
            end
            if best then break end
        end
        if not best then return nil, false end
        gx, gy = best[1], best[2]
    end
    -- A*, octile distance
    local g, from, closed = { [sx * 65536 + sy] = 0 }, {}, {}
    local heap = {}
    -- {{{ local function h(cx, cy)
    local function h(cx, cy)
        local dx, dy = math.abs(cx - gx), math.abs(cy - gy)
        return math.max(dx, dy) + 0.41421356 * math.min(dx, dy)
    end
    -- }}}
    heap_push(heap, sx * 65536 + sy, h(sx, sy))
    local found = false
    -- the closest cell to the goal reached so far: where to go when the goal
    -- can't be reached (as close as it can get)
    local closest, closest_h = sx * 65536 + sy, h(sx, sy)
    while #heap > 0 do
        local key = heap_pop(heap)
        if not closed[key] then
            closed[key] = true
            local cx, cy = math.floor(key / 65536), key % 65536
            if cx == gx and cy == gy then found = true; break end
            if h(cx, cy) < closest_h then closest, closest_h = key, h(cx, cy) end
            for _, s in ipairs(STEPS) do
                local nx, ny = cx + s[1], cy + s[2]
                -- a diagonal step needs both cells beside it open (no corner cutting)
                local diagonal_ok = s[1] == 0 or s[2] == 0 or (open(cx + s[1], cy) and open(cx, cy + s[2]))
                if diagonal_ok and open(nx, ny) then
                    local nk = nx * 65536 + ny
                    local ng = g[key] + s[3]
                    if not g[nk] or ng < g[nk] then
                        g[nk], from[nk] = ng, key
                        heap_push(heap, nk, ng + h(nx, ny))
                    end
                end
            end
        end
    end
    -- Two paths: the goal cell was reached -> the path to it; it wasn't ->
    -- the path to the closest cell reached, not ending at the goal (nil
    -- only if the unit can't leave its own cell at all)
    local key = gx * 65536 + gy
    if not found then
        if closest == sx * 65536 + sy then return nil, false end
        key, exact = closest, false
    end
    local cells = {}
    while key ~= sx * 65536 + sy do
        table.insert(cells, 1, key)
        key = from[key]
    end
    local path = {}
    -- already in the goal's cell: the only step left is to the goal point
    -- (or none, when the goal was taken and this cell is the nearest free)
    if #cells == 0 then
        if exact then path[1] = { x = u.goal_x, y = u.goal_y } end
        return path, exact
    end
    for i, k in ipairs(cells) do
        local px, py = self:centre_of(math.floor(k / 65536), k % 65536)
        -- the last point is the goal itself when it was reachable
        if i == #cells and exact then px, py = u.goal_x, u.goal_y end
        path[#path + 1] = { x = px, y = py }
    end
    return path, exact
end
-- }}}
-- }}}

-- {{{ function crowd:move(id, x, y)
-- Orders a unit to (x, y). Planned now; with no path it waits and retries.
function crowd:move(id, x, y)
    local u = self.units[id]
    if not u then error("no unit " .. id .. " in the crowd", 0) end
    u.goal_x, u.goal_y = x, y
    u.moving, u.gave_up = true, false
    u.blocked, u.pathless, u.stalled = 0, 0, 0
    u.closest, u.no_progress = math.huge, 0
    self:replan(u)
end
-- }}}

-- {{{ function crowd:move_group(orders)
-- Orders several units at once: `orders` is a list of {id, x, y}. Every
-- one is marked moving before any plans, so none plans around another's
-- starting place.
function crowd:move_group(orders)
    for _, o in ipairs(orders) do
        local u = self.units[o[1]]
        if not u then error("no unit " .. o[1] .. " in the crowd", 0) end
        u.goal_x, u.goal_y = o[2], o[3]
        u.moving, u.gave_up = true, false
        u.blocked, u.pathless, u.stalled = 0, 0, 0
        u.closest, u.no_progress = math.huge, 0
    end
    for _, o in ipairs(orders) do self:replan(self.units[o[1]]) end
end
-- }}}

-- {{{ function crowd:replan(u, extra)
-- Two paths: a path found -> follow it from its start; none -> count the
-- unit pathless and try again after RETRY_TICKS.
function crowd:replan(u, extra)
    local path, exact = self:plan(u, extra)
    u.path_changed = true
    if path and #path == 0 then
        self:stand(u, false)   -- already as close as it can get
    elseif path then
        u.path, u.step, u.retry, u.exact = path, 1, 0, exact
    else
        u.path, u.step, u.retry = nil, 0, crowd.RETRY_TICKS
    end
end
-- }}}

-- {{{ function crowd:stand(u, gave_up)
function crowd:stand(u, gave_up)
    u.moving, u.path, u.step = false, nil, 0
    u.vx, u.vy = 0, 0
    u.gave_up = gave_up
    u.path_changed = true
end
-- }}}

-- {{{ function crowd:tick(dt)
-- One tick of `dt` seconds for every unit, in id order.
function crowd:tick(dt)
    self.tick_count = self.tick_count + 1
    self:rehash()
    for _, id in ipairs(self.order) do
        local u = self.units[id]
        if u.moving then self:advance(u, dt) end
    end
end
-- }}}

-- {{{ function crowd:advance(u, dt)
-- One moving unit's tick. The branches are the rules at the top of the file.
function crowd:advance(u, dt)
    -- pathless: wait for the next try, and give up after long enough
    if not u.path then
        u.pathless = u.pathless + 1
        u.stalled = u.stalled + 1
        u.vx, u.vy = 0, 0
        if u.pathless >= crowd.GIVE_UP_TICKS then self:stand(u, true); return end
        u.retry = u.retry - 1
        if u.retry <= 0 then self:replan(u) end
        return
    end
    -- no closer to the goal for too long: give up
    local to_goal = math.sqrt((u.goal_x - u.x) ^ 2 + (u.goal_y - u.y) ^ 2)
    if to_goal < u.closest - crowd.PROGRESS then u.closest, u.no_progress = to_goal, 0
    else u.no_progress = u.no_progress + 1 end
    if u.no_progress >= crowd.NO_PROGRESS_TICKS then self:stand(u, true); return end

    local target = u.path[u.step]
    local dx, dy = target.x - u.x, target.y - u.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local reach = u.speed * dt
    local nx, ny
    if dist <= reach then nx, ny = target.x, target.y
    else nx, ny = u.x + dx / dist * reach, u.y + dy / dist * reach end

    local blocker = self:overlapping(u, nx, ny)
    local walled = not self:clear_of_walls(nx, ny, u.radius)
    if blocker or walled then
        u.vx, u.vy = 0, 0
        u.blocked = u.blocked + 1
        u.stalled = u.stalled + 1
        if walled or self:in_the_way(blocker) then
            -- standing, stalled, or a wall the path didn't expect: plan around it
            if u.blocked % crowd.REPLAN_TICKS == 1 then self:replan(u) end
        elseif u.blocked % (crowd.WAIT_TICKS + u.id % 4) == 0 then
            -- a moving unit that hasn't moved on: plan around where it is
            self:replan(u, { blocker })
        end
        return
    end

    u.blocked, u.pathless, u.stalled = 0, 0, 0
    if dist > 1e-9 then u.facing = math.atan2(dy, dx) end
    u.vx, u.vy = (nx - u.x) / dt, (ny - u.y) / dt
    u.x, u.y = nx, ny
    self:move_in_hash(u)
    if math.abs(nx - target.x) < crowd.ARRIVE_EPSILON and math.abs(ny - target.y) < crowd.ARRIVE_EPSILON then
        u.step = u.step + 1
        if u.step > #u.path then
            -- Two paths: it reached the goal itself -> stand; it stopped
            -- short because the goal was taken -> look again, and stand
            -- unless the goal is now reachable
            -- (a third: it stopped short only because moving units were in
            -- the way -> wait and try again, rather than stand for good)
            local reached_goal = u.exact
            if not reached_goal then
                local path, exact = self:plan(u)
                if path and exact and #path > 0 then u.path, u.step, u.exact, u.path_changed = path, 1, true, true; return end
                if self:only_moving_units_in_the_way(u) then
                    u.path, u.step, u.retry, u.path_changed = nil, 0, crowd.RETRY_TICKS, true
                    return
                end
            end
            self:stand(u, false)
        end
    end
end
-- }}}

-- {{{ function crowd:only_moving_units_in_the_way(u)
-- Whether u could reach its goal if every moving unit (stalled or not) were
-- gone: then what stops it now will clear.
function crowd:only_moving_units_in_the_way(u)
    local saved = {}
    for _, id in ipairs(self.order) do
        local o = self.units[id]
        if o ~= u and o.moving then saved[#saved + 1] = o; o.stalled_saved = o.stalled; o.stalled = 0 end
    end
    local path, exact = self:plan(u)
    for _, o in ipairs(saved) do o.stalled = o.stalled_saved; o.stalled_saved = nil end
    return path ~= nil and exact
end
-- }}}

-- {{{ function crowd:any_overlap()
-- The first pair of units overlapping, or nil: the rule the tests hold the
-- crowd to at every tick.
function crowd:any_overlap()
    for i, a_id in ipairs(self.order) do
        local a = self.units[a_id]
        for j = i + 1, #self.order do
            local b = self.units[self.order[j]]
            local reach = a.radius + b.radius
            local dx, dy = a.x - b.x, a.y - b.y
            if dx * dx + dy * dy < reach * reach - 1e-6 then return a, b end
        end
    end
end
-- }}}

return crowd
