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

-- 029-random-streams.lua
--
-- Named seeded generators. The determinism guarantee everything else rests on.
--
-- There is no global generator here and nothing takes a number from the clock.
-- Each system draws from its own named stream, so that editing how a creature
-- idles cannot shift the draws that built the maze.

local bit = require("bit")

local M = {}

-- xorshift32. The shift triple 13, 17, 5 is Marsaglia's and is not a knob --
-- changing any of the three silently turns this into a generator with a
-- dramatically shorter period. It is not cryptographic and does not need to be:
-- what is asked of it is that it be the same every time, which is a much weaker
-- property than being unpredictable, and the two are constantly confused.
local SHIFT_A, SHIFT_B, SHIFT_C = 13, 17, 5

-- Zero is xorshift's fixed point and produces zeros forever. It is reachable
-- only when a seed happens to equal a stream name's hash, which is rare and
-- would be utterly baffling to debug, so it is redirected here rather than left
-- as a trap for somebody in six months.
local ZERO_ESCAPE = 0x9E3779B9

local Stream = {}
Stream.__index = Stream

-- {{{ local function hash_name(name)
-- Mixes a stream's name into a 32-bit value, so that two streams built from one
-- seed do not start in the same place and therefore do not produce the same
-- sequence.
local function hash_name(name)
  local h = 2166136261
  for i = 1, #name do
    h = bit.bxor(h, name:byte(i))
    -- The FNV prime, applied with shifts and adds rather than a multiply,
    -- because LuaJIT's multiply on a 32-bit pattern goes through a double and
    -- loses the top bits on some builds.
    h = bit.band(h + bit.lshift(h, 1) + bit.lshift(h, 4) + bit.lshift(h, 7)
                   + bit.lshift(h, 8) + bit.lshift(h, 24), 0xFFFFFFFF)
  end
  return h
end
-- }}}

-- {{{ function M.new(seed, name)
-- One stream. Everything else in this file is built on next_raw.
function M.new(seed, name)
  local state = bit.band(bit.bxor(seed, hash_name(name)), 0xFFFFFFFF)
  if state == 0 then
    state = ZERO_ESCAPE
  end
  return setmetatable({ name = name, state = state, count = 0 }, Stream)
end
-- }}}

-- {{{ function Stream:next_raw()
-- The next 31-bit non-negative integer. The count is not used by anything; it is
-- here because it is occasionally the fastest way to find out which system is
-- burning luck it should not be -- a count that climbs while nothing is
-- happening is a system drawing in its idle path.
function Stream:next_raw()
  local x = self.state
  x = bit.band(bit.bxor(x, bit.lshift(x, SHIFT_A)), 0xFFFFFFFF)
  x = bit.bxor(x, bit.rshift(x, SHIFT_B))
  x = bit.band(bit.bxor(x, bit.lshift(x, SHIFT_C)), 0xFFFFFFFF)
  self.state = x
  self.count = self.count + 1
  return bit.band(x, 0x7FFFFFFF)
end
-- }}}

-- {{{ function Stream:next_float()
-- A double in [0, 1).
function Stream:next_float()
  return self:next_raw() / 2147483648.0
end
-- }}}

-- {{{ function Stream:next_below(limit)
-- An integer in 1..limit.
--
-- The modulo bias here is real and it is accepted deliberately. With limits in
-- the low hundreds against a 2^31 span the bias is under one part in ten
-- million. Rejection sampling would remove it and would make the *number of
-- generator steps* depend on the values drawn -- which would make a recorded run
-- depend on them too, and a recorded run that cannot be replayed is worth less
-- than a bias nobody can measure.
function Stream:next_below(limit)
  if limit < 1 then
    error("next_below asked for a value in 1.." .. tostring(limit))
  end
  return (self:next_raw() % limit) + 1
end
-- }}}

-- {{{ function Stream:next_between(low, high)
-- An integer in low..high inclusive.
function Stream:next_between(low, high)
  return low + (self:next_raw() % (high - low + 1))
end
-- }}}

-- {{{ function Stream:chance(p)
-- True with probability p.
function Stream:chance(p)
  return self:next_float() < p
end
-- }}}

-- {{{ function Stream:pick(list)
-- One element of a non-empty array.
function Stream:pick(list)
  return list[self:next_below(#list)]
end
-- }}}

-- {{{ function Stream:shuffle(list)
-- The same list, shuffled in place. Fisher-Yates, walked downward, which is the
-- version that is uniform. Walking upward and drawing from the whole range is
-- the common mistake and it is not uniform.
function Stream:shuffle(list)
  for i = #list, 2, -1 do
    local j = self:next_below(i)
    list[i], list[j] = list[j], list[i]
  end
  return list
end
-- }}}

-- The streams the project uses. The camera's is on this list and does not belong
-- to the simulation: it must exist, and the simulation must never read it. A
-- viewer drawing from a simulation stream would make the world depend on whether
-- anybody was watching, and two runs of one seed would diverge based on whether
-- somebody pressed a key. Giving the camera its own makes that mistake
-- impossible to make by accident rather than merely discouraged.
local STREAM_NAMES = {
  "terrace", "carve", "braid", "stair",     -- the generator
  "spawn", "idle", "meeting", "duel",       -- the simulation
  "wander_ball", "wander_guy", "wander_dino",
  "burn",                                   -- phase seven
  "camera",                                 -- NOT the simulation's
}

-- {{{ function M.make_set(seed)
-- Every stream the project uses, so that nothing constructs one inline and
-- nothing is unnamed.
function M.make_set(seed)
  local set = {}
  for _, name in ipairs(STREAM_NAMES) do
    set[name] = M.new(seed, name)
  end
  return set
end
-- }}}

-- {{{ function M.names()
-- For the report, and for the test that asserts every stream is accounted for.
function M.names()
  return STREAM_NAMES
end
-- }}}

return M
