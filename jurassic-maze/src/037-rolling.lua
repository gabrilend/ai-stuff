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

-- 037-rolling.lua
--
-- The row with momentum in it. Balls.
--
-- A ball is never on a cell. It is at some fractional x and y, and the floor
-- under it is a smooth surface obtained by interpolating the heights of the four
-- cells around it. It never asks the stone which of four answers applies; it
-- integrates a velocity and collides with faces.

local M = {}

local Stone, Locomotion, Moving, Creatures

-- The four diagonals, hoisted out of the corner resolver.
--
-- Written inline it was a fresh table -- five of them, counting the pairs --
-- allocated once per body per tick. At a few hundred bodies that is a million
-- allocations a minute for a constant, and the whole move pass spent most of its
-- time in the collector. A renderer that allocates per frame stutters; a
-- simulation that allocates per body per tick just runs slowly and gives no clue
-- why.
local DIAGONALS = { {1, 1}, {1, -1}, {-1, 1}, {-1, -1} }

-- {{{ function M.link(stone, locomotion, moving, creatures)
-- The modules are handed in rather than loaded here, because this file is loaded
-- by the tick which already has them, and loading them again would produce a
-- second copy of every table -- including the creature table, which would then
-- be tuned in one copy and read from the other.
function M.link(stone, locomotion, moving, creatures)
  Stone, Locomotion, Moving, Creatures = stone, locomotion, moving, creatures
end
-- }}}

-- {{{ local function sample_height(store, cx, cy, ref_h)
-- The floor height one cell contributes to the interpolation.
--
-- **Only cells within one layer of the ball's own surface contribute their real
-- height.** A cell higher than that is a wall and contributes the ball's own
-- height instead; a cell lower than that is a cliff and does the same.
--
-- Without the clamp, interpolating between a corridor at layer four and a wall
-- at layer six produces a gentle ramp into the wall, and the ball rolls up it.
-- With it, the floor is flat right up to the wall, and the wall is dealt with by
-- collision -- which is what a wall is.
--
-- The cliff half of the clamp matters just as much and is easier to forget:
-- without it the floor slopes away over the edge and the ball is dragged down
-- the cliff face rather than leaving the ledge and falling.
local function sample_height(store, cx, cy, ref_h)
  if cx < 0 or cy < 0 or cx >= store.width or cy >= store.depth then
    return ref_h
  end
  local h = store.height[cx + cy * store.width]
  if h > ref_h + Moving.CLIMB_LIMIT then return ref_h end
  if h < ref_h - 1 then return ref_h end
  return h
end
-- }}}

-- {{{ local function floor_patch(store, x, y, ref_h, out)
-- The interpolated floor under a point **and its slope**, from one set of four
-- samples.
--
-- Heights are sampled at cell centres, so a ball at the exact centre of a cell
-- sits at that cell's height and one on the boundary between two sits halfway
-- between theirs. Sampling at cell corners instead puts the ball half a cell out
-- of step with the stone it is standing on, which reads as the whole maze being
-- shifted.
--
-- The slope is differentiated analytically rather than by sampling the field
-- either side of the point. Four corner heights make the patch *exactly*
-- bilinear, so the derivative is exact and free -- where sampling means four
-- more interpolations, twenty more bounds-checked array reads, and an answer
-- that is wrong wherever the two sample points straddle a patch boundary and
-- average across a seam that is genuinely a discontinuity.
--
-- This was five interpolations per ball per tick and is now one. It is most of
-- the difference between the move pass costing fourteen microseconds a body and
-- costing two.
--
-- A staircase is where the interpolation pays off. Every step is one layer, so
-- every step is within the clamp, so the flight becomes a continuous ramp and
-- the ball accelerates smoothly down it. That is a deliberate lie about the
-- geometry -- the steps really are steps -- told because the alternative is a
-- ball bouncing chaotically down every staircase in the maze, which is harder to
-- test and no more convincing.
local function floor_patch(store, x, y, ref_h, out)
  local gx, gy = x - 0.5, y - 0.5
  local ix, iy = math.floor(gx), math.floor(gy)
  local fx, fy = gx - ix, gy - iy

  local h00 = sample_height(store, ix,     iy,     ref_h)
  local h10 = sample_height(store, ix + 1, iy,     ref_h)
  local h01 = sample_height(store, ix,     iy + 1, ref_h)
  local h11 = sample_height(store, ix + 1, iy + 1, ref_h)

  local top = h00 * (1 - fx) * (1 - fy)
            + h10 * fx       * (1 - fy)
            + h01 * (1 - fx) * fy
            + h11 * fx       * fy

  out[1] = Locomotion.surface_top(top)
  out[2] = (h10 - h00) * (1 - fy) + (h11 - h01) * fy   -- slope along x
  out[3] = (h01 - h00) * (1 - fx) + (h11 - h10) * fx   -- slope along y
  return out
end
-- }}}

