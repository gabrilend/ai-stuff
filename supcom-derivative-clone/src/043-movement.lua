-- supcom-derivative-clone — a factory war on dunes where nothing is out of range
-- Copyright (C) 2026 gabrilend
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU Affero General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or (at
-- your option) any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero
-- General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program. If not, see <https://www.gnu.org/licenses/>.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

-- 043-movement.lua
--
-- Land and sea units walk their pattern one leg at a time and hold at its end.
--
-- A pattern is a list of points in the world's pattern store; a unit's row holds
-- which pattern (`pattern`) and which point it is heading for (`leg`). Each pass
-- moves every live land and sea unit along its leg by its speed, slowed going
-- uphill, and turns to the next point on reaching one. One past the last point
-- it holds for good: no chase, no return, no loop (A4's working ruling).
--
-- The water is a wall: a step a unit's domain may not stand on is not taken,
-- and the unit does not turn round. Two land units do not share a cell: a unit
-- whose next cell is held by another waits one pass, then steps aside, square
-- to its way, until its way is clear. Planes do not move here; their missions do.
--
-- The pass is sliced (issue 209): a slice reads the field, the patterns and the
-- occupancy, and writes only its own units' rows. The occupancy is rewritten by
-- `occupancy_pass`, which is not sliced and which the whole-world pass runs first.

local M = {}

-- {{{ local function the_world()
-- The world module, which holds the loader every module uses to find another by
-- its stem. It is found here by that same rule -- exactly one NNN-the-world.lua
-- beside this file -- because a file cannot use the loader to find the loader.
local function the_world()
  local path = debug.getinfo(1, "S").source:sub(2)
  if path:sub(1, 1) ~= "/" then
    path = os.getenv("PWD") .. "/" .. path
  end
  local here = path:match("^(.*)/[^/]+$")
  local found = {}
  local handle = io.popen("ls -1 '" .. here .. "' 2>/dev/null")
  for name in handle:lines() do
    if name:match("^%d%d%d%-the%-world%.lua$") then
      found[#found + 1] = here .. "/" .. name
    end
  end
  handle:close()
  if #found ~= 1 then
    error("movement: wants exactly one NNN-the-world.lua beside it, and found " .. #found, 2)
  end
  if package.loaded[found[1]] == nil then
    package.loaded[found[1]] = dofile(found[1])
  end
  return package.loaded[found[1]]
end
-- }}}

local world_module = the_world()
local dunes = world_module.load("the-dunes")
local domains = world_module.load("domains")
local units = world_module.load("units")
local ffi = require("ffi")

-- {{{ local function stand()
-- Whether a unit of `domain` may stand at (x, y), with a position off the field
-- an answer of no rather than a refusal: the edge is a wall like the water.
local function stand(field, domain, x, y)
  local size = field.size
  if x < -0.5 or y < -0.5 or x >= size - 0.5 or y >= size - 0.5 then
    return false
  end
  return domains.can_stand(field, domain, x, y)
end
-- }}}

-- {{{ local function cell_index()
local function cell_index(field, x, y)
  local cx, cy = dunes.cell_of(field, x, y)
  return dunes.index(field, cx, cy)
end
-- }}}

-- {{{ function M.step_length()
-- How far a unit of `kind` (a name or an index) goes in one pass from (from_x,
-- from_y) toward (to_x, to_y): its flat-ground speed, divided by one plus its
-- `climb` times the rise from the cell it stands in to the cell one step of a
-- whole cell ahead (C1's working ruling, slope costs). Downhill is never faster
-- than flat, and a ship's water is flat.
function M.step_length(field, kind, from_x, from_y, to_x, to_y)
  local row = units.kind(kind)
  local dx, dy = to_x - from_x, to_y - from_y
  local distance = math.sqrt(dx * dx + dy * dy)
  if distance == 0 or row.climb == 0 or row.domain ~= domains.LAND then
    return row.speed
  end
  local here = field.height[cell_index(field, from_x, from_y)]
  local ahead = field.height[cell_index(field, from_x + dx / distance, from_y + dy / distance)]
  local rise = ahead - here
  if rise <= 0 then
    return row.speed
  end
  return row.speed / (1 + row.climb * rise)
end
-- }}}

-- {{{ function M.occupancy_pass()
-- The cells land units stand in, rewritten from nothing: each live land unit's
-- cell holds its id, the lowest id first when two share one. Not sliced; the
-- move pass reads it and never writes it.
function M.occupancy_pass(world)
  local cell, unit, field = world.cell, world.unit, world.field
  ffi.fill(cell.occupant, (cell.capacity + 1) * ffi.sizeof("int32_t"))
  local occupant = cell.occupant
  for id = 1, unit.top do
    if unit.alive[id] == 1 and unit.kind[id] ~= 0 and unit.domain[id] == domains.LAND then
      local index = cell_index(field, unit.x[id], unit.y[id])
      if occupant[index] == 0 then
        occupant[index] = id
      end
    end
  end
end
-- }}}

-- {{{ local function free()
-- Whether a land unit may step into the cell at (x, y): its own cell always, any
-- other only if nobody else stood there when the pass began. Other domains do
-- not hold cells.
local function free(world, id, domain, x, y)
  if domain ~= domains.LAND then
    return true
  end
  local field = world.field
  local index = cell_index(field, x, y)
  if index == cell_index(field, world.unit.x[id], world.unit.y[id]) then
    return true
  end
  local occupant = world.cell.occupant[index]
  return occupant == 0 or occupant == id
end
-- }}}

-- {{{ local function sidestep()
-- After a wait, a step square to the way: to the left of it first, then to the
-- right. Taken pass after pass while the way stays blocked, it carries the unit
-- into the next row of cells, from which the way runs past the cell that was
-- held. The first a unit may stand on and nobody holds, or nothing.
local function sidestep(world, id, domain, ux, uy, length)
  local unit, field = world.unit, world.field
  local x, y = unit.x[id], unit.y[id]
  for _, turn in ipairs({1, -1}) do
    local nx, ny = x - turn * uy * length, y + turn * ux * length
    if stand(field, domain, nx, ny) and free(world, id, domain, nx, ny) then
      return nx, ny
    end
  end
  return nil
end
-- }}}

-- {{{ local function walk()
-- One unit's pass: skip the points it already stands on, step toward the next,
-- landing exactly on a point it reaches and turning to the one after it.
local function walk(world, id)
  local unit, field = world.unit, world.field
  local points = world.pattern.points[unit.pattern[id]]
  local count = #points
  local leg = unit.leg[id]
  local x, y = unit.x[id], unit.y[id]
  while leg <= count and points[leg].x == x and points[leg].y == y do
    leg = leg + 1
  end
  unit.leg[id] = leg
  if leg > count then
    return
  end
  local goal = points[leg]
  local dx, dy = goal.x - x, goal.y - y
  local distance = math.sqrt(dx * dx + dy * dy)
  local ux, uy = dx / distance, dy / distance
  local domain = unit.domain[id]
  local length = M.step_length(field, unit.kind[id], x, y, goal.x, goal.y)
  local nx, ny
  if distance <= length then
    nx, ny = goal.x, goal.y
  else
    nx, ny = x + ux * length, y + uy * length
  end
  if not stand(field, domain, nx, ny) then
    return
  end
  if not free(world, id, domain, nx, ny) then
    if unit.waited[id] == 0 then
      unit.waited[id] = 1
      return
    end
    -- Still waiting, so a blocked way next pass steps aside again at once.
    nx, ny = sidestep(world, id, domain, ux, uy, length)
    if nx ~= nil then
      unit.x[id], unit.y[id] = nx, ny
    end
    return
  end
  unit.x[id], unit.y[id] = nx, ny
  unit.waited[id] = 0
  if nx == goal.x and ny == goal.y then
    unit.leg[id] = leg + 1
  end
end
-- }}}

-- {{{ function M.move_pass_slice()
-- The units from `first` to `last`: every live land or sea unit with a pattern
-- walks it. Writes only those units' rows.
function M.move_pass_slice(world, first, last)
  local unit = world.unit
  local alive, domain, pattern = unit.alive, unit.domain, unit.pattern
  for id = first, last do
    if alive[id] == 1 and pattern[id] ~= 0 and domain[id] ~= domains.AIR and unit.kind[id] ~= 0 then
      walk(world, id)
    end
  end
end
-- }}}

-- {{{ function M.move_pass_before()
-- What the thread pool runs, unsliced, before the move pass's slices: the
-- occupancy they read.
M.move_pass_before = function(world)
  M.occupancy_pass(world)
end
-- }}}

-- {{{ function M.move_pass()
-- The tick's move row over the whole world: the occupancy first, then every unit.
function M.move_pass(world)
  M.occupancy_pass(world)
  M.move_pass_slice(world, 1, world.unit.top)
end
-- }}}

-- {{{ function M.held()
-- Whether a unit has passed the last point of its pattern and holds there.
function M.held(world, id)
  local pattern = world.unit.pattern[id]
  if pattern == 0 then
    return false
  end
  return world.unit.leg[id] > #world.pattern.points[pattern]
end
-- }}}

return M
