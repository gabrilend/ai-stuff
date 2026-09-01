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

-- 035-targeting.lua
--
-- What a body decides to hit, and the grid that makes deciding affordable.
--
-- The ranking, cheapest test first:
--
--   1. an enemy soldier already attacking me
--   2. the lowest-health enemy soldier within acquisition range
--   3. an enemy structure within weapon range
--   4. nothing -- keep walking
--
-- **Lowest health, not nearest**, and it is the most consequential line in the
-- file. A rank that spreads its damage across everything in front of it kills
-- nothing and dies anyway; a rank that concentrates removes an enemy from the
-- fight and lowers the incoming damage for everybody behind it. Focus is how a
-- smaller force beats a larger one, and this design gives a player no way to
-- arrange it by hand -- so the brain has to do it.
--
-- Structures rank below soldiers deliberately. A soldier that walks past a
-- defended tower to chew on the tower is a soldier that dies for free, and a
-- frontline made of those never moves.
--
-- ## The grid
--
-- Every body asking every other body how far away it is would be a million
-- distance checks a tick at the scale this game runs at. Instead the map is cut
-- into square cells one acquisition range across, every living body is dropped
-- into its cell once per tick, and a query reads the nine cells around it.
--
-- Rebuilt from scratch every tick rather than maintained incrementally. A grid
-- that is updated as bodies move is a grid that is wrong the first time somebody
-- forgets to update it, and being wrong looks like soldiers ignoring an enemy
-- standing next to them -- which is the hardest possible bug to attribute.

local M = {}

-- How wide a body stands as an obstacle to a straight shot, as a fraction of the room
-- it keeps around itself.
--
-- About a body's own drawn size rather than the whole of its personal space: that
-- space is how much room a soldier *wants*, not how much of one there is, and a shot
-- passing between two of them standing comfortably apart should get through.
--
-- Measured over nine thousand ticks, with flat arrows needing a line:
--
--   width   kills   left standing
--   8.1       759     506
--   5.4       696     476
--   3.6       827     433
--   2.2       835     430
--
-- Which is the useful shape of the answer: **the width is not the lever.** Halving it
-- recovers a tenth of the damage and the pile-up stays. See the note in the unit
-- catalogue about what actually decides this.
local BLOCKS_THE_VIEW = 0.20

-- How many ticks a body whose shot was blocked waits before looking again.
--
-- Small enough to be imperceptible -- an eighth of a second -- and it is most of the
-- cost of having line of sight at all. A body standing behind an unbroken rank is
-- blocked on every tick of its life, so without this it pays for a grid query on
-- every one of them, and one match went from twenty-eight seconds to five minutes.
local BLOCKED_PATIENCE = 4

-- {{{ local function cell_index()
-- The cell a position falls in, as a single integer, so the grid is one flat
-- table rather than a table of tables of tables.
local function cell_index(grid, x, y)
  local column = math.floor((x - grid.min_x) / grid.cell) 
  local row    = math.floor((y - grid.min_y) / grid.cell)
  if column < 0 then column = 0 end
  if row < 0 then row = 0 end
  if column >= grid.columns then column = grid.columns - 1 end
  if row >= grid.rows then row = grid.rows - 1 end
  return row * grid.columns + column + 1
end
-- }}}

-- {{{ function M.make_grid()
-- Allocates the grid once, at world creation. The cell size is the widest
-- acquisition range any body has, so that a query never has to look further than
-- the ring of cells immediately around it.
function M.make_grid(world)
  local bounds = world.map.bounds
  local widest = 0
  for _, row in ipairs(world.parameters.unit.archetype) do
    if row.acquire_range > widest then
      widest = row.acquire_range
    end
  end
  -- Towers reach further than any body does, and they query this grid too.
  local tower_range = world.parameters.structure.tower.range
  if tower_range > widest then
    widest = tower_range
  end

  local margin = widest
  local grid = {
    cell  = widest,
    min_x = bounds.min_x - margin,
    min_y = bounds.min_y - margin,
  }
  grid.columns = math.ceil((bounds.max_x - bounds.min_x + margin * 2) / grid.cell) + 1
  grid.rows    = math.ceil((bounds.max_y - bounds.min_y + margin * 2) / grid.cell) + 1
  grid.bucket  = {}
  for index = 1, grid.columns * grid.rows do
    grid.bucket[index] = {}
  end
  return grid
end
-- }}}

