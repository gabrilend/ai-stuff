-- jurassic-maze — a simulation living inside an isometric maze of stacked stone
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

-- 035-creature-table.lua
--
-- Every number that distinguishes one creature from another.
--
-- This file and 028-maze-parameters.lua hold every balance number in the
-- project, and no document restates one of them. A page that says "balls roll at
-- four cells a second" is a page that is wrong the first time somebody tunes it,
-- and it will be believed anyway because it is written down.
--
-- Why a number was changed goes in docs/balance-updates.md, appended, never
-- edited. What it is now is here.

local M = {}

-- The locomotion rows, by name. The numbers are indices into the dispatch table
-- in 036-locomotion.lua; naming them here means a creature row says how it moves
-- in words rather than as a magic integer.
M.ROLLING   = 1
M.WALKING   = 2
M.STRIDING  = 3
M.LUMBERING = 4
M.CREEPING  = 5
M.CARRIED   = 6
M.STILL     = 7

-- {{{ M.KINDS
-- One row per creature. `name` is what the palette and the report call it.
--
-- Fields every kind has:
--   locomotion    which row of the dispatch table moves it
--   radius        in cells; decides its footprint and what it collides with
--   body_height   in layers; how much headroom it needs to enter a cell
--   drop_limit    how far it may descend before that is falling rather than
--                 stepping. Per creature, because falling is not climbing --
--                 a body may go down further than it can come up.
--   health, team  for the phases that have fighting in them
M.KINDS = {
  -- {{{ ball
  {
    name        = "ball",
    locomotion  = M.ROLLING,
    radius      = 0.40,      -- comfortably under half a cell, so it fits down a
                             -- one-cell corridor with clearance on both sides
    body_height = 1,
    drop_limit  = 1e9,       -- none at all. What a walker treats as a wall to
                             -- route around, a ball treats as the interesting
                             -- part and goes over.
    health      = 1,
    team        = 0,

    gravity        = 45,     -- cells per second squared. Not real gravity; a
                             -- cell is not a metre.
    roll_friction  = 0.10,   -- per second. Some is needed or the aquarium fills
                             -- with balls oscillating in the bottom of every dip
                             -- forever; much more than this and they stop before
                             -- they have found a way down.
    -- Bouncy, and deliberately not realistic.
    --
    -- Stone against stone would be somewhere near a third, and at a third a ball
    -- loses nearly all its energy on the first wall it meets -- in a maze made
    -- entirely of walls, which it meets within a cell or two of being dropped.
    -- Measured over nine hundred ticks: at 0.32 the average ball travels two
    -- cells and thirty-six of them are motionless; at 0.85 it travels seventeen
    -- and one is. The whole aquarium is the difference.
    restitution    = 0.85,
    bounce_floor   = 0.7,    -- below this a bounce is set to zero. Without it a
                             -- ball performs several hundred invisible bounces a
                             -- second forever, each one a landing event.
    max_speed      = 8.0,    -- one tick at this speed moves 0.13 cells, well
                             -- under the radius. This is what stops a ball
                             -- passing a wall without ever being within radius
                             -- of it, and it is why the timestep is fixed.
    rest_seconds   = 3.5,    -- how long it sits still before the aquarium takes
                             -- it away and drops a new one in at the top
    slope_gain     = 1.0,
  },
  -- }}}

  -- {{{ little guy
  {
    name        = "guy",
    locomotion  = M.WALKING,
    radius      = 0.30,
    body_height = 1,
    -- One layer, not two.
    --
    -- A wall stands two layers above its corridor and a terrace four above the
    -- one below it, so a drop limit of two would let a walker step off a terrace
    -- edge onto the top of a wall and then walk along it. There is no wall
    -- height that avoids that while staying unclimbable from below, so the limit
    -- goes here instead: a walker moves only where the maze is mutually
    -- reachable, which is exactly the connectivity the validator checks.
    drop_limit  = 1,
    health      = 10,
    team        = 0,

    step_seconds   = 0.42,   -- one cell per step. Slow enough to read as walking
                             -- rather than sliding.
    reverse_weight = 0.15,   -- an unweighted random walk goes back and forth
                             -- across two cells and looks broken. Never zero: a
                             -- body in a dead end must be able to turn around.
    idle_chance    = 0.09,   -- per arrival
    notice_seconds = 1.5,
    search_budget  = 4000,
  },
  -- }}}
}
-- }}}

-- {{{ function M.by_name(name)
function M.by_name(name)
  for index, kind in ipairs(M.KINDS) do
    if kind.name == name then return index, kind end
  end
  error("no creature named '" .. tostring(name) .. "' in the table")
end
-- }}}

-- {{{ M.POPULATIONS
-- How many of each kind the aquarium keeps alive, per scene.
--
-- A scene is a list, not a phase. Which kinds are present is a parameter of the
-- run rather than a property of what has been built -- balls and little guys can
-- share one maze, and the locomotion table is what makes that cost nothing.
M.POPULATIONS = {
  balls    = { ball = 260 },
  guys     = { guy = 200 },
  both     = { ball = 180, guy = 140 },
  empty    = {},
}
-- }}}

return M
