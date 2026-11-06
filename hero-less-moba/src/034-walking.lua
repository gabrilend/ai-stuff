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
-- A body on a road keeps how far along its lane it has got and how far across it
-- stands; everything else keeps a point. Neither ever searches for a route: every
-- route anything could take was decided when the map was built.
--
-- Everything moves the same way, in two layers. A movement pattern places a goal
-- and a pace (072-the-movement-patterns); this file caps the step toward that goal
-- at what the pace allows, moves it out of anybody standing on it, and places the
-- body there through whichever representation its position lives in.
--
-- **A tower guard used to be the exception.** Its position was an edge and a
-- fraction -- "between node 14 and node 15, 0.62 of the way along" -- plus an offset
-- in world paces to stand it clear of whoever else was at the same tower, and it
-- moved by advancing the fraction. Issue 216d made it a point like everything else:
-- the graph is now a thing a guard *consults* about where to aim, not a thing it
-- lives on.

local M = {}

-- {{{ function M.arrived_at_node()
-- Whether a body standing off the graph has got to a node, near enough to count.
--
-- **Near enough, not on it.** A guard aiming at a node can very often never stand on
-- it: a tower is standing there, or a library, or the other guard of the same tower
-- got there first. A body walking at a building is put back onto its face every tick
-- by the rule about standing in masonry, so "within a pace of the centre" is a
-- condition it can never meet -- and a guard waiting to arrive somewhere it cannot
-- arrive is a guard that has stopped patrolling.
--
-- So the node counts as reached from one body's room away, measured from the outside
-- of whatever stone stands on it rather than from its centre. This is also the one
-- definition of "home" for a guard that is walking back to its leash: it used to be a
-- fixed eighteen paces from the leash node, which a base guard -- leashed to a library
-- twenty-one paces in radius -- could not get inside of by any amount of walking.
function M.arrived_at_node(world, id, node_id)
  local soldier = world.soldier
  local node = world.map.node[node_id]
  local room = world.parameters.shape.personal_space

  -- A live building on the node moves the threshold out to its face. Rubble is walked
  -- over, so a fallen tower's node is reached the same way as an empty one.
  local stone = node.structure
  if stone ~= nil and stone ~= 0 then
    local building = world.structure[stone]
    if building ~= nil and building.alive == 1 then
      room = room + building.radius + soldier.radius[id]
    end
  end

  local dx = node.x - soldier.x[id]
  local dy = node.y - soldier.y[id]
  return dx * dx + dy * dy <= room * room
end
-- }}}

-- {{{ function M.round_the_stone()
-- Where to aim instead, when the straight line to a goal runs through a building.
--
-- **Only stone, never bodies.** Bodies move, and whether one is in the way is the step
-- layer's question, asked one pace at a time. A building does not move, and walking at
-- one head-on is a question the step layer *cannot* answer: it puts a body back onto the
-- face along the line from the building's centre, and head-on that line has no sideways
-- in it, so the body is put back exactly where it started and stands there forever. That
-- is H18's stall, and for a body against a body it is open; against a building there is
-- only one sensible answer, which is to walk round it.
--
-- This is what made it matter. A guard that has reached its tower's node -- against the
-- face, on the road -- and picks the neighbour on the far side is standing dead in line
-- with the tower and the place it wants to be. Before guards were points, it was carried
-- through the masonry by the edge it walked; as a point aiming at a point, it stood at the
-- wall for three thousand ticks.
--
-- Asked about the two buildings the step layer itself knows about, on the nodes this body
-- came from and is going to. A body **behind** a building -- on the far side of its centre
-- from the goal -- whose straight line would touch it aims first at the building's side,
-- level with its centre, on whichever side it already is. Once level, the straight line
-- leads away from the centre and any contact slides off.
function M.round_the_stone(world, id, goal_x, goal_y)
  local soldier = world.soldier
  local node = world.map.node
  local x, y = soldier.x[id], soldier.y[id]

  for _, end_id in ipairs({soldier.node_from[id], soldier.node_to[id]}) do
    local here = node[end_id]
    local stone = here ~= nil and here.structure or 0
    if stone ~= nil and stone ~= 0 then
      local building = world.structure[stone]
      if building ~= nil and building.alive == 1 then
        local room = building.radius + soldier.radius[id]

        -- The axis runs from the building's centre toward the goal. A goal at the
        -- building's own centre is the building's own node, which is arrived at from
        -- outside the wall and never walked through.
        local ax, ay = goal_x - here.x, goal_y - here.y
        local reach = math.sqrt(ax * ax + ay * ay)
        if reach > room then
          ax, ay = ax / reach, ay / reach
          local px, py = x - here.x, y - here.y
          local level = px * ax + py * ay        -- along the axis: negative is behind
          local aside = px * (-ay) + py * ax     -- across it, signed

          if level < 0 then
            -- How near the straight line from here to the goal passes the centre: the
            -- segment's closest point, clamped to its ends.
            local sx, sy = goal_x - x, goal_y - y
            local length2 = sx * sx + sy * sy
            local u = 0
            if length2 > 0 then
              u = -(px * sx + py * sy) / length2
              if u < 0 then u = 0 elseif u > 1 then u = 1 end
            end
            local cx, cy = px + sx * u, py + sy * u
            if cx * cx + cy * cy < room * room then
              -- Round on the side it is already on. Dead on the line is a tie with no
              -- side to it; it is broken by the slot number, which is arbitrary and is
              -- the same on every machine, which is all a tie-break here has to be.
              local side = 1
              if aside < 0 or (aside == 0 and id % 2 == 0) then
                side = -1
              end
              local clear = room + world.parameters.shape.personal_space * 0.25
              return here.x + (-ay) * side * clear, here.y + ax * side * clear
            end
          end
        end
      end
    end
  end
  return goal_x, goal_y
end
-- }}}

