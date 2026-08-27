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

-- 034-walking.lua
--
-- How a body gets from one place to another.
--
-- There is no pathfinding in this game. No A*, no flow field, no per-tick search.
-- A body's position is always "on the edge between node 14 and node 15, 0.62 of
-- the way along," and advancing is: add speed divided by the edge's length to
-- progress; if it passes 1, step to the next node and carry the remainder. With
-- a thousand bodies on the map that difference is the whole frame budget.
--
-- What varies is only **which node comes next**, and that is a dispatch on what
-- the body is doing rather than a branch inside the move loop:
--
--   along a lane   -- read the next entry out of the lane's path array
--   wandering      -- a guard, stepping to a random neighbour inside its leash
--   going home     -- a guard, stepping to whichever neighbour is nearer its tower
--
-- All three are "read one number out of a table." None of them searches.

local M = {}

-- {{{ local function position_of()
-- Writes a body's x and y from the edge it is on. Derived every move pass; the
-- renderer reads these and nothing else does.
local function position_of(world, id)
  local soldier = world.soldier
  local node = world.map.node
  local from = node[soldier.node_from[id]]
  local to   = node[soldier.node_to[id]]
  local u = soldier.progress[id]
  soldier.x[id] = from.x + (to.x - from.x) * u
  soldier.y[id] = from.y + (to.y - from.y) * u
end
-- }}}

M.position_of = position_of

-- {{{ local function edge_length()
-- How long the edge a body is standing on is.
--
-- A body walking a lane reads the precomputed step length; a body walking free
-- of a lane -- a guard on patrol -- has no path index, so its edge is measured.
-- The measurement is the uncommon case: there are at most a couple of dozen
-- guards on the map against hundreds of lane bodies.
local function edge_length(world, id)
  local soldier = world.soldier
  local index = soldier.path_index[id]
  if index > 0 then
    local lane = world.map.lane[soldier.lane[id]]
    local step = index
    if soldier.facing[id] < 0 then
      step = index - 1
    end
    local length = lane.step_length[step]
    if length ~= nil then
      return length
    end
  end
  local node = world.map.node
  local from = node[soldier.node_from[id]]
  local to   = node[soldier.node_to[id]]
  return math.sqrt((to.x - from.x) ^ 2 + (to.y - from.y) ^ 2)
end
-- }}}

-- {{{ local function next_along_lane()
-- The next node for a body following its lane. Returns 0 when the body has
-- reached the far end -- which means it is standing at the enemy library, and
-- there is nowhere further to walk.
local function next_along_lane(world, id)
  local soldier = world.soldier
  local lane = world.map.lane[soldier.lane[id]]
  local index = soldier.path_index[id] + soldier.facing[id]
  if index < 1 or index > #lane.path then
    return 0, index
  end
  return lane.path[index], index
end
-- }}}

