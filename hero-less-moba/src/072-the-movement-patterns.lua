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

-- 072-the-movement-patterns.lua
--
-- Every way a body can want to move, as a table of rows.

-- Every way a body can want to move, as a table of rows.
--
-- ## What a pattern is allowed to do
--
-- **Place a goal and a pace. Nothing else.**
--
-- It may not move a body, may not look at whether anything is standing in the way, and
-- may not know how fast the body will actually travel. It answers one question -- *where
-- do I want to be* -- and everything from there belongs to
-- [the layer underneath](034-walking.info.md): capping the step at what this pace allows,
-- moving it out of anybody standing on it, and placing the body through whichever
-- representation its position lives in.
--
-- ## Why this is a table
--
-- What it replaces is a run of nine early returns inside one function in the brain, every
-- one of them correct, and the **order between them was the policy**. A policy that is a
-- position in a sequence can only be read by reading the sequence, and adding a tenth way
-- to move meant choosing a place in it.
--
-- Three things become possible once they are rows. A pattern can be tested on its own --
-- give a body a pattern, run one tick, assert where the goal landed, with no world full of
-- other bodies and no question of whether it arrived. A pattern can be named on screen,
-- which is the difference between watching bodies move and watching them decide. And the
-- order stops being policy: two patterns that could both apply have to be resolved out
-- loud rather than by whichever `return` came first.

local M = {}

-- The paces, by the name the unit catalogue gives them. Named here so a row reads as a
-- sentence rather than as an integer nobody can check.
local RELAX, NORMAL, HURRY = 1, 2, 3

