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

-- 033-moving.lua
--
-- Four answers to whether a body may move, and the component labels.
--
-- One function, called by every kind of creature. A dinosaur, a ball and a stone
-- golem get the same answer to the same question, because the maze has to mean
-- one thing.

local M = {}

-- The four compass directions. Movement is four-directional: a body cannot cut a
-- corner. The cost is boxy paths across open ground; the reason to accept it is
-- that a diagonal move between two open cells whose shared neighbours are both
-- wall would pass a body through the seam where two stone blocks meet, and the
-- only ways out of that are to forbid it as a special case or to let bodies clip
-- through corners. Both are worse than boxy paths.
--
-- Continuous movers are not bound by this. A rolling ball has a real velocity
-- pointing wherever it likes and collides against wall faces instead of asking
-- this question at all. The four directions are the *graph's* structure, not the
-- world's.
M.DIRECTIONS = { {1, 0}, {-1, 0}, {0, 1}, {0, -1} }

M.BLOCKED   = 0
M.FLAT      = 1
M.STEP_UP   = 2
M.STEP_DOWN = 3

M.ANSWER_NAMES = { [0] = "blocked", "flat", "step up", "step down" }

-- The tallest step anything may climb. This is not a knob.
--
-- The generator's wall_rise was chosen against it: a wall stands two layers above
-- the corridor it flanks precisely because one layer is climbable and two is not.
-- Raising this to two does not make bodies more agile, it deletes every wall in
-- the maze at once.
M.CLIMB_LIMIT = 1

-- {{{ function M.step(Stone, store, cell, layer, direction, drop_limit, body_height)
-- The whole movement rule. Returns an answer and the destination cell and layer.
--
--   flat       the neighbour has a surface at the same layer -- walk onto it
--   step up    the neighbour has a surface one layer up, with headroom -- climb
--   step down  the highest surface below is within drop_limit -- walk down
--   blocked    anything else -- the move does not happen
--
-- drop_limit is per creature and climb_limit is not, because falling is not the
-- same act as climbing. A body may go down further than it can come up, which is
-- exactly why a maze can collect bodies in a pit: they walk in and cannot walk
-- out. The validator counts those pits for that reason.
function M.step(Stone, store, cell, layer, direction, drop_limit, body_height)
  local d = M.DIRECTIONS[direction]
  local x, y = Stone.coords(store, cell)
  local nx, ny = x + d[1], y + d[2]

  -- Off the edge of the world. The rim is wall so this should be unreachable,
  -- and the check runs anyway -- the rim is the only thing standing between a
  -- body that has gone wrong and an array index that is not there.
  if not Stone.in_bounds(store, nx, ny) then
    return M.BLOCKED, cell, layer
  end

  local n = Stone.index(store, nx, ny)
  body_height = body_height or 1

  -- Flat, then up, then down. The order matters only in that a neighbour can
  -- have surfaces at several layers -- a tunnel has a floor and a roof -- and
  -- the nearest one is the one meant.
  if Stone.is_surface(store, n, layer)
     and Stone.headroom(store, n, layer) >= body_height then
    return M.FLAT, n, layer
  end

  if Stone.is_surface(store, n, layer + M.CLIMB_LIMIT)
     and Stone.headroom(store, n, layer + M.CLIMB_LIMIT) >= body_height then
    return M.STEP_UP, n, layer + M.CLIMB_LIMIT
  end

  local below = Stone.highest_surface_at_or_below(store, n, layer - 1)
  if below >= 0 and (layer - below) <= drop_limit
     and Stone.headroom(store, n, below) >= body_height then
    return M.STEP_DOWN, n, below
  end

  return M.BLOCKED, cell, layer
end
-- }}}

-- {{{ function M.pack(store, cell, layer)
-- A stance as one integer, so that a came-from map or a visited set is a flat
-- array rather than a table of tables. Layers fit in five bits.
function M.pack(store, cell, layer)
  return cell * 32 + layer
end
-- }}}

-- {{{ function M.unpack(store, packed)
function M.unpack(store, packed)
  local layer = packed % 32
  return (packed - layer) / 32, layer
end
-- }}}

