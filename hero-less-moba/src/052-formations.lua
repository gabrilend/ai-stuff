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

-- 052-formations.lua
--
-- How a host arranges itself before it fights.
--
-- **The lane decides the path you take toward the enemy. It does not decide how
-- you are arranged when you engage.**
--
-- A host walks its lane in column while there is nothing to fight. When an enemy
-- host comes into view -- and *before* anything is in weapon reach, because the
-- approach is how you engage -- it leaves the path, draws a line through the mass
-- of the enemy, and forms its ranks parallel to that line. Melee in front, ranged
-- behind at their own reach, cavalry behind that to flank whichever of the enemy's
-- flanks is weak.
--
-- Once swords cross, cohesion stops being enforced. The formation was for getting
-- there.
--
-- ## The line is not a new idea
--
-- It is already how a ranged body with nothing to shoot decides which way to
-- orbit: draw a line through the mass of the enemy formation, and a body on the
-- left of it drifts left while one on the right drifts right. This file computes
-- that line **once per host per tick** and hands it to both consumers, because
-- computing it twice in two places, slightly differently, is how those two
-- behaviours would quietly stop agreeing about which way is left.
--
-- ## A host
--
-- One team's non-guard bodies in one lane. Not a wave -- waves overlap, and two
-- waves fighting side by side are one battle line rather than two. Guards are
-- excluded because a guard is not going anywhere; it is standing on a piece of
-- ground it has been told not to leave.

local M = {}

-- How far away an enemy host has to be before this one starts forming up. Wider
-- than any acquisition range on purpose: a body should be standing in its slot
-- before it can hit anything, or the formation is a thing that assembles during
-- the fight, which is not a formation.
local FORM_RANGE = 340

-- How far the front rank stands off from the **near edge** of the enemy's host --
-- not from its centre.
--
-- Measuring from the centre was the first attempt and it was badly wrong in a way
-- worth recording, because it looked reasonable. Both hosts anchor against each
-- other, so if each front rank aims for a point a fixed distance short of the
-- other's *centre of mass*, and the hosts are three hundred paces apart, each
-- front rank's destination is somewhere behind the other host's front rank. The
-- two lines walk straight through one another and the battle becomes a jumble
-- with bodies from both sides on both sides of it.
--
-- Anchored off the near edge instead, the two front ranks stop just short of each
-- other -- close enough to acquire, which is what turns the approach into the
-- engagement.
local ENGAGE_STANDOFF = 26

-- Paces between two ranks, and between two bodies in the same rank.
local RANK_SPACING = 21
local FILE_SPACING = 15

-- How close to its slot a body has to be before it counts as formed up.
local SLOT_TOLERANCE = 9

-- How far back from their nearest body the enemy is still considered part of the
-- group being formed against.
--
-- **"The enemy group" is the cluster you are walking into, not their whole tail.**
-- A host marching down a lane is strung out over hundreds of paces, and a line
-- drawn through all of it runs *along* the lane rather than across it. Form your
-- ranks parallel to that and you have formed a column beside their column, which
-- is geometrically what was asked for and tactically nothing at all.
local CONTACT_SPREAD = 175

-- How far back from the formation's anchor a body can be and still be given a
-- place in it.
--
-- **A host is not everything that shares a lane.** Bodies that have just left the
-- library are hundreds of paces behind the fighting, and giving them a rear-rank
-- slot -- which is only a few ranks back, and therefore right behind the front --
-- would send them beelining across open ground toward it, cutting every corner
-- the lane bends around on the way.
--
-- The lane is the path. A body marches it until it is close enough to deploy, and
-- only then does the arrangement have anything to say about where it stands.
local DEPLOY_RADIUS = 300