-- {{{ local function floor_at(store, x, y, ref_h)
-- The interpolated floor alone, for callers that do not want the slope.
local PATCH = { 0, 0, 0 }
local function floor_at(store, x, y, ref_h)
  return floor_patch(store, x, y, ref_h, PATCH)[1]
end
-- }}}

-- {{{ local function is_wall(store, cx, cy, ref_h)
-- A neighbouring cell whose surface stands more than a body can climb above the
-- ball's own. Off the edge of the world counts as wall, so the rim collides.
local function is_wall(store, cx, cy, ref_h)
  if cx < 0 or cy < 0 or cx >= store.width or cy >= store.depth then
    return true
  end
  return store.height[cx + cy * store.width] > ref_h + Moving.CLIMB_LIMIT
end
-- }}}

-- {{{ local function resolve_faces(store, bodies, id, r, restitution, cx, cy, ref_h)
-- Push the ball out of any wall face it has overlapped, and reflect the velocity
-- component along that face's normal.
--
-- Pushed out along the normal, not moved back along its path: resolving an
-- overlap is about ending up somewhere legal, and straight out is the cheapest
-- legal place. The component along the face is left alone, so a ball arriving at
-- a shallow angle slides along the wall instead of stopping dead.
local function resolve_faces(store, bodies, id, r, restitution, cx, cy, ref_h)
  local x, y = bodies.x[id], bodies.y[id]

  if is_wall(store, cx + 1, cy, ref_h) and x > cx + 1 - r then
    x = cx + 1 - r
    if bodies.vx[id] > 0 then bodies.vx[id] = -bodies.vx[id] * restitution end
  end
  if is_wall(store, cx - 1, cy, ref_h) and x < cx + r then
    x = cx + r
    if bodies.vx[id] < 0 then bodies.vx[id] = -bodies.vx[id] * restitution end
  end
  if is_wall(store, cx, cy + 1, ref_h) and y > cy + 1 - r then
    y = cy + 1 - r
    if bodies.vy[id] > 0 then bodies.vy[id] = -bodies.vy[id] * restitution end
  end
  if is_wall(store, cx, cy - 1, ref_h) and y < cy + r then
    y = cy + r
    if bodies.vy[id] < 0 then bodies.vy[id] = -bodies.vy[id] * restitution end
  end

  bodies.x[id], bodies.y[id] = x, y
end
-- }}}

-- {{{ local function resolve_corners(store, bodies, id, r, restitution, cx, cy, ref_h)
-- The case that gets forgotten, and the single most likely bug in this file.
--
-- Where two walls meet, the nearest point of the obstacle is not on either face
-- -- it is the corner post between them -- so the ball has to be pushed away
-- from a *point* rather than a plane. Handling only the faces lets a ball
-- squeeze diagonally through the join between two blocks, which looks exactly
-- like the ball passing through solid stone, and which happens rarely enough to
-- be dismissed as a glitch.
--
-- Only the diagonals whose two orthogonal neighbours are *open* matter. Where
-- one of them is wall, the face has already dealt with it, and pushing off the
-- corner as well would shove the ball back through the face it was just pushed
-- out of.
local function resolve_corners(store, bodies, id, r, restitution, cx, cy, ref_h)
  for k = 1, 4 do
    local d = DIAGONALS[k]
    local dx, dy = d[1], d[2]
    if is_wall(store, cx + dx, cy + dy, ref_h)
       and not is_wall(store, cx + dx, cy, ref_h)
       and not is_wall(store, cx, cy + dy, ref_h) then

      -- The shared vertex of the four cells, which is the corner post itself.
      local px = cx + (dx > 0 and 1 or 0)
      local py = cy + (dy > 0 and 1 or 0)
      local ox, oy = bodies.x[id] - px, bodies.y[id] - py
      local dist = math.sqrt(ox * ox + oy * oy)

      if dist < r and dist > 1e-9 then
        local nx, ny = ox / dist, oy / dist
        bodies.x[id] = px + nx * r
        bodies.y[id] = py + ny * r
        local along = bodies.vx[id] * nx + bodies.vy[id] * ny
        if along < 0 then
          bodies.vx[id] = bodies.vx[id] - (1 + restitution) * along * nx
          bodies.vy[id] = bodies.vy[id] - (1 + restitution) * along * ny
        end
      end
    end
  end
end
-- }}}

