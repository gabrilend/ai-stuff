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

-- 048-enforcer.lua
--
-- The enforcer eats bones for its team and itself, upgrades on what it has
-- eaten, and its sphere takes the shots aimed at friends inside it.
--
-- One row in the unit arrays with rules of its own, all of them reading only
-- enforcer rows and the arrays they act on. It is tall and claims wide, which
-- are catalogue relations and not code. It eats: the eat pass finds the bones
-- within its `eat_radius`, eats them last first, and splits the mass by the
-- row's `eat_share` between the team's treasury and its own `eaten`. What it
-- has eaten decides its upgrade step -- one step per `upgrade_mass`, up to the
-- catalogue's last -- and each step raises the health cap, the damage and the
-- sphere's radius together (open question A9's working ruling). It has a
-- sphere: a shield on its own recharge pair that takes the damage meant for any
-- unit of its team inside the sphere, itself included, until it is down.
-- `absorb` is that rule, and `combat.hurt` asks it before any health is taken.

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
    error("enforcer: wants exactly one NNN-the-world.lua beside it, and found " .. #found, 2)
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
local bones = world_module.load("bones")

M.KIND = "enforcer"

-- {{{ function M.step()
-- The upgrade step a unit has reached: one per `upgrade_mass` it has eaten, and
-- never past its kind's last. Zero for a kind that never upgrades. Derived, not
-- stored: `eaten` only rises, so the step can only rise with it.
function M.step(world, id)
  local row = units.kind(world.unit.kind[id])
  if row.upgrade_steps == 0 then
    return 0
  end
  local step = math.floor(world.unit.eaten[id] / row.upgrade_mass)
  if step > row.upgrade_steps then
    step = row.upgrade_steps
  end
  return step
end
-- }}}

-- {{{ function M.cap()
-- A unit's health cap: its kind's, plus what its upgrade steps add. Every kind
-- but one adds nothing, so this is the catalogue's cap for all of them.
function M.cap(world, id)
  local row = units.kind(world.unit.kind[id])
  return row.health + M.step(world, id) * row.upgrade_health
end
-- }}}

-- {{{ function M.sphere()
-- A unit's sphere radius, in cells: its kind's, plus what its steps add. Zero
-- for a kind with no shield.
function M.sphere(world, id)
  local row = units.kind(world.unit.kind[id])
  if row.sphere_radius <= 0 then
    return 0
  end
  return row.sphere_radius + M.step(world, id) * row.upgrade_sphere
end
-- }}}

-- {{{ function M.shield()
-- A unit's shield now, from its pair and its kind's recharge counter.
function M.shield(world, id)
  local unit = world.unit
  local row = units.kind(unit.kind[id])
  if row.shield <= 0 then
    return 0
  end
  return timers.read(unit.shield[id], unit.shield_at[id], world.recharge[row.name], row.shield)
end
-- }}}

-- {{{ function M.upgrade()
-- Brings a row to the step its `eaten` has reached: the damage rewritten in
-- place as the kind's plus a step's worth for each step. The cap and the sphere
-- are derived from the step, so they follow without a write. Returns the step.
-- Nothing goes past the catalogue's last step. Refuses a row that does not
-- upgrade.
function M.upgrade(world, id)
  local unit = world.unit
  if unit.alive[id] ~= 1 or unit.kind[id] == 0 or units.kind(unit.kind[id]).upgrade_steps == 0 then
    error("enforcer: unit " .. tostring(id) .. " is not a live unit of a kind that upgrades", 2)
  end
  local row = units.kind(unit.kind[id])
  local step = M.step(world, id)
  unit.damage[id] = row.damage + step * row.upgrade_damage
  return step
end
-- }}}

-- {{{ function M.eat_pass()
-- Every live unit that eats, in row order: the bones within its `eat_radius`,
-- eaten last first so the rows still to eat keep their places; each bone's mass
-- split by the row's `eat_share` -- that share to the team's treasury, the rest,
-- rounded down, to `eaten` -- and the row upgraded to the step it has reached.
-- Unsliced: it writes the treasury and the bone queue.
function M.eat_pass(world)
  local unit, team = world.unit, world.team
  for id = 1, unit.top do
    if unit.alive[id] == 1 and unit.kind[id] ~= 0 then
      local row = units.kind(unit.kind[id])
      if row.eat_radius > 0 and world.bone.count > 0 then
        local found = bones.near(world, unit.x[id], unit.y[id], row.eat_radius)
        local before = M.step(world, id)
        for index = #found, 1, -1 do
          local mass = bones.eat(world, id, found[index])
          local kept = math.floor(mass * (1 - unit.eat_share[id]))
          unit.eaten[id] = unit.eaten[id] + kept
          team.mass[unit.team[id]] = team.mass[unit.team[id]] + (mass - kept)
        end
        if row.upgrade_steps > 0 and M.step(world, id) ~= before then
          M.upgrade(world, id)
        end
      end
    end
  end
end
-- }}}

-- {{{ function M.absorb()
-- What is left of `amount` aimed at unit `target` after a sphere has taken its
-- share: the first live unit of the target's team, in row order, with a shield
-- up and the target inside its sphere -- itself included, and the sphere a
-- sphere, so a plane flying higher than its radius is outside it -- takes as
-- much as its shield holds, and its pair is rewritten with the increment of
-- now. Without such a sphere the whole amount is left. One sphere at most takes
-- a hit; overlapping spheres are a proving-ground question.
function M.absorb(world, target, amount)
  local unit = world.unit
  local team = unit.team[target]
  local tx, ty, tz = unit.x[target], unit.y[target], unit.altitude[target]
  for id = 1, unit.top do
    if unit.alive[id] == 1 and unit.kind[id] ~= 0 and unit.team[id] == team then
      local row = units.kind(unit.kind[id])
      if row.shield > 0 then
        local radius = M.sphere(world, id)
        local dx, dy, dz = tx - unit.x[id], ty - unit.y[id], tz - unit.altitude[id]
        if dx * dx + dy * dy + dz * dz <= radius * radius then
          local counter = world.recharge[row.name]
          local up = timers.read(unit.shield[id], unit.shield_at[id], counter, row.shield)
          if up > 0 then
            local taken = math.min(up, amount)
            unit.shield[id], unit.shield_at[id] =
              timers.write(unit.shield[id], unit.shield_at[id], counter, row.shield, -taken)
            return amount - taken
          end
        end
      end
    end
  end
  return amount
end
-- }}}

return M