-- {{{ local function enemy_line()
-- The centroid of the enemy bodies near a point, and the dominant axis of their
-- positions.
--
-- The axis is the principal component of the two-by-two covariance, and in two
-- dimensions that is a **closed form** rather than an iterative solve: the angle
-- that diagonalises [[sxx, sxy], [sxy, syy]] is half the arctangent of twice the
-- off-diagonal over the difference of the diagonals. Worth saying so, because it
-- looks like the kind of thing somebody would reach for a matrix library to do.
--
-- Returns centroid x, centroid y, axis x, axis y, half-extent along the axis, and
-- the count. Count is zero when there is nothing near.
local function enemy_line(world, x, y, team, radius)
  local soldier = world.soldier

  -- Their nearest body first. It is the anchor of the group -- everything within a
  -- contact spread of it is what this host is about to fight, and everything
  -- behind that is their reinforcements, which are a problem for later and would
  -- drag the line the wrong way if counted now.
  local nearest_id, nearest_distance = 0, math.huge
  world.targeting.for_each_near(world, x, y, radius, function(id)
    if world.targeting.hostile(team, soldier.team[id]) then
      local dx, dy = soldier.x[id] - x, soldier.y[id] - y
      local distance = dx * dx + dy * dy
      if distance < nearest_distance then
        nearest_id, nearest_distance = id, distance
      end
    end
  end)

  if nearest_id == 0 then
    return 0, 0, 0, 0, 0, 0, 0
  end

  local front_x, front_y = soldier.x[nearest_id], soldier.y[nearest_id]

  -- {{{ local function for_each_in_group()
  local function for_each_in_group(visit)
    world.targeting.for_each_near(world, x, y, radius, function(id)
      if world.targeting.hostile(team, soldier.team[id]) then
        local dx, dy = soldier.x[id] - front_x, soldier.y[id] - front_y
        if dx * dx + dy * dy <= CONTACT_SPREAD * CONTACT_SPREAD then
          visit(id)
        end
      end
    end)
  end
  -- }}}

  local sum_x, sum_y, count = 0, 0, 0
  for_each_in_group(function(id)
    sum_x = sum_x + soldier.x[id]
    sum_y = sum_y + soldier.y[id]
    count = count + 1
  end)

  if count == 0 then
    return 0, 0, 0, 0, 0, 0, 0
  end

  local mean_x, mean_y = sum_x / count, sum_y / count

  local sxx, syy, sxy = 0, 0, 0
  for_each_in_group(function(id)
    local dx = soldier.x[id] - mean_x
    local dy = soldier.y[id] - mean_y
    sxx = sxx + dx * dx
    syy = syy + dy * dy
    sxy = sxy + dx * dy
  end)

  -- Which way this host is walking at them. Needed twice below: once as a
  -- fallback when they have no line of their own, and once as a check on the line
  -- they do have.
  local approach_x, approach_y = mean_x - x, mean_y - y
  local approach_length = math.sqrt(approach_x * approach_x + approach_y * approach_y)
  if approach_length > 0.0001 then
    approach_x, approach_y = approach_x / approach_length, approach_y / approach_length
  else
    approach_x, approach_y = 1, 0
  end

  local axis_x, axis_y
  if count == 1 or (sxx == 0 and syy == 0 and sxy == 0) then
    -- A single body, or several standing on exactly the same spot, has no axis of
    -- its own. Rather than leave the direction undefined -- which would make the
    -- formation spin -- the line is taken perpendicular to the approach, which is
    -- what a host walking at one enemy would form anyway.
    axis_x, axis_y = -approach_y, approach_x
  else
    local angle = 0.5 * math.atan2(2 * sxy, sxx - syy)
    axis_x, axis_y = math.cos(angle), math.sin(angle)

    -- **A rank has to face the enemy.** If the line through their mass comes out
    -- more parallel to the approach than across it, they are still in column and
    -- have no front yet -- so there is nothing to form parallel to, and the host
    -- forms across its own line of advance instead.
    --
    -- Without this the two columns reach a stable, useless arrangement: each one
    -- sees a line running away from it, forms alongside, and the battle never
    -- develops a front at all.
    local alignment = axis_x * approach_x + axis_y * approach_y
    if alignment < 0 then alignment = -alignment end
    if alignment > 0.7071 then
      axis_x, axis_y = -approach_y, approach_x
    end
  end

  -- Two measurements of the enemy host, and they answer different questions.
  --
  -- **Extent along the axis** is how wide their line is, which decides how wide
  -- this host's own rank should be -- a rank is as wide as theirs.
  --
  -- **Reach along the perpendicular** is how far their nearest bodies stand out in
  -- front of their centre, which is what the front rank has to stop short of. A
  -- host with a long tail has a centre a long way behind its front, and aiming at
  -- the centre would mean aiming through the front.
  -- How wide their line is, which is how wide this host's rank should be, and how
  -- far their front reaches out ahead of their centre, which is what the front
  -- rank has to stop short of.
  local extent, depth = 0, 0
  for_each_in_group(function(id)
    local dx = soldier.x[id] - mean_x
    local dy = soldier.y[id] - mean_y

    local along = dx * axis_x + dy * axis_y
    if along < 0 then along = -along end
    if along > extent then extent = along end

    -- Measured against the approach, which is the direction that matters: how far
    -- toward us does their group reach.
    local toward_us = -(dx * approach_x + dy * approach_y)
    if toward_us > depth then depth = toward_us end
  end)

  return mean_x, mean_y, axis_x, axis_y, extent, count, depth
end
-- }}}

