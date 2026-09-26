--[[
crowd.lua - round units of several sizes that slide past, orbit, nudge and pack, as Warcraft III's do (issue 405f)

What this is: ground units moving the way the owner describes Warcraft III's
(2026-09-25): "That game had lots of circles and you could slide around
units easier. [...] They don't jam. If they need to get past a unit, they
'orbit' the units in the way, viewing them as a bundle. Sometimes they
stand still while units move past them." It stands alone (no global entity
system), so the server's own thread can run one.

Units are circles, each of its own size, moving continuously. The grid of
cells only describes the ground: which cells are walls, and how far each
open cell's centre is from the nearest wall (its clearance).

Each tick, in unit id order, a moving unit wants to step toward its next
waypoint. The branches, in order:
  - the step is clear of walls and every unit          -> it takes it;
  - it would overlap a unit                            -> it SLIDES: it steps
      along that unit's edge instead, always the same way round (chosen at
      first contact by which side its waypoint is on; head-on, to its
      right, so two units meeting head-on pass each other) until it is
      clear of it -- orbiting; a shorter slide is tried before giving up
      the tick;
  - it would touch a wall                              -> it slides along
      the wall (the step's part along each axis alone);
  - the one in the way is an idle unit of its own side -> that unit is
      NUDGED: it steps aside, out of the mover's line;
  - two moving units block each other for a few ticks  -> the higher id
      GIVES WAY: it steps aside out of the other's line if there's room,
      or else stands still a moment while the other goes round;
  - sliding along units without getting closer for a while -> the units
      touching the blocker form a BUNDLE, and the mover plans a new path
      with the whole bundle as an obstacle, going round it;
  - no closer to its goal for 2 s: GRIDLOCKED -> it backs off, and so do
      the stuck units round it, then all try again (up to three times an
      order), to shake the knot loose.
Before any of that, a unit STEERS round others early: each unit has two
radii, the one it collides with and a larger pathing radius, and a unit
aims to pass outside the pathing circles in its way, so it walks round
units before it touches them.
No unit ever overlaps another or a wall; a step that would is not taken.

Paths are planned around the ground only (A* over cells whose clearance
fits the unit's radius, eight directions, no corner cutting), then pulled
straight: a waypoint is kept only where a straight line would clip a wall.
Units are left to sliding, except a bundle being gone round.

Orders go to groups. A group ordered to a point gets no places in
advance: every member heads for the point itself, and a member that runs
into a groupmate who has already ARRIVED slides on toward the point while
it can, then SETTLES where it is: it has arrived too. So the first to
arrive fill the middle and a slow latecomer stops at the edge nearest
itself -- the owner's example: slow unit A among fifteen fast Bs; "The unit
B's will shuffle to fill the space unit A is intended for, and unit A will
take the closer spot." Places come from where the circles actually touch,
so units of every size end up displaced by their own radii. A unit ordered
alone is a group of one; blocked right beside its goal by anyone standing,
it stands there, as close as it can get.

(A first version reserved each member a packed spot as it came near and
sent it there. Members bound for neighbouring spots had to cross each
other at the finish, blocked each other in the last half unit, and the
crossing armies gridlocked round their destinations; swapping spots and
settling near them only moved the jam.)

A unit that gets no closer to its goal for 20 s gives up and stands.

Same orders, same result: no clock, no random numbers, units in id order.
]]

local crowd = {}
crowd.__index = crowd

-- {{{ The numbers (changes go in docs/balance-updates.md)
crowd.GAP = 0.05               -- space left between packed circles, world units
crowd.GIVE_WAY_TICKS = 6       -- two moving units blocking each other this long: one gives way
crowd.GIVE_WAY_FOR = 30        -- ... and stands still this long
crowd.BUNDLE_TICKS = 25        -- sliding along units without getting closer this long: plan round the bundle
crowd.BUNDLE_GAP = 0.3         -- units this close (edge to edge) belong to the same bundle
crowd.BUNDLE_KEEP = 120        -- ticks a bundle stays an obstacle to that unit's planning
crowd.NUDGE_EVERY = 20         -- a unit is nudged at most once in this many ticks
crowd.NO_PROGRESS_TICKS = 1250 -- no closer to the goal this long (20 s at 62.5/s): give up
crowd.PROGRESS = 0.25          -- getting this much closer counts as progress
crowd.ARRIVE = 0.02            -- this close to a waypoint counts as there
crowd.SLIDE_OUTWARD = 0.15     -- a slide leans this much away from the unit it slides along
crowd.SLIDE_AROUND = 0.5       -- ... and this much round it, on top of the part of the step not into it
crowd.REPLAN_EVERY = 15        -- a unit plans again at most this often, in ticks (new orders excepted)
crowd.SETTLE_TICKS = 10        -- blocked by an arrived groupmate within the group's packed size,
                               -- sliding without getting closer this long: settle
crowd.SETTLE_FAR_TICKS = 90    -- ... and outside it (sliding round the group for a way in)
crowd.PACKING = 0.6            -- how much of a disc packed circles of mixed sizes fill
crowd.PATHING_EXTRA = 0.2      -- a unit's pathing radius: its collision radius plus this (world units)
crowd.LOOK_AHEAD = 0.8         -- how far ahead (world units) a unit steers round others' pathing radius;
                               -- 0 turns steering off (each crowd may set its own: crowd.look_ahead).
                               -- Measured on the crossing demo (80 units, 2026-09-25): +0.35 and 1.2
                               -- took 57.6 s with 13 giving up; +0.2 and 0.8, 45.9 s and none; off,
                               -- 39.7 s and none. It suits sparse scenes better than head-on armies
crowd.GRIDLOCK_TICKS = 125     -- no closer to the goal this long (2 s): gridlocked -- back off and retry
crowd.BACK_OFF = 1.0           -- how far a gridlocked unit backs off (world units, plus its radius)
crowd.BACK_OFFS = 3            -- at most this many back-offs per order; then the give-up rule stands
-- }}}

