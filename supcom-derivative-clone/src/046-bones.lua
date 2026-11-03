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

-- 046-bones.lua
--
-- A dead unit leaves bones: a position and a mass, belonging to nobody, until an
-- enforcer eats them.
--
-- Bones are a queue in the world's layout, apart from the units: `x`, `y` and
-- `mass`, nothing else. The mass is the dead kind's `bone_share` of its
-- `cost_mass`, rounded down, and it is the only thing a death puts back into the
-- world. Bones do nothing: they block no step and no sightline, and they belong
-- to no team, whoever's ground they lie on. The die pass leaves them (`leave`),
-- the enforcer's eat pass finds them (`near`) and eats them (`eat`), and nothing
-- else writes them. The queue is allocated once and refuses by name when full:
-- more bones than the parameters allowed is a parameter that was wrong, not a
-- case to paper over by forgetting the oldest.

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
    error("bones: wants exactly one NNN-the-world.lua beside it, and found " .. #found, 2)
  end
  if package.loaded[found[1]] == nil then
    package.loaded[found[1]] = dofile(found[1])
  end
  return package.loaded[found[1]]
end
-- }}}

local world_module = the_world()
local units = world_module.load("units")

-- {{{ function M.mass_of()
-- What the bones of a kind (a name or an index) carry: its `bone_share` of its
-- `cost_mass`, rounded down. Zero for a kind that cost no mass.
function M.mass_of(kind)
  local row = units.kind(kind)
  return math.floor(row.cost_mass * row.bone_share)
end
-- }}}

-- {{{ function M.leave_at()
-- New bones at a position, carrying a whole mass of at least one, as their row.
-- Refuses a position off the field or a mass that is not a whole number from
-- one, and a full queue by name.
function M.leave_at(world, x, y, mass)
  local size = world.field.size
  if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y
     or x < -0.5 or y < -0.5 or x > size - 0.5 or y > size - 0.5 then
    error("bones: (" .. tostring(x) .. ", " .. tostring(y) .. ") is not on the field", 2)
  end
  if type(mass) ~= "number" or mass ~= math.floor(mass) or mass < 1 then
    error("bones: a mass is " .. tostring(mass) .. ", not a whole number from one", 2)
  end
  local bone = world.bone
  if bone.count >= bone.capacity then
    error("bones: the bone queue is full at its capacity of " .. bone.capacity
          .. "; the parameters allowed fewer bones than this match left", 2)
  end
  local index = world_module.push(world, "bone")
  bone.x[index], bone.y[index], bone.mass[index] = x, y, mass
  return index
end
-- }}}

-- {{{ function M.leave()
-- The bones of a unit that has just died, where it stands: called by the die
-- pass before the row is released, and by nothing else. Returns their row, or
-- zero for a kind whose bones would carry nothing, which leaves none.
function M.leave(world, id)
  local unit = world.unit
  if unit.alive[id] ~= 1 or unit.kind[id] == 0 then
    error("bones: unit " .. tostring(id) .. " is not a unit of a kind to leave bones", 2)
  end
  local mass = M.mass_of(unit.kind[id])
  if mass < 1 then
    return 0
  end
  return M.leave_at(world, unit.x[id], unit.y[id], mass)
end
-- }}}

-- {{{ function M.near()
-- The bone rows within `radius` cells of a position, in queue order: one walk
-- of the bone arrays, which only the eat pass makes.
function M.near(world, x, y, radius)
  local bone = world.bone
  local square = radius * radius
  local found = {}
  for index = 1, bone.count do
    local dx, dy = bone.x[index] - x, bone.y[index] - y
    if dx * dx + dy * dy <= square then
      found[#found + 1] = index
    end
  end
  return found
end
-- }}}

-- {{{ function M.eat()
-- A live unit eats a row of bones: the row leaves the queue and its mass is
-- handed back for the caller to share out. The queue closes up in order, so
-- every later row moves down by one: an eat pass that eats several rows from
-- `near` eats them last first. Called by issue 211's eat pass and nothing else.
function M.eat(world, id, index)
  local unit, bone = world.unit, world.bone
  if unit.alive[id] ~= 1 or unit.kind[id] == 0 then
    error("bones: unit " .. tostring(id) .. " is not a live unit to eat", 2)
  end
  if type(index) ~= "number" or index < 1 or index > bone.count then
    error("bones: there is no bone row " .. tostring(index) .. "; the queue holds " .. bone.count, 2)
  end
  local mass = bone.mass[index]
  world_module.remove(world, "bone", index)
  return mass
end
-- }}}

-- {{{ function M.total()
-- All the mass lying in bones on the field: what a death has put back and no
-- enforcer has eaten yet.
function M.total(world)
  local bone = world.bone
  local sum = 0
  for index = 1, bone.count do
    sum = sum + bone.mass[index]
  end
  return sum
end
-- }}}

return M
