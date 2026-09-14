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

-- **How wide a body stands as an obstacle to a straight shot is its radius**, and
-- there is nothing left here to tune.
--
-- It used to be a fraction -- a fifth -- of the one shared `personal_space`, with a
-- paragraph explaining that the fraction was there because a body's own size is
-- smaller than the room it wants, and a shot between two soldiers standing
-- comfortably apart should get through. That reasoning was right and it was
-- reconstructing, in a constant, a number the game did not have: a fifth of eighteen
-- is 3.6, which is exactly the melee body's size. It had been tuned to the picture.
--
-- Now that a body has a size, it is that. A Golem blocks a shot with thirty-one paces
-- of Golem and a soldier with three and a half of soldier, which the fraction could
-- not say at all -- it gave every body in the game the same width, and the widest
-- thing on the field was the thing it was most wrong about.
--
-- Measured over nine thousand ticks with flat arrows needing a line, before this
-- changed, across widths of 8.1, 5.4, 3.6 and 2.2 paces: the width is **not** the
-- lever. Halving it recovers a tenth of the damage and the pile-up stays. The tables
-- are in H14 of the open questions along with the sweep that still wants running.

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

  -- **And the biggest body actually standing on the field**, which the collision test
  -- needs and which is not the same thing as the biggest body in the catalogue.
  --
  -- That test asks "is anything's circle over this point", and a grid query takes one
  -- distance up front, so it has to be sized for the largest thing it might find. Sized
  -- from the catalogue it is always the Golem's thirty-one paces, which is nearly four
  -- times the area to search for the whole of every match in which no monster is out --
  -- and a monster is out for a few thousand ticks of a match that lasts tens of them.
  --
  -- Taken here because this loop already walks every living body, so it is exact and
  -- costs a comparison per body rather than a second pass.
  local soldier = world.soldier
  local largest = 0
  for id = 1, world.high_water do
    if soldier.alive[id] == 1 then
      local index = cell_index(grid, soldier.x[id], soldier.y[id])
      local bucket = grid.bucket[index]
      bucket[#bucket + 1] = id
      if soldier.radius[id] > largest then
        largest = soldier.radius[id]
      end
    end
  end
  world.largest_body = largest
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

-- {{{ function M.reach_to()
-- How far apart two bodies' **centres** may be and still be in reach of each other.
--
-- A body's `range` is measured from its own centre, and it always was. What changed is
-- that the thing it is swinging at now has a size, so the far end of the measurement
-- is that body's skin rather than its middle: `range + other.radius`.
--
-- This is not a refinement, it is the difference between the game working and not.
-- Bodies stop against each other at the sum of their radii, so a soldier standing on a
-- monster is thirty paces from its centre while its sword reaches seventeen. Measured
-- centre to centre, **every melee body in the game misses every monster, forever**, and
-- what that looks like from outside is a challenge phase that never ends: the monsters
-- do not die, so the calm never begins, so no boon is ever offered.
--
-- Between two ordinary soldiers it moves engagement by three and a half paces, which
-- is a body's width and is the correct amount to move it by.
--
-- One function rather than the four places that each wrote the comparison out, because
-- four copies of a rule is four chances for one of them to still be measuring to the
-- middle.
function M.reach_to(world, id, other)
  return world.soldier.range[id] + world.soldier.radius[other]
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

  -- The search has to be wide enough for the widest possible blocker, because the
  -- test that follows is per candidate and a body missed by the query is never asked.
  local widest = world.largest_body
  local blocked = false
  M.for_each_near(world, (ax + bx) * 0.5, (ay + by) * 0.5,
                  length * 0.5 + widest, function(other)
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
    if across < soldier.radius[other] then
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

-- {{{ local function enemy_to_swing_at()
-- Rule 2. The enemy this body picks, or 0.
--
-- **Anything it can already reach, chosen at random. Otherwise the nearest.**
--
-- Two rules that are really one: a body fights whoever is in front of it. When several
-- are, it has no reason to prefer any of them, and picking at random is what stops an
-- entire rank fixating on one man while the ones beside him swing at nobody.
--
-- ## What this replaced, and why it was the wrong rule
--
-- It used to take the **weakest enemy anywhere in acquisition range** -- seventy-four
-- paces for a melee body, a hundred and thirty for an archer -- with a random choice
-- only among exact health ties, which stop happening the moment anybody is wounded.
--
-- It reads sensibly: finish the hurt one. What it actually does is send a soldier past
-- the man standing in front of him to reach somebody bleeding seventy paces away, and
-- when two lines meet, *both* sides do it at once. Everybody converges on whoever is
-- most hurt, from every direction, and the two lines walk through each other rather
-- than into each other. There is no frontline because nobody is fighting the person
-- opposite them.
--
-- That mattered much less when bodies could stand inside one another and a rank was
-- held together by a queueing rule. With bodies solid and the queue gone, targeting is
-- what makes a line: two ranks stop against each other because each body is swinging at
-- the body in front of it.
--
-- The reservoir sampling is kept and now does real work rather than breaking rare
-- ties: the nth equally-good candidate replaces the incumbent with probability 1/n,
-- which is a uniform choice among them while advancing the stream a fixed number of
-- times per call -- and a fixed number of steps is what keeps a replay reproducible.
local function enemy_to_swing_at(world, id, must_see)
  local soldier = world.soldier
  local team = soldier.team[id]

  -- Anything inside this body's reach, and anything at all, gathered in one sweep.
  -- Reach is measured to the other body's skin, so a large enemy is reachable from
  -- further out -- see `reach_to`.
  local in_reach, in_reach_count = 0, 0
  local nearest, nearest_distance, nearest_ties = 0, math.huge, 0

  M.for_each_near(world, soldier.x[id], soldier.y[id], soldier.acquire_range[id],
    function(other)
      if M.hostile(team, soldier.team[other])
         and (not must_see or M.can_see(world, id, other)) then
        local dx = soldier.x[other] - soldier.x[id]
        local dy = soldier.y[other] - soldier.y[id]
        local distance = dx * dx + dy * dy

        local reach = M.reach_to(world, id, other)
        if distance <= reach * reach then
          in_reach_count = in_reach_count + 1
          if world.stream.tie[team]:next_below(in_reach_count) == 1 then
            in_reach = other
          end
        end

        if distance < nearest_distance then
          nearest, nearest_distance, nearest_ties = other, distance, 1
        elseif distance == nearest_distance then
          nearest_ties = nearest_ties + 1
          if world.stream.tie[team]:next_below(nearest_ties) == 1 then
            nearest = other
          end
        end
      end
    end)

  if in_reach ~= 0 then
    return in_reach
  end
  return nearest
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

  -- **Being hit by somebody new spends the look.** Cleared here whether or not the
  -- ranking below finds anything, because the thing it records is that the body owes
  -- the world one look, and it has now had it.
  local struck_by_somebody_new = soldier.look_up[id] == 1
  soldier.look_up[id] = 0

  -- A body whose last look was blocked by its own rank waits a moment before looking
  -- again. The line in front of it is still there; asking every tick is asking the
  -- same question of the same people, and the asking is a grid query.
  --
  -- **A new assailant overrides the wait**, because being hit is exactly the event
  -- that makes it wrong. The wait is founded on nothing having changed since the last
  -- look, and somebody arriving who was not there before is the change.
  if soldier.search_pause[id] > 0 and not struck_by_somebody_new then
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

  -- Rule 2 -- whoever this body can already reach, or the nearest it cannot.
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
  local chosen = enemy_to_swing_at(world, id, false)
  local row = world.parameters.unit.archetype[soldier.archetype[id]]
  if world.parameters.unit.flat_arrows_need_a_line
     and chosen ~= 0 and soldier.reach[id] == 2 and not (row ~= nil and row.arcs)
     and not M.can_see(world, id, chosen) then
    chosen = 0
    soldier.search_pause[id] = BLOCKED_PATIENCE
  end
  if chosen ~= 0 then
    soldier.target[id] = chosen
    soldier.target_generation[id] = soldier.generation[chosen]
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

-- {{{ local function remember_the_striker()
-- Writes an attacker into its victim's short memory, and says whether it was new.
--
-- Most recent first, oldest pushed off the end. Four comparisons and, on the rare
-- occasion something is actually new, three shifts -- which is cheaper than keeping a
-- cursor per body would be, and means the slots are in recency order for free.
--
-- The key carries the attacker's **generation** as well as its id, because slots are
-- recycled: remembering a bare id would have a body sit calmly through the first blows
-- of an entirely different soldier that happened to be born into the same slot.
local function remember_the_striker(soldier, capacity, victim, striker)
  local key = soldier.generation[striker] * capacity + striker
  if soldier.struck_by_1[victim] == key or soldier.struck_by_2[victim] == key
     or soldier.struck_by_3[victim] == key or soldier.struck_by_4[victim] == key then
    return false
  end
  soldier.struck_by_4[victim] = soldier.struck_by_3[victim]
  soldier.struck_by_3[victim] = soldier.struck_by_2[victim]
  soldier.struck_by_2[victim] = soldier.struck_by_1[victim]
  soldier.struck_by_1[victim] = key
  return true
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
--
-- **And this is where a body notices it is being hit by somebody new.** Every
-- attacker-and-victim pair in the game is already visited here, so the noticing costs
-- a walk of four numbers rather than a second pass over the world. What it raises is
-- read by the next tick's retargeting, which is the same one-tick lag the "somebody is
-- already swinging at me" rule has always run on.
function M.sweep_attackers(world)
  local soldier = world.soldier
  local attacker_of = world.attacker_of
  local ticks_per_second = world.parameters.unit.ticks_per_second
  local capacity = world.capacity

  for id = 1, world.high_water do
    attacker_of[id] = 0
    soldier.incoming_dps[id] = 0
  end

  for id = 1, world.high_water do
    if soldier.alive[id] == 1 then
      local target = soldier.target[id]
      if target ~= 0 and soldier.alive[target] == 1 then
        -- Last writer wins, and that is fine: this answers "somebody is hitting me"
        -- rather than "everybody who is hitting me". What follows is the part that
        -- cares about all of them.
        attacker_of[target] = id
        local per_swing = soldier.damage[id] - soldier.armour[target]
        if per_swing < 1 then per_swing = 1 end
        local swings_per_second = ticks_per_second / soldier.cooldown_max[id]
        soldier.incoming_dps[target] =
          soldier.incoming_dps[target] + per_swing * swings_per_second

        -- A body already in the memory passes without comment -- which is the half of
        -- this that keeps a frontline from re-deciding every tick. A body in a scrum
        -- is struck constantly by the same few enemies and should settle down and
        -- keep swinging; it is the *fourth* enemy, arriving from a direction nobody
        -- was covering, that is worth turning round for.
        if M.hostile(soldier.team[id], soldier.team[target])
           and remember_the_striker(soldier, capacity, target, id) then
          soldier.look_up[target] = 1
        end
      end
    end
  end
end
-- }}}

return M