-- {{{ local function next_while_wandering()
-- A guard's next step. It picks a neighbour at random from those still inside
-- its leash, using the wander stream.
--
-- Random, and from the *wander* stream specifically, so that changing how guards
-- move can never change which upgrades a team draws. That separation is the
-- whole reason the streams are named.
--
-- A guard is area denial, not a push. It never advances with a wave and never
-- follows a retreating enemy down the lane; it is the reason the ground *around*
-- a tower is dangerous rather than just the tower's own tile.
local function next_while_wandering(world, id)
  local soldier = world.soldier
  local node = world.map.node
  local here = node[soldier.node_from[id]]
  local leash = node[soldier.leash_node[id]]
  local radius = world.parameters.structure.tower.leash_radius

  local candidates = {}
  for _, neighbour_id in ipairs(here.neighbour) do
    local neighbour = node[neighbour_id]
    local dx, dy = neighbour.x - leash.x, neighbour.y - leash.y
    if (dx * dx + dy * dy) <= radius * radius then
      candidates[#candidates + 1] = neighbour_id
    end
  end

  -- Standing on the leash node itself with nowhere inside the radius to go
  -- cannot happen on a built map -- the leash radius is far wider than the node
  -- spacing -- but a guard with no candidates would freeze, so it is checked
  -- and named rather than left as a silent stall.
  if #candidates == 0 then
    error("guard " .. id .. " at node " .. here.id ..
          " has no neighbour inside its leash radius -- the map spacing and the " ..
          "leash radius disagree")
  end

  return candidates[world.stream.wander:next_below(#candidates)]
end
-- }}}

-- {{{ local function next_toward_home()
-- A leashing guard's next step: whichever neighbour is nearer its tower.
--
-- Greedy rather than a path search, which is correct here and would not be in
-- general: a guard is never more than a couple of nodes from its leash and the
-- graph between them is a corridor, so "downhill" always arrives.
local function next_toward_home(world, id)
  local soldier = world.soldier
  local node = world.map.node
  local here = node[soldier.node_from[id]]
  local leash = node[soldier.leash_node[id]]

  local best, best_distance = 0, math.huge
  for _, neighbour_id in ipairs(here.neighbour) do
    local neighbour = node[neighbour_id]
    local dx, dy = neighbour.x - leash.x, neighbour.y - leash.y
    local distance = dx * dx + dy * dy
    if distance < best_distance then
      best, best_distance = neighbour_id, distance
    end
  end
  return best
end
-- }}}

-- {{{ local function next_toward_target()
-- A guard closing on something. It steps to whichever neighbour is nearest its
-- target's position.
--
-- Greedy, like going home, and correct for the same reason: a guard only ever
-- chases inside its own leash radius, and the graph in there is a corridor. A
-- guard that needed a real path search would already have wandered further from
-- its tower than it is allowed to be.
local function next_toward_target(world, id)
  local soldier = world.soldier
  local node = world.map.node
  local here = node[soldier.node_from[id]]

  local target = soldier.target[id]
  local goal_x, goal_y
  if target ~= 0 and soldier.alive[target] == 1 then
    goal_x, goal_y = soldier.x[target], soldier.y[target]
  elseif soldier.target_structure[id] ~= 0 then
    local structure_node = node[world.structure[soldier.target_structure[id]].node]
    goal_x, goal_y = structure_node.x, structure_node.y
  else
    -- Nothing to close on any more. Stand still and let the brain notice next
    -- tick, rather than picking a direction that means nothing.
    return soldier.node_from[id]
  end

  local best, best_distance = 0, math.huge
  for _, neighbour_id in ipairs(here.neighbour) do
    local neighbour = node[neighbour_id]
    local dx, dy = neighbour.x - goal_x, neighbour.y - goal_y
    local distance = dx * dx + dy * dy
    if distance < best_distance then
      best, best_distance = neighbour_id, distance
    end
  end
  return best
end
-- }}}

-- {{{ M.next_node
-- The dispatch. Indexed by how the body is moving, not by what it is.
M.next_node = {
  lane    = next_along_lane,
  wander  = next_while_wandering,
  home    = next_toward_home,
  toward  = next_toward_target,
}
-- }}}

-- {{{ function M.mode_of()
-- Which of the three ways of moving this body is using.
--
-- A guard heading home is leashing; a guard otherwise is wandering; everything
-- else follows its lane. The three cases are named here so that the move pass
-- itself contains no test at all.
function M.mode_of(world, id)
  local soldier = world.soldier
  if soldier.flavour[id] == 3 then
    -- Leashing: walk back to the tower, refusing everything on the way.
    if soldier.state[id] == 4 then
      return "home"
    end
    -- Closing on something inside the leash: approach it rather than wander.
    -- Without this a guard with a target would keep random-walking and would
    -- reach its enemy only by luck, which reads as a guard that cannot see.
    if soldier.state[id] == 2 then
      return "toward"
    end
    return "wander"
  end
  return "lane"
end
-- }}}

-- {{{ function M.step()
-- Advances one body by one tick. Returns true if it crossed at least one node,
-- which the caller uses to know when to re-read milestones.
--
-- The remainder is carried rather than dropped. A fast body on a short edge can
-- cross more than one node in a tick, and truncating at the first would make
-- speed upgrades quietly stop paying above a threshold nobody wrote down.
function M.step(world, id)
  local soldier = world.soldier
  local crossed = false
  local remaining = soldier.speed[id]

  -- Bounded rather than a bare while loop. A body that somehow cannot advance --
  -- a zero-length edge, a corrupt index -- would otherwise spin here forever, and
  -- a frozen frame is a much worse symptom than a body that stops.
  for _ = 1, 8 do
    if remaining <= 0 then
      break
    end
    local length = edge_length(world, id)
    if length <= 0 then
      break
    end

    local advance = remaining / length
    local progress = soldier.progress[id] + advance
    if progress < 1 then
      soldier.progress[id] = progress
      remaining = 0
    else
      -- Arrived. Step across and carry what is left of this tick's movement.
      remaining = (progress - 1) * length
      soldier.node_from[id] = soldier.node_to[id]
      soldier.progress[id] = 0
      crossed = true

      local mode = M.mode_of(world, id)
      local next_id, next_index = M.next_node[mode](world, id)

      if mode == "lane" then
        soldier.path_index[id] = next_index
      end

      if next_id == 0 then
        -- Nowhere left to walk. The body is standing at the enemy library, which
        -- is the end of its lane and the end of the game if it lives long
        -- enough. It stops here and lets targeting find the structure.
        soldier.node_to[id] = soldier.node_from[id]
        soldier.progress[id] = 0
        remaining = 0
      else
        soldier.node_to[id] = next_id
      end
    end
  end

  position_of(world, id)
  return crossed
end
-- }}}

-- {{{ function M.set_lane_position()
-- Writes a body's lane coordinates and derives everything else from them.
--
-- **These two numbers are the truth for a body on a lane** -- how far along it has
-- got, and how far to one side of the centre it stands. Its world position, its
-- path index, and the edge it is nominally on are all read off them.
--
-- Deriving rather than storing is what makes a rank survive a corner. Every body
-- in a rank shares one distance-along, so the lane's own curve carries the whole
-- line round the bend together; nothing has to notice that the outside of the turn
-- is longer, because nothing is measuring the turn.
function M.set_lane_position(world, id, along, across)
  local soldier = world.soldier
  local lane = world.map.lane[soldier.lane[id]]

  if along < 0 then along = 0 end
  if along > lane.length then along = lane.length end

  soldier.lane_along[id] = along
  soldier.lane_across[id] = across

  local x, y, tx, ty, index =
    world.map_builder.point_at(world.map, lane, along, soldier.path_index[id])

  -- The normal is the tangent turned a quarter turn. Derived here and nowhere else,
  -- so there is one definition of which side of a lane is the positive one.
  soldier.x[id] = x - ty * across
  soldier.y[id] = y + tx * across

  soldier.path_index[id] = index
  soldier.node_from[id] = lane.path[index]
  local next_index = index + soldier.facing[id]
  if next_index < 1 or next_index > #lane.path then
    soldier.node_to[id] = lane.path[index]
  else
    soldier.node_to[id] = lane.path[next_index]
  end
  -- Kept roughly current so that anything still reading progress sees something
  -- sensible; nothing on a lane depends on it any more.
  local step = lane.step_length[index]
  if step ~= nil and step > 0 then
    soldier.progress[id] = (along - lane.cumulative[index]) / step
  else
    soldier.progress[id] = 0
  end
end
-- }}}

-- {{{ function M.project_onto_lane()
-- Where a world point falls in a lane's coordinates: how far along, and how far
-- across.
--
-- Used when a body's target is not on its own lane -- a tower guard, mostly. The
-- search is a window around a hint rather than the whole lane, for the same reason
-- everything else here is: a body has not moved far since last tick.
function M.project_onto_lane(world, lane_id, x, y, hint)
  local lane = world.map.lane[lane_id]
  local node = world.map.node

  local first = (hint or 1) - 14
  local last  = (hint or 1) + 14
  if first < 1 then first = 1 end
  if last > #lane.path - 1 then last = #lane.path - 1 end

  local best_along, best_across, best_distance = 0, 0, math.huge
  for index = first, last do
    local a = node[lane.path[index]]
    local b = node[lane.path[index + 1]]
    local step = lane.step_length[index]
    local tx, ty = (b.x - a.x) / step, (b.y - a.y) / step
    local dx, dy = x - a.x, y - a.y

    local along = dx * tx + dy * ty
    if along < 0 then along = 0 end
    if along > step then along = step end

    local px, py = a.x + tx * along, a.y + ty * along
    local distance = (x - px) ^ 2 + (y - py) ^ 2
    if distance < best_distance then
      best_distance = distance
      best_along = lane.cumulative[index] + along
      -- Signed against the normal, so which side is which agrees with
      -- set_lane_position.
      best_across = (x - px) * (-ty) + (y - py) * tx
    end
  end
  return best_along, best_across
end
-- }}}

-- {{{ function M.step_in_formation()
-- Moves a body toward its place in its wave's formation.
--
-- The forward correction carries this tick's cohesion multiplier -- bodies behind
-- their place hurry and bodies in front of it wait, out of one conserved budget.
-- The sideways correction does not, and is slower than walking: sliding back into
-- file costs forward progress, so a wave bent by a turn visibly takes a moment to
-- straighten rather than snapping back into shape.
function M.step_in_formation(world, id)
  local soldier = world.soldier
  local target_along, target_across = world.formations.target_of(world, id)

  local scale = soldier.speed_scale[id]
  if scale <= 0 then scale = 1 end
  local forward = soldier.speed[id] * scale

  local along = soldier.lane_along[id]
  local gap = target_along - along
  if gap > forward then
    along = along + forward
  elseif gap < -forward then
    along = along - forward
  else
    along = target_along
  end

  local lateral = soldier.speed[id] * 0.55
  local across = soldier.lane_across[id]
  local side_gap = target_across - across
  if side_gap > lateral then
    across = across + lateral
  elseif side_gap < -lateral then
    across = across - lateral
  else
    across = target_across
  end

  M.set_lane_position(world, id, along, across)
end
-- }}}

-- {{{ function M.step_toward_point()
-- Moves a body toward a point given in its own lane's coordinates.
--
-- Used when closing on something. Cohesion is not applied: once a body is going
-- for an enemy it has left the formation's business, and *once fighting begins it
-- is less important to retain cohesion.*
function M.step_toward_point(world, id, target_along, target_across)
  local soldier = world.soldier
  local speed = soldier.speed[id]

  local along = soldier.lane_along[id]
  local across = soldier.lane_across[id]
  local dx = target_along - along
  local dy = target_across - across
  local distance = math.sqrt(dx * dx + dy * dy)

  if distance <= speed then
    M.set_lane_position(world, id, target_along, target_across)
    return true
  end

  M.set_lane_position(world, id, along + dx / distance * speed,
                                 across + dy / distance * speed)
  return false
end
-- }}}

-- {{{ function M.begin_crossing()
-- Puts a body onto a connector, heading for the far end.
--
-- The only time anything leaves a lane on purpose. A hero that has obeyed a
-- sign-post walks the connector node by node and joins the lane at the other end --
-- which is the whole of what a sign-post buys: **the ability to move a body into a
-- neighbouring lane, once, with a delay**, the delay being the walk.
function M.begin_crossing(world, id, connector, from_lane)
  local soldier = world.soldier
  soldier.crossing[id] = connector.id
  if connector.lane_a == from_lane then
    soldier.crossing_step[id] = 1
    soldier.crossing_dir[id] = 1
  else
    soldier.crossing_step[id] = #connector.path
    soldier.crossing_dir[id] = -1
  end
  -- Off any lane for the duration. Nothing counts a body on a connector toward a
  -- push, no wave spawns onto one, and no tower covers it.
  soldier.lane[id] = 0
  soldier.turns_left[id] = 0
end
-- }}}

-- {{{ function M.step_crossing()
-- Advances a body along the connector it is on. Returns true once it has arrived
-- and been put back onto a lane.
function M.step_crossing(world, id)
  local soldier = world.soldier
  local connector = world.map.connector[soldier.crossing[id]]
  local direction = soldier.crossing_dir[id]
  local next_step = soldier.crossing_step[id] + direction

  if next_step < 1 or next_step > #connector.path then
    -- Arrived. Join the lane at this end, at the junction it came out at.
    local lane_id = (direction == 1) and connector.lane_b or connector.lane_a
    local lane = world.map.lane[lane_id]
    local junction_index = lane.milestone_index[4]

    soldier.crossing[id] = 0
    soldier.crossing_step[id] = 0
    soldier.crossing_dir[id] = 0
    soldier.lane[id] = lane_id
    soldier.path_index[id] = junction_index
    M.set_lane_position(world, id, lane.cumulative[junction_index], 0)
    return true
  end

  local node = world.map.node[connector.path[next_step]]
  local dx, dy = node.x - soldier.x[id], node.y - soldier.y[id]
  local distance = math.sqrt(dx * dx + dy * dy)
  local speed = soldier.speed[id]

  if distance <= speed then
    soldier.x[id], soldier.y[id] = node.x, node.y
    soldier.crossing_step[id] = next_step
  else
    soldier.x[id] = soldier.x[id] + dx / distance * speed
    soldier.y[id] = soldier.y[id] + dy / distance * speed
  end
  return false
end
-- }}}

-- {{{ function M.place_on_lane()
-- Puts a body onto a lane at a given path index, facing a given direction. The
-- one way a body enters a lane, used by the wave spawner and by hero placement
-- alike, so that there is one definition of what "being in a lane" means.
function M.place_on_lane(world, id, lane_id, path_index, facing, across)
  local soldier = world.soldier
  local lane = world.map.lane[lane_id]

  soldier.lane[id] = lane_id
  soldier.facing[id] = facing
  soldier.path_index[id] = path_index
  M.set_lane_position(world, id, lane.cumulative[path_index], across or 0)
end
-- }}}

-- {{{ function M.place_at_node()
-- Puts a body at a node with no lane -- a guard at its tower. It holds a zero
-- path index for its whole life, which is how everything else knows it is not
-- walking a lane.
function M.place_at_node(world, id, node_id)
  local soldier = world.soldier
  soldier.lane[id] = 0
  soldier.facing[id] = 0
  soldier.path_index[id] = 0
  soldier.node_from[id] = node_id
  soldier.node_to[id] = node_id
  soldier.progress[id] = 0
  position_of(world, id)
end
-- }}}

return M