-- {{{ function M.advance(world, bodies, roster, first, last, dt)
-- Moves a slice of the rolling roster.
--
-- A range rather than one body, because a per-body function forces an indirect
-- call once per body per tick and because a range is what a thread pool takes.
function M.advance(world, bodies, roster, first, last, dt)
  local store = world.store
  local kinds = Creatures.KINDS

  for slot = first, last do
    local id = roster[slot]
    if bodies.alive[id] == 1 then
      local kind = kinds[bodies.kind[id]]
      local r = kind.radius

      local cx = math.floor(bodies.x[id])
      local cy = math.floor(bodies.y[id])
      if cx < 0 then cx = 0 elseif cx >= store.width then cx = store.width - 1 end
      if cy < 0 then cy = 0 elseif cy >= store.depth then cy = store.depth - 1 end
      local ref_h = store.height[cx + cy * store.width]

      -- Is it on the ground, or over a drop it has already gone past?
      local ground = Locomotion.surface_top(ref_h)
      local airborne = bodies.z[id] > ground + 0.02

      if airborne then
        -- While in the air the ball is checked against the stone at its
        -- *current* height, not against the surface below it. A column that is
        -- solid at the ball's z is a wall to it right now, and skipping that
        -- check lets balls tunnel into the sides of walls and re-emerge inside
        -- them -- after which every rule in this file gives the wrong answer,
        -- because the floor under the ball is the top of the block it is inside,
        -- so it is standing on nothing, so it falls forever.
        local at_layer = math.floor(bodies.z[id])
        local solid_ref = at_layer - 1
        resolve_faces(store, bodies, id, r, kind.restitution, cx, cy, solid_ref)
        resolve_corners(store, bodies, id, r, kind.restitution, cx, cy, solid_ref)

        bodies.x[id] = bodies.x[id] + bodies.vx[id] * dt
        bodies.y[id] = bodies.y[id] + bodies.vy[id] * dt
        Locomotion.apply_falling(Stone, store, bodies, id, kind, dt)
      else
        -- On the floor. Gravity acts along the slope, which is sampled from the
        -- interpolated field rather than reasoned about from cell heights -- so
        -- it is automatically zero on flat ground, automatically downhill on a
        -- staircase, and automatically zero at a wall, because that is what the
        -- field does there.
        floor_patch(store, bodies.x[id], bodies.y[id], ref_h, PATCH)
        local gx, gy = PATCH[2], PATCH[3]

        local g = kind.gravity * kind.slope_gain
        bodies.vx[id] = bodies.vx[id] - g * gx * dt
        bodies.vy[id] = bodies.vy[id] - g * gy * dt

        -- Rolling resistance, so a ball on flat ground eventually stops rather
        -- than drifting until the machine is turned off.
        local damp = 1 - kind.roll_friction * dt
        if damp < 0 then damp = 0 end
        bodies.vx[id] = bodies.vx[id] * damp
        bodies.vy[id] = bodies.vy[id] * damp

        -- The speed cap, which is what stops a ball passing a wall without ever
        -- being within its radius of it. No amount of correct collision code
        -- catches a body that moved further than its own width in one tick, so
        -- the fix is to make that impossible -- and it is why the timestep is
        -- fixed rather than whatever the frame took.
        local speed = math.sqrt(bodies.vx[id] ^ 2 + bodies.vy[id] ^ 2)
        if speed > kind.max_speed then
          local s = kind.max_speed / speed
          bodies.vx[id] = bodies.vx[id] * s
          bodies.vy[id] = bodies.vy[id] * s
          speed = kind.max_speed
        end

        bodies.x[id] = bodies.x[id] + bodies.vx[id] * dt
        bodies.y[id] = bodies.y[id] + bodies.vy[id] * dt

        resolve_faces(store, bodies, id, r, kind.restitution, cx, cy, ref_h)
        resolve_corners(store, bodies, id, r, kind.restitution, cx, cy, ref_h)

        -- Glued to the interpolated floor while it is on it. The ball leaves the
        -- ground by its cell changing to one whose stone is lower, not by this
        -- ever letting go.
        local nx = math.floor(bodies.x[id])
        local ny = math.floor(bodies.y[id])
        if nx >= 0 and ny >= 0 and nx < store.width and ny < store.depth then
          local nh = store.height[nx + ny * store.width]
          local nground = Locomotion.surface_top(nh)
          if nground < bodies.z[id] - 0.02 then
            bodies.vz[id] = 0                 -- it has gone over an edge
          else
            bodies.z[id]  = floor_at(store, bodies.x[id], bodies.y[id], nh)
            bodies.vz[id] = 0
          end
        end

        -- How long it has been effectively still. The aquarium takes a resting
        -- ball away and drops a new one in at the top, which is what makes this
        -- a circulation rather than a run with an end.
        if speed < 0.25 then
          bodies.rest_timer[id] = bodies.rest_timer[id] + dt
        else
          bodies.rest_timer[id] = 0
        end
        bodies.distance[id] = bodies.distance[id] + speed * dt
      end

      Locomotion.check_in_world(Stone, store, bodies, id, "rolling")
      Locomotion.settle_stance(Stone, store, bodies, id)
    end
  end
end
-- }}}

return M
