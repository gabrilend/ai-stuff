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

-- 036-locomotion.lua
--
-- The dispatch table of ways to move, and the machinery its rows share.
--
-- Two kinds of motion were asked for by name -- continuous with momentum for the
-- balls, a smoothed graph walk for the little guys -- with the instruction to
-- accommodate multiple. So there is no "how bodies move" in this project. There
-- is a table, and each row is one way of moving.

local M = {}

-- A body's z is the height of its feet, in layer units. A body standing on the
-- surface at layer L has z = L + 1, because the block occupying layer L spans
-- heights L to L+1 and its top is the thing being stood on.
--
-- Getting this off by one buries every body half a layer inside the stone it is
-- standing on, which looks like nothing at all, because the block it is inside
-- is exactly the same colour as the one it should be on top of.
-- {{{ function M.surface_top(layer)
function M.surface_top(layer)
  return layer + 1
end
-- }}}

-- {{{ function M.new_table()
-- The rows, in the order the creature table names them.
--
-- All seven rows are built. Five of them spent time as stubs that raised by
-- name -- "lumbering is not built yet, phase 7" -- which is a far better failure
-- than a nil index three calls away, and which meant the shape of the design was
-- visible in the code and not only in the documents.
--
-- The helper that made those stubs is gone with them. Three of the five turned
-- out to be `Walking.advance` with different numbers in the creature's row, and
-- `carried` turned out to be a function that does nothing: a new way of moving
-- was a new row rather than a new function, four times out of five, which is
-- what the table was for and was not guaranteed.
function M.new_table(Rolling, Walking, Bouncing)
  return {
    { name = "rolling",  advance = Rolling.advance,  parallel = true,
      needs = { "x", "y", "z", "vx", "vy", "vz" } },

    { name = "walking",  advance = Walking.advance,  parallel = true,
      needs = { "cell", "layer", "from_cell", "from_layer", "progress" } },

    -- Striding is walking with the enterability check widened to every cell of
    -- the body's footprint. It is the same function, not a copy of it: a row
    -- shares the step machinery by calling it, not by being it, and two copies
    -- of a step is two places for a walker and a dinosaur to start disagreeing
    -- about what the maze is.
    { name = "striding", advance = Walking.advance, parallel = true,
      needs = { "cell", "layer", "from_cell", "from_layer", "progress" } },

    -- Lumbering and creeping are both the walking step with a different opinion
    -- about what counts as a legal move -- the golem's is that a wall is
    -- something to go through, the vine's is that a drop is not a problem. Both
    -- are the same function, and the difference lives in the creature's row:
    -- `breaks_stone` and a `drop_limit` of ninety-nine.
    --
    -- That is the dispatch table doing its job. A new way of moving turned out
    -- to be a new row of numbers rather than a new function, which is the best
    -- outcome available and was not guaranteed.
    { name = "lumbering", advance = Walking.advance, parallel = true,
      needs = { "cell", "layer", "progress" } },

    { name = "creeping", advance = Walking.advance, parallel = true,
      needs = { "cell", "layer", "progress" } },

    -- Riding. This row does nothing, which is the correct amount of work for a
    -- body that is not moving under its own power -- and being a row rather than
    -- a flag means the move pass never learns that riding exists.
    { name = "carried",  advance = function() end, parallel = true, needs = {} },

    { name = "still",    advance = function() end, parallel = true, needs = {} },

    -- Bouncing: a sphere against the model's rectangles, and against other
    -- spheres.
    --
    -- **`parallel` is false, and that is the point of the flag.** Every other row
    -- touches one body per iteration, so a thread pool can hand each core a range
    -- of the roster and no two cores ever write the same body. This one resolves
    -- pairs, and the second body of a pair is not in the range the core was
    -- given. Nothing splits anything yet, so the claim costs nothing today -- and
    -- it is the difference between adding a pool later as a change to the tick
    -- and adding it as an audit of every row.
    { name = "bouncing", advance = Bouncing.advance, parallel = false,
      needs = { "x", "y", "z", "vx", "vy", "vz", "rest_timer", "distance" } },
  }
end
-- }}}

