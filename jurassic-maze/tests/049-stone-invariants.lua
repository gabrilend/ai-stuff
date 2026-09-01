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

-- 049-stone-invariants.lua
--
-- The column, the surface trick, and the accessors, against slow references.
--
-- Every clever thing in 030-the-stone.lua is checked here against an obvious
-- thing that does the same job with a loop. The clever version is three bit
-- operations evaluating all thirty-two layers at once; the obvious version tests
-- two bits per layer and is impossible to get wrong. If they ever disagree, the
-- clever one is wrong, because the obvious one is what the definition says.

local M = {}

-- {{{ local function reference_surfaces(column, layers)
-- A surface is a stone layer with air directly above it. Straight from the
-- definition, one layer at a time.
local function reference_surfaces(column, layers)
  local bit = require("bit")
  local out = 0
  for l = 0, layers - 1 do
    local here  = bit.band(column, bit.lshift(1, l)) ~= 0
    local above = (l + 1 < 32) and bit.band(column, bit.lshift(1, l + 1)) ~= 0 or false
    if here and not above then out = bit.bor(out, bit.lshift(1, l)) end
  end
  return out
end
-- }}}

-- {{{ local function reference_height_shaped(column, layers)
local function reference_height_shaped(column, layers)
  local bit = require("bit")
  local seen_air = false
  for l = 0, layers - 1 do
    if bit.band(column, bit.lshift(1, l)) ~= 0 then
      if seen_air then return false end
    else
      seen_air = true
    end
  end
  return true
end
-- }}}

-- {{{ function M.run(root, t)
function M.run(root, t)
  local Stone   = dofile(root .. "/src/030-the-stone.lua")
  local Streams = dofile(root .. "/src/029-random-streams.lua")
  local bit     = require("bit")

  -- The surface expression, against the definition, over the degenerate cases
  -- and then over a great many random columns.
  local fixed = { 0, 1, 0xFFFFFFFF, 0x80000000, 0x00000007, 0x00000047, 0x0F0F0F0F }
  for _, c in ipairs(fixed) do
    t.equal(Stone.surfaces_of(c), reference_surfaces(c, 32),
            "surfaces of column " .. string.format("%08x", c))
  end

  local rng = Streams.new(1234, "test-columns")
  for _ = 1, 4000 do
    local c = bit.bor(bit.lshift(rng:next_raw() % 65536, 16), rng:next_raw() % 65536)
    t.equal(Stone.surfaces_of(c), reference_surfaces(c, 32), "random column surfaces")
  end

  -- height_shaped, which is two operations pretending to be a loop.
  for _ = 1, 4000 do
    local c = bit.bor(bit.lshift(rng:next_raw() % 65536, 16), rng:next_raw() % 65536)
    t.equal(Stone.height_shaped(c) and 1 or 0,
            reference_height_shaped(c, 32) and 1 or 0,
            "height_shaped agrees with the loop")
  end

  -- The accessors, against a plain table of booleans.
  local store = Stone.new(9, 7, 12)
  local truth = {}
  for i = 0, store.cells - 1 do
    truth[i] = {}
    for l = 0, 11 do truth[i][l] = false end
  end

  for _ = 1, 3000 do
    local i = rng:next_below(store.cells) - 1
    local l = rng:next_below(12) - 1
    if rng:chance(0.5) then
      Stone.set_stone(store, i, l);   truth[i][l] = true
    else
      Stone.clear_stone(store, i, l); truth[i][l] = false
    end
  end

  for i = 0, store.cells - 1 do
    for l = 0, 11 do
      t.equal(Stone.is_stone(store, i, l) and 1 or 0, truth[i][l] and 1 or 0,
              "is_stone agrees with the reference table")
    end
  end

  -- Below the ground is stone forever and above the world is air forever, so
  -- that no caller needs a bounds test of its own.
  t.truthy(Stone.is_stone(store, 0, -1), "below the ground is stone")
  t.falsy(Stone.is_stone(store, 0, 99),  "above the world is air")

  -- Headroom over a surface with nothing above it is sky, not zero. Reporting
  -- zero there severs every staircase that reaches the world's top layer, and
  -- the maze then validates as two pieces for reasons nothing to do with the
  -- maze -- which is exactly the bug this line was written after.
  local tall = Stone.new(3, 3, 8)
  Stone.fill_to(tall, 4, 7)
  Stone.recompute_surfaces(tall)
  t.truthy(Stone.headroom(tall, 4, 7) >= 1,
           "a surface at the top layer has sky above it, not a ceiling")

  -- A tunnel: two runs, two surfaces, and the expression finds both without
  -- knowing tunnels exist.
  local holed = Stone.new(3, 3, 12)
  holed.column[4] = bit.bor(0x07, bit.lshift(0x07, 6))   -- layers 0-2 and 6-8
  Stone.recompute_surfaces(holed)
  t.truthy(Stone.is_surface(holed, 4, 2), "the tunnel floor is a surface")
  t.truthy(Stone.is_surface(holed, 4, 8), "the roof above it is a surface too")
  t.equal(Stone.headroom(holed, 4, 2), 3, "headroom under the tunnel roof")
  t.falsy(Stone.height_shaped(holed.column[4]), "a holed column is not height-shaped")

  -- Runs, which are what the renderer sweeps.
  local runs = {}
  t.equal(Stone.runs_of(holed.column[4], 12, runs), 2, "a holed column has two runs")
  t.equal(runs[1], 0, "first run bottom")
  t.equal(runs[2], 2, "first run top")
  t.equal(runs[3], 6, "second run bottom")
  t.equal(runs[4], 8, "second run top")

  -- A column solid to the top of the world has nowhere to stand on it.
  local solid = Stone.new(3, 3, 6)
  solid.column[4] = 0x3F
  Stone.recompute_surfaces(solid)
  t.equal(solid.surfaces[4], bit.lshift(1, 5),
          "the top of a full column is still its surface")

  -- Round-tripping the index.
  for y = 0, store.depth - 1 do
    for x = 0, store.width - 1 do
      local i = Stone.index(store, x, y)
      local rx, ry = Stone.coords(store, i)
      t.equal(rx, x, "index round-trips x")
      t.equal(ry, y, "index round-trips y")
    end
  end
end
-- }}}

return M
