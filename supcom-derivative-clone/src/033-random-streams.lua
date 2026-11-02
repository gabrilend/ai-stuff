-- supcom-derivative-clone — a factory war on dunes where nothing is out of range
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

-- 033-random-streams.lua
--
-- Every random draw names its stream.
--
-- There is no global random generator anywhere in this project. A random use
-- opens a stream by name, and the stream is seeded from the match seed and that
-- name alone, so the same seed gives the same sequence in every stream on every
-- machine, and a new random use is a new name that disturbs no existing stream --
-- which is what keeps a replay recorded before the addition valid after it.
--
-- The generator is Marsaglia's xorshift: thirty-two bits of state, three shifts
-- and three exclusive-ors a draw, all through the `bit` library so the handheld's
-- C draws the same numbers. The dunes do not use a stream; their noise is a hash
-- of position, so the field never depends on draw order.

local bit = require("bit")

local M = {}

-- {{{ the named streams
-- Every stream the match draws from, in the order their rows sit in the world.
-- A new random use appends a name here; it never inserts one, because a row's
-- place is part of the world's hash.
M.STREAMS = {"roster-hurt", "cloud-round", "report-order"}

-- Which row of the world's stream group each name is.
M.ROW = {}
for row, name in ipairs(M.STREAMS) do
  M.ROW[name] = row
end
-- }}}

-- The largest `below` a draw takes: a thirty-two-bit draw times this stays under
-- 2^53, so the product is exact in a double on every machine.
local LARGEST_BELOW = 2097152

-- {{{ local function unsigned()
-- A thirty-two-bit pattern as the whole number from zero to 2^32 - 1 it means.
local function unsigned(state)
  return state % 4294967296
end
-- }}}

-- {{{ local function step()
-- One xorshift step: the next state from this one. Never zero from non-zero.
local function step(state)
  state = bit.bxor(state, bit.lshift(state, 13))
  state = bit.bxor(state, bit.rshift(state, 17))
  state = bit.bxor(state, bit.lshift(state, 5))
  return state
end
-- }}}

-- {{{ function M.seed_state()
-- The starting state of a stream: the seed, then each byte of the name, folded
-- in by an exclusive-or and a rotation, then stirred by four steps so that names
-- differing in one letter start far apart. A fold that lands on zero is refused,
-- because a zero state never leaves zero.
function M.seed_state(seed, name)
  if type(seed) ~= "number" or seed ~= math.floor(seed) then
    error("random-streams: seed " .. tostring(seed) .. " is not a whole number", 2)
  end
  if type(name) ~= "string" or name == "" then
    error("random-streams: a stream's name is " .. tostring(name) .. ", not a word", 2)
  end
  local state = bit.bxor(bit.tobit(seed % 4294967296), 0x9e3779b9)
  for index = 1, #name do
    state = bit.rol(bit.bxor(state, name:byte(index)), 7)
    state = bit.tobit(state + 0x7f4a7c15)
  end
  for _ = 1, 4 do
    state = step(bit.bxor(state, 0x2545f491))
  end
  if state == 0 then
    error("random-streams: seed " .. seed .. " and name '" .. name .. "' fold to zero", 2)
  end
  return state
end
-- }}}

-- {{{ function M.open()
-- A stream by name, as a table holding its state. The world holds its streams as
-- rows of one array instead; this is for anything outside a match.
function M.open(seed, name)
  return {name = name, state = M.seed_state(seed, name)}
end
-- }}}

-- {{{ local function integer_from()
-- A draw scaled to [0, below): the thirty-two bits times below, divided by 2^32,
-- floored. No rejection loop, so a draw is always exactly one step -- a little
-- bias at the top of a large range is the price, and it is the same on every
-- machine.
local function integer_from(state, below)
  if type(below) ~= "number" or below ~= math.floor(below) or below < 1 or below > LARGEST_BELOW then
    error("random-streams: cannot draw below " .. tostring(below)
          .. "; it must be a whole number from 1 to " .. LARGEST_BELOW, 3)
  end
  return math.floor(unsigned(state) * below / 4294967296)
end
-- }}}

-- {{{ function M.next_integer()
-- The next whole number in [0, below) from a stream table.
function M.next_integer(stream, below)
  stream.state = step(stream.state)
  return integer_from(stream.state, below)
end
-- }}}

-- {{{ function M.next_double()
-- The next double in [0, 1) from a stream table, from the same thirty-two bits.
function M.next_double(stream)
  stream.state = step(stream.state)
  return unsigned(stream.state) / 4294967296
end
-- }}}

-- {{{ local function row_of()
-- The world's row for a stream name, or a refusal naming the name.
local function row_of(name)
  local row = M.ROW[name]
  if row == nil then
    error("random-streams: no stream is named '" .. tostring(name)
          .. "'; a new random use adds its name to STREAMS", 3)
  end
  return row
end
-- }}}

-- {{{ function M.draw()
-- The next whole number in [0, below) from one of the world's streams. The state
-- lives in the world's flat arrays, so the hash covers it and a replay resumes it.
function M.draw(world, name, below)
  local row = row_of(name)
  local state = step(world.stream.state[row])
  world.stream.state[row] = state
  return integer_from(state, below)
end
-- }}}

-- {{{ function M.draw_double()
-- The next double in [0, 1) from one of the world's streams.
function M.draw_double(world, name)
  local row = row_of(name)
  local state = step(world.stream.state[row])
  world.stream.state[row] = state
  return unsigned(state) / 4294967296
end
-- }}}

return M