-- {{{ Small helpers
local sqrt, floor, abs, max, min = math.sqrt, math.floor, math.abs, math.max, math.min
-- {{{ local function length(x, y)
local function length(x, y) return sqrt(x * x + y * y) end
-- }}}
-- }}}

-- {{{ function crowd.new(grid, cell_size)
-- `grid[y][x]`: true where ground units may walk (x, y from 1). Cell (x, y)
-- covers world x from (x-1)*cell_size to x*cell_size, and likewise y.
function crowd.new(grid, cell_size)
    local c = setmetatable({
        grid = grid, cell = cell_size, h = #grid, w = #grid[1],
        units = {}, order = {},
        tick_count = 0, largest = 0, buckets = {}, bucket_size = 1,
        look_ahead = crowd.LOOK_AHEAD,
    }, crowd)
    c:measure_clearance()
    return c
end
-- }}}

-- {{{ The ground
-- {{{ function crowd:cell_of(x, y)
function crowd:cell_of(x, y)
    return floor(x / self.cell) + 1, floor(y / self.cell) + 1
end
-- }}}

-- {{{ function crowd:centre_of(cx, cy)
function crowd:centre_of(cx, cy)
    return (cx - 0.5) * self.cell, (cy - 0.5) * self.cell
end
-- }}}

-- {{{ function crowd:walkable(cx, cy)
-- Outside the grid counts as wall.
function crowd:walkable(cx, cy)
    local row = self.grid[cy]
    return row ~= nil and row[cx] == true
end
-- }}}

-- {{{ local function to_rect(px, py, x1, y1, x2, y2)
-- Distance from a point to a rectangle (0 inside).
local function to_rect(px, py, x1, y1, x2, y2)
    local dx = max(x1 - px, 0, px - x2)
    local dy = max(y1 - py, 0, py - y2)
    return length(dx, dy)
end
-- }}}

-- {{{ function crowd:clear_of_walls(x, y, r)
-- Whether a circle at (x, y) of radius r touches no wall cell.
function crowd:clear_of_walls(x, y, r)
    local x1, y1 = self:cell_of(x - r, y - r)
    local x2, y2 = self:cell_of(x + r, y + r)
    local c = self.cell
    for cy = y1, y2 do
        for cx = x1, x2 do
            if not self:walkable(cx, cy) and to_rect(x, y, (cx - 1) * c, (cy - 1) * c, cx * c, cy * c) < r then
                return false
            end
        end
    end
    return true
end
-- }}}

-- {{{ function crowd:measure_clearance()
-- Each open cell's clearance: the distance from its centre to the nearest
-- wall cell's edge (the grid's outside counts as wall). Worked out once.
function crowd:measure_clearance()
    local walls = {}
    for y = 0, self.h + 1 do
        for x = 0, self.w + 1 do
            if not self:walkable(x, y) then walls[#walls + 1] = { x, y } end
        end
    end
    self.clearance = {}
    local c = self.cell
    for y = 1, self.h do
        self.clearance[y] = {}
        for x = 1, self.w do
            local best = 0
            if self:walkable(x, y) then
                best = math.huge
                local px, py = self:centre_of(x, y)
                for _, wc in ipairs(walls) do
                    local d = to_rect(px, py, (wc[1] - 1) * c, (wc[2] - 1) * c, wc[1] * c, wc[2] * c)
                    if d < best then best = d end
                end
            end
            self.clearance[y][x] = best
        end
    end
end
-- }}}
-- }}}

