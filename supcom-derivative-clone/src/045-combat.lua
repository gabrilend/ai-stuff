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

-- 045-combat.lua
--
-- Firing changes nothing; a shot lands at its tick, health comes back on a
-- shared timer, and the dead are taken out.
--
-- Three passes, in the tick's order fire, land, die. The fire pass is sliced:
-- a ready unit with a target appends one shot to the world's shot queue and
-- rewrites its own `reload_at`, and nothing else moves. The land pass runs on
-- one worker and walks the queue from one to its count: every shot whose
-- arrival tick has come is applied to its target through `hurt`, which derives
-- the target's health from its heal pair, takes the damage off and rewrites the
-- pair with the increment of now. The die pass then reads every unit's derived
-- health once; a unit at or below zero is released, and the shots still flying
-- at it are dropped. Nothing but the die pass ever observes a unit to be dead.
--
-- A shot follows its target (open question A3's working ruling): it lands on the
-- unit it was fired at, wherever that unit is by then. The other reading -- a
-- shell that lands on the ground it was aimed at -- would be a different land
-- pass and a shot row with a position, and this file is where it would change.

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
    error("combat: wants exactly one NNN-the-world.lua beside it, and found " .. #found, 2)
  end
  if package.loaded[found[1]] == nil then
    package.loaded[found[1]] = dofile(found[1])
  end
  return package.loaded[found[1]]
end
-- }}}

local world_module = the_world()
local units = world_module.load("units")
local timers = world_module.load("timers")
local targeting = world_module.load("targeting")

-- {{{ local function heal_counter()
-- The heal counter of a unit's kind, and the kind's cap.
local function heal_counter(world, id)
  local row = units.kind(world.unit.kind[id])
  return world.heal[row.name], row.health
end
-- }}}

-- {{{ function M.health()
-- A unit's health now: what was written, plus one for every increment of its
-- kind's heal counter since, held to the catalogue's cap. Four operations; no
-- unit is ever walked to be healed.
function M.health(world, id)
  local unit = world.unit
  if unit.alive[id] ~= 1 or unit.kind[id] == 0 then
    error("combat: unit " .. tostring(id) .. " is not a live unit of a kind", 2)
  end
  local counter, cap = heal_counter(world, id)
  return timers.read(unit.health[id], unit.health_at[id], counter, cap)
end
-- }}}

-- {{{ function M.hurt()
-- Takes `amount` off a unit's health: the current value is derived, the amount
-- subtracted, and the pair rewritten with the increment of now. Two hurts on one
-- increment both apply, and the heal after them counts from the second. Health
-- may fall below zero; that is the die pass's business. Refuses a negative or
-- fractional amount, so nothing heals through here.
function M.hurt(world, id, amount)
  if type(amount) ~= "number" or amount ~= math.floor(amount) or amount < 0 then
    error("combat: a hurt is " .. tostring(amount) .. ", not a whole number from zero", 2)
  end
  local unit = world.unit
  if unit.alive[id] ~= 1 or unit.kind[id] == 0 then
    error("combat: unit " .. tostring(id) .. " is not a live unit of a kind to hurt", 2)
  end
  -- Issue 211: a unit inside an enforcer's sphere has the shield take the
  -- amount first; until then the amount goes straight to the heal pair.
  local counter, cap = heal_counter(world, id)
  unit.health[id], unit.health_at[id] =
    timers.write(unit.health[id], unit.health_at[id], counter, cap, -amount)
end
-- }}}

-- {{{ function M.damage_at()
-- What a shot from `id` does at `distance`: the unit's damage times its falloff
-- curve's fraction there, rounded down, and never less than one, so every shell
-- that lands is felt.
function M.damage_at(world, id, distance)
  local unit = world.unit
  local amount = math.floor(unit.damage[id] * targeting.falloff(unit.falloff[id], distance))
  if amount < 1 then
    amount = 1
  end
  return amount
end
-- }}}

