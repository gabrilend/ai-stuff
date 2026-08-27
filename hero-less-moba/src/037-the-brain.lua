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

-- 037-the-brain.lua
--
-- What a body is doing, as a dispatch table.
--
-- The state field indexes an array of behaviour functions, one per state, each
-- returning the state the body should be in next tick. There is no chain of
-- conditionals deciding what a soldier is doing -- the soldier already knows, and
-- the table says what knowing that means.
--
-- Having one body type is a design constraint with teeth: anything worth giving
-- a hero has to be expressible as a field on the common record, which keeps this
-- table small enough to actually be good. The alternative -- a separate hero
-- controller -- is how lane-pushers end up with soldiers visibly stupider than
-- heroes, and in a game with no heroes at the centre of it, visibly stupid
-- soldiers are the whole product.

local M = {}

-- {{{ local function distance_to_target()
local function distance_to_target(world, id)
  local soldier = world.soldier
  local target = soldier.target[id]
  local dx = soldier.x[target] - soldier.x[id]
  local dy = soldier.y[target] - soldier.y[id]
  return math.sqrt(dx * dx + dy * dy)
end
-- }}}

-- {{{ local function distance_to_structure()
local function distance_to_structure(world, id)
  local soldier = world.soldier
  local structure = world.structure[soldier.target_structure[id]]
  local node = world.map.node[structure.node]
  local dx = node.x - soldier.x[id]
  local dy = node.y - soldier.y[id]
  return math.sqrt(dx * dx + dy * dy)
end
-- }}}

-- {{{ local function walking()
-- Advance along the lane. If anything hostile came inside acquisition range, the
-- targeting pass has already written it down; act on that.
--
-- Blocked -> hold position this tick, which is what forms the rank.
-- Has a target -> close on it.
-- Otherwise   -> keep walking.
local function walking(world, id)
  local soldier = world.soldier

  -- A guard never forms up. It is not going anywhere -- it is standing on a piece
  -- of ground it has been told not to leave -- so the whole question of how to
  -- arrange for an advance does not arise.
  if soldier.flavour[id] == 3 then
    if not world.frontline.blocked(world, id) then
      world.walking.step(world, id)
    end
    return 1
  end

  -- Forming. The host has drawn a line through the enemy's mass and this body has
  -- a place in the ranks parallel to it. Leave the lane and go and stand in it --
  -- **the approach is how you engage**, so being in position is something that has
  -- to be finished before there is anything to fight.
  if soldier.slot_live[id] == 1 then
    soldier.off_lane[id] = 1
    local dx = soldier.slot_x[id] - soldier.x[id]
    local dy = soldier.slot_y[id] - soldier.y[id]
    local length = math.sqrt(dx * dx + dy * dy)
    local arrived = true
    if length > 0.0001 and not world.frontline.blocked(world, id, dx / length, dy / length) then
      arrived = world.walking.step_free(world, id, soldier.slot_x[id], soldier.slot_y[id], 6)
    end
    -- Keep the graph position sliding along underneath, so push depth still
    -- describes where this body actually is.
    world.walking.reproject(world, id)

    -- **A body holds its place until it is standing in it.** This is the whole of
    -- "the approach is how you engage": a body that broke off to chase the first
    -- enemy that wandered into its acquisition range would never arrive, and the
    -- host would meet the enemy as a crowd of individual duels rather than as a
    -- line. Once it is in position, it fights like anything else.
    if arrived and (soldier.target[id] ~= 0 or soldier.target_structure[id] ~= 0) then
      return 2
    end
    return 1
  end

  if soldier.target[id] ~= 0 or soldier.target_structure[id] ~= 0 then
    return 2   -- closing
  end

  -- The fight ended, or moved on, and there is no slot any more. Walk back onto
  -- the path rather than snapping onto it -- the re-projection has kept the graph
  -- position beside the body, so this is a short walk and not a teleport.
  if soldier.off_lane[id] == 1 then
    local goal_x, goal_y = world.walking.graph_position(world, id)
    if world.walking.step_free(world, id, goal_x, goal_y, 4) then
      soldier.off_lane[id] = 0
    end
    return 1
  end

  if not world.frontline.blocked(world, id) then
    world.walking.step(world, id)
  end
  return 1
end
-- }}}

