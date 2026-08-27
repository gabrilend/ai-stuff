-- hero-less-moba — a lane-pushing game with the heroes subtracted out
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

-- 040-structures.lua
--
-- The stone: towers that shoot, the guards they put on the ground, and what
-- happens when one falls.
--
-- Every guard tower is the same strength as every other guard tower. There are no
-- tiers and no inner-tower-is-tougher rule, and that flatness is deliberate: if
-- towers already differed, a slotted upgrade would be a small adjustment to an
-- existing hierarchy. Because they are flat, a slotted upgrade is the *only*
-- thing distinguishing one lane's stone from another's, which makes the slotting
-- decision visible from across the map.
--
-- ## The command radius, and the inversion at the heart of it
--
-- A tower fills its patrol back up to a cap, and **only while no enemy stands
-- inside its command radius.**
--
-- That is the opposite of what a tower usually does, and the inversion is the
-- whole mechanic. A tower under attack does not reinforce itself; a tower with
-- clear ground around it does. So the way to make a tower approachable is to
-- *reach* it -- get a body inside the circle and hold it there. Grinding the
-- guards down from outside the radius achieves nothing, because they come
-- straight back.
--
-- The same circle decides where a hero may be put down. One radius, two jobs,
-- drawn once -- and drawn for **both** teams, which makes it the single piece of
-- information in this game that both sides can see. The attacker needs to know
-- how far in they must get to shut the reinforcements off; the defender needs to
-- know how far out they must push to turn them back on. Everything else here is
-- hidden until it walks into you.

local M = {}

-- The guard archetype's row in the unit table.
local GUARD = 4

-- {{{ local function enemy_inside_radius()
-- Whether any living enemy body stands inside a tower's command radius.
local function enemy_inside_radius(world, structure)
  local node = world.map.node[structure.node]
  local soldier = world.soldier
  local found = false

  -- The grid's cells are sized to the widest query anybody makes, and a command
  -- radius is wider than that. So this one walks the live bodies directly rather
  -- than through the grid -- there are eighteen towers and the walk is over the
  -- high-water mark, not the capacity.
  for id = 1, world.high_water do
    if soldier.alive[id] == 1 and world.targeting.hostile(structure.team, soldier.team[id]) then
      local dx = soldier.x[id] - node.x
      local dy = soldier.y[id] - node.y
      if dx * dx + dy * dy <= structure.command_radius * structure.command_radius then
        found = true
        break
      end
    end
  end
  return found
end
-- }}}

