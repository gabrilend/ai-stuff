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

-- 027-upgrade-table.lua
--
-- The upgrade catalogue. One row per kind; a body carries a small integer count
-- of each kind rather than a bit set, because duplicates stack and a bit set
-- cannot count.
--
-- Two fields decide everything about how a kind behaves and they are easy to
-- confuse, so: `add` terms are summed and applied first, `mul` factors are
-- multiplied and applied after. That order is fixed across the whole game, so
-- that two teams holding the same upgrades in a different sequence arrive at the
-- same numbers.
--
-- `reaches` is the field that makes placing into a lane a decision about
-- *composition* rather than only about quantity, because a lane's upgrades only
-- reach the half of a wave they match:
--
--   1 -- melee bodies only
--   2 -- ranged bodies only
--   3 -- both
--
-- The same field is read again when the kind is slotted into a lane's stone,
-- where it means something that rhymes rather than something identical: melee
-- upgrades are delivered to the tower's *guards*, ranged upgrades to the tower
-- *itself*, and common ones to both. A tower is a thing that shoots from a
-- distance and a guard is a body standing in front of it, so the split falls out
-- of what they are rather than being a second rule to remember.
--
-- `lane` is what the kind does to the **deck** of a lane it is slotted into (issue
-- 213, its second half): **an upgrade is a change to what a lane raises**, read once
-- a wave from whatever the lane holds at that moment. Some mixture of:
--
--   ticket = row    -- one more ticket for that unit's entry: it turns up more often
--   resource = n    -- n more tickets turned a wave: more troops, or heavier ones
--   trade = {from = row, to = row}
--                   -- an entry unlocked at the cost of an old one, the one it takes
--                   -- its equipment from. As many tickets move as the old entry
--                   -- costs bare, and the lane gains as many points a wave as the
--                   -- pieces the new one carries beyond the old one cost -- the
--                   -- design's own arithmetic, so neither is a number here.
--
-- Which kind does which is chosen by Claude, open for Ritz: a melee kind feeds a line
-- entry, a ranged kind a missile entry, and the common ones the purse -- with two
-- exceptions, Whetstone feeding light infantry and Boots skirmishers, so that every
-- entry a lane starts with has some upgrade that makes it turn up more.
--
-- The `add` and `mul` stamping onto wave bodies is **kept** alongside this. The design
-- says an upgrade "is not a stat bonus applied to a lane"; the chest, the captain rule
-- and doc 010 all still say it is. Both hold until Ritz picks.

local M = {}

-- {{{ M.kind
M.kind = {

  {
    name    = "Whetstone",
    glyph   = "W",
    colour  = {0.93, 0.72, 0.30},
    reaches = 3,
    add     = { damage = 5 },
    mul     = {},
    tower   = { damage = 9 },
    lane    = {ticket = 20},
  },

  {
    name    = "Plate",
    glyph   = "P",
    colour  = {0.62, 0.68, 0.78},
    reaches = 1,
    add     = { armour = 2 },
    mul     = {},
    -- A melee kind, so in stone it reaches the guards. What it gives a tower is
    -- another body standing under it rather than a tougher tower, which is the
    -- same idea one level out.
    tower   = { guard_cap = 1 },
    lane    = {ticket = 19},
  },

  {
    name    = "Rations",
    glyph   = "R",
    colour  = {0.55, 0.79, 0.44},
    reaches = 3,
    add     = { health = 34 },
    mul     = {},
    tower   = { health = 190 },
    lane    = {resource = 1},
  },

  {
    name    = "Longbow",
    glyph   = "L",
    colour  = {0.51, 0.77, 0.85},
    reaches = 2,
    add     = { range = 26, acquire_range = 26 },
    mul     = {},
    tower   = { range = 34 },
    lane    = {ticket = 22},
  },

  {
    name    = "Boots",
    glyph   = "B",
    colour  = {0.86, 0.55, 0.36},
    reaches = 3,
    add     = { speed = 0.13 },
    mul     = {},
    -- Stone does not walk. A kind with nothing to give a tower gives it nothing,
    -- and that is a real placement decision rather than a gap in the table:
    -- Boots in a lane is a push, Boots in stone is a wasted slot.
    tower   = {},
    lane    = {ticket = 21},
  },

  {
    name    = "Drums",
    glyph   = "D",
    colour  = {0.80, 0.44, 0.52},
    reaches = 3,
    -- Cooldown is the one stat where smaller is stronger, so its multiplier sits
    -- below one. Worth the comment because every other mul in this table is
    -- above one and this row looks like a typo next to them.
    add     = {},
    mul     = { cooldown_max = 0.86 },
    tower   = { cooldown_max = 0.88 },
    lane    = {resource = 1},
  },

  {
    name    = "Banner",
    glyph   = "N",
    colour  = {0.90, 0.42, 0.35},
    reaches = 3,
    add     = {},
    mul     = { damage = 1.16 },
    tower   = { damage_mul = 1.14 },
    lane    = {resource = 1},
  },

  {
    name    = "Bulwark",
    glyph   = "K",
    colour  = {0.47, 0.55, 0.72},
    reaches = 1,
    add     = {},
    mul     = { health = 1.22 },
    tower   = { guard_cap = 1 },
    lane    = {trade = {from = 20, to = 23}},
  },
}
-- }}}

-- {{{ M.deck
M.deck = {
  -- How many copies of each kind the shared deck is built from. Both teams draw
  -- from one sequence generated once at match start, so what the enemy holds is
  -- knowable in aggregate -- you learn *where they put it* by looking at what
  -- walks at you, and that is the whole of the fog.
  copies_per_kind = 6,

  -- What it costs to send a stone to the bottom of the deck and take the next card.
  --
  -- **The only thing personal resource can do to the chest**, and it trades rather
  -- than adds -- resource can never buy an upgrade outright. Priced in two colours
  -- like a hero, and deliberately cheap next to one: a reroll should be the thing
  -- you do with an awkward remainder rather than a purchase you save for.
  reroll_cost = {[3] = 1, [6] = 1},
}
-- }}}

return M
