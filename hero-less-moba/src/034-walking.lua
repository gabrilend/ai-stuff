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

-- {{{ function M.graph_position()
-- Where on the path graph a body currently belongs, regardless of where its body
-- actually is. A body off the lane keeps this current; it is the place it rejoins.
function M.graph_position(world, id)
  local soldier = world.soldier
  local node = world.map.node
  local from = node[soldier.node_from[id]]
  local to   = node[soldier.node_to[id]]
  local u = soldier.progress[id]
  return from.x + (to.x - from.x) * u, from.y + (to.y - from.y) * u
end
-- }}}

-- {{{ function M.step_free()
-- Moves a body toward a point across open ground, ignoring the graph entirely.
--
-- The one kind of movement in this game that is not "read the next node out of an
-- array", and it exists for one reason: a host arranges itself against the enemy
-- rather than against the corridor it walked down, so a body forming up is walking
-- to a place the graph has no opinion about.
--
-- Returns true once it has arrived.
function M.step_free(world, id, goal_x, goal_y, tolerance)
  local soldier = world.soldier
  local dx, dy = goal_x - soldier.x[id], goal_y - soldier.y[id]
  local distance = math.sqrt(dx * dx + dy * dy)

  if distance <= tolerance then
    return true
  end

  local speed = soldier.speed[id]
  if speed >= distance then
    soldier.x[id], soldier.y[id] = goal_x, goal_y
    return true
  end

  soldier.x[id] = soldier.x[id] + dx / distance * speed
  soldier.y[id] = soldier.y[id] + dy / distance * speed
  return false
end
-- }}}

-- {{{ function M.reproject()
-- Slides a body's graph position along its lane to whichever point is nearest to
-- where the body has actually got to.
--
-- Without this, a body that leaves the lane to form up freezes its path index, and
-- push depth -- which is measured in path indices -- stops describing the world. A
-- host could fight its way to the enemy base and the lane would still report the
-- milestone it was standing on when it deployed.
--
-- Searched in a window around the current index rather than along the whole lane.
-- A body cannot have moved far since last tick, and scanning a hundred nodes per
-- body per tick to find that out would cost more than everything else in the move
-- pass put together.
function M.reproject(world, id)
  local soldier = world.soldier
  local lane = world.map.lane[soldier.lane[id]]
  if lane == nil then
    return
  end

  local here = soldier.path_index[id]
  local first = here - 12
  local last  = here + 12
  if first < 1 then first = 1 end
  if last > #lane.path then last = #lane.path end

  local best, best_distance = here, math.huge
  for index = first, last do
    local node = world.map.node[lane.path[index]]
    local dx, dy = node.x - soldier.x[id], node.y - soldier.y[id]
    local distance = dx * dx + dy * dy
    if distance < best_distance then
      best, best_distance = index, distance
    end
  end

  soldier.path_index[id] = best
  soldier.progress[id] = 0
  soldier.node_from[id] = lane.path[best]
  local next_index = best + soldier.facing[id]
  if next_index < 1 or next_index > #lane.path then
    soldier.node_to[id] = lane.path[best]
  else
    soldier.node_to[id] = lane.path[next_index]
  end
end
-- }}}

-- {{{ function M.place_on_lane()
-- Puts a body onto a lane at a given path index, facing a given direction. The
-- one way a body enters a lane, used by the wave spawner and by hero placement
-- alike, so that there is one definition of what "being in a lane" means.
function M.place_on_lane(world, id, lane_id, path_index, facing)
  local soldier = world.soldier
  local lane = world.map.lane[lane_id]

  soldier.lane[id] = lane_id
  soldier.facing[id] = facing
  soldier.path_index[id] = path_index
  soldier.node_from[id] = lane.path[path_index]

  local next_index = path_index + facing
  if next_index < 1 or next_index > #lane.path then
    soldier.node_to[id] = soldier.node_from[id]
  else
    soldier.node_to[id] = lane.path[next_index]
  end
  soldier.progress[id] = 0
  position_of(world, id)
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