-- {{{ function M.rebuild_grid()
-- Empties every bucket and drops every living body back in.
--
-- The buckets are truncated rather than replaced, so that a match allocates its
-- grid once and then never allocates for it again. Replacing them would produce
-- a few thousand short-lived tables a second, which is the kind of garbage that
-- turns a smooth frame rate into a periodic hitch.
function M.rebuild_grid(world)
  local grid = world.grid
  for index = 1, #grid.bucket do
    local bucket = grid.bucket[index]
    for slot = #bucket, 1, -1 do
      bucket[slot] = nil
    end
  end

  local soldier = world.soldier
  for id = 1, world.high_water do
    if soldier.alive[id] == 1 then
      local index = cell_index(grid, soldier.x[id], soldier.y[id])
      local bucket = grid.bucket[index]
      bucket[#bucket + 1] = id
    end
  end
end
-- }}}

-- {{{ function M.for_each_near()
-- Calls visit(id) for every living body within `radius` of a point.
--
-- The ring of cells searched is sized from the radius asked for rather than
-- fixed at three by three. That matters because a body's acquisition range is
-- not a constant: a Longbow adds to it, Longbows stack, and a body carrying two
-- of them reaches further than the cell size the grid was built around.
--
-- The first version of this took the three-by-three ring and refused any radius
-- wider than one cell. The refusal was right to exist -- a silent miss would have
-- read as soldiers ignoring an enemy standing next to them, which is close to
-- unattributable -- but refusing was the wrong answer to a question the upgrade
-- table is entitled to ask. Widening the ring costs one ceiling division and
-- removes the ceiling on the upgrade instead.
function M.for_each_near(world, x, y, radius, visit)
  local grid = world.grid
  local span = math.ceil(radius / grid.cell)
  if span < 1 then
    span = 1
  end

  local column = math.floor((x - grid.min_x) / grid.cell)
  local row    = math.floor((y - grid.min_y) / grid.cell)
  local soldier = world.soldier
  local radius_squared = radius * radius

  for r = row - span, row + span do
    if r >= 0 and r < grid.rows then
      for c = column - span, column + span do
        if c >= 0 and c < grid.columns then
          local bucket = grid.bucket[r * grid.columns + c + 1]
          for index = 1, #bucket do
            local id = bucket[index]
            local dx = soldier.x[id] - x
            local dy = soldier.y[id] - y
            if dx * dx + dy * dy <= radius_squared then
              visit(id)
            end
          end
        end
      end
    end
  end
end
-- }}}

-- {{{ function M.can_see()
-- Whether this body has a clear line to that one, with **its own allies** as the
-- only blockers.
--
-- Not a general visibility rule and not fog of war. Nothing in this game is hidden;
-- what this answers is whether a straight thing thrown from here would arrive, and
-- the only things in the way are the people on your own side. An enemy between you
-- and your target is not an obstacle -- it is a closer target, and something else has
-- already had that thought.
--
-- **This is why the frontline is a targeting constraint.** A body standing behind a
-- solid rank of its own has no line through it; a body that has a line is standing
-- somewhere with a hole in front of it. Which gives a player something to read off
-- the field: a druid throwing moons is a druid whose line has gaps in it.
--
-- Arrows are not subject to it. An arrow arcs, and a body with a bow standing behind
-- its own line is doing the thing bows are for. What this gates is the flat, straight
-- things -- see the moon spike in the abilities table.
--
-- One grid query, about the midpoint, with a radius that covers the whole segment.
-- Then a perpendicular distance per candidate, which is two multiplies. Cheaper than
-- walking the line in steps and exact rather than sampled.
function M.can_see(world, id, target)
  local soldier = world.soldier
  local ax, ay = soldier.x[id], soldier.y[id]
  local bx, by = soldier.x[target], soldier.y[target]
  local dx, dy = bx - ax, by - ay
  local length = math.sqrt(dx * dx + dy * dy)
  if length < 0.0001 then
    return true
  end

  local width = world.parameters.shape.personal_space * BLOCKS_THE_VIEW
  local blocked = false
  M.for_each_near(world, (ax + bx) * 0.5, (ay + by) * 0.5,
                  length * 0.5 + width, function(other)
    if blocked or other == id or other == target then
      return
    end
    if soldier.alive[other] ~= 1 or soldier.team[other] ~= soldier.team[id] then
      return
    end
    -- How far along the line the blocker sits, and how far off it. Outside the
    -- segment is beside us or behind us, and neither is in the way.
    local px, py = soldier.x[other] - ax, soldier.y[other] - ay
    local along = (px * dx + py * dy) / length
    if along <= 0 or along >= length then
      return
    end
    local across = px * (dy / length) - py * (dx / length)
    if across < 0 then across = -across end
    if across < width then
      blocked = true
    end
  end)

  return not blocked
end
-- }}}

-- {{{ function M.hostile()
-- Whether two teams are enemies.
--
-- Team 3 is the monsters', which is allied with nobody and hostile to
-- everything, including other monsters' -- which is why this is a function and
-- not a comparison written inline in four places.
function M.hostile(a, b)
  if a == 0 or b == 0 then
    return false
  end
  return a ~= b
end
-- }}}

-- {{{ local function lowest_health_enemy()
-- Rule 2. Returns the id of the weakest enemy in range, or 0.
--
-- Exact ties are broken by the tie stream using reservoir sampling: the nth
-- equally-good candidate replaces the incumbent with probability 1/n. That gives
-- a uniform choice among the tied while advancing the stream a fixed number of
-- times, which keeps a replay reproducible.
local function lowest_health_enemy(world, id, must_see)
  local soldier = world.soldier
  local team = soldier.team[id]
  local best, best_health, ties = 0, math.huge, 0

  M.for_each_near(world, soldier.x[id], soldier.y[id], soldier.acquire_range[id],
    function(other)
      if M.hostile(team, soldier.team[other])
         and (not must_see or M.can_see(world, id, other)) then
        local health = soldier.health[other]
        if health < best_health then
          best, best_health, ties = other, health, 1
        elseif health == best_health then
          ties = ties + 1
          if world.stream.tie[team]:next_below(ties) == 1 then
            best = other
          end
        end
      end
    end)

  return best
end
-- }}}

-- {{{ local function enemy_structure_in_reach()
-- Rule 3. The nearest living enemy structure within this body's weapon range.
--
-- Only this lane's stone and the two libraries are considered, which is eight
-- records rather than twenty. A body in a lane cannot reach another lane's
-- tower, and checking anyway would be work spent to reach the same answer.
local function enemy_structure_in_reach(world, id)
  local soldier = world.soldier
  local team = soldier.team[id]
  local x, y = soldier.x[id], soldier.y[id]
  local reach = soldier.range[id]
  local best, best_distance = 0, math.huge

  for _, structure in ipairs(world.structure) do
    if structure.alive == 1 and M.hostile(team, structure.team) then
      local node = world.map.node[structure.node]
      local dx, dy = node.x - x, node.y - y
      local distance = dx * dx + dy * dy
      if distance <= reach * reach and distance < best_distance then
        best, best_distance = structure.id, distance
      end
    end
  end
  return best
end
-- }}}

-- {{{ function M.choose()
-- The whole ranking, for one body. Writes target, target_generation and
-- target_structure, and leaves all three at zero when there is nothing to hit.
function M.choose(world, id)
  local soldier = world.soldier

  -- A body whose last look was blocked by its own rank waits a moment before looking
  -- again. The line in front of it is still there; asking every tick is asking the
  -- same question of the same people, and the asking is a grid query.
  if soldier.search_pause[id] > 0 then
    soldier.search_pause[id] = soldier.search_pause[id] - 1
    return
  end

  -- Rule 1 -- somebody is already swinging at me. Cheapest of all, because it is
  -- a single array read: the previous tick's sweep left the answer here.
  --
  -- It outranks the weakest enemy on purpose. A body that ignores whoever is
  -- hitting it in favour of a wounded target further away turns its back on a
  -- fight it is already in, and two bodies doing that walk past each other
  -- swinging at strangers.
  local attacker = world.attacker_of[id]
  if attacker ~= 0 and soldier.alive[attacker] == 1
     and M.hostile(soldier.team[id], soldier.team[attacker]) then
    soldier.target[id] = attacker
    soldier.target_generation[id] = soldier.generation[attacker]
    soldier.target_structure[id] = 0
    return
  end

  -- Rule 2 -- the weakest enemy within acquisition range.
  --
  -- **And one it has a line to, if it needs one.** An ordinary arrow is long-ranged
  -- and flat, so its own side's rank is in the way of it; only a longbow and certain
  -- magic throw high enough to clear the people in front.
  --
  -- One line check, on the winner, and no second search if it fails. A body behind an
  -- unbroken rank simply takes no target this tick -- **which is the point**, because
  -- having no shot is the condition that makes it fan out looking for an angle. The
  -- blocked shot is not a dead end; it is what moves the body.
  --
  -- Rescanning for a target it *could* see was the first version and it cost ten times
  -- the whole simulation. An archer stands behind a line, so it is blocked nearly
  -- always, so the fallback ran nearly every tick for nearly every archer -- a grid
  -- query per candidate inside a grid query over candidates. One match went from
  -- twenty-eight seconds to five minutes.
  local weakest = lowest_health_enemy(world, id, false)
  local row = world.parameters.unit.archetype[soldier.archetype[id]]
  if world.parameters.unit.flat_arrows_need_a_line
     and weakest ~= 0 and soldier.reach[id] == 2 and not (row ~= nil and row.arcs)
     and not M.can_see(world, id, weakest) then
    weakest = 0
    soldier.search_pause[id] = BLOCKED_PATIENCE
  end
  if weakest ~= 0 then
    soldier.target[id] = weakest
    soldier.target_generation[id] = soldier.generation[weakest]
    soldier.target_structure[id] = 0
    return
  end

  -- Rule 3 -- stone, but only what is already inside weapon range.
  local structure = enemy_structure_in_reach(world, id)
  if structure ~= 0 then
    soldier.target[id] = 0
    soldier.target_generation[id] = 0
    soldier.target_structure[id] = structure
    return
  end

  -- Rule 4 -- nothing. Keep walking.
  soldier.target[id] = 0
  soldier.target_generation[id] = 0
  soldier.target_structure[id] = 0
end
-- }}}

-- {{{ function M.target_is_alive()
-- Whether a body's stored target is still the body it thought it was.
--
-- The generation check is what makes recycled slots safe. Without it a body
-- whose target died would keep swinging at whoever moved into that slot next --
-- possibly a friend, possibly across the map -- and the symptom would be a
-- soldier attacking nothing at all.
function M.target_is_alive(world, id)
  local soldier = world.soldier
  local target = soldier.target[id]
  if target == 0 then
    return false
  end
  return soldier.alive[target] == 1
     and soldier.generation[target] == soldier.target_generation[id]
end
-- }}}

-- {{{ function M.sweep_attackers()
-- Rebuilds "who is swinging at me" and the incoming-damage-per-second figure,
-- once per tick, from everybody's chosen target.
--
-- Maintained here in one pass rather than updated at every swing, because a body
-- that changes target has to *decrement* the old one's figure, and a decrement
-- that gets missed leaves a body permanently believing it is under fire. A full
-- rebuild cannot drift.
function M.sweep_attackers(world)
  local soldier = world.soldier
  local attacker_of = world.attacker_of
  local ticks_per_second = world.parameters.unit.ticks_per_second

  for id = 1, world.high_water do
    attacker_of[id] = 0
    soldier.incoming_dps[id] = 0
  end

  for id = 1, world.high_water do
    if soldier.alive[id] == 1 then
      local target = soldier.target[id]
      if target ~= 0 and soldier.alive[target] == 1 then
        attacker_of[target] = id
        local per_swing = soldier.damage[id] - soldier.armour[target]
        if per_swing < 1 then per_swing = 1 end
        local swings_per_second = ticks_per_second / soldier.cooldown_max[id]
        soldier.incoming_dps[target] =
          soldier.incoming_dps[target] + per_swing * swings_per_second
      end
    end
  end
end
-- }}}

return M
