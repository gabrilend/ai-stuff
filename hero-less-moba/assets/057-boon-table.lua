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

-- 057-boon-table.lua
--
-- The three named things that come out of the middle, what killing two of them
-- pays, and how long each stretch of a match lasts.
--
-- **There are three challenges in a match and they are always the same three, in
-- the same order.** A fixed, named sequence rather than a random draw: a player who
-- has played one match knows what is coming in the next and can build toward it,
-- which is the same reasoning that put the surge on a visible clock. The escalation
-- is the point -- the first two can be beaten, and then the third one cannot.

local M = {}

-- {{{ M.challenge
-- Which body walks out, and whether killing it pays anything.
M.challenge = {
  {archetype = 12, name = "the Pillar Orc",    pays_a_boon = true},
  {archetype = 13, name = "the Field Dragon",  pays_a_boon = true},
  -- Pays nothing, cannot be killed, and ends the match by arriving. **The deadline
  -- is the walk.** There is no separate timer, because a timer is a number on a
  -- panel and a monster walking down the centre lane is a thing you can see -- a
  -- player who has never read a rules screen knows exactly how long is left,
  -- because the time left is distance.
  {archetype = 14, name = "the Eternal Golem", pays_a_boon = false},
}
-- }}}

-- {{{ M.timing
-- Every duration in the shape of a match, in ticks.
M.timing = {
  -- How long the first ordinary stretch runs before the first surge. Longer than
  -- the others, so a match has time to develop a board worth disturbing.
  first_normal = 5400,
  -- Between one challenge ending and the next surge beginning.
  normal       = 4200,
  -- Long enough that a team's arrangement genuinely stops mattering, short enough
  -- that it is a disruption rather than a different game.
  surge        = 1500,
  -- The quiet stretch after a slain monster, in which the map empties and each
  -- player picks a boon.
  calm         = 900,
}
-- }}}

-- {{{ M.stream
-- The surge's spawn shape.
--
-- **One body per lane, on one shared timer** -- all lanes fire at the same instant,
-- so a surge produces bodies in threes. That is not tidiness: it is what makes the
-- dealing possible, because at every spawn there are exactly three new bodies and
-- the whole holding can be split across them.
M.stream = {
  interval = 15,
}
-- }}}

-- {{{ M.boon
-- What killing a monster pays.
--
-- **Boons are the thing that reaches everybody.** They are not in a lane and have
-- no slot, so there is no placement decision for them to multiply with -- which is
-- exactly why they are allowed where a lane upgrade is not. A boon is best
-- understood as a modifier on the commander that radiates out to everything that
-- team fields, heroes included. Monsters get none, having no team to belong to.
--
-- Each player picks **one of two**, offered from this list.
M.boon = {
  {name = "Sharpened",  glyph = "S", colour = {0.93, 0.72, 0.30}, add = {damage = 4}},
  {name = "Hardened",   glyph = "H", colour = {0.62, 0.68, 0.78}, add = {armour = 2}},
  {name = "Enduring",   glyph = "E", colour = {0.55, 0.79, 0.44}, mul = {health = 1.15}},
  {name = "Quickened",  glyph = "Q", colour = {0.86, 0.55, 0.36}, add = {speed = 0.09}},
  {name = "Relentless", glyph = "R", colour = {0.80, 0.44, 0.52}, mul = {cooldown_max = 0.9}},
  {name = "Farsighted", glyph = "F", colour = {0.51, 0.77, 0.85}, add = {range = 14, acquire_range = 14}},
}

-- How many a player is offered. Two, not three -- a choice between two is a
-- decision and a choice between six is a menu.
M.boon_offer = 2
-- }}}

return M
