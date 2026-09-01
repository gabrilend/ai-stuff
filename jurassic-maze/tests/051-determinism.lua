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

-- 051-determinism.lua
--
-- One seed, twice, must agree about everything.
--
-- Determinism does not fail loudly. It fails by one system taking a number from
-- somewhere it should not, and the symptom is that a bug report from three weeks
-- ago no longer reproduces. This is the only thing standing between the project
-- and a category of bug that cannot be investigated at all.

local M = {}

-- {{{ local function checksum_columns(store)
-- Order-independent would be wrong here: two mazes that are permutations of each
-- other are not the same maze. So the position is folded in.
local function checksum_columns(store)
  local bit = require("bit")
  local h = 5381
  for i = 0, store.cells - 1 do
    h = bit.band(h * 33 + store.column[i] + i, 0x7FFFFFFF)
  end
  return h
end
-- }}}

-- {{{ function M.run(root, t)
function M.run(root, t)
  local Params  = dofile(root .. "/src/028-maze-parameters.lua")
  local Streams = dofile(root .. "/src/029-random-streams.lua")
  local Carve   = dofile(root .. "/src/031-carving.lua")

  -- The same seed twice.
  for _, seed in ipairs({ 1, 2, 17, 1000 }) do
    local p1 = Params.check(Params.with{ seed = seed })
    local s1 = Carve.generate(root, p1, Streams.make_set(seed))
    local p2 = Params.check(Params.with{ seed = seed })
    local s2 = Carve.generate(root, p2, Streams.make_set(seed))
    t.equal(checksum_columns(s1), checksum_columns(s2),
            "seed " .. seed .. " builds the same maze twice")
  end

  -- Different seeds must not.
  local a = Carve.generate(root, Params.check(Params.with{ seed = 1 }), Streams.make_set(1))
  local b = Carve.generate(root, Params.check(Params.with{ seed = 2 }), Streams.make_set(2))
  t.truthy(checksum_columns(a) ~= checksum_columns(b),
           "two seeds build different mazes")

  -- Each stream's sequence must not depend on how the others were used, or in
  -- what order. This is the property the whole named-stream arrangement exists
  -- to buy: a change to how creatures idle must not be able to move the maze.
  --
  -- Run one draws each stream to exhaustion before touching the next. Run two
  -- goes round-robin, and draws seven extra from the camera in every round --
  -- the camera being the stream that changes most, because somebody watching is
  -- pressing keys. Every other stream must come out identical.
  local names = Streams.names()

  local set1 = Streams.make_set(42)
  local want = {}
  for _, name in ipairs(names) do
    want[name] = {}
    for k = 1, 50 do want[name][k] = set1[name]:next_raw() end
  end

  local set2 = Streams.make_set(42)
  local got = {}
  for _, name in ipairs(names) do got[name] = {} end
  for k = 1, 50 do
    for i = #names, 1, -1 do              -- and in the opposite order, too
      local name = names[i]
      got[name][k] = set2[name]:next_raw()
    end
    for _ = 1, 7 do set2.camera:next_raw() end
  end

  for _, name in ipairs(names) do
    if name ~= "camera" then
      for k = 1, 50 do
        t.equal(got[name][k], want[name][k],
                "stream " .. name .. " draw " .. k ..
                " is unmoved by how the others were used")
      end
    end
  end

  -- And the camera, which really was drawn from differently, must have moved --
  -- otherwise the test above is passing because nothing is connected to
  -- anything, which is a way for this whole check to be vacuous.
  local camera_moved = false
  for k = 1, 50 do
    if got.camera[k] ~= want.camera[k] then camera_moved = true end
  end
  t.truthy(camera_moved, "the stream that was drawn from differently did diverge")

  -- Two streams of one seed must not start in the same place, or two systems
  -- would draw the same numbers and correlate for no reason anybody could find.
  local set3 = Streams.make_set(9)
  t.truthy(set3.terrace.state ~= set3.carve.state,
           "streams of one seed start in different places")

  -- Zero is xorshift's fixed point and produces zeros forever. It must be
  -- unreachable however the seed is chosen.
  for seed = 0, 40 do
    local set = Streams.make_set(seed)
    for _, name in ipairs(Streams.names()) do
      t.truthy(set[name].state ~= 0, "no stream starts at the fixed point")
      local sum = 0
      for _ = 1, 20 do sum = sum + set[name]:next_raw() end
      t.truthy(sum > 0, "no stream produces only zeros")
    end
  end

  -- shuffle must be uniform, which the version that walks upward is not. Ten
  -- thousand shuffles of five items: every item should land in every position
  -- about a fifth of the time.
  local rng = Streams.new(7, "shuffle-check")
  local counts = {}
  for i = 1, 5 do counts[i] = {0, 0, 0, 0, 0} end
  for _ = 1, 10000 do
    local list = {1, 2, 3, 4, 5}
    rng:shuffle(list)
    for pos, item in ipairs(list) do
      counts[item][pos] = counts[item][pos] + 1
    end
  end
  for item = 1, 5 do
    for pos = 1, 5 do
      local n = counts[item][pos]
      t.truthy(n > 1700 and n < 2300,
               "shuffle is uniform: item " .. item .. " at position " .. pos ..
               " landed " .. n .. " times in 10000")
    end
  end
end
-- }}}

return M