-- {{{ function M.fire_pass_slice()
-- The shooters from `first` to `last`, in row order: every live unit whose
-- weapon is ready and which has a live target appends one shot and rewrites its
-- own `reload_at` to the next increment of its kind's reload counter. Shots are
-- appended in row order, so slices run in ascending order append exactly what
-- the whole pass would.
function M.fire_pass_slice(world, first, last)
  local unit, shot = world.unit, world.shot
  for id = first, last do
    local target = unit.target[id]
    if unit.alive[id] == 1 and target ~= 0 and unit.alive[target] == 1 and unit.kind[target] ~= 0
       and targeting.ready(world, id) then
      local row = units.kind(unit.kind[id])
      local distance = targeting.distance(world, id, target)
      local index = world_module.push(world, "shot")
      shot.shooter[index] = id
      shot.target[index] = target
      shot.damage[index] = M.damage_at(world, id, distance)
      shot.arrives[index] = world.tick + targeting.flight_ticks(row.index, distance)
      unit.reload_at[id] = world.reload[row.name].increment + 1
    end
  end
end
-- }}}

-- {{{ function M.fire_pass()
-- The tick's `fire` row over the whole world.
function M.fire_pass(world)
  M.fire_pass_slice(world, 1, world.unit.top)
end
-- }}}

-- {{{ local function keep_shots()
-- Walks the shot queue once, from one to its count, asking `drop(index)` of
-- each; the shots it keeps close up in the order they were, and the slots left
-- over at the end are zeroed. A stable compaction rather than moving the last
-- row into a freed slot, because the order of the queue is the order of
-- landing, and two machines must land in the same order.
local function keep_shots(world, drop)
  local shot = world.shot
  local kept = 0
  for index = 1, shot.count do
    if not drop(index) then
      kept = kept + 1
      if kept ~= index then
        shot.shooter[kept] = shot.shooter[index]
        shot.target[kept] = shot.target[index]
        shot.damage[kept] = shot.damage[index]
        shot.arrives[kept] = shot.arrives[index]
      end
    end
  end
  for index = kept + 1, shot.count do
    shot.shooter[index], shot.target[index], shot.damage[index], shot.arrives[index] = 0, 0, 0, 0
  end
  shot.count = kept
end
-- }}}

-- {{{ function M.land_pass()
-- The tick's `land` row, on one worker: every shot whose arrival tick has come
-- is applied to its target, in queue order, and leaves the queue; a shot whose
-- target is no longer a live unit is dropped. Every other shot stays, in order.
function M.land_pass(world)
  local unit, shot, tick = world.unit, world.shot, world.tick
  keep_shots(world, function(index)
    if shot.arrives[index] > tick then
      return false
    end
    local target = shot.target[index]
    if unit.alive[target] == 1 and unit.kind[target] ~= 0 then
      M.hurt(world, target, shot.damage[index])
    end
    return true
  end)
end
-- }}}

-- {{{ function M.die_pass()
-- The tick's `die` row, on one worker: every live unit whose derived health is
-- at or below zero is released, in row order, which lowers the live count, and
-- every shot still flying at it is dropped, so a row handed out again is never
-- hit by a shell meant for the unit that held it. Returns how many died.
-- Issue 208 calls its `leave` here, before the row is released. Allocates
-- nothing on a tick nobody dies.
function M.die_pass(world)
  local unit = world.unit
  local dead = nil
  for id = 1, unit.top do
    if unit.alive[id] == 1 and unit.kind[id] ~= 0 and M.health(world, id) <= 0 then
      dead = dead or {}
      dead[#dead + 1] = id
    end
  end
  if dead == nil then
    return 0
  end
  local gone = {}
  for _, id in ipairs(dead) do
    world_module.release(world, "unit", id)
    gone[id] = true
  end
  local shot = world.shot
  keep_shots(world, function(index)
    return gone[shot.target[index]] == true
  end)
  return #dead
end
-- }}}

-- {{{ function M.describe()
-- One shot as a line, for a test that finds a shot landing early or late: its
-- place in the queue, who fired it at whom, for how much, when it arrives, and
-- the tick it was looked at in.
function M.describe(world, index)
  local shot = world.shot
  if index < 1 or index > shot.count then
    return string.format("no shot %d; the queue holds %d at tick %d", index, shot.count, world.tick)
  end
  return string.format("shot %d: unit %d at unit %d for %d, arrives at tick %d, checked at tick %d",
                       index, shot.shooter[index], shot.target[index], shot.damage[index],
                       shot.arrives[index], world.tick)
end
-- }}}

return M
