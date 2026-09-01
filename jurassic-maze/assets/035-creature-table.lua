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
    crowd_weight   = 0.06,   -- how much less likely a step into an occupied cell
                             -- is. Never zero, for the same reason: in a corridor
                             -- with somebody coming the other way, refusing
                             -- outright means both of them stand there forever.
    idle_chance    = 0.09,   -- per arrival
    errand_chance  = 0.02,   -- per arrival, a decision to go somewhere in
                             -- particular rather than nowhere. A wandering body
                             -- never arrives, so nothing it does ever finishes,
                             -- and the camera has no moment to notice.
    notice_seconds = 1.5,
    search_budget  = 2500,   -- surfaces examined before a search gives up and
                             -- the body falls back to wandering. Counted, never
                             -- silent.
  },
  -- }}}
}
-- }}}

-- {{{ M.IDLES
-- An idle is a row with a clock. There is no animation system here and there is
-- not going to be one.
--
-- The simulation's whole involvement is which row and how much of its clock is
-- left. Everything visible about it is arithmetic in the renderer driven by the
-- fraction elapsed, so an idling body costs one timer decrement per tick -- which
-- is what lets there be a great many of them.
--
--   low, high   how long it runs, in seconds
--   bob         how far the drawn height oscillates, in layers
--   rate        oscillations per second
--   turn        whether facing rotates a quarter turn at a time while it runs
--   squat       a constant offset to the drawn height, in layers
M.IDLES = {
  -- The default, and the one that matters. A genuinely motionless body reads as
  -- a bug -- the eye assumes something crashed. A body whose drawn height moves
  -- by a twentieth of a layer on a slow cycle reads as alive, and nobody
  -- notices why.
  { name = "breathe",     low = 2.0, high = 6.0, bob = 0.05, rate = 0.55 },
  { name = "look_around", low = 1.6, high = 4.0, bob = 0.02, rate = 0.4, turn = true },
  { name = "stretch",     low = 0.8, high = 1.6, bob = 0.22, rate = 1.1 },
  { name = "crouch",      low = 0.7, high = 1.8, bob = 0.04, rate = 0.6, squat = -0.28 },
  { name = "scratch",     low = 0.5, high = 1.2, bob = 0.10, rate = 3.4 },
  { name = "sit",         low = 4.0, high = 11.0, bob = 0.02, rate = 0.3, squat = -0.42 },
}
-- }}}

-- {{{ M.IDLE_WEIGHTS
-- Which idles a kind chooses, and how often. Weights per creature name, in the
-- order M.IDLES lists them.
--
-- A nervous little guy scratches and looks around. A sunning dinosaur sits.
M.IDLE_WEIGHTS = {
  guy = { 5, 4, 1, 2, 3, 1 },
}
-- }}}

-- {{{ function M.pick_idle(rng, kind_name)
-- One idle row, and how long it runs. Drawn from the `idle` stream, weighted.
function M.pick_idle(rng, kind_name)
  local weights = M.IDLE_WEIGHTS[kind_name]
  if not weights then return 1, M.IDLES[1].low end

  local total = 0
  for _, w in ipairs(weights) do total = total + w end

  local roll = rng:next_float() * total
  local running = 0
  for index, w in ipairs(weights) do
    running = running + w
    if roll <= running then
      local row = M.IDLES[index]
      return index, row.low + rng:next_float() * (row.high - row.low)
    end
  end
  return 1, M.IDLES[1].low
end
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
-- The numbers are a density, not a count, and the density is what decides
-- whether anything happens between two bodies at all. Two hundred walkers in
-- nine thousand floor cells is two percent occupancy, and two of them are
-- adjacent about six times a minute -- so the shared idle, which is most of what
-- phase four built, essentially never fires.
M.POPULATIONS = {
  balls    = { ball = 300 },
  guys     = { guy = 700 },
  both     = { ball = 260, guy = 480 },
  crowd    = { guy = 1400 },     -- shoulder to shoulder, for watching the meeting
  empty    = {},
}
-- }}}

return M
