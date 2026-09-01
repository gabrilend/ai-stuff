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
  -- {{{ dinosaur
  --
  -- A body wider than one cell, and that is the whole of what is different about
  -- it. The same graph, the same step, the same timing -- with the enterability
  -- check applied to every cell of its footprint instead of one.
  --
  -- The consequence is the most interesting thing about them sharing a maze: a
  -- one-cell corridor does not admit a three-cell animal, so the little guys
  -- have a whole network of boltholes and nobody added it. It was in the maze all
  -- along.
  {
    name        = "dino",
    locomotion  = M.STRIDING,
    radius      = 1.0,        -- a three-by-three footprint
    body_height = 2,
    drop_limit  = 1,
    health      = 60,
    team        = 0,

    step_seconds   = 0.72,    -- heavy. Slower than a little guy by half again.
    reverse_weight = 0.25,    -- a big animal turns around more readily than a
                              -- small one, having fewer places to go
    crowd_weight   = 0.04,
    idle_chance    = 0.14,
    errand_chance  = 0.03,
    notice_seconds = 2.0,
    search_budget  = 2500,

    sight_range    = 26,      -- in cells
    sight_interval = 0.5,     -- seconds between sight checks

    -- Games. Nothing here knows it is playing: these are the numbers of a state
    -- machine that two or more bodies share.
    -- A dinosaur carries a weapon, and **only while navigating the dungeon** --
    -- which is the reading taken of that half of the sentence. Outside the
    -- delve these numbers are still here and nothing opposes it, so nothing
    -- happens; a dinosaur in the habitat has nobody to swing at.
    --
    -- Long reach is the field that changes behaviour rather than numbers: it
    -- lets a dinosaur fight down a corridor it cannot itself enter, which is a
    -- mounted party's answer to the narrow places it cannot go.
    weapon            = "blunt",
    exchange_seconds  = 0.85,
    skill             = 0.60,
    parry             = 0.46,
    swing             = 0.55,
    damage            = 7.0,
    reach             = 2,
    stalemate_seconds = 30,
    disengage_seconds = 0,

    game_chance      = 0.35,  -- of a meeting between two of them becoming one
    game_seconds     = 40,    -- the clock every game ends on
    grace_seconds    = 2.5,   -- after a tag, before the roles may swap back --
                              -- without it they swap every tick while the two of
                              -- them are standing next to each other
    give_up_distance = 34,    -- a chase across half the maze is not a chase
    count_seconds    = 6,     -- how long the seeker counts, facing a wall
  },
  -- }}}

  -- {{{ fencer
  --
  -- A little guy with a sword and a side. Walks the same graph, idles the same
  -- way, and stops doing both when a duel takes hold of it.
  --
  -- A separate kind rather than the little guy with a field set, which is open
  -- question 11 answered for now in the cheap direction: a kind is a row, and
  -- rows are cheap. Turning them back into one is deleting a row.
  {
    name        = "fencer",
    locomotion  = M.WALKING,
    radius      = 0.30,
    body_height = 1,
    drop_limit  = 1,
    health      = 14,
    team        = 0,          -- assigned at spawn from team_count
    team_count  = 2,

    step_seconds   = 0.38,
    reverse_weight = 0.15,
    crowd_weight   = 0.06,
    idle_chance    = 0.05,
    errand_chance  = 0.05,    -- fencers go looking. A crowd that only wanders
                              -- meets by accident; one on errands meets on
                              -- purpose, and a duel needs two of them to meet.
    notice_seconds = 1.5,
    search_budget  = 2500,

    -- The exchange.
    exchange_seconds  = 0.55,   -- one blow thrown, by one of them, this often
    skill             = 0.50,   -- the attacker's base
    parry             = 0.42,   -- the defender's. Below skill, or nothing lands.
    swing             = 0.55,   -- how much of each is luck
    damage            = 3.0,
    stalemate_seconds = 26,     -- two well-matched fencers will otherwise stand
                                -- there until the machine is turned off, and the
                                -- camera watching them has nothing to swap to
    -- Zero: a released fencer re-engages immediately and the fight rolls on.
    --
    -- This was open question 1, and it is answered: *the fencers* swap to a new
    -- opponent, not the camera. A corridor becomes a running brawl and the camera
    -- never has to move to keep watching one.
    --
    -- The number is still a knob, and above zero it is a series of separate
    -- duels with the camera going looking between them. Both behaviours have
    -- tests. This is the default because it is what was meant.
    disengage_seconds = 0,
  },
  -- }}}
  -- {{{ human
  --
  -- One cell wide, goes anywhere, weak. Half of the delve's geometry: the
  -- corridors a human can use alone are the ones a dinosaur cannot follow it
  -- down.
  {
    name        = "human",
    locomotion  = M.WALKING,
    radius      = 0.28,
    body_height = 1,
    drop_limit  = 1,
    health      = 12,
    team        = 1,

    step_seconds   = 0.36,
    reverse_weight = 0.15,
    crowd_weight   = 0.06,
    idle_chance    = 0.04,
    errand_chance  = 0.06,
    notice_seconds = 1.5,
    search_budget  = 2500,
    sight_range    = 22,
    sight_interval = 0.5,

    flammable      = 0.15,    -- carries things that burn
    fuel           = 3.0,
    mounts         = true,    -- will climb a willing dinosaur

    -- Armed. A human alone is not much, and against a golem it is nothing at
    -- all -- which is the point of there being dinosaurs.
    weapon            = "fire",   -- a torch. The party's only answer to a vine.
    exchange_seconds  = 0.60,
    skill             = 0.52,
    parry             = 0.40,
    swing             = 0.50,
    damage            = 2.6,
    reach             = 1,
    stalemate_seconds = 30,
    disengage_seconds = 0,
  },
  -- }}}

  -- {{{ stone golem
  --
  -- Made of the maze. Not standing in the corridor -- it *is* corridor, walking.
  -- The only thing in the project that changes the stone after generation, which
  -- is why the surface array is recomputed rather than assumed constant and why
  -- nothing anywhere caches the graph.
  {
    name        = "golem",
    locomotion  = M.LUMBERING,
    radius      = 1.0,
    body_height = 2,
    drop_limit  = 3,
    health      = 400,        -- nothing a party carries hurts stone
    team        = 2,

    step_seconds   = 1.05,
    reverse_weight = 0.3,
    crowd_weight   = 0.5,     -- it does not much mind what is in the way
    idle_chance    = 0.05,
    errand_chance  = 0.10,
    notice_seconds = 3.0,
    search_budget  = 1200,
    sight_range    = 20,
    sight_interval = 0.7,

    flammable      = 0,       -- stone does not burn
    breaks_stone   = true,
    break_seconds  = 1.4,     -- how long one block takes

    weapon            = "blunt",
    exchange_seconds  = 1.10,
    skill             = 0.66,
    parry             = 0.30,   -- it does not dodge; it does not need to
    swing             = 0.50,
    damage            = 9.0,
    reach             = 1,
    stalemate_seconds = 40,
    disengage_seconds = 0,

    -- Stone. A blade chips it, fire does nothing at all, and a heavy blow is
    -- the only thing that really tells -- which is why a party without a
    -- dinosaur is not going to win this one.
    resist = { blade = 0.20, fire = 0.0, blunt = 1.0 },
  },
  -- }}}

  -- {{{ vine monster
  --
  -- Grows along walls rather than walking on floors, and holds what it reaches.
  -- The most flammable thing in the maze, and the only monster whose answer is
  -- not another monster's body.
  {
    name        = "vine",
    locomotion  = M.CREEPING,
    radius      = 0.34,
    body_height = 1,
    drop_limit  = 99,         -- a vine falls down a cliff face and keeps growing
    health      = 40,
    team        = 2,

    step_seconds   = 0.62,
    reverse_weight = 0.2,
    crowd_weight   = 0.3,
    idle_chance    = 0.02,
    errand_chance  = 0.04,
    notice_seconds = 2.0,
    search_budget  = 1800,
    sight_range    = 14,
    sight_interval = 0.6,

    flammable      = 1.0,     -- the most of anything here
    fuel           = 7.0,
    entangles      = true,
    hold_seconds   = 6.0,

    weapon            = "blade",   -- thorns
    exchange_seconds  = 0.75,
    skill             = 0.50,
    parry             = 0.52,      -- there is a great deal of it to cut through
    swing             = 0.55,
    damage            = 1.6,
    reach             = 1,
    stalemate_seconds = 30,
    disengage_seconds = 0,

    -- Growing plant. Fire is devastating and a hammer mostly pushes it about.
    resist = { blade = 1.0, fire = 3.2, blunt = 0.35 },
  },
  -- }}}

  -- {{{ wooden machine automaton
  --
  -- Not steam powered. A machine made of wood whose power is to set things
  -- alight -- and which is therefore, being wood, the thing most likely to be
  -- set alight by what it did. Nothing in the code arranges that.
  {
    name        = "automaton",
    locomotion  = M.WALKING,
    radius      = 0.40,
    body_height = 1,
    drop_limit  = 1,
    health      = 26,
    team        = 2,

    step_seconds   = 0.50,
    reverse_weight = 0.2,
    crowd_weight   = 0.1,
    idle_chance    = 0.03,
    errand_chance  = 0.08,
    notice_seconds = 2.0,
    search_budget  = 2000,
    sight_range    = 18,
    sight_interval = 0.4,

    flammable      = 0.85,    -- it is made of wood
    fuel           = 9.0,
    ignites        = true,
    ignite_seconds = 2.2,     -- between one ignition and the next
    ignite_range   = 5,       -- it is not a projectile; this is reach, not flight

    weapon            = "blunt",
    exchange_seconds  = 0.65,
    skill             = 0.58,
    parry             = 0.44,
    swing             = 0.50,
    damage            = 3.4,
    reach             = 1,
    stalemate_seconds = 30,
    disengage_seconds = 0,

    -- Wood. It splits under a blade, it burns, and a stone fist ends it.
    resist = { blade = 1.4, fire = 2.6, blunt = 1.8 },
  },
  -- }}}
}
-- }}}

