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

-- 062-sight.lua
--
-- Marching a line through stone, and finding somewhere it cannot reach.
--
-- Hiding is the point of the habitat, and hiding is meaningless unless
-- not-being-seen is a fact the program can establish.

local M = {}

local Stone, Moving, Creatures

-- {{{ function M.link(stone, moving, creatures)
function M.link(stone, moving, creatures)
  Stone, Moving, Creatures = stone, moving, creatures
end
-- }}}

-- How far above a creature's **feet** its eyes are, in layers.
--
-- Above its feet, not above its stance's layer, and the difference is the whole
-- of it. A body standing on the surface at layer L has its feet on top of that
-- block, at height L+1; measuring the eye from L instead puts the line inside
-- the very block the creature is standing on, so the first sample of every march
-- hits stone and **nothing can ever see anything**. Measured: one pair in four
-- hundred and forty-one, which is the one pair that happened to be adjacent.
--
-- Half a layer above the feet, which is comfortably inside the air above the
-- floor and comfortably below the top of a wall.
M.EYE = 0.5

-- {{{ function M.can_see(store, from_cell, from_layer, to_cell, to_layer, range)
-- Whether a straight line between two surfaces reaches without hitting stone.
--
-- The march visits cells in steps of at most half a cell, so none is skipped,
-- and at each step it is one array read and one bit test. That cheapness is what
-- makes asking often affordable, and it is a direct consequence of a column
-- being one integer.
function M.can_see(store, from_cell, from_layer, to_cell, to_layer, range)
  local ax, ay = Stone.coords(store, from_cell)
  local bx, by = Stone.coords(store, to_cell)
  local dx, dy = bx - ax, by - ay

  local flat = math.sqrt(dx * dx + dy * dy)
  -- Out of range is answered with two subtractions and a comparison, before any
  -- marching at all.
  if range and flat > range then return false, flat end
  if flat < 0.5 then return true, flat end

  local az = from_layer + 1 + M.EYE
  local bz = to_layer + 1 + M.EYE
  local steps = math.ceil(flat * 2)

  for k = 1, steps - 1 do
    local t = k / steps
    local x = math.floor(ax + dx * t + 0.5)
    local y = math.floor(ay + dy * t + 0.5)
    local z = math.floor(az + (bz - az) * t)

    if x >= 0 and y >= 0 and x < store.width and y < store.depth then
      if Stone.is_stone(store, x + y * store.width, z) then
        return false, flat
      end
    end
  end

  return true, flat
end
-- }}}

-- {{{ function M.sees_body(world, watcher, quarry)
-- The same question, asked about two bodies.
function M.sees_body(world, watcher, quarry)
  local bodies = world.bodies
  local kind = Creatures.KINDS[bodies.kind[watcher]]
  return M.can_see(world.store,
                   bodies.cell[watcher], bodies.layer[watcher],
                   bodies.cell[quarry],  bodies.layer[quarry],
                   kind.sight_range or 20)
end
-- }}}

-- {{{ function M.due(world, bodies, id, kind)
-- Whether this body's sight check is due.
--
-- Sight is asked on a cadence rather than every tick, and each body carries a
-- **phase offset** -- its own id, modulo the interval -- so that the whole
-- population does not check on the same tick and produce a periodic stall.
--
-- Spreading regular-but-not-urgent work by giving each body a phase is worth
-- naming as a technique: the cost becomes flat instead of spiky, and a flat cost
-- is one nobody has to think about again.
function M.due(world, bodies, id, kind)
  local every = math.max(1, math.floor((kind.sight_interval or 0.5) * 60))
  return (world.tick_count + id) % every == 0
end
-- }}}

-- {{{ function M.find_cover(world, id, from_id, budget)
-- Somewhere nearby that the given body cannot see.
--
-- Returns a cell and a layer, or nil. Searches outward over surfaces reachable
-- by the ordinary movement rule, scoring blocked sight first and distance
-- second -- so a nearer hiding place beats a farther one, and any hiding place
-- beats none.
function M.find_cover(world, id, from_id, budget)
  local store  = world.store
  local bodies = world.bodies
  local kind   = Creatures.KINDS[bodies.kind[id]]
  local Walking = world.modules.Walking

  local start = Moving.pack(store, bodies.cell[id], bodies.layer[id])
  local seen  = { [start] = true }
  local queue = { start }
  local head, tail = 1, 1
  local examined = 0

  local best, best_cell, best_layer = -1, nil, nil

  while head <= tail and examined < (budget or 400) do
    local here = queue[head]
    head = head + 1
    examined = examined + 1

    local hc, hl = Moving.unpack(store, here)

    if here ~= start then
      local visible = M.can_see(store, bodies.cell[from_id], bodies.layer[from_id],
                                hc, hl, nil)
      if not visible then
        -- Nearer is better, so the score falls with the number of surfaces
        -- examined before this one was reached -- which is a breadth-first
        -- distance and therefore already in hand.
        local score = 1000 - examined
        if score > best then
          best, best_cell, best_layer = score, hc, hl
        end
        -- The first hidden place found by a breadth-first walk is the nearest
        -- one. There is nothing better further out.
        break
      end
    end

    for di = 1, 4 do
      local answer, nc, nl = Moving.step(Stone, store, hc, hl, di,
                                         kind.drop_limit, kind.body_height)
      if answer ~= Moving.BLOCKED
         and Walking.footprint_fits(world, bodies, id, kind, nc, nl) then
        local key = Moving.pack(store, nc, nl)
        if not seen[key] then
          seen[key] = true
          tail = tail + 1
          queue[tail] = key
        end
      end
    end
  end

  if best_cell then return best_cell, best_layer end

  -- Nowhere within the budget. Counted, never silent: a maze where hiding always
  -- fails is a maze with no cover, which is a fact about the generator's
  -- parameters and should arrive as a number.
  world.counters.cover_not_found = (world.counters.cover_not_found or 0) + 1
  return nil
end
-- }}}

return M