-- {{{ M.pattern
-- The rows. Each takes the world and a body, and places that body's goal.
--
-- Returning false means "this pattern does not apply to this body right now", which is
-- how the chooser walks down the list. Returning true means a goal has been placed.
M.pattern = {}

-- {{{ M.pattern.hold
-- Stand where you are.
--
-- The goal is the body's own feet, so the step is a step of nothing and the body does not
-- move -- but it is still **separated out of anybody who walks into it**, which is why a
-- stray drifts a tenth of a pace over a whole run rather than being immovable. Whether a
-- body holding ground should return to where it was holding is M3 and is not decided.
M.pattern.hold = {
  name = "hold",
  place = function(world, id)
    local soldier = world.soldier
    world.walking.aim(world, id, soldier.x[id], soldier.y[id], NORMAL)
    return true
  end,
}
-- }}}

-- {{{ M.pattern.march
-- Toward this body's place in its wave's formation.
--
-- **Computed in lane coordinates and converted at the end**, which is what makes a rank
-- curve round a bend as a rank: every body in it shares one distance-along, so the lane's
-- own curve carries the whole line round together. Working the goal out directly in world
-- coordinates would lose that, and nothing below this layer would notice.
--
-- The pace comes from the gear the formation put this body in -- seven tenths if it has
-- got ahead of its place, full pace otherwise. **A body marching in a line never hurries**,
-- which is the half of the old no-sprinting rule that survives: a line dresses itself by
-- the inside of a turn slowing, and a body that has left the line to charge something is
-- no longer dressing anything.
M.pattern.march = {
  name = "march",
  place = function(world, id)
    local soldier = world.soldier
    if soldier.wave[id] == 0 then
      return false
    end
    -- **The Golem falls through to walking its lane**, and this is the whole of why it
    -- never stops for anything: nothing gives it a formation to hold, so nothing gives it
    -- a reason to dress a line. It used to be a test near the top of a function with a
    -- paragraph asking somebody to find it before wondering why the Golem parks.
    local row = world.parameters.unit.archetype[soldier.archetype[id]]
    if row ~= nil and row.deathless then
      return false
    end
    local along, across = world.formations.target_of(world, id)
    local scale = soldier.speed_scale[id]
    world.walking.aim_on_lane(world, id, along, across,
                              (scale > 0 and scale < 1) and RELAX or NORMAL)
    return true
  end,
}
-- }}}

-- {{{ M.pattern.lane_walk
-- Straight down the lane, alone.
--
-- A hero belongs to no wave, so it has no place in a formation to hold. The Eternal Golem
-- takes this row and no other, and that -- rather than a test near the top of a function
-- and a paragraph asking somebody to find it -- is the whole of why it never stops to
-- fight: nothing ever gives it a different pattern.
M.pattern.lane_walk = {
  name = "lane_walk",
  place = function(world, id)
    local soldier = world.soldier
    local lane = world.map.lane[soldier.lane[id]]
    if lane == nil then
      return false
    end
    -- A goal a good way down the road rather than one step down it. How far a body
    -- actually gets this tick is the pace's business, and a goal that was already only
    -- one step away would make every pace identical.
    local ahead = soldier.lane_along[id] + soldier.speed[id] * 4 * soldier.facing[id]
    if ahead < 0 then ahead = 0 end
    if ahead > lane.length then ahead = lane.length end
    world.walking.aim_on_lane(world, id, ahead, soldier.lane_across[id], NORMAL)
    return true
  end,
}
-- }}}

-- {{{ M.pattern.charge
-- At whatever this body is trying to reach.
--
-- **Hurry**, and this is the row that reverses the rule that nothing exceeds marching
-- pace. That rule was about a line, and it still holds there. A body that has left the
-- line to charge something has left the formation's business -- which the cohesion budget
-- already recognises by excluding it -- and it is allowed to run.
M.pattern.charge = {
  name = "charge",
  place = function(world, id)
    local soldier = world.soldier
    local target = soldier.target[id]
    if target ~= 0 and soldier.alive[target] == 1 then
      -- **At its skin, not its middle.** A body that has walked up to something is
      -- standing against it, and how far that is from its centre depends on how big it is
      -- -- which is the same sentence the range check makes, and the two have to agree or
      -- a body spends every tick wanting to be somewhere it is not allowed to stand.
      --
      -- Aimed at the centre instead, a charging body wants to occupy its target. It is
      -- moved off that ground every tick by the rule about standing on people and shoves
      -- back at a third again its own speed, and in a crowded fight that pressure was
      -- enough to leave two bodies a sixteenth of a pace inside each other.
      local dx = soldier.x[target] - soldier.x[id]
      local dy = soldier.y[target] - soldier.y[id]
      local distance = math.sqrt(dx * dx + dy * dy)
      local stop_at = world.targeting.reach_to(world, id, target)
      if distance <= stop_at or distance < 0.000001 then
        world.walking.aim(world, id, soldier.x[id], soldier.y[id], NORMAL)
      else
        world.walking.aim(world, id,
                          soldier.x[target] - dx / distance * stop_at,
                          soldier.y[target] - dy / distance * stop_at, HURRY)
      end
      return true
    end
    -- A tower or a library is a thing to walk at too, and it is not a body -- it has no
    -- slot in the soldier arrays and its position is its node's.
    local structure_id = soldier.target_structure[id]
    if structure_id ~= 0 then
      local structure = world.structure[structure_id]
      if structure ~= nil and structure.alive == 1 then
        -- A structure's reach is the body's own weapon range: stone has no radius in the
        -- soldier arrays because it is not a body.
        local node = world.map.node[structure.node]
        local dx = node.x - soldier.x[id]
        local dy = node.y - soldier.y[id]
        local distance = math.sqrt(dx * dx + dy * dy)
        local stop_at = soldier.range[id]
        if distance <= stop_at or distance < 0.000001 then
          world.walking.aim(world, id, soldier.x[id], soldier.y[id], NORMAL)
        else
          world.walking.aim(world, id,
                            node.x - dx / distance * stop_at,
                            node.y - dy / distance * stop_at, HURRY)
        end
        return true
      end
    end
    return false
  end,
}
-- }}}

-- {{{ M.pattern.withdraw
-- Back down the lane and off the map.
--
-- A hero handing back what it cost during a calm. Hurry, because it has stopped being part
-- of anybody's line and there is nothing left for it to dress.
M.pattern.withdraw = {
  name = "withdraw",
  place = function(world, id)
    local soldier = world.soldier
    if soldier.going_home[id] ~= 1 then
      return false
    end
    local lane = world.map.lane[soldier.lane[id]]
    if lane == nil then
      return false
    end
    local home = (soldier.facing[id] == 1) and lane.length or 0
    world.walking.aim_on_lane(world, id, home, soldier.lane_across[id], HURRY)
    return true
  end,
}
-- }}}
-- }}}

-- {{{ M.order
-- Which pattern a body takes, as an ordered list of rows to try.
--
-- **The order is still an order and that is still policy** -- what has changed is that it
-- is a list somebody can read rather than the sequence of returns inside a function. M4
-- asks whether the choice should stop being a walk down a list at all and become something
-- the brain writes down; it is not answered, and keeping the same order as the run of
-- early returns it replaces is what makes this change provably behaviour-preserving before
-- anything is redesigned.
M.order = {"withdraw", "charge", "march", "lane_walk", "hold"}
-- }}}

-- {{{ function M.choose()
-- Give this body a goal, by the first row in the order that applies to it.
--
-- Writes down **which** row it was, on the body, rather than leaving it to be recomputed.
-- That is what lets the window draw what a body is trying to do and lets a test assert on
-- it, and both of those are half of why the patterns were pulled into a table at all.
function M.choose(world, id)
  local soldier = world.soldier
  for index = 1, #M.order do
    local row = M.pattern[M.order[index]]
    if row.place(world, id) then
      soldier.pattern[id] = index
      return row
    end
  end
  -- Every body reaches `hold` if it reaches nothing else, so arriving here means the order
  -- has been edited into a state where a body can want nothing at all.
  error("body " .. id .. " matched no movement pattern")
end
-- }}}

return M