-- {{{ M.BURNS
-- Fire, as numbers.
--
-- Ignite is a **state**, not an event. A fireball happens at a place and is over;
-- a thing that is ignited stays ignited, loses fuel, and sets fire to what is
-- beside it. That distinction was made explicitly when the mode was asked for,
-- and it is the whole reason fire is a tick pass rather than a function call.
M.BURNS = {
  damage_per_second = 3.2,
  spread_chance     = 0.24,   -- per second, per flammable neighbour
  spread_range      = 1,      -- cells. Fire does not jump gaps.
}
-- }}}

-- {{{ M.CHART
-- What hurts what, as a multiplier on damage.
--
-- The chart lives in each monster's `resist` field; this is the same thing
-- gathered in one place so that a person can read it, and so that
-- `./run-maze --describe` can print it.
--
-- "Solve" was meant loosely: the monsters are enemies with health rather than
-- locks with keys, and the cycle between the three of them is this table rather
-- than the point of the mode. It is still a cycle, and it still means a party
-- without a dinosaur is not going to win against stone.
--
--                blade    fire    blunt
--   golem         0.20    0.00     1.00     stone. only weight tells.
--   vine          1.00    3.20     0.35     a plant. fire ruins it.
--   automaton     1.40    2.60     1.80     wood. everything works.
--
-- And what the party brings: a human carries fire, a dinosaur carries weight.
-- Neither alone is an answer to all three.
M.CHART = { "blade", "fire", "blunt" }
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
  guy       = { 5, 4, 1, 2, 3, 1 },
  human     = { 4, 6, 2, 1, 3, 0 },
  golem     = { 8, 2, 0, 0, 0, 0 },   -- stone breathes, slowly, and little else
  vine      = { 9, 1, 0, 0, 0, 0 },
  automaton = { 3, 7, 0, 0, 2, 0 },   -- it looks around a great deal
  fencer = { 4, 6, 2, 1, 2, 0 },   -- looks around more, never sits
  dino   = { 6, 3, 1, 0, 0, 5 },   -- breathes and suns itself
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
  fencers  = { fencer = 600 },
  habitat  = { dino = 90 },
  jungle   = { dino = 70, guy = 300 },

  -- The delve. Humans and dinosaurs against three monsters that undo each other.
  delve    = { human = 120, dino = 40, golem = 10, vine = 40, automaton = 25 },
  golems   = { human = 60, golem = 20 },
  burning  = { human = 40, vine = 80, automaton = 30 },
  war      = { fencer = 900, guy = 200 },
  empty    = {},
}
-- }}}

return M
