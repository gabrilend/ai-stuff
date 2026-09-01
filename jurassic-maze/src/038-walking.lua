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

-- 038-walking.lua
--
-- The row that steps from surface to surface. Little guys.
--
-- A walking body has no velocity. It occupies a surface, chooses an adjacent
-- one, and takes a fixed time to get there. Everything smooth about it is the
-- renderer's doing, and the simulation never reads that.

local M = {}

local Stone, Locomotion, Moving, Creatures

-- {{{ function M.link(stone, locomotion, moving, creatures)
function M.link(stone, locomotion, moving, creatures)
  Stone, Locomotion, Moving, Creatures = stone, locomotion, moving, creatures
end
-- }}}

M.INTENT_WANDER = 1
M.INTENT_IDLE   = 2

-- {{{ local function opposite(direction)
local function opposite(direction)
  if direction == 1 then return 2 end
  if direction == 2 then return 1 end
  if direction == 3 then return 4 end
  return 3
end
-- }}}

-- {{{ local function choose_step(world, bodies, id, kind)
-- Which adjacent surface to walk to next.
--
-- Weighted against turning around. An unweighted random walk on a graph spends
-- most of its time going back and forth across the same two cells, which reads
-- as broken rather than as aimless -- a body that is wandering should get
-- somewhere eventually, even if it did not mean to.
--
-- The weight is never zero. A body in a dead end must be able to turn around,
-- and a rule that forbids it produces a body that stands in a corner for the
-- rest of the run, vibrating.
local function choose_step(world, bodies, id, kind)
  local store = world.store
  local rng   = world.streams.wander_guy
  local cell, layer = bodies.cell[id], bodies.layer[id]
  local came_from = opposite(bodies.facing[id] == 0 and 1 or bodies.facing[id])

  local total = 0
  local weights, targets = {}, {}

  for di = 1, 4 do
    local answer, ncell, nlayer =
      Moving.step(Stone, store, cell, layer, di, kind.drop_limit, kind.body_height)
    if answer ~= Moving.BLOCKED then
      local w = (di == came_from) and kind.reverse_weight or 1.0
      total = total + w
      weights[#weights + 1] = total
      targets[#targets + 1] = { di, ncell, nlayer }
    end
  end

  if #targets == 0 then return nil end

  local roll = rng:next_float() * total
  for k = 1, #targets do
    if roll <= weights[k] then return targets[k] end
  end
  return targets[#targets]
end
-- }}}

-- {{{ function M.begin_step(world, bodies, id, kind)
-- Sets up the journey from the current surface to the next one.
function M.begin_step(world, bodies, id, kind)
  local pick = choose_step(world, bodies, id, kind)
  if not pick then
    -- Nowhere to go at all. Legal -- a body can be standing on a surface with
    -- four walls around it, which the validator counts as a dead end -- so it
    -- idles rather than erroring, and the report is where that shows up.
    bodies.intent[id] = M.INTENT_IDLE
    bodies.timer[id]  = 1.0
    return false
  end

  bodies.from_cell[id]    = bodies.cell[id]
  bodies.from_layer[id]   = bodies.layer[id]
  bodies.facing[id]       = pick[1]
  bodies.intent_cell[id]  = pick[2]
  bodies.intent_layer[id] = pick[3]
  bodies.progress[id]     = 0
  bodies.intent[id]       = M.INTENT_WANDER
  return true
end
-- }}}

-- {{{ function M.advance(world, bodies, roster, first, last, dt)
-- Moves a slice of the walking roster.
--
-- The body is **either at one surface or at another**. It is never between them
-- as far as anything that matters is concerned, which is what makes both spatial
-- questions simple: which cell it is in is exactly one cell, always, and who is
-- near it is one bucket lookup. A continuous position would put a walker in two
-- cells for half of every step and every question about it would need a
-- tie-breaking rule.
function M.advance(world, bodies, roster, first, last, dt)
  local store = world.store
  local kinds = Creatures.KINDS

  for slot = first, last do
    local id = roster[slot]
    if bodies.alive[id] == 1 then
      local kind = kinds[bodies.kind[id]]

      -- Falling first, and it is the shared fall, not one of this row's own. A
      -- walker that has walked off a ledge and a ball that has rolled off one
      -- are doing the same thing, and writing it twice is how they start
      -- disagreeing about what a fall is.
      local ground = Locomotion.floor_under(Stone, store, bodies, id)
      if ground >= 0 and bodies.z[id] > ground + 0.02 then
        Locomotion.apply_falling(Stone, store, bodies, id, kind, dt)
        -- The step it was taking is abandoned rather than resumed: the surface
        -- it was heading for is no longer adjacent to where it has landed.
        bodies.progress[id] = 0
        bodies.intent[id]   = 0
        Locomotion.settle_stance(Stone, store, bodies, id)
      elseif bodies.intent[id] == M.INTENT_IDLE then
        bodies.timer[id] = bodies.timer[id] - dt
        bodies.rest_timer[id] = bodies.rest_timer[id] + dt
        if bodies.timer[id] <= 0 then
          bodies.intent[id] = 0
        end
      elseif bodies.intent[id] == M.INTENT_WANDER then
        bodies.progress[id] = bodies.progress[id] + dt / kind.step_seconds
        if bodies.progress[id] >= 1 then
          bodies.cell[id]  = bodies.intent_cell[id]
          bodies.layer[id] = bodies.intent_layer[id]
          bodies.progress[id] = 0
          bodies.intent[id]   = 0
          bodies.distance[id] = bodies.distance[id] + 1
          bodies.rest_timer[id] = 0

          local x, y = Stone.coords(store, bodies.cell[id])
          bodies.x[id] = x + 0.5
          bodies.y[id] = y + 0.5
          bodies.z[id] = Locomotion.surface_top(bodies.layer[id])
        end
      else
        -- Nothing decided. Idle sometimes, walk otherwise -- standing still for
        -- a moment is most of what makes a crowd read as alive rather than as a
        -- flock of things all going somewhere.
        if world.streams.idle:chance(kind.idle_chance) then
          bodies.intent[id] = M.INTENT_IDLE
          bodies.timer[id]  = 0.6 + world.streams.idle:next_float() * 2.5
        else
          M.begin_step(world, bodies, id, kind)
        end
      end

      Locomotion.check_in_world(Stone, store, bodies, id, "walking")
    end
  end
end
-- }}}

-- {{{ function M.drawn_position(bodies, id)
-- Where the renderer puts a walking body, and the only place the interpolation
-- happens.
--
-- The simulation never calls this. That separation is the whole reason a
-- smoothed graph walk was chosen for these bodies over continuous motion: the
-- simulation gets a graph, which is cheap and exact, and the eye gets
-- smoothness, which is a lie the renderer tells.
--
-- The arc on a vertical step is a cosmetic hack and it is written down because
-- somebody tidying up will delete it. Interpolating a one-layer climb in a
-- straight line makes the body slide up a diagonal, which reads as ascending an
-- invisible ramp rather than as climbing; a small hump peaking at the middle of
-- the step fixes it. A flat step gets no arc, because the difference is zero.
function M.drawn_position(Stone, store, bodies, id)
  local p = bodies.progress[id]
  if p <= 0 or bodies.intent[id] ~= M.INTENT_WANDER then
    local x, y = Stone.coords(store, bodies.cell[id])
    return x + 0.5, y + 0.5, bodies.z[id]
  end

  local fx, fy = Stone.coords(store, bodies.from_cell[id])
  local tx, ty = Stone.coords(store, bodies.intent_cell[id])
  local fz = bodies.from_layer[id] + 1
  local tz = bodies.intent_layer[id] + 1

  local x = (fx + 0.5) + ((tx + 0.5) - (fx + 0.5)) * p
  local y = (fy + 0.5) + ((ty + 0.5) - (fy + 0.5)) * p
  local z = fz + (tz - fz) * p

  local rise = math.abs(tz - fz)
  if rise > 0 then
    z = z + math.sin(p * math.pi) * 0.35 * rise
  end

  return x, y, z
end
-- }}}

return M