-- {{{ local function gather_host()
-- One team's non-guard bodies in one lane, and where their leading edge is.
--
-- The leading edge -- the body furthest along the lane in the direction of travel
-- -- is what the enemy search is centred on, not the host's centre of mass. A host
-- strung out down a lane should start forming when its *front* meets something,
-- not when its middle does.
local function gather_host(world, team, lane_id, into)
  local soldier = world.soldier
  local count = 0
  local best_position, lead_x, lead_y = -math.huge, 0, 0

  for id = 1, world.high_water do
    if soldier.alive[id] == 1
       and soldier.team[id] == team
       and soldier.lane[id] == lane_id
       and soldier.flavour[id] ~= 3
       and soldier.state[id] ~= 5 then
      count = count + 1
      into[count] = id
      -- Multiplying by facing folds the two directions into one comparison, so
      -- team 2 walking backwards down the path array leads with its front too.
      local position = (soldier.path_index[id] + soldier.progress[id]) * soldier.facing[id]
      if position > best_position then
        best_position = position
        lead_x, lead_y = soldier.x[id], soldier.y[id]
      end
    end
  end

  for index = count + 1, #into do
    into[index] = nil
  end
  return count, lead_x, lead_y
end
-- }}}

-- {{{ local function assign_slots()
-- Gives every body in the host a place in the arrangement.
--
-- Ranks are lines parallel to the enemy's, stacked back away from it. Melee take
-- the front ranks, ranged the ones behind, and the rank is as wide as the enemy's
-- line rather than as wide as the lane.
--
-- **Bodies are ordered within their role by where they already are along the
-- line.** That is what makes the assignment stable between ticks: a body keeps
-- its left-to-right place and nobody crosses the whole formation to reach a slot.
-- Without it the slots reshuffle every tick and the formation shimmers instead of
-- forming.
local function assign_slots(world, host, count, frame)
  local soldier = world.soldier

  -- Only what is near enough to deploy. Everything further back keeps marching.
  local melee, ranged = {}, {}
  local deployed = 0
  for index = 1, count do
    local id = host[index]
    local dx = soldier.x[id] - frame.anchor_x
    local dy = soldier.y[id] - frame.anchor_y
    if dx * dx + dy * dy <= DEPLOY_RADIUS * DEPLOY_RADIUS then
      deployed = deployed + 1
      if soldier.reach[id] == 2 then
        ranged[#ranged + 1] = id
      else
        melee[#melee + 1] = id
      end
    end
  end

  frame.deployed = deployed
  if deployed == 0 then
    return
  end

  local along_of = {}
  for _, id in ipairs(melee) do
    along_of[id] = (soldier.x[id] - frame.centre_x) * frame.axis_x
                 + (soldier.y[id] - frame.centre_y) * frame.axis_y
  end
  for _, id in ipairs(ranged) do
    along_of[id] = (soldier.x[id] - frame.centre_x) * frame.axis_x
                 + (soldier.y[id] - frame.centre_y) * frame.axis_y
  end

  local function by_position(a, b)
    if along_of[a] == along_of[b] then
      -- A deterministic tiebreak, so that two bodies standing at exactly the same
      -- offset always sort the same way. Sorting by id costs nothing and keeps
      -- the assignment reproducible, which the whole simulation depends on.
      return a < b
    end
    return along_of[a] < along_of[b]
  end
  table.sort(melee, by_position)
  table.sort(ranged, by_position)

  -- How many stand abreast. As wide as theirs, and never narrower than a few, so
  -- that a host walking at a single straggler still forms a line rather than a
  -- column of one.
  local per_rank = math.floor((frame.extent * 2) / FILE_SPACING) + 1
  if per_rank < 3 then per_rank = 3 end
  if per_rank > deployed then per_rank = deployed end

  -- {{{ local function place()
  -- Walks one role into ranks starting at a given depth, and returns the depth
  -- the next role starts at.
  local function place(list, first_rank)
    local rank = first_rank
    local file = 0
    for _, id in ipairs(list) do
      -- Centred on the formation's middle, so the line grows outward from the
      -- axis rather than off to one side of it.
      local offset = (file - (per_rank - 1) * 0.5) * FILE_SPACING
      local back = rank * RANK_SPACING

      soldier.slot_x[id] = frame.anchor_x + frame.axis_x * offset - frame.forward_x * back
      soldier.slot_y[id] = frame.anchor_y + frame.axis_y * offset - frame.forward_y * back
      soldier.slot_live[id] = 1

      file = file + 1
      if file >= per_rank then
        file = 0
        rank = rank + 1
      end
    end
    if file > 0 then
      rank = rank + 1
    end
    return rank
  end
  -- }}}

  local next_rank = place(melee, 0)

  -- Ranged bodies do not queue for the front and never did. They start far enough
  -- back that they are shooting over the melee rather than standing in it -- their
  -- own reach behind the line, expressed in ranks so the two roles use one
  -- arrangement rather than two.
  if #ranged > 0 then
    local stand_off = 1
    if #melee > 0 then
      local reach = soldier.range[ranged[1]]
      stand_off = math.floor(reach * 0.55 / RANK_SPACING)
      if stand_off < 1 then stand_off = 1 end
    end
    place(ranged, next_rank + stand_off)
  end
end
-- }}}

-- {{{ function M.plan()
-- Computes every host's line and slots. One pass, once per tick, before the brain
-- runs.
function M.plan(world)
  local soldier = world.soldier

  -- Clear last tick's slots. A body whose host has lost sight of the enemy must
  -- go back to walking its lane, and a stale slot would hold it standing in a
  -- field waiting for a fight that has moved on.
  for id = 1, world.high_water do
    soldier.slot_live[id] = 0
  end

  local host = world.formation_scratch
  for team = 1, 2 do
    for lane_id = 1, world.parameters.lane_count do
      local count, lead_x, lead_y = gather_host(world, team, lane_id, host)
      local line = world.formation[team][lane_id]
      line.count = count

      if count == 0 then
        line.live = 0
      else
        local centre_x, centre_y, axis_x, axis_y, extent, enemies, depth =
          enemy_line(world, lead_x, lead_y, team, FORM_RANGE)

        if enemies == 0 then
          -- Nothing in sight. March.
          line.live = 0
        else
          -- Forward is perpendicular to the enemy's line, pointing at them.
          local to_x, to_y = centre_x - lead_x, centre_y - lead_y
          local forward_x, forward_y = -axis_y, axis_x
          -- The perpendicular has two directions and only one of them faces the
          -- enemy. Flip it if it points the wrong way.
          if forward_x * to_x + forward_y * to_y < 0 then
            forward_x, forward_y = -forward_x, -forward_y
          end

          line.live = 1
          line.centre_x, line.centre_y = centre_x, centre_y
          line.axis_x, line.axis_y = axis_x, axis_y
          line.forward_x, line.forward_y = forward_x, forward_y
          line.extent = extent
          line.enemies = enemies
          -- Their near edge is their centre pulled back toward us by however far
          -- their host reaches out in front of itself, and the front rank stands a
          -- short step short of that.
          local stand = depth + ENGAGE_STANDOFF
          line.anchor_x = centre_x - forward_x * stand
          line.anchor_y = centre_y - forward_y * stand
          line.depth = depth

          assign_slots(world, host, count, line)
        end
      end
    end
  end
end
-- }}}

-- {{{ function M.step_to_slot()
-- Moves a body toward its formation slot across open ground.
--
-- This is the one place in the game where something moves without reference to
-- the path graph, and it is deliberate: the lane is the path, and this is what
-- happens after a body has stopped taking the path. The graph position underneath
-- is left exactly as it was, so a body that loses its formation rejoins the lane
-- where it left it rather than somewhere it never walked.
--
-- Returns true once the body is standing in its slot.
function M.step_to_slot(world, id)
  local soldier = world.soldier
  local dx = soldier.slot_x[id] - soldier.x[id]
  local dy = soldier.slot_y[id] - soldier.y[id]
  local distance = math.sqrt(dx * dx + dy * dy)

  if distance <= SLOT_TOLERANCE then
    return true
  end

  local speed = soldier.speed[id]
  if speed >= distance then
    soldier.x[id] = soldier.slot_x[id]
    soldier.y[id] = soldier.slot_y[id]
    return true
  end

  soldier.x[id] = soldier.x[id] + dx / distance * speed
  soldier.y[id] = soldier.y[id] + dy / distance * speed
  return false
end
-- }}}

-- {{{ function M.side_of_line()
-- Which side of the enemy's line a body stands on: -1, 0, or +1.
--
-- The second consumer of the line, and the reason it is computed here rather than
-- inside the formation code. A ranged body with nothing to shoot orbits toward the
-- side it is already on, and commits to that direction -- so both sides send their
-- long-reach bodies to the same flanks and they end up facing each other, which is
-- a fight at the shoulders that nobody had to write a rule for.
function M.side_of_line(world, id)
  local soldier = world.soldier
  local line = world.formation[soldier.team[id]][soldier.lane[id]]
  if line == nil or line.live == 0 then
    return 0
  end
  local along = (soldier.x[id] - line.centre_x) * line.axis_x
              + (soldier.y[id] - line.centre_y) * line.axis_y
  if along > 0 then return 1 end
  if along < 0 then return -1 end
  return 0
end
-- }}}

-- {{{ function M.begin()
-- Allocates the per-host records and the scratch list, once.
function M.begin(world)
  world.formation = {}
  for team = 1, 2 do
    world.formation[team] = {}
    for lane = 1, world.parameters.lane_count do
      world.formation[team][lane] = {
        live = 0, count = 0, enemies = 0, deployed = 0, depth = 0,
        centre_x = 0, centre_y = 0,
        axis_x = 1, axis_y = 0,
        forward_x = 0, forward_y = 1,
        anchor_x = 0, anchor_y = 0,
        extent = 0,
      }
    end
  end
  world.formation_scratch = {}
end
-- }}}

M.FORM_RANGE = FORM_RANGE

return M
