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

-- 047-command-truck.lua
--
-- The one unit a command moves: it walks where it is pointed, launches its
-- plane on a compass heading, and dies in one shell.
--
-- The truck is a unit like any other: a land row with the catalogue's one-shell
-- health. What sets it apart is the command door, where `move` and `launch` are
-- the two verbs that name a unit, and both name a truck. Moving is being handed
-- a fresh one-leg pattern from where it stands to where it is pointed; the move
-- pass walks it like any pattern and knows nothing of trucks. Launching puts the
-- truck's plane in the air at the truck, on its `heading` mission, when the
-- team's launch pair allows: one launch counter for the world, and each team's
-- `launch_at`, the increment from which it may launch again. What the plane
-- does once it flies is issue 406's.
--
-- Open questions built on their working rulings: A1, the command tank and the
-- command truck are one unit; A2, a team whose last truck dies has lost, which
-- the match's ending rule reads through `trucks_alive`; A8, the truck flies one
-- plane kind, `PLANE`, that scouts and shoots.

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
    error("command-truck: wants exactly one NNN-the-world.lua beside it, and found " .. #found, 2)
  end
  if package.loaded[found[1]] == nil then
    package.loaded[found[1]] = dofile(found[1])
  end
  return package.loaded[found[1]]
end
-- }}}

local world_module = the_world()
local units = world_module.load("units")
local domains = world_module.load("domains")

-- The kind a truck is, and the kind of plane it launches (A8's working ruling:
-- one plane that scouts and shoots; the catalogue's one plane is the helicopter).
M.KIND = "command-truck"
M.PLANE = "helicopter"

-- The truck plane's missions, in the order of the truck document's table; a
-- plane row's `mission` holds the number. Zero is no mission.
M.MISSIONS = {"heading", "hunting", "striking", "returning"}
M.MISSION = {}
for number, name in ipairs(M.MISSIONS) do
  M.MISSION[name] = number
end

-- {{{ local function is_truck()
-- Whether a row is a live command truck.
local function is_truck(world, id)
  local unit = world.unit
  return type(id) == "number" and id == math.floor(id) and id >= 1 and id <= unit.top
         and unit.alive[id] == 1 and unit.kind[id] == units.index_of(M.KIND)
end
-- }}}

-- {{{ function M.owned_by()
-- Why `team` may not command the row `id`, or nil when the row is a live truck
-- of that team. The door asks this before either verb.
function M.owned_by(world, id, team)
  if not is_truck(world, id) then
    return "unit " .. tostring(id) .. " is not a command truck"
  end
  if world.unit.team[id] ~= team then
    return "unit " .. id .. " is not your truck; it is team " .. world.unit.team[id] .. "'s"
  end
  return nil
end
-- }}}

-- {{{ function M.move()
-- Points a truck at (x, y): a fresh one-leg pattern from where it stands to
-- there, written into the pattern store, and the truck set walking it from its
-- first point. A second move replaces the first. Returns nothing, or a refusal:
-- not a truck, or not a land cell.
function M.move(world, id, x, y)
  if not is_truck(world, id) then
    return "unit " .. tostring(id) .. " is not a command truck"
  end
  local field = world.field
  if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y
     or x < -0.5 or y < -0.5 or x >= field.size - 0.5 or y >= field.size - 0.5
     or not domains.can_stand(field, domains.LAND, x, y) then
    return string.format("(%s, %s) is not a land cell; a truck goes only where land is",
                         tostring(x), tostring(y))
  end
  local unit, store = world.unit, world.pattern
  store.count = store.count + 1
  store.points[store.count] = {{x = unit.x[id], y = unit.y[id]}, {x = x, y = y}}
  unit.pattern[id] = store.count
  unit.leg[id] = 1
  unit.waited[id] = 0
  return nil
end
-- }}}

-- {{{ function M.next_launch_tick()
-- The tick from which a team's truck may launch again: now if its launch pair
-- allows, otherwise the tick the launch counter reaches the team's `launch_at`.
function M.next_launch_tick(world, team)
  local counter = world.launch
  local wanted = world.team.launch_at[team]
  if counter.increment >= wanted then
    return world.tick
  end
  return counter.next + (wanted - counter.increment - 1) * counter.period
end
-- }}}

-- {{{ local function edge_along()
-- Where a line from (x, y) on a compass heading (degrees, nought north -- up
-- the picture, toward row zero -- and ninety east) leaves the field.
local function edge_along(field, x, y, heading)
  local radians = math.rad(heading)
  local dx, dy = math.sin(radians), -math.cos(radians)
  local low, high = -0.5, field.size - 0.5
  local reach = math.huge
  if dx > 1e-9 then reach = math.min(reach, (high - x) / dx) end
  if dx < -1e-9 then reach = math.min(reach, (low - x) / dx) end
  if dy > 1e-9 then reach = math.min(reach, (high - y) / dy) end
  if dy < -1e-9 then reach = math.min(reach, (low - y) / dy) end
  return x + dx * reach, y + dy * reach
end
-- }}}

-- {{{ function M.launch()
-- Launches a truck's plane on a compass heading, in degrees from north: a
-- plane spawned at the truck, on the `heading` mission, its goal the point
-- where that heading leaves the field. The team's `launch_at` becomes the
-- launch counter's next increment. Returns nothing, or a refusal: not a
-- truck, a heading that is not a number, or a truck still reloading, with the
-- tick the next launch is allowed.
function M.launch(world, id, heading)
  if not is_truck(world, id) then
    return "unit " .. tostring(id) .. " is not a command truck"
  end
  if type(heading) ~= "number" or heading ~= heading or heading == math.huge or heading == -math.huge then
    return "a heading is " .. tostring(heading) .. ", not a compass direction in degrees"
  end
  local unit = world.unit
  local team = unit.team[id]
  local counter = world.launch
  if counter.increment < world.team.launch_at[team] then
    return string.format("team %d's truck is still reloading its plane; the next launch is allowed at tick %d",
                         team, M.next_launch_tick(world, team))
  end
  if unit.released == 0 and unit.top >= unit.capacity then
    return "the world has no room for another unit, so the plane stays on the truck"
  end
  local x, y = unit.x[id], unit.y[id]
  local plane = units.spawn(world, M.PLANE, team, x, y)
  unit.mission[plane] = M.MISSION.heading
  unit.goal_x[plane], unit.goal_y[plane] = edge_along(world.field, x, y, heading % 360)
  world.team.launch_at[team] = counter.increment + 1
  return nil
end
-- }}}

-- {{{ function M.trucks_alive()
-- How many live command trucks a team has: a walk over the unit rows. The
-- match's ending rule reads it (A2's working ruling: none left is a loss).
function M.trucks_alive(world, team)
  local unit = world.unit
  local truck = units.index_of(M.KIND)
  local count = 0
  for id = 1, unit.top do
    if unit.alive[id] == 1 and unit.kind[id] == truck and unit.team[id] == team then
      count = count + 1
    end
  end
  return count
end
-- }}}

return M