-- {{{ function M.check_needs(rows, bodies)
-- Every field a row claims to touch must exist, checked once at startup.
--
-- A row naming a field that is not there is a typo, and a typo caught at load is
-- a message; the same typo caught in the inner loop is a nil arithmetic error
-- forty thousand ticks into a headless run.
function M.check_needs(rows, bodies)
  for index, row in ipairs(rows) do
    for _, field in ipairs(row.needs) do
      if bodies[field] == nil then
        error(string.format(
          "locomotion row %d (%s) needs a body field called '%s' and there is none",
          index, row.name, field))
      end
    end
  end
end
-- }}}

-- The three things every row shares. Shared as functions the rows call, not as
-- behaviour in a base class -- a row that wants a different fall writes one.

-- {{{ function M.settle_stance(Stone, store, bodies, id)
-- Brings `cell` and `layer` back into agreement with where the body actually is.
--
-- Everything else in the program reads the stance and not the position: the
-- spatial buckets, the renderer's draw order, the meet pass. A body whose stance
-- has drifted from its position is a body that is drawn in one place, collides
-- in another, and is found by neither.
function M.settle_stance(Stone, store, bodies, id)
  local x = math.floor(bodies.x[id])
  local y = math.floor(bodies.y[id])
  if not Stone.in_bounds(store, x, y) then return false end

  local cell = Stone.index(store, x, y)
  bodies.cell[id] = cell

  -- The surface it is standing on is the highest one at or below its feet.
  local layer = Stone.highest_surface_at_or_below(store, cell,
                                                  math.floor(bodies.z[id]))
  if layer >= 0 then
    bodies.layer[id] = layer
  end
  return true
end
-- }}}

-- {{{ function M.floor_under(Stone, store, bodies, id)
-- The height of the stone directly beneath a body's feet, or -1 over the void.
function M.floor_under(Stone, store, bodies, id)
  local x = math.floor(bodies.x[id])
  local y = math.floor(bodies.y[id])
  if not Stone.in_bounds(store, x, y) then return -1 end
  local cell = Stone.index(store, x, y)
  local layer = Stone.highest_surface_at_or_below(store, cell,
                                                  math.floor(bodies.z[id] + 0.001))
  if layer < 0 then return -1 end
  return M.surface_top(layer)
end
-- }}}

-- {{{ function M.apply_falling(Stone, store, bodies, id, kind, dt)
-- One piece of machinery, called by every row.
--
-- Identical for a ball that went over a cliff, a little guy that walked off a
-- terrace, a rider dropped when its mount died, and a vine that let go. Writing
-- it once is what keeps them agreeing about what a fall is.
--
-- Returns true while the body is in the air.
function M.apply_falling(Stone, store, bodies, id, kind, dt)
  local floor = M.floor_under(Stone, store, bodies, id)

  -- Over the void. The rim makes this impossible; it is checked anyway, and the
  -- caller is the one that shouts, because it knows which row let the body get
  -- there.
  if floor < 0 then return false end

  if bodies.z[id] <= floor + 1e-6 and bodies.vz[id] <= 0 then
    bodies.z[id]  = floor
    bodies.vz[id] = 0
    return false
  end

  bodies.vz[id] = bodies.vz[id] - kind.gravity * dt
  bodies.z[id]  = bodies.z[id] + bodies.vz[id] * dt

  if bodies.z[id] <= floor then
    bodies.z[id] = floor
    local bounce = -bodies.vz[id] * (kind.restitution or 0)
    -- Below the floor a bounce is set to zero rather than allowed to shrink
    -- forever. Without this the velocity approaches zero without reaching it and
    -- the body spends the rest of the run performing several hundred
    -- infinitesimal bounces a second -- each one a landing event, none of them
    -- visible, all of them costing.
    if bounce < (kind.bounce_floor or 0) then bounce = 0 end
    bodies.vz[id] = bounce
    return bounce > 0
  end

  return true
end
-- }}}

-- {{{ function M.check_in_world(Stone, store, bodies, id, row_name)
-- The rim makes leaving the world impossible, and this runs anyway, and it is
-- loud -- and it names the row that let the body get there, because that is the
-- one piece of information the stack trace will not have.
function M.check_in_world(Stone, store, bodies, id, row_name)
  local x, y = bodies.x[id], bodies.y[id]
  if x < 0 or y < 0 or x >= store.width or y >= store.depth then
    error(string.format(
      "body %d left the world at (%.2f, %.2f) while moving as '%s' -- " ..
      "the rim is supposed to make that impossible",
      id, x, y, row_name))
  end
end
-- }}}

return M