-- {{{ function M.next_patrol_node()
-- Where a patrolling guard aims next, once it has reached where it was aiming: a
-- neighbour of the node it reached, chosen at random from those still inside its
-- leash, using the wander stream.
--
-- Random, and from the *wander* stream specifically, so that changing how guards
-- move can never change which upgrades a team draws. That separation is the
-- whole reason the streams are named.
--
-- A guard is area denial, not a push. It never advances with a wave and never
-- follows a retreating enemy down the lane; it is the reason the ground *around*
-- a tower is dangerous rather than just the tower's own tile.
--
-- **This used to be one row of four**, in a table that said which node a body
-- stepped to next: along its lane, wandering, going home, closing on a target. The
-- lane row had stopped being read once everything on a road placed goals, and going
-- home and closing on a target aim straight at where they are going now (see the
-- patterns), so this is the one question left that the graph answers. M6 in issue
-- 216d is why it still answers it.
function M.next_patrol_node(world, id)
  local soldier = world.soldier
  local node = world.map.node
  local here = node[soldier.node_from[id]]
  local leash = node[soldier.leash_node[id]]
  local radius = world.structures.leash_radius(world, id)

  local candidates = {}
  for _, neighbour_id in ipairs(here.neighbour) do
    local neighbour = node[neighbour_id]
    local dx, dy = neighbour.x - leash.x, neighbour.y - leash.y
    if (dx * dx + dy * dy) <= radius * radius then
      candidates[#candidates + 1] = neighbour_id
    end
  end

  -- Standing on a node with nowhere inside the radius to go cannot happen on a built
  -- map -- the leash radius is far wider than the node spacing -- but a guard with no
  -- candidates would freeze, so it is checked and named rather than left as a silent
  -- stall.
  if #candidates == 0 then
    error("guard " .. id .. " at node " .. here.id ..
          " has no neighbour inside its leash radius -- the map spacing and the " ..
          "leash radius disagree")
  end

  return candidates[world.stream.wander:next_below(#candidates)]
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

-- {{{ function M.clear_step()
-- The same rule as the frontline's, asked and answered in **lane** coordinates,
-- about the step a body is about to take rather than about where it is headed.
--
-- A body's destination is written as how far along the lane and how far across it;
-- the rule that keeps bodies out of each other is about circles and is written in
-- world coordinates. This converts between them, in both directions, without a
-- search either way.
--
-- Out is exact: the lane's own `point_at` gives the point and the tangent, and the
-- across offset is laid along the normal, which is the tangent turned a quarter turn.
-- That is the same arithmetic `set_lane_position` does and it must stay the same
-- arithmetic, or a waypoint would be checked at a different place from the one the
-- body would actually stand.
--
-- Back is a **local** conversion rather than a projection: the correction is a small
-- world-space nudge, so it is resolved against the tangent and the normal at the
-- waypoint and added to the lane coordinates we already had. A body is never moved
-- more than a body's width by this, and over that distance a lane is straight. The
-- alternative -- projecting the corrected point back onto the lane -- is a
-- twenty-nine step search per body per tick for an answer that agrees to five
-- figures.
function M.clear_step(world, id, delta_along, delta_across)
  local soldier = world.soldier
  local lane = world.map.lane[soldier.lane[id]]
  if lane == nil then
    return delta_along, delta_across
  end

  local along = soldier.lane_along[id] + delta_along
  local across = soldier.lane_across[id] + delta_across

  local x, y, tx, ty = world.map_builder.point_at(world.map, lane, along,
                                                  soldier.path_index[id])
  local want_x = x - ty * across
  local want_y = y + tx * across

  local got_x, got_y = world.frontline.clear_of_bodies(world, id, want_x, want_y)
  if got_x == want_x and got_y == want_y then
    return delta_along, delta_across
  end

  local dx, dy = got_x - want_x, got_y - want_y
  return delta_along + dx * tx + dy * ty,
         delta_across + dx * (-ty) + dy * tx
end
-- }}}

-- {{{ function M.move_limited()
-- Moves a body by a lane-space step, but **no faster than its speed in the world.**
--
-- This is the correction for the one thing lane coordinates get wrong, and the
-- error was invisible until somebody asked for it to be measured. Holding a
-- formation in lane coordinates makes a turn free: every body in a rank shares one
-- distance-along, so going round a bend costs each of them the same number, and
-- their world positions simply follow the curve. But the body on the **outside** of
-- that bend has further to walk in the world, and nothing was telling it so -- it
-- was covering that extra ground for nothing, moving faster than its own speed,
-- silently.
--
-- So the step is measured after it is taken and scaled back if it was too far. The
-- outer body then genuinely falls behind its place, the inner one gets ahead, and
-- **the cohesion budget does the rest**: whoever is behind hurries, taken from
-- whoever is in front. Turning left, the left of the line slows and the right
-- hurries, which is what keeps it a line.
--
-- Three passes rather than a solve. Displacement is monotonic in the fraction, the
-- first correction is nearly exact, and a fixed pass count keeps the cost the same
-- every tick -- which a search would not.
function M.move_limited(world, id, delta_along, delta_across, allowance)
  local soldier = world.soldier
  local from_x, from_y = soldier.x[id], soldier.y[id]
  local along = soldier.lane_along[id]
  local across = soldier.lane_across[id]

  local fraction = 1
  for _ = 1, 3 do
    M.set_lane_position(world, id, along + delta_along * fraction,
                                   across + delta_across * fraction)
    local dx = soldier.x[id] - from_x
    local dy = soldier.y[id] - from_y
    local moved = math.sqrt(dx * dx + dy * dy)
    if moved <= allowance or moved < 0.000001 then
      return moved
    end
    fraction = fraction * (allowance / moved)
  end
  return allowance
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

  local gap = target_along - soldier.lane_along[id]
  if gap > forward then
    gap = forward
  elseif gap < -forward then
    gap = -forward
  end

  local lateral = soldier.speed[id] * 0.55
  local side_gap = target_across - soldier.lane_across[id]
  if side_gap > lateral then
    side_gap = lateral
  elseif side_gap < -lateral then
    side_gap = -lateral
  end

  -- **Checked where this step lands, not where the slot is.** The place a formation
  -- has for a body can be ninety paces away; whether somebody is standing there is a
  -- question about the future and not about this tick. What the body is about to walk
  -- into is the ground one step ahead of it, so that is the point the rule is asked
  -- about -- and asking about the slot instead moved bodies off their places for
  -- obstacles they were nowhere near, which is how a formation stops dressing.
  gap, side_gap = M.clear_step(world, id, gap, side_gap)

  -- The allowance is the body's own speed with this tick's cohesion multiplier on
  -- it, and it is a limit **in the world**, not along the lane. A body on the
  -- outside of a bend cannot buy extra ground by being offset.
  M.move_limited(world, id, gap, side_gap, forward)
end
-- }}}

-- {{{ function M.nudge()
-- Move a body a small distance in **world** coordinates, writing the change through
-- whichever representation that body's position actually lives in.
--
-- This exists because a body's world position is usually not where its position is
-- kept. For anything on a road the truth is two numbers -- how far along the lane and
-- how far across it -- and `x` and `y` are derived from them every time they are set.
-- Writing a correction straight into `x` and `y` therefore lasts exactly until the next
-- time the body moves, which is one tick, which looks from outside like a rule that
-- fires and does nothing.
--
-- So: for a body on a lane, the world-space nudge is resolved against the tangent and
-- the normal where it stands and added to its lane coordinates. That is a **local**
-- conversion rather than a projection, and it is sound for the same reason the same
-- conversion in `clear_step` is sound -- a nudge is at most about a body's width, and
-- over that distance a lane is straight.
--
-- For a body with no lane -- a guard, or a hero partway across a connector -- the truth
-- is the world position itself, so the nudge is simply added to it.
function M.nudge(world, id, dx, dy)
  local soldier = world.soldier
  local lane = world.map.lane[soldier.lane[id]]

  -- No lane: a guard, or a hero partway across a connector. Its x and y *are* where it
  -- is, so the nudge is written straight into them and nothing will re-derive it away.
  if lane == nil then
    soldier.x[id] = soldier.x[id] + dx
    soldier.y[id] = soldier.y[id] + dy
    return
  end

  local _, _, tx, ty = world.map_builder.point_at(world.map, lane,
                                                  soldier.lane_along[id],
                                                  soldier.path_index[id])
  -- The normal is the tangent turned a quarter turn, the same quarter turn
  -- `set_lane_position` uses. Two different ideas of which way is across a lane would
  -- put a body on the wrong side of the road.
  M.set_lane_position(world, id,
                      soldier.lane_along[id] + dx * tx + dy * ty,
                      soldier.lane_across[id] + dx * (-ty) + dy * tx)
end
-- }}}

-- {{{ function M.place_at()
-- Put a body on a world point, through whichever representation its position lives in.
--
-- **This is the one conversion.** A body on a road keeps how far along its lane it has got
-- and how far across it stands, and its world position is derived from those; anything
-- with no lane keeps its world position and nothing else. Every rule that ever wanted to
-- move a body used to have to know which kind it was holding -- a guard was a third kind
-- once, an edge and a fraction and an offset -- and two of them got it wrong, writing a
-- world position into a lane body, watching the next move pass re-derive it, and achieving
-- nothing while firing every tick.
function M.place_at(world, id, x, y)
  local soldier = world.soldier
  M.nudge(world, id, x - soldier.x[id], y - soldier.y[id])
end
-- }}}

-- {{{ function M.aim()
-- Write down where a body wants to be, and how urgently.
--
-- The upper of the two layers, and the only thing a movement pattern is allowed to do. A
-- goal may be a very long way off -- a formation's place for a body can be ninety paces
-- away, an enemy can be across the lane -- and a pattern may not look at whether anything
-- is standing between here and there. That is the layer below's question, and keeping the
-- two apart is the whole reason there are two.
function M.aim(world, id, x, y, pace)
  local soldier = world.soldier
  soldier.goal_x[id] = x
  soldier.goal_y[id] = y
  soldier.goal_pace[id] = pace
end
-- }}}

-- {{{ function M.aim_on_lane()
-- The same, for a goal that is natural to say in lane coordinates.
--
-- **A marching body's goal has to be computed this way and converted at the end**, not
-- computed directly in world coordinates. Holding a formation in lane coordinates is what
-- makes a rank curve round a bend as a rank: every body in it shares one distance-along,
-- so the lane's own curve carries the whole line round together. That property belongs to
-- how the goal is worked out, not to how it is stored, so storing it in world coordinates
-- costs nothing -- but working it out in world coordinates would cost everything.
function M.aim_on_lane(world, id, along, across, pace)
  local soldier = world.soldier
  local lane = world.map.lane[soldier.lane[id]]
  local x, y, tx, ty = world.map_builder.point_at(world.map, lane, along,
                                                  soldier.path_index[id])
  -- The normal is the tangent turned a quarter turn, the same quarter turn
  -- `set_lane_position` uses. Two different ideas of which way is across a lane would put
  -- a body on the wrong side of the road.
  M.aim(world, id, x - ty * across, y + tx * across, pace)
end
-- }}}

-- {{{ function M.take_step()
-- Move a body one tick toward its goal: cap, clear, place.
--
-- **The lower of the two layers, and the only one that knows other bodies exist.**
--
-- *Cap.* The step starts at the goal and is pulled back along the line to the body until
-- it is no further off than this pace allows, measured **in the world**. That last word is
-- the whole of a correction this replaces: holding a formation in lane coordinates makes a
-- turn free, so a body on the outside of a bend was covering more ground than its speed
-- allowed, and the old arrangement caught it afterwards by measuring what it had done and
-- rolling it back over three passes. Capping a world point at a world distance means the
-- extra ground is never taken, so there is nothing to roll back -- the outer body simply
-- falls behind its place, honestly, and the gears deal with it.
--
-- *Clear.* The capped step is asked whether anything is standing on it, and moved out if
-- so. Asked about **the step and not the goal**, which is the existing rule and the
-- existing reason for it: the place a formation has for a body can be ninety paces away
-- and whether somebody is standing there is a question about the future.
--
-- *Place.* Onto the cleared point, through the one conversion.
function M.take_step(world, id)
  local soldier = world.soldier

  local pace = soldier.goal_pace[id]
  local multiplier = world.parameters.unit.pace_multiplier[pace]
  if multiplier == nil then
    -- A body being stepped without a pace is a body whose pattern did not finish. Raised
    -- rather than defaulted, because a default here is a body moving at a speed nobody
    -- chose, which is exactly the class of thing that gets measured and believed.
    error("body " .. id .. " was asked to step with no pace set")
  end
  local allowance = soldier.speed[id] * multiplier

  local dx = soldier.goal_x[id] - soldier.x[id]
  local dy = soldier.goal_y[id] - soldier.y[id]
  local distance = math.sqrt(dx * dx + dy * dy)

  local want_x, want_y
  if distance <= allowance or distance < 0.000001 then
    want_x, want_y = soldier.goal_x[id], soldier.goal_y[id]
  else
    want_x = soldier.x[id] + dx / distance * allowance
    want_y = soldier.y[id] + dy / distance * allowance
  end

  -- Sets `gave_way` as a side effect, which is what the window rings in red.
  local step_x, step_y = world.frontline.clear_of_bodies(world, id, want_x, want_y)
  soldier.step_x[id] = step_x
  soldier.step_y[id] = step_y

  M.place_at(world, id, step_x, step_y)
end
-- }}}

-- {{{ function M.march_pass()
-- Every body that belongs to a formation takes one step toward its place.
--
-- **This is here rather than in whatever is doing the marching.** The loop is three
-- lines and looks like the kind of thing a caller can be trusted to write, and it was
-- written out by hand in the arena for exactly that reason -- which left the project
-- holding two descriptions of what a marching tick is, one of them the game's and one
-- of them a test harness's. When they disagree, the test is measuring the harness.
--
-- A body with no wave is a **stray**: nothing is keeping it in a line and nothing comes
-- to collect it, so it stands where it was put. That is not an omission -- a stray is
-- the thing an army has to get past, and it has to be able to stand still to be one.
function M.march_pass(world)
  local soldier = world.soldier
  for id = 1, world.high_water do
    if soldier.alive[id] == 1 and soldier.wave[id] ~= 0 then
      -- Through the same two layers the game uses. A pass that stepped bodies its own way
      -- would be a second description of what marching is, which is the mistake this whole
      -- arrangement was built to stop making.
      world.patterns.choose(world, id)
      M.take_step(world, id)
    end
  end
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


  local dx = target_along - soldier.lane_along[id]
  local dy = target_across - soldier.lane_across[id]
  local distance = math.sqrt(dx * dx + dy * dy)

  -- Closing on an enemy is walking at a body, so the ground being walked onto is
  -- inside one the moment the body gets there. What the rule moves it to is the near
  -- face of him, which is where somebody who has run up to somebody stands.
  local step_along, step_across
  if distance <= speed then
    step_along, step_across = dx, dy
  else
    step_along, step_across = dx / distance * speed, dy / distance * speed
  end
  step_along, step_across = M.clear_step(world, id, step_along, step_across)

  if distance <= speed then
    M.set_lane_position(world, id, soldier.lane_along[id] + step_along,
                                   soldier.lane_across[id] + step_across)
    return true
  end

  M.move_limited(world, id, step_along, step_across, speed)
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
-- Puts a body beside a node with no lane -- a guard at its tower. It holds a zero
-- path index for its whole life, which is how everything else knows it is not
-- walking a lane.
--
-- The node is where it last was and where it is aiming, both, so that its first
-- patrol step asks the graph from here. Where it actually *stands* is the node plus
-- the displacement given -- written once into its position, which is the truth from
-- then on.
--
-- A node is a point, and a point holds one body. Whoever is putting a second one
-- there has to say where beside it, or they are asking for two bodies in the same
-- place -- which the rule about bodies not overlapping cannot undo afterwards,
-- because there is no direction to push them apart along.
function M.place_at_node(world, id, node_id, beside_x, beside_y)
  local soldier = world.soldier
  local node = world.map.node[node_id]
  soldier.lane[id] = 0
  soldier.facing[id] = 0
  soldier.path_index[id] = 0
  soldier.node_from[id] = node_id
  soldier.node_to[id] = node_id
  soldier.progress[id] = 0
  soldier.x[id] = node.x + (beside_x or 0)
  soldier.y[id] = node.y + (beside_y or 0)
end
-- }}}

return M
