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

-- 025-unit-table.lua
--
-- Every body in the game is one record with different numbers in it. This is the
-- table of those numbers, one row per archetype, and it is the only place they
-- appear.
--
-- Durations are whole numbers of ticks, never seconds, because two machines have
-- to agree about *when* even though they are allowed to disagree in the last bit
-- about *where*. Distances are paces. Speed is paces per tick.
--
-- Melee and ranged bodies have the same stats for every commander in the game --
-- a knight and a barbarian are the same body with different art. What a
-- commander sets is the mixture and the captain, not a private stat block.

local M = {}

-- How many ticks the world advances per second of wall-clock. Every duration in
-- every table is a whole number of these.
M.ticks_per_second = 30

-- {{{ M.archetype
-- Archetype ids are rows in this array, and a body stores its row rather than
-- its stats -- except that it does not, quite: a body copies the row's values
-- into its own slot at birth, because the swing path must not chase a pointer.
-- The row is what it copies *from*.
--
-- reach: 1 = melee, forms the rank. 2 = ranged, holds behind the rank at its own
-- reach and shoots over it. That single field is what splits the frontline queue
-- into two behaviours, and it is read there and nowhere else.
M.archetype = {

  -- 1 -- the melee wave body. The baseline every other row is a multiple of.
  {
    name         = "melee",
    flavour      = 1,
    reach        = 1,
    health       = 90,
    damage       = 16,
    armour       = 2,
    range        = 17,
    -- Wider than range, so a body commits to a fight slightly before it can hit.
    -- A body that acquires exactly at weapon range spends its life oscillating
    -- between walking and closing on the same target.
    acquire_range = 74,
    speed        = 1.15,
    cooldown_max = 22,
  },

  -- 2 -- the ranged wave body. Same health and damage as melee; the whole
  -- difference is that it stops further back and never wants the front.
  {
    name         = "ranged",
    flavour      = 1,
    reach        = 2,
    health       = 90,
    damage       = 16,
    armour       = 2,
    range        = 96,
    acquire_range = 132,
    speed        = 1.15,
    cooldown_max = 26,
  },

  -- 3 -- the melee captain. One per lane per wave, so no lane is ever the cheap
  -- one to ignore. 2.5x health and 1.5x damage, and -- unlike a hero -- stamped
  -- with everything sitting in its lane, which is what makes a committed lane's
  -- captain enormous.
  {
    name         = "captain",
    flavour      = 1,
    reach        = 1,
    health       = 225,
    damage       = 24,
    armour       = 4,
    range        = 19,
    acquire_range = 80,
    speed        = 1.05,
    cooldown_max = 24,
  },

  -- 4 -- the tower guard. An ordinary body with a leash. It wanders inside its
  -- tower's radius instead of advancing, engages what comes near, and walks home
  -- the moment its target dies. Area denial, not a push.
  {
    name         = "guard",
    flavour      = 3,
    reach        = 1,
    health       = 100,
    damage       = 17,
    armour       = 3,
    range        = 17,
    acquire_range = 88,
    speed        = 1.05,
    cooldown_max = 22,
  },
}
-- }}}

-- {{{ M.wave
-- What a wave is made of, and how often one leaves the base.
--
-- One captain per lane, every wave, which is the rule that makes every lane
-- worth contesting. The melee and ranged counts are the commander's mixture; at
-- prototype scale there is one commander and these are its proportions.
M.wave = {
  interval      = 620,   -- ticks between one wave leaving the base and the next
  first_at      = 90,    -- ticks before the very first wave, so a match opens calm
  melee_count   = 4,
  ranged_count  = 2,
  captain_count = 1,

  -- Ticks between two bodies of the same wave stepping out of the library, so a
  -- wave leaves as a column rather than as a single stacked point. Purely how it
  -- looks and how the queue forms; nothing reads it afterwards.
  stagger       = 9,
}
-- }}}

return M
