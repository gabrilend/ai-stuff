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

    local ti, tj = self:cell(x1, y1)
    local reachable = self:region_at(ti, tj) == home
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
    return route
end
-- }}}

return pathing
