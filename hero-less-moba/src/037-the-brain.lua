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
-- Marching. A body holds its place in its wave's formation and the wave carries it
-- down the lane.
--
-- There is no separate "form up" state, because a wave is never not formed up: it
-- leaves the library in its ranks and is battle-ready the whole way. What used to
-- be a deployment is now simply the wave stopping when its front reaches something.
local function walking(world, id)
  local soldier = world.soldier

  -- A guard never marches. It is standing on a piece of ground it has been told
  -- not to leave, so it walks the graph directly and belongs to no formation.
  if soldier.flavour[id] == 3 then
    if soldier.target[id] ~= 0 or soldier.target_structure[id] ~= 0 then
      return 2
    end
    if not world.frontline.blocked(world, id) then
      world.walking.step(world, id)
    end
    return 1
  end

  -- A hero crossing a connector is committed to it: it has already obeyed its one
  -- sign-post and there is nothing on this ground to fight.
  if soldier.crossing[id] ~= 0 then
    world.walking.step_crossing(world, id)
    return 1
  end

  if soldier.target[id] ~= 0 or soldier.target_structure[id] ~= 0 then
    return 2   -- closing
  end

  -- A hero with a turn still in it asks the sign standing at its lane's junction.
  -- Checked before moving, so a hero that would step past the junction this tick
  -- turns at it instead of over it.
  if soldier.turns_left[id] > 0 and world.signposts.check_junction(world, id) then
    return 1
  end

  -- A hero belongs to no wave, so it has no place in a formation to hold. It walks
  -- its lane on its own -- which is also what makes it fragile in a way a wave body
  -- is not, and part of what the purchase is buying.
  if soldier.wave[id] == 0 then
    local lane = world.map.lane[soldier.lane[id]]
    local along = soldier.lane_along[id] + soldier.speed[id] * soldier.facing[id]
    world.walking.set_lane_position(world, id, along, soldier.lane_across[id])
    return 1
  end

  world.walking.step_in_formation(world, id)
  return 1
end
-- }}}

-- {{{ local function target_in_lane_coordinates()
-- Where a body's current target is, in the body's own lane's coordinates.
--
-- Almost always the target is on the same lane and already carries these numbers,
-- which is a pair of array reads. The exception is a tower guard, which has no lane
-- of its own and has to be projected onto this one.
local function target_in_lane_coordinates(world, id)
  local soldier = world.soldier
  local target = soldier.target[id]

  if target ~= 0 then
    if soldier.lane[target] == soldier.lane[id] then
      return soldier.lane_along[target], soldier.lane_across[target]
    end
    return world.walking.project_onto_lane(world, soldier.lane[id],
      soldier.x[target], soldier.y[target], soldier.path_index[id])
  end

  local node = world.map.node[world.structure[soldier.target_structure[id]].node]
  return world.walking.project_onto_lane(world, soldier.lane[id],
    node.x, node.y, soldier.path_index[id])
end
-- }}}

-- {{{ local function closing()
-- Keep advancing toward the target until it is inside weapon range.
--
-- The target's generation is rechecked every tick. If it died, drop back to walking
-- rather than closing on empty air -- and drop back *this* tick, not next, because
-- an idle tick per kill is invisible one at a time and adds up to a visibly limp
-- frontline.
--
-- No cohesion here. A body going for an enemy has left the formation's business:
-- once fighting begins it is less important to retain cohesion, and the approach was
-- what the formation was for.
local function closing(world, id)
  local soldier = world.soldier
  local targeting = world.targeting

  if soldier.target[id] ~= 0 then
    if not targeting.target_is_alive(world, id) then
      soldier.target[id] = 0
      soldier.target_generation[id] = 0
      return 1
    end
    if distance_to_target(world, id) <= soldier.range[id] then
      return 3
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

  -- Guards close across the graph, because they are not on a lane at all.
  if soldier.flavour[id] == 3 then
    if not world.frontline.blocked(world, id) then
      world.walking.step(world, id)
    end
    return 2
  end

  local goal_along, goal_across = target_in_lane_coordinates(world, id)
  if not world.frontline.blocked(world, id) then
    world.walking.step_toward_point(world, id, goal_along, goal_across)
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
