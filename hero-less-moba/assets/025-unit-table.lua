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

  -- 5 -- the ranged captain. The same 2.5x health and 1.5x damage as its melee
  -- cousin, standing off instead of closing. A commander picks one or the other
  -- and that choice is the only unit in its whole roster that differs from
  -- everybody else's -- melee and ranged bodies are identical for every commander
  -- in the game, differing in art alone.
  {
    name         = "ranged captain",
    flavour      = 1,
    reach        = 2,
    health       = 225,
    damage       = 24,
    armour       = 4,
    range        = 100,
    acquire_range = 138,
    speed        = 1.05,
    cooldown_max = 28,
  },

  -- ---------------------------------------------------------------------------
  -- Heroes. Everything below is bought with personal resource and fights until it
  -- dies, and then it is gone.
  --
  -- "About 2.5x a wave unit" is a **weight, not a stat**. A hero might be 2.5x the
  -- health at 1x the damage, or 1.2x both with a very good ability. What makes two
  -- heroes different purchases is not their numbers -- they are all roughly
  -- equivalent -- it is **what their abilities fire on**, because a player has no
  -- manual control over a hero at all and the condition carries the whole weight.
  --
  -- A roster covers distinct jobs rather than three grades of the same soldier:
  -- something that holds a frontline, something that kills a frontline, something
  -- that kills stone. A roster of small, medium and large gives a player one
  -- decision; a roster of distinct jobs gives them two.
  -- ---------------------------------------------------------------------------

  -- 6 -- holds a frontline.
  {
    name         = "bulwark knight",
    flavour      = 2,
    reach        = 1,
    health       = 320,
    damage       = 18,
    armour       = 7,
    range        = 19,
    acquire_range = 82,
    speed        = 1.0,
    cooldown_max = 24,
    ability      = {"guard_the_line"},
  },

  -- 7 -- kills a frontline.
  {
    name         = "storm lancer",
    flavour      = 2,
    reach        = 1,
    health       = 210,
    damage       = 26,
    armour       = 3,
    range        = 20,
    acquire_range = 90,
    speed        = 1.2,
    cooldown_max = 20,
    ability      = {"cleave"},
  },

  -- 8 -- kills stone.
  {
    name         = "siege ram",
    flavour      = 2,
    reach        = 1,
    health       = 260,
    damage       = 20,
    armour       = 5,
    range        = 24,
    acquire_range = 70,
    speed        = 0.9,
    cooldown_max = 26,
    ability      = {"sunder"},
  },

  -- 9 -- mends. Sunlight against coal, water against earth: the counter structure
  -- is elemental and is legible before anybody writes a stat.
  {
    name         = "sunlight paladin",
    flavour      = 2,
    reach        = 2,
    health       = 230,
    damage       = 14,
    armour       = 4,
    range        = 92,
    acquire_range = 130,
    speed        = 1.05,
    cooldown_max = 30,
    ability      = {"mend"},
  },

  -- 10 -- reaches past the line.
  {
    name         = "longbow ranger",
    flavour      = 2,
    reach        = 2,
    health       = 190,
    damage       = 30,
    armour       = 2,
    range        = 138,
    acquire_range = 176,
    speed        = 1.1,
    cooldown_max = 30,
    ability      = {"volley"},
  },

  -- 11 -- the coal side's frontline holder. Emits fear rather than swinging
  -- harder: the statue is slayable, you just have to have a stronger spirit.
  {
    name         = "coal warden",
    flavour      = 2,
    reach        = 1,
    health       = 300,
    damage       = 19,
    armour       = 6,
    range        = 21,
    acquire_range = 96,
    speed        = 1.0,
    cooldown_max = 23,
    ability      = {"dread"},
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

-- {{{ M.bounty
-- What killing a body pays, per player on the other team.
--
-- **Every kill your team lands pays every player on your team, in full.** It is
-- not a pot to be divided -- the figure below is per player -- so a team's income
-- scales with its size. Nothing asks what did the killing; the reap pass reads the
-- dead body's own team and credits the other one.
--
-- Paid in **one colour**, the one that body was carrying, which its commander
-- decided. So you farm what the enemy fields, and their commander selection
-- decides what you can afford.
M.bounty = {
  wave    = 1,   -- an ordinary melee or ranged body
  captain = 3,   -- the signature body, worth three of them
  guard   = 1,
  hero    = 5,
  monster = 40,
}
-- }}}

return M
