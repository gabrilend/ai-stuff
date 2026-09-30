--[[
Map Pathing (Issue 519a)

Routes for ground units over a loaded map, on the project's pathing grid
(runtime/pathfinding/grid.lua: one cell per tilepoint, 128 units apart,
blocked by cliff edges without ramps, deep water and the boundary) with its
A* and path smoothing.

As in WC3, an order to somewhere a unit can't reach sends it as close as it
can get: every walkable cell is labelled with its connected region once, so
an unreachable target is swapped for the nearest cell of the unit's own
region instead of a search that fails. Flying units go straight.

    local pathing = require("demo.wc3map.pathing").new(terrain)
    local route = pathing:route(x0, y0, x1, y1)   -- { {x=, y=}, ... } or nil

Buildings block (issue 541): each building's footprint cells that keep
walkers out (footprint.lua, 32 units a cell) are kept in a fine layer.
A route cell (128 units) half or more covered by them is closed, and the
regions are labelled again, so routes go round buildings and a walled-in
base is reached only through its gaps. Units don't step into a closed
fine cell (they slide along the wall, else stop), and a building put
down where units stand pushes them out to the nearest open cell.

    pathing:set_blockers(game)       -- after buildings come or go
    pathing:blocked(x, y)            -- a building's cell keeps walkers out here
    pathing:ground_walkable(i, j)    -- the terrain's own answer
    pathing:free_spot(x, y)          -- the nearest open point
]]

local grid_mod = require("runtime.pathfinding.grid")
local astar = require("runtime.pathfinding.astar")

local Pathing = {}
Pathing.__index = Pathing

local pathing = {}

pathing.MAX_ITERATIONS = 200000   -- A* limit per route
pathing.SEARCH_RADIUS = 48        -- cells searched for a reachable stand-in

-- {{{ pathing.new
function pathing.new(terrain)
    local self = setmetatable({}, Pathing)
    self.grid = grid_mod.build_from_terrain(terrain)
    self.w, self.h = terrain.width, terrain.height
    self.x0, self.y0 = terrain.offset_x, terrain.offset_y
    self:label_regions()
    return self
end
-- }}}

-- {{{ Pathing:walkable
function Pathing:walkable(i, j)
    local row = self.grid.cells[j]
    local c = row and row[i]
    return c ~= nil and c.walkable
end

-- the terrain's own walkability, whatever buildings stand there
function Pathing:ground_walkable(i, j)
    local row = self.grid.cells[j]
    local c = row and row[i]
    if c == nil then return false end
    if c.ground_walkable ~= nil then return c.ground_walkable end
    return c.walkable
end
-- }}}

