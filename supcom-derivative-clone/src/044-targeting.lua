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

-- 044-targeting.lua
--
-- Any enemy in sight may be shot, at any distance; distance falls the damage
-- and delays the shell.
--
-- Nothing is out of range. A unit whose weapon has reloaded considers every live
-- enemy in a domain its weapon reaches, keeps those it has a sightline to, and
-- picks an enemy command truck first, then the closest, ties going to the lower
-- row. It keeps the target it has while that target lives, stays in sight, and
-- nothing of higher priority appears, so it never flickers between two at an
-- equal distance. Distance does two things and never forbids the shot: damage
-- falls off in a straight line from full to a floor, and the shell takes the
-- distance over its speed, in whole ticks, to arrive.
--
-- The aim pass is sliced (issue 209): it reads the world and writes only the
-- shooter's own `target`.

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
    error("targeting: wants exactly one NNN-the-world.lua beside it, and found " .. #found, 2)
  end
  if package.loaded[found[1]] == nil then
    package.loaded[found[1]] = dofile(found[1])
  end
  return package.loaded[found[1]]
end
-- }}}

local world_module = the_world()
local dunes = world_module.load("the-dunes")
local sightlines = world_module.load("sightlines")
local units = world_module.load("units")
local domains = world_module.load("domains")
local bit = require("bit")

-- The one rule for choosing (raised in issue 205: per kind only when a kind
-- needs otherwise): an enemy of this kind first, then the closest.
M.FIRST = "command-truck"

-- {{{ function M.falloff()
-- The fraction of full damage a shot from `kind` (a name or an index) does at
-- `distance` cells: one out to the kind's `falloff_full`, then a straight line
-- down to `falloff_floor` at `falloff_end`, and the floor beyond. A kind whose
-- floor is one loses nothing at any distance. Refuses a kind the catalogue lacks.
function M.falloff(kind, distance)
  local row = units.kind(kind)
  if type(distance) ~= "number" or distance ~= distance or distance < 0 then
    error("targeting: a distance is " .. tostring(distance) .. ", not a number from zero", 2)
  end
  if distance <= row.falloff_full then
    return 1
  end
  local floor = row.falloff_floor
  local span = row.falloff_end - row.falloff_full
  if distance >= row.falloff_end or span <= 0 then
    return floor
  end
  return 1 - (1 - floor) * (distance - row.falloff_full) / span
end
-- }}}

-- {{{ function M.flight_ticks()
-- How many ticks a shell from `kind` takes over `distance`: the distance over
-- the shell's speed, rounded up, and never less than one. Refuses a kind with
-- no weapon.
function M.flight_ticks(kind, distance)
  local row = units.kind(kind)
  if row.shell_speed <= 0 then
    error("targeting: a " .. row.name .. " has no weapon, so its shells have no flight", 2)
  end
  local ticks = math.ceil(distance / row.shell_speed)
  if ticks < 1 then
    ticks = 1
  end
  return ticks
end
-- }}}

-- {{{ function M.distance()
-- How far apart two units are across the field, in cells.
function M.distance(world, a, b)
  local unit = world.unit
  local dx, dy = unit.x[b] - unit.x[a], unit.y[b] - unit.y[a]
  return math.sqrt(dx * dx + dy * dy)
end
-- }}}

-- {{{ local function above_ground()
-- How high above the ground under it a unit's point is: its eye or its
-- profile, and for a plane its altitude over that ground besides.
local function above_ground(world, id, height)
  local unit, field = world.unit, world.field
  if unit.domain[id] ~= domains.AIR then
    return height
  end
  local cx, cy = dunes.cell_of(field, unit.x[id], unit.y[id])
  return unit.altitude[id] - field.height[dunes.index(field, cx, cy)] + height
end
-- }}}

-- {{{ function M.sees()
-- Whether unit `a` has a sightline to unit `b`: from a's eye to b's top, both at
-- their altitudes. One sightline question.
function M.sees(world, a, b)
  local unit = world.unit
  return sightlines.can_see(world.field, unit.x[a], unit.y[a], above_ground(world, a, unit.eye[a]),
                            unit.x[b], unit.y[b], above_ground(world, b, unit.profile[b]))
end
-- }}}

