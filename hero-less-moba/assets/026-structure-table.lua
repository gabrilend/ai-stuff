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

-- 026-structure-table.lua
--
-- The numbers for stone. Two rows -- a guard tower and a library -- and the
-- library's health is expressed as a *ratio* of the tower's rather than as its
-- own figure, so that retuning towers retunes the library and the two can never
-- drift apart.
--
-- Every guard tower in the game is the same strength as every other one. There
-- are no tiers. That flatness is what makes a slotted upgrade interesting: it is
-- the only thing that distinguishes one lane's stone from another's, so the
-- decision is visible from across the map.

local M = {}

-- {{{ M.tower
M.tower = {
  health        = 1400,
  damage        = 34,
  range         = 168,
  cooldown_max  = 34,

  -- The circle of ground around a tower, and the one piece of information in
  -- this game both teams can see. It gates two things with one radius: whether
  -- the tower may replace a fallen guard, and whether a player may put a hero
  -- down here.
  --
  -- Deliberately larger than the tower's weapon range. The attacker has to get
  -- *inside* it to shut the reinforcements off, and that has to be reachable
  -- ground rather than a spot already under maximum fire.
  command_radius = 232,

  -- How many guards a tower may hold at once, before any upgrade raises it.
  guard_cap     = 2,

  -- Ticks between putting one guard on the ground and being allowed to put the
  -- next one there -- and only counting down while the command radius is clear.
  guard_interval = 260,

  -- How far a guard may drift from its tower before it gives up whatever it is
  -- doing and walks home.
  leash_radius  = 128,

  -- And how far a **base** guard may drift, which is much further, because the three
  -- towers inside a base share one patrol area rather than three.
  --
  -- **The interior of a base is one open space, not three corridors.** Guards spawned
  -- by any base tower move to attack invaders from any lane, and what stops that
  -- turning the base into an impenetrable ball is the towers themselves: a tower's
  -- arrows are a plain radius around it, so in practice each one only reaches the
  -- mouth of the lane it sits at. **Bodies flow across a base freely; arrows do not.**
  --
  -- The consequence worth telling players: pushing into a base means fighting every
  -- guard in it at once, but only under the arrows of the one tower you walked past.
  -- Splitting a push across two lanes into the same base is therefore meaningfully
  -- better than doubling up on one, which is another shove away from tunnel vision.
  base_leash_radius = 340,
}
-- }}}

-- {{{ M.library
M.library = {
  -- One and a half towers' worth, and stored as a ratio for exactly that reason.
  -- Smaller than players expect: once the stone in front of it is gone, a team
  -- gets about one wave's worth of grace rather than a long grinding defence.
  -- A game whose premise is "the frontline must move" cannot afford a fortress
  -- at the end of it.
  health_in_towers = 1.5,

  damage       = 0,     -- it is a building, not a defence
  range        = 0,
  cooldown_max = 0,
}
-- }}}

-- {{{ M.reward
M.reward = {
  -- Felling a tower pays three upgrades at once -- three separate draws, three
  -- separate things to place, not one worth three times as much. The plurality
  -- is the point: it should trigger a burst of placement decisions.
  tower_felled_draws = 3,

  -- Wiping a wave pays exactly one, to the team that did *not* spawn it.
  wave_wiped_draws   = 1,
}
-- }}}

return M
