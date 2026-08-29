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

-- 053-commander-table.lua
--
-- Commanders, the colours their bodies pay in, and the heroes they may buy.
--
-- **A commander is not a body on the map.** There is no avatar to move, no
-- commander health bar, and nothing to kill. A commander is four things: a
-- captain, a proportion, a bounty, and a roster.
--
-- Melee and ranged bodies are identical for every commander in the game -- a
-- knight and a barbarian are the same body with different art. So adding a
-- commander is choosing proportions, colours and a signature, rather than
-- balancing three new stat blocks against everything that already exists.

local M = {}

-- {{{ M.colour
-- Resource is not one number. There are as many kinds as there are attribute
-- scores, each with a colour -- and each with its own **display shape**, which is
-- written down as an accessibility requirement and is worth reading as a design
-- principle: **never encode meaning in hue alone.**
--
-- A bar, pips one to six, a flowing script, a playing card with a suit. Somebody
-- who cannot tell the red from the green can still tell the pips from the card.
M.colour = {
  {name = "might",  shape = "pips",   rgb = {0.88, 0.36, 0.32}},
  {name = "grace",  shape = "bar",    rgb = {0.42, 0.78, 0.56}},
  {name = "wit",    shape = "script", rgb = {0.46, 0.66, 0.92}},
  {name = "spirit", shape = "card",   rgb = {0.80, 0.60, 0.92}},
  {name = "vigour", shape = "block",  rgb = {0.92, 0.70, 0.30}},
  {name = "luck",   shape = "ring",   rgb = {0.60, 0.84, 0.88}},
}
-- }}}

-- {{{ M.ceiling
-- How much of one colour a player may hold, by rung.
--
-- The ladder is dice. A wallet starts small and climbs as the match runs, topping
-- out at a d12 -- five rungs, and no further. **Income arriving at a full colour is
-- lost**: not stored, not carried, not converted. Spend it or waste it.
--
-- That is the limiter on the hero economy, and it is deliberately a limit on
-- *hoarding* rather than a limit on how many heroes may be alive. There is no cap
-- on heroes at all.
M.ceiling = {4, 6, 8, 10, 12}

-- How many ticks between one rung and the next. The ladder climbs on the match
-- clock rather than on anything a player does, so both sides climb together and
-- nobody can out-bank anybody.
M.rung_interval = 2400
-- }}}

-- {{{ M.commander
-- | Field | Meaning |
-- | --- | --- |
-- | `captain` | Row in the unit table. Its signature body, and the only wave unit that differs between commanders. |
-- | `melee_share` | What proportion of a wave is melee. The rest is ranged. |
-- | `bounty` | Which colours its bodies carry, and in what ratio. Killing them pays this. |
-- | `roster` | Rows in the unit table. The heroes this commander may buy. |
M.commander = {

  {
    name        = "the paladin",
    captain     = 5,          -- a priest: the ranged captain
    melee_share = 0.62,
    -- Three spirit for every two grace and one wit. You farm what the enemy
    -- fields, so a team facing this commander is paid mostly in spirit -- and what
    -- they can afford is decided by who they are fighting.
    --
    -- **Between them, the two commanders have to cover every colour any hero's bill
    -- names.** The first draft had both of them paying might and neither paying
    -- wit, which made two of the five heroes on the paladin's own roster impossible
    -- to buy in any match -- not rare, not expensive: impossible, silently, with no
    -- refusal to read because nobody could get far enough to be refused.
    --
    -- The right reading of that is not "make every commander pay every colour". It
    -- is that a *pair* of commanders defines an economy, and the catalogue owes a
    -- check that the pairing can pay for the rosters it offers.
    bounty      = {[4] = 3, [2] = 2, [3] = 1},
    roster      = {6, 9, 12, 13, 10},
  },

  {
    name        = "the savage noble",
    captain     = 3,          -- a hobgoblin: the melee captain
    melee_share = 0.74,
    bounty      = {[1] = 3, [5] = 2, [6] = 1},
    roster      = {11, 7, 8, 14, 15},
  },
}
-- }}}

