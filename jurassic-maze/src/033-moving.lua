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

-- {{{ function M.find_path(Stone, store, from_cell, from_layer, to_cell, to_layer, drop_limit, body_height, budget, into, fits)
-- A-star over the surface graph. Returns the number of steps, or nil.
--
-- The path is written into `into` as packed stances, nearest first, so a caller
-- that keeps one array per body allocates nothing per search.
--
-- Three things bound the cost, and all three matter:
--
-- **The component labels are checked first.** If the destination is in a
-- different piece there is no path, and one comparison saves the entire search.
--
-- **The estimate is the straight-line distance in cells plus the difference in
-- layers**, which never overestimates -- every step moves one cell and at most
-- one layer -- so the first route found is the shortest.
--
-- `fits` is an optional test the destination of every step must pass. A body
-- wider than one cell needs it: without it a dinosaur is handed a route through
-- a corridor it cannot enter, walks it as far as the first narrow cell, and
-- stops -- and what shows up is a search that succeeded and a body that did not
-- move, which looks like a broken locomotion row and is nothing of the kind.
--
-- **It gives up.** After `budget` surfaces examined it stops and returns nil,
-- and the caller counts that. A search that quietly failed leaves a body
-- standing still looking stuck for no reason anybody can name, and the count is
-- how it is ever noticed at all. This is the project's one sanctioned fallback,
-- and the rule about fallbacks is that they are announced and counted.
function M.find_path(Stone, store, from_cell, from_layer, to_cell, to_layer,
                     drop_limit, body_height, budget, into, fits)
  if from_cell == to_cell and from_layer == to_layer then
    into[1] = nil
    return 0
  end
  if fits and not fits(to_cell, to_layer) then return nil end

  if store.label then
    local a = store.label[M.pack(store, from_cell, from_layer)]
    local b = store.label[M.pack(store, to_cell, to_layer)]
    if a and b and a ~= b then return nil end
  end

  local tx, ty = Stone.coords(store, to_cell)

  -- {{{ local function estimate(cell, layer)
  local function estimate(cell, layer)
    local x, y = Stone.coords(store, cell)
    local dx = (x > tx) and (x - tx) or (tx - x)
    local dy = (y > ty) and (y - ty) or (ty - y)
    local dl = (layer > to_layer) and (layer - to_layer) or (to_layer - layer)
    return dx + dy + dl
  end
  -- }}}

  -- A binary heap over a flat array of {priority, key} pairs, rebuilt per search
  -- rather than allocated. A sorted table would be simpler and would make every
  -- insertion cost the length of the frontier.
  local heap_key, heap_pri, heap_n = {}, {}, 0

  -- {{{ local function push(key, pri)
  local function push(key, pri)
    heap_n = heap_n + 1
    heap_key[heap_n], heap_pri[heap_n] = key, pri
    local i = heap_n
    while i > 1 do
      local parent = math.floor(i / 2)
      if heap_pri[parent] <= heap_pri[i] then break end
      heap_key[i], heap_key[parent] = heap_key[parent], heap_key[i]
      heap_pri[i], heap_pri[parent] = heap_pri[parent], heap_pri[i]
      i = parent
    end
  end
  -- }}}

  -- {{{ local function pop()
  local function pop()
    if heap_n == 0 then return nil end
    local top = heap_key[1]
    heap_key[1], heap_pri[1] = heap_key[heap_n], heap_pri[heap_n]
    heap_n = heap_n - 1
    local i = 1
    while true do
      local l, r = i * 2, i * 2 + 1
      local best = i
      if l <= heap_n and heap_pri[l] < heap_pri[best] then best = l end
      if r <= heap_n and heap_pri[r] < heap_pri[best] then best = r end
      if best == i then break end
      heap_key[i], heap_key[best] = heap_key[best], heap_key[i]
      heap_pri[i], heap_pri[best] = heap_pri[best], heap_pri[i]
      i = best
    end
    return top
  end
  -- }}}

  local start  = M.pack(store, from_cell, from_layer)
  local goal   = M.pack(store, to_cell, to_layer)
  local came   = {}
  local cost   = { [start] = 0 }
  local seen   = 0

  push(start, estimate(from_cell, from_layer))

  while heap_n > 0 do
    local here = pop()
    if here == goal then
      -- Unwind, nearest first.
      local n = 0
      local node = goal
      while node ~= start do
        n = n + 1
        node = came[node]
      end
      local k = n
      node = goal
      while node ~= start do
        into[k] = node
        k = k - 1
        node = came[node]
      end
      into[n + 1] = nil
      return n
    end

    seen = seen + 1
    if seen > budget then return nil end

    local hc, hl = M.unpack(store, here)
    local here_cost = cost[here]

    for di = 1, 4 do
      local answer, nc, nl = M.step(Stone, store, hc, hl, di, drop_limit, body_height)
      if answer ~= M.BLOCKED and (not fits or fits(nc, nl)) then
        local nkey = M.pack(store, nc, nl)
        local next_cost = here_cost + 1
        if cost[nkey] == nil or next_cost < cost[nkey] then
          cost[nkey] = next_cost
          came[nkey] = here
          push(nkey, next_cost + estimate(nc, nl))
        end
      end
    end
  end

  return nil
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