-- {{{ local function closing()
-- Keep advancing toward the target until it is inside weapon range.
--
-- The target's generation is rechecked every tick. If it died, drop back to
-- walking rather than closing on empty air -- and drop back *this* tick, not
-- next, because an idle tick per kill is invisible one at a time and adds up to
-- a visibly limp frontline.
local function closing(world, id)
  local soldier = world.soldier
  local targeting = world.targeting

  if soldier.target[id] ~= 0 then
    if not targeting.target_is_alive(world, id) then
      soldier.target[id] = 0
      soldier.target_generation[id] = 0
      return 1  -- walking
    end
    if distance_to_target(world, id) <= soldier.range[id] then
      return 3  -- fighting
    end
  elseif soldier.target_structure[id] ~= 0 then
    local structure = world.structure[soldier.target_structure[id]]
    if structure.alive == 0 then
      soldier.target_structure[id] = 0
      return 1
    end
    if distance_to_structure(world, id) <= soldier.range[id] then
      return 3
    end
  else
    return 1
  end

  -- A body that has left the lane closes across open ground. Sending it back
  -- through the graph here would drag it sideways onto the path in the middle of
  -- a charge, which is the one moment it is most obviously wrong.
  if soldier.off_lane[id] == 1 then
    local goal_x, goal_y
    if soldier.target[id] ~= 0 then
      goal_x, goal_y = soldier.x[soldier.target[id]], soldier.y[soldier.target[id]]
    else
      local node = world.map.node[world.structure[soldier.target_structure[id]].node]
      goal_x, goal_y = node.x, node.y
    end
    local dx, dy = goal_x - soldier.x[id], goal_y - soldier.y[id]
    local length = math.sqrt(dx * dx + dy * dy)
    if length > 0.0001 and not world.frontline.blocked(world, id, dx / length, dy / length) then
      world.walking.step_free(world, id, goal_x, goal_y, soldier.range[id] * 0.9)
    end
    world.walking.reproject(world, id)
    return 2
  end

  if not world.frontline.blocked(world, id) then
    world.walking.step(world, id)
  end
  return 2
end
-- }}}

-- {{{ local function fighting()
-- Stop. Swing when the cooldown allows -- which the attack pass does, not this
-- function; all this decides is whether the body is still in a fight.
--
-- If the target died, go straight back to walking on the same tick.
local function fighting(world, id)
  local soldier = world.soldier
  local targeting = world.targeting

  if soldier.target[id] ~= 0 then
    if not targeting.target_is_alive(world, id) then
      soldier.target[id] = 0
      soldier.target_generation[id] = 0
      return 1
    end
    -- Out of range again: the target moved, or this body was pushed off it by a
    -- knockback that does not exist yet. Close again rather than swinging at
    -- nothing.
    if distance_to_target(world, id) > soldier.range[id] then
      return 2
    end
    return 3
  end

  if soldier.target_structure[id] ~= 0 then
    local structure = world.structure[soldier.target_structure[id]]
    if structure.alive == 0 then
      soldier.target_structure[id] = 0
      return 1
    end
    if distance_to_structure(world, id) > soldier.range[id] then
      return 2
    end
    return 3
  end

  return 1
end
-- }}}

-- {{{ local function leashing()
-- Guards only. Walk back toward the leash node, refusing to acquire anything on
-- the way.
--
-- The refusal is the point. A guard that re-acquires while walking home never
-- gets home, and the ground around the tower it was supposed to be denying ends
-- up empty while the guard chases somebody down the lane.
local function leashing(world, id)
  local soldier = world.soldier
  soldier.target[id] = 0
  soldier.target_generation[id] = 0
  soldier.target_structure[id] = 0

  local node = world.map.node
  local here_x, here_y = soldier.x[id], soldier.y[id]
  local leash = node[soldier.leash_node[id]]
  local dx, dy = leash.x - here_x, leash.y - here_y

  -- Home. Go back to wandering; the tower's ground is covered again.
  if dx * dx + dy * dy <= world.parameters.shape.personal_space ^ 2 then
    return 1
  end

  world.walking.step(world, id)
  return 4
end
-- }}}

-- {{{ local function dying()
-- One tick of bookkeeping, done by the reap pass rather than here. A body in
-- this state is already accounted for and is waiting to have its slot freed.
local function dying(world, id)
  return 5
end
-- }}}

-- {{{ local function waiting()
-- A hero bought during the calm, standing at its own library until spawning
-- resumes. It does not advance, does not acquire, and cannot be hurt, because by
-- then the map is empty in both directions.
--
-- This is one of only two states where a body is doing nothing useful, which
-- makes it the only place in the game where a body can have a personality. A
-- waiting hero should meander, idle, and turn to look at the other bodies
-- standing around it. None of that may touch the world; it is the one moment a
-- player watches a body they paid for and nothing is at stake.
--
-- Nothing enters this state yet -- heroes are not built. The row exists so that
-- the table is the whole list of states rather than the list of implemented ones.
local function waiting(world, id)
  return 6
end
-- }}}

-- {{{ local function recovering()
-- A wounded body that has pulled out of the line to mend. It returns to walking
-- when the frontline turns against its team -- the line pulls its wounded out
-- while it is winning and feeds them back in while it is losing, with nobody
-- deciding that centrally.
--
-- The condition is about the health on the ground *around* it, not about its
-- own. Made too eager, this is a body that spends the match walking.
--
-- Not built. The row exists for the same reason `waiting` does.
local function recovering(world, id)
  return 1
end
-- }}}

-- {{{ M.state
-- The dispatch table. Adding a state is adding a row.
M.state = {
  [1] = walking,
  [2] = closing,
  [3] = fighting,
  [4] = leashing,
  [5] = dying,
  [6] = waiting,
  [7] = recovering,
}
-- }}}

-- {{{ function M.run()
-- Advances every living body by one tick of thinking.
function M.run(world)
  local soldier = world.soldier
  for id = 1, world.high_water do
    if soldier.alive[id] == 1 then
      local behaviour = M.state[soldier.state[id]]
      if behaviour == nil then
        error("soldier " .. id .. " is in state " .. tostring(soldier.state[id]) ..
              ", which has no row in the brain's dispatch table")
      end
      soldier.state[id] = behaviour(world, id)
    end
  end
end
-- }}}

return M