-- {{{ local function living_guards()
-- How many of a tower's guard slots still hold a living body, compacting the
-- slots as it goes.
local function living_guards(world, structure)
  local soldier = world.soldier
  local kept = {}
  for _, id in ipairs(structure.guard_slot) do
    if id ~= 0 and soldier.alive[id] == 1 then
      kept[#kept + 1] = id
    end
  end
  structure.guard_slot = kept
  return #kept
end
-- }}}

-- {{{ local function put_guard_on_the_ground()
-- Spawns one guard at a tower, leashed to it and stamped from it.
local function put_guard_on_the_ground(world, structure)
  local id = world.allocate(world)
  local soldier = world.soldier
  local row = world.parameters.unit.archetype[GUARD]

  world.give_body(world, id, row)
  soldier.team[id] = structure.team
  soldier.archetype[id] = GUARD
  soldier.owner[id] = 0
  -- Zero, because a guard is not in a wave. The reap pass reads this to know
  -- whose living count to decrement, and a guard's death must decrement nothing.
  soldier.wave[id] = 0
  soldier.leash_node[id] = structure.node
  soldier.guard_of[id] = structure.id

  world.walking.place_at_node(world, id, structure.node)
  world.chest.stamp_from_stone(world, id, structure)

  structure.guard_slot[#structure.guard_slot + 1] = id
  return id
end
-- }}}

-- {{{ function M.guard_pass()
-- Two jobs: towers replace fallen guards when their ground is clear, and guards
-- that have drifted too far turn round and go home.
function M.guard_pass(world)
  local soldier = world.soldier
  local leash_radius = world.parameters.structure.tower.leash_radius

  for _, structure in ipairs(world.structure) do
    if structure.alive == 1 and structure.kind ~= 3 then
      local standing = living_guards(world, structure)

      if standing < structure.guard_cap then
        -- The inversion: the timer only runs while the ground is clear. A tower
        -- being attacked stops producing, which is what makes reaching it the
        -- thing that matters rather than out-damaging it from range.
        if enemy_inside_radius(world, structure) then
          -- Held, not reset. Resetting would mean a tower that is harassed once a
          -- second never reinforces at all, and a single body could shut a tower
          -- down permanently by standing at the edge of the circle.
          structure.guard_timer = structure.guard_timer
        else
          structure.guard_timer = structure.guard_timer - 1
          if structure.guard_timer <= 0 then
            put_guard_on_the_ground(world, structure)
            structure.guard_timer = world.parameters.structure.tower.guard_interval
          end
        end
      else
        structure.guard_timer = world.parameters.structure.tower.guard_interval
      end
    end
  end

  -- Guards that have wandered or chased past their leash. Checked here rather
  -- than in the brain because it is a fact about the tower's ground, not about
  -- what the body was thinking.
  for id = 1, world.high_water do
    if soldier.alive[id] == 1 and soldier.flavour[id] == 3
       and soldier.state[id] ~= 4 and soldier.leash_node[id] ~= 0 then
      local leash = world.map.node[soldier.leash_node[id]]
      local dx = soldier.x[id] - leash.x
      local dy = soldier.y[id] - leash.y
      if dx * dx + dy * dy > leash_radius * leash_radius then
        soldier.state[id] = 4   -- leashing
      end
    end
  end
end
-- }}}

-- {{{ function M.tower_pass()
-- Towers pick a target and keep it, then shoot.
--
-- Sticky rather than nearest-every-tick. A tower that re-picks constantly spreads
-- its damage across a whole wave and kills nothing, which makes it feel like
-- weather rather than a defence. A tower that commits kills one soldier every few
-- seconds, and a player can watch it happen and count.
function M.tower_pass(world)
  local soldier = world.soldier

  for _, structure in ipairs(world.structure) do
    -- A library attacks nothing. It is a building, not a defence.
    if structure.alive == 1 and structure.kind ~= 3 then
      if structure.cooldown > 0 then
        structure.cooldown = structure.cooldown - 1
      end

      local node = world.map.node[structure.node]
      local target = structure.target

      -- Keep the current target while it lives and stays in range.
      local keep = false
      if target ~= 0 and soldier.alive[target] == 1
         and soldier.generation[target] == structure.target_generation then
        local dx = soldier.x[target] - node.x
        local dy = soldier.y[target] - node.y
        keep = (dx * dx + dy * dy) <= structure.range * structure.range
      end

      if not keep then
        -- Nearest, for a tower -- not lowest health. A tower is defending a piece
        -- of ground, and the body about to walk past it is the one that matters,
        -- not the weakest one somewhere in the crowd.
        local best, best_distance = 0, math.huge
        world.targeting.for_each_near(world, node.x, node.y, structure.range,
          function(id)
            if world.targeting.hostile(structure.team, soldier.team[id]) then
              local dx = soldier.x[id] - node.x
              local dy = soldier.y[id] - node.y
              local distance = dx * dx + dy * dy
              if distance < best_distance then
                best, best_distance = id, distance
              end
            end
          end)
        structure.target = best
        structure.target_generation = (best ~= 0) and soldier.generation[best] or 0
        target = best
      end

      if target ~= 0 and structure.cooldown <= 0 then
        world.combat.strike(world, target, structure.damage)
        structure.cooldown = structure.cooldown_max
      end
    end
  end
end
-- }}}

-- {{{ function M.guard_died()
-- One guard is gone. Its tower forgets it; the slot is compacted on the next
-- guard pass rather than searched for here.
function M.guard_died(world, id)
  local tower_id = world.soldier.guard_of[id]
  if tower_id == 0 then
    return
  end
  local structure = world.structure[tower_id]
  for index, guard in ipairs(structure.guard_slot) do
    if guard == id then
      table.remove(structure.guard_slot, index)
      break
    end
  end
end
-- }}}

-- {{{ function M.tower_fell()
-- Three upgrades to the team that knocked it down, and the tower's guards do not
-- survive it.
--
-- Three separate draws, not one worth three times as much. The vision says "three
-- unit upgrades" and the plurality is the point: felling a tower should trigger a
-- burst of placement decisions, which is a burst of teamwork.
--
-- **The lane's slotted upgrades are untouched.** An upgrade is slotted into a
-- lane's stone as a whole, never into one specific tower, so there is nothing in
-- a felled tower to return. The lane's other tower keeps it, and even when both
-- lane towers are gone it keeps firing -- out of the three base towers, which
-- inherit every lane's stone.
function M.tower_fell(world, structure)
  local soldier = world.soldier

  for _, id in ipairs(structure.guard_slot) do
    if id ~= 0 and soldier.alive[id] == 1 then
      soldier.health[id] = 0
      soldier.state[id] = 5   -- dying, reaped on the next tick's reap pass
    end
  end
  structure.guard_slot = {}

  local destroying_team = (structure.team == 1) and 2 or 1
  world.stones.draw(world, destroying_team,
                   world.parameters.structure.reward.tower_felled_draws)
end
-- }}}

-- {{{ function M.begin()
-- Sets every tower's guard timer running and gives each one its first patrol, so
-- that a match does not open with two minutes of empty ground around the stone.
function M.begin(world)
  local interval = world.parameters.structure.tower.guard_interval
  for _, structure in ipairs(world.structure) do
    if structure.kind ~= 3 then
      structure.guard_timer = interval
      for _ = 1, structure.guard_cap do
        put_guard_on_the_ground(world, structure)
      end
    end
  end
end
-- }}}

return M
