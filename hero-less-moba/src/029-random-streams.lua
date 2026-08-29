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

-- 029-random-streams.lua
--
-- Randomness in this project is never global and never taken from the clock. The
-- world holds a small set of *named* streams, each a seeded generator that
-- advances only when its own system asks it to.
--
-- The reason for splitting them, stated once here because it is the entire
-- argument for the file existing: if every random call came out of one stream,
-- then a cosmetic change to how tower guards choose where to wander would shift
-- every later draw from the chest, and no two runs of the "same" match would
-- agree about anything. With separate streams the draw sequence for a given seed
-- is stable no matter what else in the project is edited.
--
-- The generator is xorshift32, done through LuaJIT's bit library. It is not a
-- cryptographic generator and does not need to be -- what is being asked of it
-- is that it be *the same every time*, which is a much weaker property than
-- being unpredictable, and the two are often confused.

local bit = require("bit")
local bxor, lshift, rshift, band = bit.bxor, bit.lshift, bit.rshift, bit.band

local M = {}

-- {{{ local function mix_name()
-- Turns a stream's name into an integer, so that two streams built from the same
-- match seed still start in different places.
--
-- This is the FNV-1a hash, chosen because it is four lines and its avalanche is
-- good enough that "draw" and "deck" do not land near each other. Nothing about
-- the choice is load-bearing; what is load-bearing is that it is *deterministic
-- and written down*, rather than being whatever the string library felt like.
local function mix_name(name)
  local hash = 2166136261
  for index = 1, #name do
    hash = bxor(hash, name:byte(index))
    -- The FNV prime, 16777619, expressed as shifts and adds because a plain
    -- multiply would leave the 53-bit float domain and stop being reproducible.
    hash = hash + lshift(hash, 1) + lshift(hash, 4) + lshift(hash, 7)
                + lshift(hash, 8) + lshift(hash, 24)
  end
  return hash
end
-- }}}

-- {{{ local function advance()
-- One xorshift32 step. Returns the new state.
--
-- The shift triple 13, 17, 5 is Marsaglia's; changing any of the three turns
-- this into a generator with a much shorter period, so they are not knobs.
local function advance(state)
  state = bxor(state, lshift(state, 13))
  state = bxor(state, rshift(state, 17))
  state = bxor(state, lshift(state, 5))
  return state
end
-- }}}

local Stream = {}
Stream.__index = Stream

-- {{{ function Stream:next_raw()
-- The next 31-bit non-negative integer. Everything else in this file is built on
-- this one call, so there is exactly one place where the generator advances.
function Stream:next_raw()
  self.state = advance(self.state)
  self.count = self.count + 1
  -- The sign bit is masked off rather than shifted away: LuaJIT's bit ops are
  -- signed 32-bit, and a negative state is perfectly good randomness that would
  -- become a negative index if it escaped.
  return band(self.state, 0x7fffffff)
end
-- }}}

-- {{{ function Stream:next_float()
-- A double in [0, 1).
function Stream:next_float()
  return self:next_raw() / 2147483648.0
end
-- }}}

-- {{{ function Stream:next_below()
-- An integer in 1..limit. Used for every "pick one of these" in the game.
--
-- The modulo bias here is real and is accepted: with limit never larger than a
-- few hundred and the raw value spanning 2^31, the bias is smaller than one part
-- in ten million, and rejection sampling would make the number of generator
-- steps depend on the values drawn -- which would make a replay depend on them
-- too. A fixed number of steps per call is worth more here than perfect
-- uniformity.
function Stream:next_below(limit)
  if limit < 1 then
    error("next_below asked for a number in 1.." .. tostring(limit))
  end
  return (self:next_raw() % limit) + 1
end
-- }}}

-- {{{ function Stream:shuffle()
-- Fisher-Yates, in place. Used to build the shared deck once at match start.
function Stream:shuffle(list)
  for index = #list, 2, -1 do
    local swap = self:next_below(index)
    list[index], list[swap] = list[swap], list[index]
  end
  return list
end
-- }}}

-- {{{ function M.new()
-- One stream, from a match seed and a name.
function M.new(seed, name)
  local state = bxor(seed, mix_name(name))
  -- xorshift has one fixed point and it is zero: a zero state produces zeros
  -- forever. It is reachable here only if the seed happens to equal the name's
  -- hash, which is rare and would be baffling, so it is redirected rather than
  -- left as a trap.
  if state == 0 then
    state = 0x2545F491
  end
  return setmetatable({ name = name, state = state, count = 0 }, Stream)
end
-- }}}

-- {{{ function M.make_set()
-- Every stream the simulation uses, built from one match seed.
--
-- The per-team streams are named with their team number folded into the name, so
-- that team 1's draws and team 2's draws are independent sequences -- otherwise
-- the two teams would alternate out of one sequence and each team's luck would
-- depend on how often the other one killed something.
function M.make_set(seed)
  return {
    -- Which upgrade comes out of the chest when a wave is wiped or a tower falls.
    draw    = { M.new(seed, "draw-1"), M.new(seed, "draw-2") },
    -- The one shared upgrade sequence both teams draw from, built once.
    deck    = M.new(seed, "deck"),
    -- Where a tower's guards choose to patrol.
    wander  = M.new(seed, "wander"),
    -- Breaking exact ties in target selection, so two identical soldiers do not
    -- both pick the leftmost enemy every single time.
    --
    -- One per team, for the same reason `draw` is: a shared tie stream makes each
    -- team's luck depend on how often the *other* team had a tie to break, which
    -- is a coupling between the two sides that nothing in the design asked for and
    -- that shows up as an unexplainable asymmetry in a match nobody touched.
    -- Three, not two. The monsters are their own team -- allied with nobody and
    -- hostile to everything -- and they break ties in target selection like
    -- anything else does. Indexing a two-entry table by team three is the kind of
    -- mistake that only surfaces the first time a challenge starts, several minutes
    -- into a match nobody was watching.
    tie     = { M.new(seed, "tie-1"), M.new(seed, "tie-2"), M.new(seed, "tie-3") },
    -- Which three boons a player is offered in the calm after a challenge.
    boon    = M.new(seed, "boon"),
    -- The deal order when the chest is dealt across a surge spawn.
    surge   = { M.new(seed, "surge-1"), M.new(seed, "surge-2") },
    -- Where each zone's waypoint sits inside it, so a road has a line through it
    -- rather than a centre a wave walks down exactly.
    --
    -- **One, not one per team**, which is the exception to the rule the tie and draw
    -- streams follow. Those are per team because they are drawn *during* a match and
    -- a shared stream would make one side's luck depend on how often the other side
    -- happened to ask. These are all drawn once, at assembly, in a fixed order, so
    -- there is nothing to couple.
    --
    -- And a waypoint belongs to the ground rather than to whoever is walking over
    -- it. Both armies follow the same line down a road, the way two columns of people
    -- follow the same worn path -- which also keeps the opening a mirror, because two
    -- first waves that wandered differently would be asymmetric before either had
    -- taken a step.
    waypoint = M.new(seed, "waypoint"),
  }
end
-- }}}

return M