-- {{{ M.hero_cost
-- What each hero costs, by unit table row.
--
-- Costs are **vectors, not prices**. A hero that wants two colours cannot be
-- bought by a player who has been paid only in one, however much of it they hold,
-- which is what makes the enemy's commander selection reach into your purchases.
--
-- All heroes are roughly equivalent in strength; what differs is the shape of the
-- bill and what the thing does. What is copied from the games that do this well is
-- the relationship graph, not the numbers.
M.hero_cost = {
  [6]  = {[1] = 3, [5] = 2},          -- bulwark knight: might and vigour
  [7]  = {[1] = 2, [2] = 3},          -- storm lancer: might and grace
  [8]  = {[5] = 4, [1] = 2},          -- siege ram: vigour, mostly
  [9]  = {[4] = 4, [3] = 1},          -- sunlight paladin: spirit
  [10] = {[2] = 3, [3] = 2},          -- longbow ranger: grace and wit
  [11] = {[1] = 4, [4] = 2},          -- coal warden: might and spirit
  [12] = {[4] = 3, [3] = 2},          -- priest: spirit and wit
  [13] = {[2] = 3, [4] = 2},          -- druid: grace and spirit
  [14] = {[4] = 2, [6] = 3},          -- curse-doctor: spirit and luck
  [15] = {[3] = 2, [6] = 3},          -- rain shaman: wit and luck
}
-- }}}

-- {{{ M.ability
-- An ability is a **(condition, effect, cooldown) triple** assembled from two
-- tables. There is no cast key and no targeting cursor: an ability fires by itself
-- when its cooldown is ready and its condition is met.
--
-- That is what concentrates a hero's whole personality into its condition. With
-- nothing able to intervene, two heroes with identical stats and different
-- conditions are two genuinely different purchases -- and there is nowhere else for
-- the design effort to go.
M.ability = {
  guard_the_line = {condition = "allies_hurt_nearby", effect = "shield",  cooldown = 210, power = 60,  radius = 90},
  cleave         = {condition = "enemies_crowded",    effect = "splash",  cooldown = 150, power = 34,  radius = 74},
  sunder         = {condition = "structure_in_reach", effect = "breach",  cooldown = 120, power = 130},
  mend           = {condition = "ally_soonest_to_die",effect = "heal",    cooldown = 110, power = 90,  radius = 128},
  volley         = {condition = "enemies_crowded",    effect = "splash",  cooldown = 190, power = 26,  radius = 96},
  dread          = {condition = "enemies_crowded",    effect = "wither",  cooldown = 170, power = 18,  radius = 104},

  -- The five that mend. Each pairs a **different chooser** with an effect, which is
  -- the whole of what makes them five units rather than five numbers -- the matching
  -- problem is present, spread, absent, inverted and sequential in turn.
  mend_deeply    = {condition = "priest_target",       effect = "heal",       cooldown = 100, power = 130, radius = 132},
  regrowth       = {condition = "druid_target",        effect = "regenerate", cooldown = 70,  power = 5,   radius = 128, duration = 300},
  sunlight       = {condition = "allies_hurt_nearby",  effect = "shield",     cooldown = 150, power = 55,  radius = 118},
  affliction     = {condition = "curse_target",        effect = "curse",      cooldown = 140, power = 8,   radius = 150, duration = 420},
  chain_tide     = {condition = "shaman_target",       effect = "chain",      cooldown = 160, power = 60,  radius = 140, bounces = 4},

  -- The druid's one offensive spell, and the only thing in the game with a **line of
  -- sight** condition on it. A spike of moonlight thrown flat from the palm, so its
  -- own side's rank is in the way of it in a manner an arrow's arc is not.
  --
  -- It aims **opposite to everything else the healers do**: every mending rule here
  -- reaches for the ally closest to dying, and this reaches for the enemy furthest
  -- from it. A druid mends what is nearly gone and attacks what is barely touched,
  -- which is a temperament rather than two unrelated buttons.
  moon_spike     = {condition = "moon_target",         effect = "wither",     cooldown = 130, power = 7,   radius = 150, duration = 360},
}
-- }}}

return M