-- {{{ function M.ready()
-- Whether a unit's weapon may fire: it has one, and the increment of now on its
-- kind's reload counter has reached `reload_at`, the increment from which it may
-- fire again (zero for a weapon never fired).
function M.ready(world, id)
  local unit = world.unit
  if unit.damage[id] <= 0 or unit.kind[id] == 0 then
    return false
  end
  local counter = world.reload[units.kind(unit.kind[id]).name]
  return counter.increment >= unit.reload_at[id]
end
-- }}}

-- {{{ function M.candidates()
-- Every live enemy of `shooter` in a domain its weapon reaches, in row order:
-- a walk over the unit arrays, never a table iteration.
function M.candidates(world, shooter)
  local unit = world.unit
  local reaches = units.kind(unit.kind[shooter]).reaches
  local team = unit.team[shooter]
  local found = {}
  for id = 1, unit.top do
    if unit.alive[id] == 1 and unit.kind[id] ~= 0 and unit.team[id] ~= team
       and bit.band(reaches, bit.lshift(1, unit.domain[id] - 1)) ~= 0 then
      found[#found + 1] = id
    end
  end
  return found
end
-- }}}

-- {{{ function M.visible()
-- Every live enemy `shooter` can see, whatever its weapon reaches, in row order:
-- what the terminal viewer's sightline layer marks.
function M.visible(world, shooter)
  local unit = world.unit
  local found = {}
  for id = 1, unit.top do
    if unit.alive[id] == 1 and unit.kind[id] ~= 0 and unit.team[id] ~= unit.team[shooter]
       and M.sees(world, shooter, id) then
      found[#found + 1] = id
    end
  end
  return found
end
-- }}}

-- {{{ local function rank()
-- A candidate's place in the order of choosing: zero for the kind that comes
-- first, one for everything else, then the square of its distance.
local function rank(world, shooter, id, first)
  local unit = world.unit
  local dx, dy = unit.x[id] - unit.x[shooter], unit.y[id] - unit.y[shooter]
  return unit.kind[id] == first and 0 or 1, dx * dx + dy * dy
end
-- }}}

-- {{{ local function aim()
-- One shooter's choice. The best candidate is found in row order, and a
-- sightline is asked only of a candidate that would beat the best so far, so
-- the answer is the full rule's and the questions are as few as it allows.
local function aim(world, shooter, first)
  local unit = world.unit
  local best, best_class, best_square = 0, 2, math.huge
  for _, id in ipairs(M.candidates(world, shooter)) do
    local class, square = rank(world, shooter, id, first)
    if (class < best_class or (class == best_class and square < best_square))
       and M.sees(world, shooter, id) then
      best, best_class, best_square = id, class, square
    end
  end
  -- The current target stays while it lives, is still an enemy the weapon
  -- reaches, is still in sight, and nothing of a higher class has appeared.
  local current = unit.target[shooter]
  if current ~= 0 and current ~= best and unit.alive[current] == 1 and unit.kind[current] ~= 0
     and unit.team[current] ~= unit.team[shooter]
     and bit.band(units.kind(unit.kind[shooter]).reaches, bit.lshift(1, unit.domain[current] - 1)) ~= 0 then
    local class = rank(world, shooter, current, first)
    if class <= best_class and M.sees(world, shooter, current) then
      return
    end
  end
  unit.target[shooter] = best
end
-- }}}

-- {{{ function M.aim_pass_slice()
-- The shooters from `first` to `last`: every live unit with a reloaded weapon
-- chooses. Writes only those units' `target`.
function M.aim_pass_slice(world, first, last)
  local unit = world.unit
  local truck = units.index_of(M.FIRST)
  for id = first, last do
    if unit.alive[id] == 1 and M.ready(world, id) then
      aim(world, id, truck)
    end
  end
end
-- }}}

-- {{{ function M.aim_pass()
-- The tick's sight-and-aim row over the whole world.
function M.aim_pass(world)
  M.aim_pass_slice(world, 1, world.unit.top)
end
-- }}}

return M
