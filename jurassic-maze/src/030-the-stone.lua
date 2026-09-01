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

-- 030-the-stone.lua
--
-- The column array, the surface bits, and the arithmetic on them.
--
-- The entire world is one flat array of 32-bit integers, one per cell. Bit L of
-- entry i is set when layer L of the column above cell i is stone. Nothing
-- inside a stack is ever represented: a block is a set bit, a face is a
-- disagreement between two neighbouring bits, and neither is ever allocated.

local bit = require("bit")

local M = {}

M.MAX_LAYERS = 32

-- What headroom returns when there is nothing above a surface but sky. Any body
-- fits under it, and saying so with a number keeps the caller's comparison a
-- plain one rather than a special case.
M.OPEN_SKY = 1e9

-- {{{ function M.new(width, depth, layers)
-- The store. Allocated once, never reallocated, never grown.
--
-- The index is x + y * width and not y + x * depth. That is not arbitrary: it
-- makes the array's memory order identical to the renderer's correct
-- back-to-front draw order, so the hottest loop in the program walks memory
-- forwards instead of in strides. See docs/006-the-isometric-projection.md.
function M.new(width, depth, layers)
  if layers > M.MAX_LAYERS then
    error("a column is a 32-bit integer; " .. layers .. " layers will not fit")
  end

  local cells = width * depth
  local column   = {}
  local surfaces = {}
  for i = 0, cells - 1 do
    column[i]   = 0
    surfaces[i] = 0
  end

  return {
    width    = width,
    depth    = depth,
    layers   = layers,
    cells    = cells,
    column   = column,
    surfaces = surfaces,
    -- Bumped whenever the stone changes. Anything that caches something derived
    -- from the stone compares this rather than trusting itself. Today only a
    -- golem changes stone, and today there is nothing that caches -- the version
    -- exists so that the first thing which does cannot be silently wrong.
    version  = 0,
  }
end
-- }}}

-- {{{ function M.index(store, x, y)
function M.index(store, x, y)
  return x + y * store.width
end
-- }}}

-- {{{ function M.coords(store, i)
function M.coords(store, i)
  local y = math.floor(i / store.width)
  return i - y * store.width, y
end
-- }}}

-- {{{ function M.in_bounds(store, x, y)
function M.in_bounds(store, x, y)
  return x >= 0 and y >= 0 and x < store.width and y < store.depth
end
-- }}}

-- {{{ function M.is_stone(store, i, layer)
function M.is_stone(store, i, layer)
  if layer < 0 or layer >= store.layers then
    -- Below the ground is stone forever; above the world is air forever. Saying
    -- so here means no caller needs a bounds test of its own, and a caller that
    -- forgot one gets a sensible answer rather than a nil.
    return layer < 0
  end
  return bit.band(store.column[i], bit.lshift(1, layer)) ~= 0
end
-- }}}

-- {{{ function M.set_stone(store, i, layer)
function M.set_stone(store, i, layer)
  store.column[i] = bit.bor(store.column[i], bit.lshift(1, layer))
end
-- }}}

-- {{{ function M.clear_stone(store, i, layer)
function M.clear_stone(store, i, layer)
  store.column[i] = bit.band(store.column[i], bit.bnot(bit.lshift(1, layer)))
end
-- }}}

-- {{{ function M.fill_to(store, i, height)
-- Makes the column a plain pile of stone from the ground up to and including
-- `height`. A height of -1 leaves it empty.
--
-- This is the height-shaped special case the generator produces exclusively.
-- The bitmask can express far more than this -- tunnels, bridges, ceilings --
-- and nothing yet does. M.height_shaped below is how anybody finds out when that
-- stops being true.
function M.fill_to(store, i, height)
  if height < 0 then
    store.column[i] = 0
  else
    store.column[i] = bit.lshift(1, height + 1) - 1
  end
end
-- }}}

-- {{{ function M.surfaces_of(column)
-- Every standable top in a column, as a bitmask, in three operations.
--
-- A surface is a stone layer with air directly above it. Shifting the column
-- down by one puts what was above each layer into that layer's position;
-- complementing gives a 1 wherever the layer above was air; anding with the
-- original keeps only the layers that were stone. What is left is exactly the
-- standable tops -- all thirty-two layers evaluated at once, no loop, no branch.
--
-- This is the most load-bearing line in the project. A column with a tunnel
-- through it yields two surfaces and this expression finds both without knowing
-- tunnels exist. A column that is solid to the top of the world yields none,
-- which is correct: there is nowhere on it to stand.
function M.surfaces_of(column)
  return bit.band(column, bit.bnot(bit.rshift(column, 1)))
end
-- }}}