-- {{{ function M.label_surfaces(Stone, store)
-- Which connected piece each surface belongs to.
--
-- The relation is **mutual** reachability: two surfaces are joined when a body
-- can step from either to the other. That reduces to their layers differing by
-- no more than the climb limit, because going up is capped at one layer in both
-- directions no matter how far down a creature is willing to drop.
--
-- Using one-way reachability here was tried and is wrong, and the way it is
-- wrong is worth recording. A body may drop two layers and climb only one, so a
-- pit is reachable from the terrace above it and the terrace is not reachable
-- from the pit. A flood fill over a one-way relation therefore produces
-- different answers depending on which surface it happened to start from -- the
-- pit alone if it started inside, the pit and the terrace if it started outside.
-- Those are not components, they are the results of an arbitrary choice, and a
-- validator built on them reports a maze as broken or whole depending on array
-- order.
--
-- Falling is not travel. It is an accident, and where it can strip a body of its
-- ability to get back is counted separately rather than folded in here.
--
-- The graph itself is never stored. There is no adjacency list anywhere in this
-- project: neighbours come out of four columns and a handful of bit operations,
-- which is cheaper than the cache miss reading a stored list would have cost,
-- and a stored graph would be a second copy of the maze to invalidate every time
-- a golem walks through a wall.
function M.label_surfaces(Stone, store)
  local bit = require("bit")
  local label = {}
  local sizes = {}
  local count = 0
  local stack = {}

  for cell = 0, store.cells - 1 do
    local s = store.surfaces[cell]
    for layer = 0, store.layers - 1 do
      if bit.band(s, bit.lshift(1, layer)) ~= 0 then
        local key = M.pack(store, cell, layer)
        if label[key] == nil then
          count = count + 1
          local size = 0
          label[key] = count
          stack[1] = key
          local top = 1

          while top > 0 do
            local here = stack[top]
            top = top - 1
            size = size + 1
            local hc, hl = M.unpack(store, here)

            for di = 1, 4 do
              -- drop_limit equal to the climb limit is what makes this the
              -- mutual relation rather than the one-way one.
              local answer, nc, nl =
                M.step(Stone, store, hc, hl, di, M.CLIMB_LIMIT, 1)
              if answer ~= M.BLOCKED then
                local nkey = M.pack(store, nc, nl)
                if label[nkey] == nil then
                  label[nkey] = count
                  top = top + 1
                  stack[top] = nkey
                end
              end
            end
          end

          sizes[count] = size
        end
      end
    end
  end

  return label, count, sizes
end
-- }}}

-- {{{ function M.count_ledges(Stone, store, label, main, drop_limit)
-- How many places in the reachable maze a body can step off and not climb
-- straight back.
--
-- Restricted to surfaces in the main piece on purpose. Counting every surface
-- includes the top of every wall in the maze, and a wall top has a drop off all
-- four sides by construction -- so the total measures how many walls there are,
-- which is a number already known, rather than anything about the maze a body
-- moves through.
--
-- What is left is a real property: high means a landscape of terraces where
-- wandering bodies keep tumbling down a level, low means a flat warren.
function M.count_ledges(Stone, store, label, main, drop_limit)
  local bit = require("bit")
  local n = 0
  for cell = 0, store.cells - 1 do
    local s = store.surfaces[cell]
    for layer = 0, store.layers - 1 do
      if bit.band(s, bit.lshift(1, layer)) ~= 0
         and label[M.pack(store, cell, layer)] == main then
        for di = 1, 4 do
          local answer, _, nl = M.step(Stone, store, cell, layer, di, drop_limit, 1)
          if answer == M.STEP_DOWN and (layer - nl) > M.CLIMB_LIMIT then
            n = n + 1
          end
        end
      end
    end
  end
  return n
end
-- }}}

-- {{{ function M.is_pit(Stone, store, cell, layer, drop_limit)
-- Whether a body standing here could leave.
--
-- Legal, and worth counting: a maze full of pits slowly drains the aquarium into
-- a corner, and from a camera two hundred cells away that looks like a busy
-- corner and a quiet one, which is what a maze is supposed to look like.
function M.is_pit(Stone, store, cell, layer, drop_limit)
  for di = 1, 4 do
    local answer = M.step(Stone, store, cell, layer, di, drop_limit, 1)
    if answer ~= M.BLOCKED then return false end
  end
  return true
end
-- }}}

return M
