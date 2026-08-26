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

-- 036-the-frontline.lua
--
-- Why a wave reads as a wave rather than as a smear.
--
-- Soldiers do not overlap and do not push each other. When a body closing on a
-- fight would end its move inside the personal space of a friendly body ahead of
-- it, it stops short instead. The result is a queue: the front rank fights, the
-- ranks behind stack up along the lane and step forward as the front rank dies.
--
-- That is what makes a lane upgrade legible from across the map. A stronger front
-- rank visibly holds its ground while the enemy's queue backs up behind it, and a
-- player reads "I am winning that lane" off the shape of two crowds rather than
-- off a number.
--
-- ## A rank is a melee thing
--
-- The rule above was written when every body wanted the same place -- the front --
-- and everything behind it was waiting its turn to get there. A ranged body does
-- not want the front and never did.
--
-- So the queue has two behaviours:
--
--   melee  -- form the rank. Stop short behind whoever is ahead, step up as the
--            front thins.
--   ranged -- hold at your own reach *behind* the rank and shoot over it. Not
--            queueing for a place you will eventually take.
--
-- Treating a ranged body as a rank-in-waiting pushes it into melee range and
-- deletes the distinction entirely. The consequence for how a frontline reads is
-- worth knowing: a wave that has lost its melee rank but kept its ranged bodies
-- looks different from one that has lost everything, and it is about to
-- evaporate. That is a thing a player can see and act on without a number.

local M = {}

-- {{{ local function lane_position()
-- How far along its lane a body is, as one number: its path index plus how far
-- it is across the current edge.
--
-- Comparing two of these is comparing progress down the same corridor, which is
-- what "ahead of me" means here. It is not a distance -- the steps are only
-- roughly even -- and it is never used as one; it is used for ordering, which is
-- all the queue needs.
local function lane_position(world, id)
  local soldier = world.soldier
  return soldier.path_index[id] + soldier.progress[id]
end
-- }}}

-- {{{ function M.blocked()
-- Whether this body must stop short this tick.
--
-- Only friendly bodies block. An enemy in the way is not an obstacle, it is a
-- target, and the targeting pass has already had its say by the time this is
-- asked.
function M.blocked(world, id)
  local soldier = world.soldier

  -- A body with no lane -- a guard on patrol -- is not in anybody's queue. Guards
  -- wander; they are not going anywhere that queueing would help them reach.
  if soldier.path_index[id] == 0 then
    return false
  end

  local lane = soldier.lane[id]
  local team = soldier.team[id]
  local facing = soldier.facing[id]
  local mine = lane_position(world, id)
  local spacing = world.parameters.shape.personal_space

  -- A ranged body keeps a smaller bubble than a melee one. It is not waiting for
  -- the front, so it only needs enough room not to stand inside a friend -- and
  -- giving it a full rank's spacing would push the back of a wave a long way
  -- down the lane for no reason.
  if soldier.reach[id] == 2 then
    spacing = spacing * 0.6
  end

  local blocked = false
  M.for_each_candidate(world, id, spacing, function(other)
    if blocked then
      return
    end
    if soldier.team[other] == team
       and soldier.lane[other] == lane
       and soldier.path_index[other] > 0 then
      local theirs = lane_position(world, other)
      -- Ahead means further along in the direction I am walking. Multiplying by
      -- facing folds the two directions into one comparison, so team 2's bodies
      -- walking backwards down the path array queue exactly like team 1's.
      if (theirs - mine) * facing > 0 then
        blocked = true
      end
    end
  end)

  return blocked
end
-- }}}

-- {{{ function M.for_each_candidate()
-- Every body within one personal space of this one. Split out from `blocked` so
-- that the grid query and the queue rule can be read separately, and so that a
-- test can drive the rule with a list it made up.
function M.for_each_candidate(world, id, spacing, visit)
  local targeting = world.targeting
  local soldier = world.soldier
  targeting.for_each_near(world, soldier.x[id], soldier.y[id], spacing,
    function(other)
      if other ~= id and soldier.alive[other] == 1 then
        visit(other)
      end
    end)
end
-- }}}

return M