-- {{{ function M.recompute_surfaces(store, first, last)
-- Fills the parallel surface array over a range of cells. Takes a range rather
-- than sweeping everything, so a thread pool can call it in slices and so a
-- golem breaking one block can repair five cells instead of a hundred thousand.
function M.recompute_surfaces(store, first, last)
  first = first or 0
  last  = last  or (store.cells - 1)
  local column, surfaces = store.column, store.surfaces
  for i = first, last do
    surfaces[i] = M.surfaces_of(column[i])
  end
end
-- }}}

-- {{{ function M.is_surface(store, i, layer)
function M.is_surface(store, i, layer)
  if layer < 0 or layer >= store.layers then return false end
  return bit.band(store.surfaces[i], bit.lshift(1, layer)) ~= 0
end
-- }}}

-- {{{ function M.top_of(store, i)
-- The highest stone layer in a column, or -1 for an empty one.
function M.top_of(store, i)
  local c = store.column[i]
  if c == 0 then return -1 end
  local layer = -1
  while c ~= 0 do
    c = bit.rshift(c, 1)
    layer = layer + 1
  end
  return layer
end
-- }}}

-- {{{ function M.highest_surface_at_or_below(store, i, layer)
-- The nearest place a body could stand, looking downward from `layer`. Returns
-- -1 when there is none, which for a column with any stone in it cannot happen
-- and for an empty column means the body is over the void.
function M.highest_surface_at_or_below(store, i, layer)
  if layer >= store.layers then layer = store.layers - 1 end
  local s = store.surfaces[i]
  for l = layer, 0, -1 do
    if bit.band(s, bit.lshift(1, l)) ~= 0 then return l end
  end
  return -1
end
-- }}}

-- {{{ function M.lowest_surface_above(store, i, layer)
-- The nearest place a body could stand, looking upward from `layer`.
function M.lowest_surface_above(store, i, layer)
  local s = store.surfaces[i]
  for l = layer + 1, store.layers - 1 do
    if bit.band(s, bit.lshift(1, l)) ~= 0 then return l end
  end
  return -1
end
-- }}}

-- {{{ function M.headroom(store, i, layer)
-- How many consecutive air layers sit above a surface.
--
-- Not stored. Storing it would mean maintaining it, and it changes whenever the
-- stone does. It is only ever asked about the one cell a body is trying to
-- enter, so counting it on demand is cheaper than keeping it correct.
--
-- Nothing today has a ceiling over it, so this always returns the distance to
-- the top of the world and every caller's check passes. It is written anyway:
-- the delve is a dungeon, a dungeon has ceilings, and a check that was never
-- written is far harder to add than one that was written and always passed.
function M.headroom(store, i, layer)
  local n = 0
  for l = layer + 1, store.layers - 1 do
    if bit.band(store.column[i], bit.lshift(1, l)) ~= 0 then return n end
    n = n + 1
  end
  -- Nothing was hit on the way up, so what is above this surface is sky.
  --
  -- Counting only as far as the last layer and stopping there treats the top of
  -- the array as a ceiling, and a surface standing at the world's highest layer
  -- then reports no headroom at all -- so nothing may step onto it, so the
  -- staircase that reached it is severed, so the maze validates as two pieces
  -- for reasons that have nothing to do with the maze. Above the world is air,
  -- exactly as is_stone already says it is.
  return M.OPEN_SKY
end
-- }}}

-- {{{ function M.height_shaped(column)
-- Whether a column's set bits are contiguous from bit zero -- a plain pile with
-- no holes in it.
--
-- The generator produces nothing else. This is how the validator finds out the
-- day something does, which will be the day a golem walks through a wall.
function M.height_shaped(column)
  if column == 0 then return true end
  -- A run of ones from bit zero, plus one, is a single higher bit. Anything with
  -- a hole in it fails this, and it costs two operations instead of a loop.
  local plus_one = column + 1
  return bit.band(plus_one, column) == 0
end
-- }}}

-- {{{ function M.runs_of(column, layers)
-- Breaks a column into runs of consecutive stone, returned as a flat array of
-- bottom, top, bottom, top. The renderer's unit of work: a plain pile is one
-- run, a pile with a tunnel through it is two.
--
-- A flat array rather than a table of pairs because this is called once per
-- visible column per frame, and a renderer that allocates per frame is a
-- renderer that stutters whenever the collector notices, correlated with
-- nothing. The caller passes in the array to reuse.
function M.runs_of(column, layers, into)
  local n = 0
  local l = 0
  while l < layers do
    if bit.band(column, bit.lshift(1, l)) ~= 0 then
      local bottom = l
      while l < layers and bit.band(column, bit.lshift(1, l)) ~= 0 do
        l = l + 1
      end
      into[n + 1] = bottom
      into[n + 2] = l - 1
      n = n + 2
    else
      l = l + 1
    end
  end
  return n / 2
end
-- }}}

return M