-- {{{ Buildings (issue 541)
pathing.FINE = 32
pathing.CLOSE_AT = 8        -- fine cells of 16 that close a route cell

-- the fine cell of a point: cells line up with the route cells (four to
-- a side) and with footprints (both on the 32-unit grid)
function Pathing:fine(x, y)
    return math.floor((x - self.x0 + 64) / pathing.FINE), math.floor((y - self.y0 + 64) / pathing.FINE)
end

function Pathing:blocked(x, y)
    if not self.fine_blocked then return false end
    local fi, fj = self:fine(x, y)
    return self.fine_blocked[fj * self.fw + fi] == true
end

function Pathing:set_blockers(g)
    local fp = require("demo.wc3map.footprint")
    local cells = self.grid.cells
    -- the terrain's walkability, kept the first time
    if not self.ground_saved then
        for j = 0, self.h - 1 do
            local row = cells[j]
            for i = 0, self.w - 1 do
                local c = row and row[i]
                if c then c.ground_walkable = c.walkable end
            end
        end
        self.ground_saved = true
    end
    self.fw = self.w * 4
    local fine, count = {}, {}
    for _, b in ipairs(g.units) do
        if b.spec.design == "building" and b.alive ~= false and not b.removed and not b.hidden then
            -- its fine cells, kept on it until it moves or changes type
            local at = b.id .. "@" .. b.x .. "," .. b.y
            if b.fine_at ~= at then
                local sh = fp.shape(g, b.id)
                b.body = math.max(sh.w, sh.h) * pathing.FINE / 2
                local keys = {}
                fp.each(sh, b.x, b.y, function(_, _, flags, cx, cy)
                    if flags % 4 >= fp.NO_WALK then
                        local fi, fj = self:fine(cx, cy)
                        keys[#keys + 1] = fj * self.fw + fi
                    end
                end)
                b.fine_keys, b.fine_at = keys, at
            end
            for _, k in ipairs(b.fine_keys) do
                if not fine[k] then
                    fine[k] = true
                    local fi, fj = k % self.fw, math.floor(k / self.fw)
                    local ck = math.floor(fj / 4) * self.w + math.floor(fi / 4)
                    count[ck] = (count[ck] or 0) + 1
                end
            end
        end
    end
    self.fine_blocked = fine
    -- the route cells closed now; regions labelled again only if that changed
    local closed = {}
    for ck, n in pairs(count) do
        if n >= pathing.CLOSE_AT then
            local i, j = ck % self.w, math.floor(ck / self.w)
            local c = cells[j] and cells[j][i]
            if c and c.ground_walkable then closed[ck] = true end
        end
    end
    local changed = false
    for ck in pairs(self.closed or {}) do
        if not closed[ck] then
            changed = true
            local i, j = ck % self.w, math.floor(ck / self.w)
            cells[j][i].walkable = cells[j][i].ground_walkable
        end
    end
    for ck in pairs(closed) do
        local i, j = ck % self.w, math.floor(ck / self.w)
        if cells[j][i].walkable then changed = true; cells[j][i].walkable = false end
    end
    self.closed = closed
    if changed then self:label_regions() end
    -- units standing in a building step out to open ground
    for _, u in ipairs(g.units) do
        if u.alive ~= false and not u.removed and not u.hidden and u.spec.design == "unit"
            and u.spec.archetype ~= "flyer" and self:blocked(u.x, u.y) then
            local x, y = self:free_spot(u.x, u.y)
            if x then
                u.x, u.y = x, y
                if u.mover then u.mover.x, u.mover.y = x, y end
                u.route = nil
            end
        end
    end
end

-- whether a fine cell (fi, fj) can be walked: open ground, no building
function Pathing:fine_open(fi, fj)
    if self.fine_blocked and self.fine_blocked[fj * self.fw + fi] then return false end
    local ci, cj = math.floor(fi / 4), math.floor(fj / 4)
    return self:ground_walkable(ci, cj)
end

-- a straight walk from a to b crosses no building's cell (checked every
-- half fine cell)
function Pathing:fine_clear(x0, y0, x1, y1)
    if not self.fine_blocked then return true end
    local d = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
    local n = math.max(1, math.ceil(d / (pathing.FINE / 2)))
    for k = 0, n do
        local f = k / n
        if self:blocked(x0 + (x1 - x0) * f, y0 + (y1 - y0) * f) then return false end
    end
    return true
end

-- a way round buildings from (x0, y0) to (x1, y1) on the fine cells, in a
-- window about the two (A*, 8 ways, no cutting corners), smoothed; the
-- points after the start, or nil when there's none in the window
pathing.DETOUR_MARGIN = 12        -- fine cells round the leg
pathing.DETOUR_MAX = 128          -- the window's largest side, in fine cells
function Pathing:fine_detour(x0, y0, x1, y1)
    local F = pathing.FINE
    local si, sj = self:fine(x0, y0)
    local ti, tj = self:fine(x1, y1)
    local m = pathing.DETOUR_MARGIN
    local i0, i1 = math.min(si, ti) - m, math.max(si, ti) + m
    local j0, j1 = math.min(sj, tj) - m, math.max(sj, tj) + m
    if i1 - i0 > pathing.DETOUR_MAX or j1 - j0 > pathing.DETOUR_MAX then return nil end
    local W = i1 - i0 + 1
    local function key(i, j) return (j - j0) * W + (i - i0) end
    local function open(i, j)
        if i < i0 or i > i1 or j < j0 or j > j1 then return false end
        if (i == si and j == sj) or (i == ti and j == tj) then return true end
        return self:fine_open(i, j)
    end
    -- a binary heap of keys by f
    local heap, f, g, from, closed = {}, {}, {}, {}, {}
    local function push(k)
        heap[#heap + 1] = k
        local c = #heap
        while c > 1 do
            local p = math.floor(c / 2)
            if f[heap[p]] <= f[heap[c]] then break end
            heap[p], heap[c] = heap[c], heap[p]
            c = p
        end
    end
    local function pop()
        local top = heap[1]
        local last = table.remove(heap)
        if #heap > 0 then
            heap[1] = last
            local c = 1
            while true do
                local l, r, s = c * 2, c * 2 + 1, c
                if heap[l] and f[heap[l]] < f[heap[s]] then s = l end
                if heap[r] and f[heap[r]] < f[heap[s]] then s = r end
                if s == c then break end
                heap[s], heap[c] = heap[c], heap[s]
                c = s
            end
        end
        return top
    end
    local function h(i, j) local di, dj = math.abs(i - ti), math.abs(j - tj) return math.max(di, dj) + 0.414 * math.min(di, dj) end
    local sk, tk = key(si, sj), key(ti, tj)
    g[sk], f[sk] = 0, h(si, sj)
    push(sk)
    local found = false
    while #heap > 0 do
        local k = pop()
        if k == tk then found = true break end
        if not closed[k] then
            closed[k] = true
            local ci, cj = k % W + i0, math.floor(k / W) + j0
            for dj = -1, 1 do
                for di = -1, 1 do
                    if (di ~= 0 or dj ~= 0) and open(ci + di, cj + dj)
                        and (di == 0 or dj == 0 or (open(ci + di, cj) and open(ci, cj + dj))) then
                        local nk = key(ci + di, cj + dj)
                        local ng = g[k] + ((di ~= 0 and dj ~= 0) and 1.414 or 1)
                        if not closed[nk] and (g[nk] == nil or ng < g[nk]) then
                            g[nk], f[nk], from[nk] = ng, ng + h(ci + di, cj + dj), k
                            push(nk)
                        end
                    end
                end
            end
        end
    end
    if not found then return nil end
    -- back from the target, as world points (cell middles; the ends exact)
    local cells = {}
    local k = tk
    while k do
        cells[#cells + 1] = k
        k = from[k]
    end
    local pts = {}
    for n = #cells, 1, -1 do
        local c = cells[n]
        local ci, cj = c % W + i0, math.floor(c / W) + j0
        pts[#pts + 1] = { x = self.x0 - 64 + (ci + 0.5) * F, y = self.y0 - 64 + (cj + 0.5) * F }
    end
    pts[1] = { x = x0, y = y0 }
    pts[#pts] = { x = x1, y = y1 }
    -- smoothed: straight on while nothing's in the way
    local out, a = {}, 1
    while a < #pts do
        local b = a + 1
        for c = #pts, a + 2, -1 do
            if self:fine_clear(pts[a].x, pts[a].y, pts[c].x, pts[c].y) then b = c break end
        end
        out[#out + 1] = pts[b]
        a = b
    end
    return out
end

-- a route's legs led round buildings where they cross one
function Pathing:refine(x0, y0, route)
    if not self.fine_blocked or not next(self.fine_blocked) then return route end
    local out = {}
    local px, py = x0, y0
    for _, p in ipairs(route) do
        if self:fine_clear(px, py, p.x, p.y) then
            out[#out + 1] = p
        else
            local way = self:fine_detour(px, py, p.x, p.y)
            if way then
                for _, q in ipairs(way) do out[#out + 1] = q end
            else
                out[#out + 1] = p
            end
        end
        px, py = p.x, p.y
    end
    return out
end

-- the nearest point not in a building's cell (ring by ring, up to 1024)
function Pathing:free_spot(x, y)
    if not self:blocked(x, y) then return x, y end
    local F = pathing.FINE
    local fi, fj = self:fine(x, y)
    for r = 1, 32 do
        local best, bx, by
        for dj = -r, r do
            for di = -r, r do
                if math.abs(di) == r or math.abs(dj) == r then
                    local cx = self.x0 - 64 + (fi + di + 0.5) * F
                    local cy = self.y0 - 64 + (fj + dj + 0.5) * F
                    if not self:blocked(cx, cy) then
                        local ci, cj = self:cell(cx, cy)
                        if self:ground_walkable(ci, cj) then
                            local d = (cx - x) ^ 2 + (cy - y) ^ 2
                            if not best or d < best then best, bx, by = d, cx, cy end
                        end
                    end
                end
            end
        end
        if bx then return bx, by end
    end
    return nil
end
-- }}}

-- {{{ Pathing:label_regions
-- Flood-fill every walkable cell with the number of its connected region
-- (8-way, as A* moves)
function Pathing:label_regions()
    local region = {}
    local w, h = self.w, self.h
    local n = 0
    for j = 0, h - 1 do
        for i = 0, w - 1 do
            local k = j * w + i
            if not region[k] and self:walkable(i, j) then
                n = n + 1
                local stack = { k }
                region[k] = n
                while #stack > 0 do
                    local cur = table.remove(stack)
                    local ci, cj = cur % w, math.floor(cur / w)
                    for dj = -1, 1 do
                        for di = -1, 1 do
                            local ni, nj = ci + di, cj + dj
                            if ni >= 0 and nj >= 0 and ni < w and nj < h then
                                local nk = nj * w + ni
                                if not region[nk] and self:walkable(ni, nj) then
                                    region[nk] = n
                                    stack[#stack + 1] = nk
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    self.region, self.regions = region, n
end
-- }}}

-- {{{ Coordinates
function Pathing:cell(x, y)
    local i = math.floor((x - self.x0) / 128 + 0.5)
    local j = math.floor((y - self.y0) / 128 + 0.5)
    return math.max(0, math.min(self.w - 1, i)), math.max(0, math.min(self.h - 1, j))
end

function Pathing:world(i, j)
    return self.x0 + i * 128, self.y0 + j * 128
end

function Pathing:region_at(i, j)
    return self.region[j * self.w + i]
end
-- }}}

-- {{{ Pathing:nearest
-- The walkable cell nearest (i, j), in region `want` when given, searching
-- outward ring by ring up to `radius` cells
function Pathing:nearest(i, j, want, radius)
    local function ok(ci, cj)
        local r = self.region[cj * self.w + ci]
        return r and (not want or r == want)
    end
    if i >= 0 and j >= 0 and i < self.w and j < self.h and ok(i, j) then return i, j end
    local best, bi, bj = math.huge, nil, nil
    for r = 1, radius or pathing.SEARCH_RADIUS do
        for dj = -r, r do
            for di = -r, r do
                if math.abs(di) == r or math.abs(dj) == r then
                    local ci, cj = i + di, j + dj
                    if ci >= 0 and cj >= 0 and ci < self.w and cj < self.h and ok(ci, cj) then
                        local d = di * di + dj * dj
                        if d < best then best, bi, bj = d, ci, cj end
                    end
                end
            end
        end
        if bi then return bi, bj end
    end
    -- nothing close: the region's cell nearest the point, by a full scan
    -- (rare: a target far out to sea or across the map)
    if want then
        local w = self.w
        for k, r in pairs(self.region) do
            if r == want then
                local ci, cj = k % w, math.floor(k / w)
                local d = (ci - i) ^ 2 + (cj - j) ^ 2
                if d < best then best, bi, bj = d, ci, cj end
            end
        end
    end
    return bi, bj
end
-- }}}

-- {{{ Pathing:clear_line
-- True when a straight walk between the centres of cells (i0, j0) and
-- (i1, j1) touches only walkable cells: every cell the segment passes
-- through, and both cells beside a corner it crosses exactly (a
-- conservative grid traversal; Bresenham would let it slip past corners)
function Pathing:clear_line(i0, j0, i1, j1)
    -- cells are unit squares centred on whole numbers: shift by a half so
    -- each cell is [n, n+1)
    local x0, y0, x1, y1 = i0 + 0.5, j0 + 0.5, i1 + 0.5, j1 + 0.5
    local dx, dy = x1 - x0, y1 - y0
    local ci, cj = math.floor(x0), math.floor(y0)
    local ei, ej = math.floor(x1), math.floor(y1)
    local si, sj = dx > 0 and 1 or -1, dy > 0 and 1 or -1
    local tdx = dx ~= 0 and math.abs(1 / dx) or math.huge
    local tdy = dy ~= 0 and math.abs(1 / dy) or math.huge
    local tx = dx ~= 0 and ((si > 0 and (ci + 1 - x0) or (x0 - ci)) * tdx) or math.huge
    local ty = dy ~= 0 and ((sj > 0 and (cj + 1 - y0) or (y0 - cj)) * tdy) or math.huge
    if not self:walkable(ci, cj) then return false end
    local guard = 0
    while (ci ~= ei or cj ~= ej) and guard < 4096 do
        guard = guard + 1
        if math.abs(tx - ty) < 1e-9 then
            -- through a corner: both side cells must be open too
            if not self:walkable(ci + si, cj) or not self:walkable(ci, cj + sj) then return false end
            ci, cj = ci + si, cj + sj
            tx, ty = tx + tdx, ty + tdy
        elseif tx < ty then
            ci, tx = ci + si, tx + tdx
        else
            cj, ty = cj + sj, ty + tdy
        end
        if not self:walkable(ci, cj) then return false end
    end
    return true
end
-- }}}

-- {{{ Pathing:smooth
-- Drop waypoints a unit can walk straight past (clear_line)
function Pathing:smooth(cells)
    if #cells <= 2 then return cells end
    local out = { cells[1] }
    local i = 1
    while i < #cells do
        local far = i + 1
        for k = #cells, i + 2, -1 do
            if self:clear_line(cells[i].x, cells[i].y, cells[k].x, cells[k].y) then
                far = k
                break
            end
        end
        out[#out + 1] = cells[far]
        i = far
    end
    return out
end
-- }}}

-- {{{ Pathing:route
-- Waypoints (WC3 units) from (x0, y0) to (x1, y1) for a ground unit, not
-- including the start; the last is the target itself when it can be
-- reached, else the nearest reachable point. nil when the unit is walled
-- in where it stands.
function Pathing:route(x0, y0, x1, y1)
    local si, sj = self:cell(x0, y0)
    si, sj = self:nearest(si, sj, nil, 6)
    if not si then return nil end
    local home = self:region_at(si, sj)

    -- a point inside a building: the open point at its edge facing the
    -- walker instead (back along the line), else the nearest open point
    if self:blocked(x1, y1) then
        local dx, dy = x0 - x1, y0 - y1
        local d = math.sqrt(dx * dx + dy * dy)
        local ex, ey
        for t = 16, d, 16 do
            local px, py = x1 + dx / d * t, y1 + dy / d * t
            if not self:blocked(px, py) then ex, ey = px, py break end
        end
        if not ex then ex, ey = self:free_spot(x1, y1) end
        if ex then x1, y1 = ex, ey end
    end
    local ti, tj = self:cell(x1, y1)
    local reachable = self:region_at(ti, tj) == home and not self:blocked(x1, y1)
    if not reachable then
        ti, tj = self:nearest(ti, tj, home)
        if not ti then return nil end
    end

    local cells = { { x = si, y = sj } }
    if si ~= ti or sj ~= tj then
        local found = astar.find_path(self.grid, si, sj, ti, tj,
            { diagonal = true, corner_cutting = false, heuristic = "euclidean",
              max_iterations = pathing.MAX_ITERATIONS })
        if not found then return nil end
        cells = self:smooth(found)
    end

    local route = {}
    for k = 2, #cells do
        local x, y = self:world(cells[k].x, cells[k].y)
        route[#route + 1] = { x = x, y = y }
    end
    if reachable then
        route[#route + 1] = { x = x1, y = y1 }
    elseif #route == 0 then
        local x, y = self:world(ti, tj)
        route[1] = { x = x, y = y }
    end
    -- round the buildings on the way (issue 541)
    return self:refine(x0, y0, route)
end
-- }}}

return pathing