-- {{{ Units
-- {{{ function crowd:add(id, x, y, radius, speed, team, path_radius)
-- A standing unit. `radius` is what it collides with; `path_radius`
-- (optional; radius + PATHING_EXTRA) is the larger circle others steer
-- round, so units walk round each other before they touch (the owner,
-- 2026-09-25: "Warcraft 3 units have two separate radiuses [...] the
-- pathfinding radius is larger, so they'll try to walk around other
-- units"). `speed` in world units a second; `team` any value (units
-- nudge only their own team's).
function crowd:add(id, x, y, radius, speed, team, path_radius)
    if self.units[id] then error("unit " .. id .. " is already in the crowd", 0) end
    self.units[id] = {
        id = id, x = x, y = y, radius = radius, speed = speed, team = team or 0,
        path_radius = path_radius or radius + crowd.PATHING_EXTRA,
        backing = false, back_offs = 0,
        moving = false, path = nil, step = 0, goal_x = x, goal_y = y, exact = true,
        vx = 0, vy = 0, facing = 0, gave_up = false, path_changed = false,
        group = nil, arrived = false, settle = 0,
        orbit = 0, blocked_by = nil, mutual = 0, wait_until = 0,
        slide_since_progress = 0, bundle = nil, bundle_until = 0,
        closest = math.huge, no_progress = 0, nudged_at = -math.huge,
    }
    self.order[#self.order + 1] = id
    table.sort(self.order)
    if radius > self.largest then
        self.largest = radius
        self.bucket_size = 2 * radius + crowd.BUNDLE_GAP
    end
end
-- }}}

-- {{{ The spatial hash
-- Units by square buckets as wide as the two largest units side by side;
-- neighbours of a point are in the 3x3 buckets around it. Rebuilt each
-- tick and kept up as units step.

-- {{{ local function bucket_key(c, x, y)
local function bucket_key(c, x, y)
    return floor(x / c.bucket_size) * 65536 + floor(y / c.bucket_size)
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

-- {{{ function crowd:rebucket(u)
function crowd:rebucket(u)
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

-- {{{ function crowd:near(x, y, fn)
-- Calls fn(o) for every unit in the 3x3 buckets around (x, y).
function crowd:near(x, y, fn)
    local bx, by = floor(x / self.bucket_size), floor(y / self.bucket_size)
    for dx = -1, 1 do
        for dy = -1, 1 do
            local b = self.buckets[(bx + dx) * 65536 + (by + dy)]
            if b then for i = 1, #b do fn(b[i]) end end
        end
    end
end
-- }}}

-- {{{ function crowd:overlapping(u, x, y)
-- The unit a circle of u's size at (x, y) would overlap most deeply (not
-- u itself), or nil.
function crowd:overlapping(u, x, y)
    local found, deepest = nil, 0
    self:near(x, y, function(o)
        if o ~= u then
            local reach = u.radius + o.radius
            local dx, dy = o.x - x, o.y - y
            local d2 = dx * dx + dy * dy
            if d2 < reach * reach - 1e-9 then
                local depth = reach - sqrt(d2)
                if depth > deepest or (depth == deepest and found and o.id < found.id) then found, deepest = o, depth end
            end
        end
    end)
    return found
end
-- }}}
-- }}}
-- }}}

-- {{{ Planning
-- {{{ local function heap_push(heap, node, f)
local function heap_push(heap, node, f)
    local n = #heap + 1
    heap[n] = { node, f }
    while n > 1 do
        local parent = floor(n / 2)
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

-- {{{ local function inside_any(x, y, r, circles)
-- Whether a circle of radius r at (x, y) overlaps any of `circles`.
local function inside_any(x, y, r, circles)
    if not circles then return false end
    for _, o in ipairs(circles) do
        local reach = r + o.radius
        if (o.x - x) ^ 2 + (o.y - y) ^ 2 < reach * reach then return true end
    end
    return false
end
-- }}}

-- {{{ function crowd:line_clear(x1, y1, x2, y2, r, circles)
-- Whether a circle of radius r can travel straight from one point to the
-- other without touching a wall or any of `circles`.
function crowd:line_clear(x1, y1, x2, y2, r, circles)
    local d = length(x2 - x1, y2 - y1)
    local steps = max(1, math.ceil(d / (self.cell * 0.25)))
    for i = 0, steps do
        local t = i / steps
        local x, y = x1 + (x2 - x1) * t, y1 + (y2 - y1) * t
        if not self:clear_of_walls(x, y, r) or inside_any(x, y, r, circles) then return false end
    end
    return true
end
-- }}}

-- {{{ function crowd:plan(u, tx, ty, circles)
-- A path for u to (tx, ty): a list of waypoints, pulled straight; and
-- whether it ends at (tx, ty) itself (otherwise at the reachable place
-- nearest it). Planned around the ground and `circles` (a bundle) only;
-- nil when u can't leave where it is.
function crowd:plan(u, tx, ty, circles)
    local r = u.radius
    local sx, sy = self:cell_of(u.x, u.y)
    -- {{{ local function open(cx, cy)
    local function open(cx, cy)
        if cx == sx and cy == sy then return true end
        local row = self.clearance[cy]
        if not row or not row[cx] or row[cx] < r then return false end
        local px, py = self:centre_of(cx, cy)
        return not inside_any(px, py, r, circles)
    end
    -- }}}
    local gx, gy = self:cell_of(tx, ty)
    local fits = self:clear_of_walls(tx, ty, r) and not inside_any(tx, ty, r, circles)
    -- {{{ local function h(cx, cy)
    local function h(cx, cy)
        local dx, dy = abs(cx - gx), abs(cy - gy)
        return max(dx, dy) + 0.41421356 * min(dx, dy)
    end
    -- }}}
    local g, from, closed = { [sx * 65536 + sy] = 0 }, {}, {}
    local heap = {}
    heap_push(heap, sx * 65536 + sy, h(sx, sy))
    local closest, closest_h = sx * 65536 + sy, h(sx, sy)
    local found = false
    while #heap > 0 do
        local key = heap_pop(heap)
        if not closed[key] then
            closed[key] = true
            local cx, cy = floor(key / 65536), key % 65536
            -- the goal's cell counts as reached even if its centre is tight,
            -- as long as the goal point itself fits
            if cx == gx and cy == gy then found = true; break end
            local hh = h(cx, cy)
            if hh < closest_h then closest, closest_h = key, hh end
            for _, s in ipairs(STEPS) do
                local nx, ny = cx + s[1], cy + s[2]
                local diagonal_ok = s[1] == 0 or s[2] == 0 or (open(cx + s[1], cy) and open(cx, cy + s[2]))
                local enterable = open(nx, ny) or (nx == gx and ny == gy and fits)
                if diagonal_ok and enterable then
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
    -- Two paths: the goal's cell reached -> end at the goal point (if it
    -- fits there) or that cell's centre; not reached -> end at the
    -- closest cell reached
    local exact = found and fits
    local key = gx * 65536 + gy
    if not found then
        key = closest
        if key == sx * 65536 + sy then return nil, false end
    end
    local points = {}
    while key ~= sx * 65536 + sy do
        local px, py = self:centre_of(floor(key / 65536), key % 65536)
        table.insert(points, 1, { x = px, y = py })
        key = from[key]
    end
    if exact then
        if #points > 0 then points[#points] = { x = tx, y = ty } else points[1] = { x = tx, y = ty } end
    end
    if #points == 0 then return nil, false end
    -- pull straight: from each kept point, jump to the furthest point in
    -- plain sight at this radius
    local pulled, fx, fy, i = {}, u.x, u.y, 1
    while i <= #points do
        local far = i
        for j = #points, i + 1, -1 do
            if self:line_clear(fx, fy, points[j].x, points[j].y, r, circles) then far = j; break end
        end
        pulled[#pulled + 1] = points[far]
        fx, fy = points[far].x, points[far].y
        i = far + 1
    end
    return pulled, exact
end
-- }}}

-- {{{ function crowd:replan(u, circles)
-- Plans again toward the same goal, unless u planned less than
-- REPLAN_EVERY ticks ago (then it carries on as it is). Planning is the
-- costly part of a tick: the first version re-planned about 21 units a
-- tick in the crossing, 14 ms a tick.
function crowd:replan(u, circles)
    if self.tick_count - (u.planned_at or -math.huge) < crowd.REPLAN_EVERY then return end
    self:head_for(u, u.goal_x, u.goal_y, circles)
end
-- }}}

-- {{{ function crowd:head_for(u, tx, ty, circles)
-- Plans u's way to (tx, ty) and sets it moving. Two paths: a path ->
-- follow it; none (u can't leave where it is) -> keep the goal, try again
-- later.
function crowd:head_for(u, tx, ty, circles)
    u.planned_at = self.tick_count
    u.goal_x, u.goal_y = tx, ty
    local path, exact = self:plan(u, tx, ty, circles)
    -- no way round the bundle: plan as usual, and slide
    if not path and circles then
        u.bundle, u.bundle_until = nil, 0
        path, exact = self:plan(u, tx, ty)
    end
    u.path, u.step, u.exact = path, 1, exact
    u.path_changed = true
    u.moving = true
end
-- }}}
-- }}}

-- {{{ Groups and formations
-- {{{ function crowd:free_spot(cx, cy, u, taken, skip)
-- The free place nearest (cx, cy) where u fits: clear of walls, of every
-- spot in `taken` (circles {x, y, radius}), and of standing units other
-- than u and those in `skip` (a set: the members already in `taken`).
-- Candidates are the point itself and places touching each taken spot,
-- sixteen round each. Scored by distance to the point plus a quarter of
-- the distance to u, so that among equally central places u takes the one
-- nearest itself. Nil when there's nowhere.
function crowd:free_spot(cx, cy, u, taken, skip)
    local r = u.radius
    local candidates = { { cx, cy } }
    -- rings round the point too, for when the point itself is blocked by
    -- someone not in the group
    for ring = 1, 3 do
        for k = 0, 11 do
            local a = k * math.pi / 6
            candidates[#candidates + 1] = { cx + math.cos(a) * ring * (r * 2 + crowd.GAP), cy + math.sin(a) * ring * (r * 2 + crowd.GAP) }
        end
    end
    for _, s in ipairs(taken) do
        local d = s.radius + r + crowd.GAP
        for k = 0, 15 do
            local a = k * math.pi / 8
            candidates[#candidates + 1] = { s.x + math.cos(a) * d, s.y + math.sin(a) * d }
        end
    end
    local best, best_score
    for _, p in ipairs(candidates) do
        local x, y = p[1], p[2]
        local score = length(x - cx, y - cy) + 0.25 * length(x - u.x, y - u.y)
        if (not best_score or score < best_score) and self:clear_of_walls(x, y, r) then
            local ok = true
            for _, s in ipairs(taken) do
                local reach = s.radius + r + crowd.GAP * 0.5
                if (s.x - x) ^ 2 + (s.y - y) ^ 2 < reach * reach then ok = false; break end
            end
            if ok then
                self:near(x, y, function(o)
                    if ok and o ~= u and not o.moving and not (skip and skip[o]) then
                        local reach = o.radius + r
                        if (o.x - x) ^ 2 + (o.y - y) ^ 2 < reach * reach then ok = false end
                    end
                end)
            end
            if ok then best, best_score = { x, y }, score end
        end
    end
    return best
end
-- }}}

-- {{{ function crowd:pack(cx, cy, radii)
-- Places for units of these radii packed round (cx, cy), in order: the
-- first nearest the middle. For placing armies at the start.
function crowd:pack(cx, cy, radii)
    local taken, out = {}, {}
    self:rehash()
    for i, r in ipairs(radii) do
        local p = self:free_spot(cx, cy, { radius = r, x = cx, y = cy }, taken)
        if not p then error("no room to place unit " .. i .. " round " .. cx .. ", " .. cy, 0) end
        taken[#taken + 1] = { x = p[1], y = p[2], radius = r }
        out[i] = p
    end
    return out
end
-- }}}

-- {{{ function crowd:move_group(ids, x, y)
-- Orders the units named in `ids` to the point (x, y) together: every one
-- heads for the point; each settles where it meets the ones already
-- arrived. A unit ordered alone is a group of one. Every member is marked
-- moving before any plans, so none plans round another's starting place.
function crowd:move_group(ids, x, y)
    local group = { x = x, y = y, members = {} }
    local area = 0
    for _, id in ipairs(ids) do
        local u = self.units[id]
        if not u then error("no unit " .. id .. " in the crowd", 0) end
        group.members[#group.members + 1] = u
        area = area + (u.radius + crowd.GAP) ^ 2
        u.moving, u.gave_up, u.arrived, u.group = true, false, false, group
        u.closest, u.no_progress, u.orbit, u.wait_until, u.bundle, u.bundle_until = math.huge, 0, 0, 0, nil, 0
        u.slide_since_progress, u.mutual, u.blocked_by, u.settle = 0, 0, nil, 0
        u.backing, u.back_offs = false, 0
    end
    -- the radius the members fill packed together round the point: a
    -- member outside it keeps sliding round the group for a way in
    group.packed = sqrt(area / crowd.PACKING)
    self:rehash()
    for _, u in ipairs(group.members) do self:head_for(u, x, y) end
end
-- }}}

-- {{{ function crowd:move(id, x, y)
function crowd:move(id, x, y)
    self:move_group({ id }, x, y)
end
-- }}}

-- {{{ Moving
-- {{{ function crowd:stand(u, gave_up)
function crowd:stand(u, gave_up)
    u.moving, u.path, u.step = false, nil, 0
    u.vx, u.vy = 0, 0
    u.gave_up = gave_up
    u.arrived = not gave_up
    u.orbit, u.blocked_by, u.mutual, u.settle = 0, nil, 0, 0
    u.path_changed = true
end
-- }}}

-- {{{ function crowd:try_step(u, dx, dy)
-- Takes the step if it ends clear of walls and units. Returns true if
-- taken; otherwise the unit in the way, or false for a wall.
function crowd:try_step(u, dx, dy)
    local nx, ny = u.x + dx, u.y + dy
    if not self:clear_of_walls(nx, ny, u.radius) then return false end
    local o = self:overlapping(u, nx, ny)
    if o then return o end
    u.x, u.y = nx, ny
    u.step_x, u.step_y = dx, dy
    self:rebucket(u)
    return true
end
-- }}}

-- {{{ function crowd:nudge(o, u, dx, dy)
-- An idle unit of u's side in u's way steps aside: sideways from u's line
-- of travel (dx, dy), just far enough to clear it, on the side it is
-- already on (the far side if that's a wall).
function crowd:nudge(o, u, dx, dy)
    if o.moving or o.team ~= u.team or self.tick_count - o.nudged_at < crowd.NUDGE_EVERY then return end
    local d = length(dx, dy)
    if d == 0 then return end
    local ux, uy = dx / d, dy / d
    local ox, oy = o.x - u.x, o.y - u.y
    local across = ux * oy - uy * ox            -- how far o is to one side of u's line
    local side = across >= 0 and 1 or -1
    for _, s in ipairs({ side, -side }) do
        local shift = u.radius + o.radius + crowd.GAP - s * across
        local tx, ty = o.x - uy * s * shift, o.y + ux * s * shift
        if self:clear_of_walls(tx, ty, o.radius) then
            o.nudged_at = self.tick_count
            o.closest, o.no_progress = math.huge, 0
            o.goal_x, o.goal_y = tx, ty
            o.path, o.step, o.exact, o.moving, o.path_changed = { { x = tx, y = ty } }, 1, true, true, true
            return
        end
    end
end
-- }}}

-- {{{ function crowd:step_aside(u, o)
-- u gives way to o by stepping sideways out of o's line of travel, as far
-- as a nudge would move it; then it carries on toward its own goal.
-- Returns false if neither side has room.
function crowd:step_aside(u, o)
    local dx, dy = o.goal_x - o.x, o.goal_y - o.y
    local d = length(dx, dy)
    if d == 0 then return false end
    local ox, oy = dx / d, dy / d
    local across = ox * (u.y - o.y) - oy * (u.x - o.x)
    local side = across >= 0 and 1 or -1
    for _, sgn in ipairs({ side, -side }) do
        local shift = u.radius + o.radius + crowd.GAP - sgn * across
        local tx, ty = u.x - oy * sgn * shift, u.y + ox * sgn * shift
        if self:clear_of_walls(tx, ty, u.radius) and not self:overlapping(u, tx, ty) then
            -- the aside step first, then its own way on from there
            local path = { { x = tx, y = ty } }
            for i = u.step, #(u.path or {}) do path[#path + 1] = u.path[i] end
            if #path == 1 then path[2] = { x = u.goal_x, y = u.goal_y } end
            u.path, u.step, u.path_changed = path, 1, true
            return true
        end
    end
    return false
end
-- }}}

-- {{{ function crowd:bundle_of(o)
-- The standing units touching o, and those touching them: what a mover
-- goes round as one. (The first version counted blocked movers too; in a
-- dense moving crowd everything was one bundle, no way round it existed,
-- and the units that tried stopped.)
function crowd:bundle_of(o)
    local bundle, seen, queue = {}, { [o] = true }, { o }
    while #queue > 0 do
        local a = table.remove(queue)
        bundle[#bundle + 1] = { x = a.x, y = a.y, radius = a.radius }
        self:near(a.x, a.y, function(b)
            if not seen[b] and not b.moving then
                local reach = a.radius + b.radius + crowd.BUNDLE_GAP
                if (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 < reach * reach then
                    seen[b] = true
                    queue[#queue + 1] = b
                end
            end
        end)
    end
    return bundle
end
-- }}}

-- {{{ function crowd:slide(u, o, wx, wy, reach)
-- u's wanted step (wx, wy) would overlap o: step along o's edge instead,
-- the way round u is already going; at first contact, the way round
-- nearer its heading, or head-on, to its right. Tries the full slide, then
-- half. Returns true if u moved.
function crowd:slide(u, o, wx, wy, reach)
    local nx, ny = u.x - o.x, u.y - o.y
    local nd = length(nx, ny)
    if nd == 0 then return false end
    nx, ny = nx / nd, ny / nd
    -- the ways round: anticlockwise (+1) along (-ny, nx); clockwise (-1)
    if u.orbit == 0 then
        local along = -ny * wx + nx * wy
        if abs(along) < 0.2 * reach then
            -- head-on: its right is (wy, -wx); take the way round nearer it
            u.orbit = (-ny * wy + nx * -wx) >= 0 and 1 or -1
        else
            u.orbit = along > 0 and 1 or -1
        end
    end
    -- the part of the wanted step that doesn't point into o, plus a little
    -- round it the chosen way and a little away from it. The first version
    -- slid purely round the edge at full speed, and in a crowd units
    -- orbited each other far from their goals; keeping the goal-ward part
    -- makes a slide still head where the unit is going
    local into = wx * nx + wy * ny
    local px, py = wx, wy
    if into < 0 then px, py = wx - into * nx, wy - into * ny end
    local sx = px + (-ny * u.orbit * crowd.SLIDE_AROUND + crowd.SLIDE_OUTWARD * nx) * reach
    local sy = py + (nx * u.orbit * crowd.SLIDE_AROUND + crowd.SLIDE_OUTWARD * ny) * reach
    local sd = length(sx, sy)
    if sd == 0 then return false end
    sx, sy = sx / sd * reach, sy / sd * reach
    if self:try_step(u, sx, sy) == true then return true end
    return self:try_step(u, sx * 0.5, sy * 0.5) == true
end
-- }}}

-- {{{ function crowd:nearest_wall_point(x, y, r)
-- The nearest point of any wall cell within reach of a circle at (x, y)
-- of radius r (plus a step), or nil.
function crowd:nearest_wall_point(x, y, r)
    local reach = r + self.cell
    local x1, y1 = self:cell_of(x - reach, y - reach)
    local x2, y2 = self:cell_of(x + reach, y + reach)
    local c, best, bx, by = self.cell, math.huge, nil, nil
    for cy = y1, y2 do
        for cx = x1, x2 do
            if not self:walkable(cx, cy) then
                local qx = max((cx - 1) * c, min(x, cx * c))
                local qy = max((cy - 1) * c, min(y, cy * c))
                local d = length(x - qx, y - qy)
                if d < best then best, bx, by = d, qx, qy end
            end
        end
    end
    return bx, by
end
-- }}}

-- {{{ function crowd:slide_on_wall(u, wx, wy, reach)
-- u's wanted step (wx, wy) would touch a wall: keep the part of it along
-- the nearest wall's edge, leaning a little away from the wall. Returns
-- true if u moved.
function crowd:slide_on_wall(u, wx, wy, reach)
    local qx, qy = self:nearest_wall_point(u.x + wx, u.y + wy, u.radius)
    if not qx then return false end
    local nx, ny = u.x - qx, u.y - qy
    local nd = length(nx, ny)
    if nd == 0 then return false end
    nx, ny = nx / nd, ny / nd
    local into = wx * nx + wy * ny
    local px, py = wx, wy
    if into < 0 then px, py = wx - into * nx, wy - into * ny end
    px, py = px + crowd.SLIDE_OUTWARD * nx * reach, py + crowd.SLIDE_OUTWARD * ny * reach
    local pd = length(px, py)
    if pd < 1e-9 then return false end
    px, py = px / pd * reach, py / pd * reach
    if self:try_step(u, px, py) == true then return true end
    return self:try_step(u, px * 0.5, py * 0.5) == true
end
-- }}}

-- {{{ function crowd:steer(u, wx, wy, reach, ahead)
-- The step (wx, wy) turned to pass outside the pathing radius of the
-- nearest unit whose pathing circle lies across the next `ahead` world
-- units of u's way: aimed at the edge of the two pathing radii together,
-- on the side u is already going round (or the side its heading leans
-- to; head-on, its right). Units heading the same way, arrived
-- groupmates (so a group can pack) and idle allies (they are nudged)
-- aren't steered round.
function crowd:steer(u, wx, wy, reach, ahead)
    local d = length(wx, wy)
    if d == 0 or ahead <= 0 then return wx, wy end
    local ux, uy = wx / d, wy / d
    local best, best_along
    self:near(u.x, u.y, function(o)
        if o == u then return end
        if o.arrived and o.group == u.group then return end
        -- an idle ally isn't steered round: it will be nudged aside (in a
        -- corridor narrower than two pathing radii, steering round it
        -- never reached it, so it was never nudged)
        if not o.moving and o.team == u.team then return end
        -- heading the same way: judged by where o is going, not its speed
        -- (at the start of an order everyone's speed is zero, and an army
        -- steered round its own members and spread out)
        if o.moving then
            local gx, gy = o.goal_x - o.x, o.goal_y - o.y
            local gd = length(gx, gy)
            if gd > 0 and (gx * ux + gy * uy) / gd > 0.5 then return end
        end
        local cx, cy = o.x - u.x, o.y - u.y
        local along = cx * ux + cy * uy
        if along <= 0 or along > ahead + o.path_radius then return end
        local across = abs(cx * uy - cy * ux)
        if across < u.path_radius + o.path_radius and (not best or along < best_along) then best, best_along = o, along end
    end)
    if not best then u.steer_from = nil; return wx, wy end
    local cx, cy = best.x - u.x, best.y - u.y
    local D = length(cx, cy)
    local R = u.path_radius + best.path_radius
    -- which side: kept for as long as anyone is in the way, even as the
    -- nearest one changes (the first version chose afresh each tick and
    -- dithered left and right in front of a unit, or between the members
    -- of a bundle); chosen by the side the heading leans to, or head-on,
    -- to the right
    local side = u.steer_from and u.steer_side or nil
    if not side then
        local cross = cx * uy - cy * ux
        if abs(cross) < 0.05 * D then side = 1 else side = cross > 0 and 1 or -1 end
        u.steer_from, u.steer_side = best, side
    end
    local angle = math.atan2(cy, cx)
    local off = D > R and math.asin(R / D) or math.pi / 2
    local a = angle - side * off
    return math.cos(a) * reach, math.sin(a) * reach
end
-- }}}

-- {{{ function crowd:back_off(u)
-- A gridlocked unit backs away from the units touching it (or from its
-- goal if none), as far as it can up to BACK_OFF plus its radius, then
-- plans for its goal afresh.
function crowd:back_off(u)
    local ax, ay, n = 0, 0, 0
    self:near(u.x, u.y, function(o)
        if o ~= u and length(o.x - u.x, o.y - u.y) < u.radius + o.radius + crowd.BUNDLE_GAP then
            ax, ay, n = ax + o.x, ay + o.y, n + 1
        end
    end)
    local bx, by
    if n > 0 then bx, by = u.x - ax / n, u.y - ay / n else bx, by = u.x - u.goal_x, u.y - u.goal_y end
    local bd = length(bx, by)
    if bd == 0 then return end
    bx, by = bx / bd, by / bd
    local far = crowd.BACK_OFF + u.radius
    local tx, ty
    for k = 8, 1, -1 do
        local x, y = u.x + bx * far * k / 8, u.y + by * far * k / 8
        if self:clear_of_walls(x, y, u.radius) then tx, ty = x, y; break end
    end
    if not tx then return end
    u.back_offs = u.back_offs + 1
    self.back_offs_total = (self.back_offs_total or 0) + 1
    u.backing = true
    u.orbit, u.bundle, u.bundle_until = 0, nil, 0
    u.path, u.step, u.path_changed = { { x = tx, y = ty } }, 1, true
    -- its patience starts again from where it backs off to
    u.closest, u.no_progress = math.huge, 0
end
-- }}}

-- {{{ function crowd:advance(u, dt)
-- One moving unit's tick. The branches are the ones at the top of the file.
function crowd:advance(u, dt)
    local t = self.tick_count
    u.vx, u.vy = 0, 0
    -- giving way: standing still a moment
    if u.wait_until > t then return end

    -- no closer to the goal for too long: give up
    local to_goal = length(u.goal_x - u.x, u.goal_y - u.y)
    if to_goal < u.closest - crowd.PROGRESS then
        u.closest, u.no_progress, u.slide_since_progress = to_goal, 0, 0
    else
        u.no_progress = u.no_progress + 1
    end
    if u.no_progress >= crowd.NO_PROGRESS_TICKS then self:stand(u, true); return end
    -- gridlocked: back off, and make the stuck ones round it back off too,
    -- to shake the whole knot loose (the owner, 2026-09-25)
    if not u.backing and u.back_offs < crowd.BACK_OFFS and u.no_progress >= crowd.GRIDLOCK_TICKS * (u.back_offs + 1) then
        self:back_off(u)
        self:near(u.x, u.y, function(o)
            if o ~= u and o.moving and not o.backing and o.back_offs < crowd.BACK_OFFS
               and o.no_progress >= crowd.GRIDLOCK_TICKS / 2
               and length(o.x - u.x, o.y - u.y) < u.radius + o.radius + 1.0 then
                self:back_off(o)
            end
        end)
    end

    -- no path (it couldn't leave its place): try again
    if not u.path then
        self:replan(u, u.bundle_until > t and u.bundle or nil)
        if not u.path then return end
    end

    local target = u.path[u.step]
    local dx, dy = target.x - u.x, target.y - u.y
    local dist = length(dx, dy)
    local reach = u.speed * dt
    local wx, wy
    if dist <= reach then wx, wy = dx, dy else wx, wy = dx / dist * reach, dy / dist * reach end
    -- steer round others' pathing radius before touching their collision one
    if not u.backing and self.look_ahead > 0 then wx, wy = self:steer(u, wx, wy, reach, math.min(dist, self.look_ahead)) end

    local moved = self:try_step(u, wx, wy)
    if moved == true then
        u.orbit, u.blocked_by, u.mutual = 0, nil, 0
    elseif moved == false then
        -- a wall: slide along its edge; stuck even so -> the path clips a
        -- wall it didn't expect (sliding took it off its line): plan again.
        -- (The first version slid along each axis alone, which fails at a
        -- pillar's corner met diagonally.)
        if not self:slide_on_wall(u, wx, wy, reach) then
            self:replan(u)
            return
        end
    else
        local o = moved
        u.blocked_by = o
        -- Arriving, before anything else. Two paths:
        --   o is a groupmate that has arrived -> slide on toward the point
        --     while that gets closer; once it hasn't for a moment (or can't
        --     slide), settle here: arrived
        --   o stands right beside u's goal     -> as close as it gets: stand
        if not o.moving and o.arrived and o.group == u.group then
            -- within the group's packed size it settles soon; outside, it
            -- slides round the group a good while first (the first version
            -- settled at the first arrived groupmate it met, and a group
            -- arriving from one side stopped in a comet's tail behind itself)
            u.settle = u.settle + 1
            local inside = to_goal <= u.group.packed + u.radius
            local patience = inside and crowd.SETTLE_TICKS or crowd.SETTLE_FAR_TICKS
            if u.settle >= patience then self:stand(u, false); return end
            if not self:slide(u, o, wx, wy, reach) then
                -- Two paths: inside the packed size -> settle here; outside
                -- -> try the other way round next tick
                if inside then self:stand(u, false) else u.orbit = -u.orbit end
                return
            end
            -- only real progress (as the give-up rule counts it) starts the
            -- patience again: counting small gains, one unit circled a
            -- group bigger than its estimate for 20 s and gave up
            if u.no_progress == 0 then u.settle = 0 end
            u.vx, u.vy = u.step_x / dt, u.step_y / dt
            u.facing = math.atan2(u.vy, u.vx)
            return
        end
        if not o.moving and to_goal < u.radius + 2 * o.radius + crowd.GAP then
            self:stand(u, false)
            return
        end
        -- an idle unit of its own side: nudge it aside
        if not o.moving then self:nudge(o, u, wx, wy) end
        -- two moving units in each other's way: the higher id gives way
        if o.moving and o.blocked_by == u then
            u.mutual = u.mutual + 1
            if u.mutual >= crowd.GIVE_WAY_TICKS and u.id > o.id then
                -- Two paths: room beside o's line -> step aside into it (then
                -- carry on); none -> stand still a moment. Standing still in
                -- a narrow channel blocked it for everyone behind.
                u.mutual = 0
                if not self:step_aside(u, o) then u.wait_until = t + crowd.GIVE_WAY_FOR end
                return
            end
        end
        local slid = self:slide(u, o, wx, wy, reach)
        u.slide_since_progress = u.slide_since_progress + 1
        -- sliding without getting anywhere: go round the whole bundle
        if u.slide_since_progress >= crowd.BUNDLE_TICKS and u.bundle_until <= t then
            u.bundle = self:bundle_of(o)
            u.bundle_until = t + crowd.BUNDLE_KEEP
            u.slide_since_progress = 0
            u.orbit = 0
            u.planned_at = nil
            self:replan(u, u.bundle)
        end
        if not slid then return end
    end

    u.vx, u.vy = u.step_x / dt, u.step_y / dt
    u.facing = math.atan2(u.vy, u.vx)
    -- at the waypoint: on to the next, or arrived
    if abs(u.x - target.x) < crowd.ARRIVE and abs(u.y - target.y) < crowd.ARRIVE then
        u.step = u.step + 1
        if u.step > #u.path then
            -- Two paths: backed off -> head for the goal again; otherwise
            -- -> arrived
            if u.backing then
                u.backing = false
                u.planned_at = nil
                self:head_for(u, u.goal_x, u.goal_y)
                return
            end
            self:stand(u, false)
        end
    end
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
-- }}}

-- {{{ Checks
-- {{{ function crowd:any_overlap()
-- The first pair of units overlapping, or nil.
function crowd:any_overlap()
    for i, a_id in ipairs(self.order) do
        local a = self.units[a_id]
        for j = i + 1, #self.order do
            local b = self.units[self.order[j]]
            local reach = a.radius + b.radius
            if (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 < reach * reach - 1e-6 then return a, b end
        end
    end
end
-- }}}

-- {{{ function crowd:any_in_wall()
-- The first unit touching a wall, or nil.
function crowd:any_in_wall()
    for _, id in ipairs(self.order) do
        local u = self.units[id]
        if not self:clear_of_walls(u.x, u.y, u.radius - 1e-6) then return u end
    end
end
-- }}}
-- }}}

return crowd
