-- hero-less-moba — a lane-pushing game with the heroes subtracted out
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

-- 074-the-drawn-body.lua
--
-- Where a body is drawn when the picture is allowed weight: a second, softer
-- position that chases the real one and that only the screen reads.
--
-- ## Not a blend
--
-- The honest picture draws a body a fraction of the way between the two most recent
-- frames. It has no state of its own, so a body that turns, turns instantly. This one
-- does: each drawn body has a place and a velocity, and is pulled toward the honest
-- position by a spring that is a little too lively to settle at once. It leans into a
-- turn, runs a little past a stop, and comes back -- the decaying oscillation added to
-- the real path that issue 709 asked for.
--
-- ## Nothing here is read by anything but the screen
--
-- The simulation never sees these numbers, and nothing in this file can reach the
-- world: it is handed two snapshots and writes only into its own arrays. The moment a
-- drawn position fed back into a decision, the game would be played by the renderer.
--
-- ## How far the picture may lie
--
-- **Never further than half a body's personal space from where the body really is.**
-- Half, because a neighbour can stand one personal space away, and a drawn body further
-- off than half of that could appear on the far side of somebody it never passed. The
-- spring at walking pace lags by a pace or two and never reaches this; the bound is for
-- whatever the spring was not designed for.
--
-- ## A body that was put somewhere, rather than walking there
--
-- A spawn, a hero bought onto a tower, a guard placed beside its post. A body chasing
-- with weight would fly across the screen to get there, so a body **snaps** -- is drawn
-- exactly where it is, with no velocity -- when:
--
--   * it was not alive in the previous frame, or not followed last time (just born, or
--     its slot was reused by somebody else);
--   * it moved further than one personal space between two consecutive ticks. Nothing
--     walks that far in a tick -- the fastest gait covers under two paces -- so a body
--     that did was placed, not walked;
--   * the clock is running faster than walking pace, where a frame spans many ticks and
--     the honest picture is already drawn as it stands, unblended.

local M = {}

-- {{{ The spring
-- **Provisional, and found by looking** (709, R2). How lively a drawn body is and how
-- fast that dies away decide together whether it reads as weight or as wobble, and
-- nobody has looked yet. Three swings a second with half the damping that would stop it
-- dead trails a hurrying body by about two paces, runs past a stop by under one, and
-- settles inside two-thirds of a second.
M.FREQUENCY = 3.0
M.DAMPING   = 0.5

-- The solution below is the one for a spring that swings. A damping of one or more
-- does not swing, has no weight to show, and would divide by nought; it is refused
-- here rather than handled, because it is a different spring and not a setting.
if M.DAMPING <= 0 or M.DAMPING >= 1 then
  error("the drawn body's damping must lie strictly between 0 and 1, not " .. M.DAMPING)
end

-- How far, as a fraction of personal space, the drawn body may be from the real one.
M.LAG_LIMIT = 0.5
-- }}}

-- {{{ function M.create()
-- One drawn place and velocity per body slot, and whether that slot was followed last
-- frame. Flat arrays, the same shape as the world's own.
function M.create(capacity, personal_space)
  local drawn = {
    x = {}, y = {}, vx = {}, vy = {}, followed = {},
    capacity = capacity,
    lag_limit = personal_space * M.LAG_LIMIT,
    placed_distance = personal_space,
  }
  for id = 1, capacity do
    drawn.x[id], drawn.y[id], drawn.vx[id], drawn.vy[id] = 0, 0, 0, 0
    drawn.followed[id] = 0
  end
  return drawn
end
-- }}}

-- {{{ local function snap()
local function snap(drawn, id, x, y)
  drawn.x[id], drawn.y[id] = x, y
  drawn.vx[id], drawn.vy[id] = 0, 0
end
-- }}}

-- {{{ local function was_placed()
-- Whether this body arrived where it is by some means other than walking.
local function was_placed(drawn, previous, newest, id)
  if previous.alive[id] ~= 1 or drawn.followed[id] ~= 1 then
    return true
  end
  local dx, dy = newest.x[id] - previous.x[id], newest.y[id] - previous.y[id]
  return dx * dx + dy * dy > drawn.placed_distance * drawn.placed_distance
end
-- }}}

-- {{{ function M.follow()
-- Pulls one drawn body toward a target for `seconds` of real time, and then holds it
-- within the lag limit.
--
-- **Solved, not stepped.** Over one frame the target stands still, and a damped spring
-- pulled toward a fixed point has an exact answer, so the drawn body is put where that
-- answer says. Stepping it instead would make the motion depend on how long the frames
-- were, and the picture on a slow machine would swing differently from the picture on
-- a fast one.
function M.follow(drawn, id, target_x, target_y, seconds)
  local omega = 2 * math.pi * M.FREQUENCY
  local decay = M.DAMPING * omega
  local swing = omega * math.sqrt(1 - M.DAMPING * M.DAMPING)
  local fade = math.exp(-decay * seconds)
  local cosine, sine = math.cos(swing * seconds), math.sin(swing * seconds)

  -- Per axis, as an offset from the target: the offset and its rate now, and the two
  -- amplitudes of the decaying swing they start.
  local ex, ey = drawn.x[id] - target_x, drawn.y[id] - target_y
  local vx, vy = drawn.vx[id], drawn.vy[id]
  local bx = (vx + decay * ex) / swing
  local by = (vy + decay * ey) / swing

  local x = target_x + fade * (ex * cosine + bx * sine)
  local y = target_y + fade * (ey * cosine + by * sine)
  vx = fade * ((bx * swing - decay * ex) * cosine - (ex * swing + decay * bx) * sine)
  vy = fade * ((by * swing - decay * ey) * cosine - (ey * swing + decay * by) * sine)

  -- The bound. Pulled back onto its edge rather than snapped, so a body that strays
  -- past it still moves continuously; and the velocity carrying it outward is dropped,
  -- so it does not lean on the edge.
  local dx, dy = x - target_x, y - target_y
  local distance = math.sqrt(dx * dx + dy * dy)
  if distance > drawn.lag_limit then
    local scale = drawn.lag_limit / distance
    x, y = target_x + dx * scale, target_y + dy * scale
    local outward = (vx * dx + vy * dy) / distance
    if outward > 0 then
      vx = vx - outward * dx / distance
      vy = vy - outward * dy / distance
    end
  end

  drawn.x[id], drawn.y[id], drawn.vx[id], drawn.vy[id] = x, y, vx, vy
end
-- }}}

-- {{{ function M.update()
-- One frame. `honest_x` and `honest_y` are the straight-blend positions the honest
-- picture would draw -- the drawn body chases those rather than the raw frames, so it
-- chases something that is itself moving smoothly. `walking_pace` is false whenever
-- the clock runs faster than one tick per tick.
--
-- Every live body is followed every frame whichever picture is on screen, so that
-- switching to the weighted one starts from bodies that are already moving rather than
-- from every body snapping at once.
function M.update(drawn, previous, newest, honest_x, honest_y, seconds, walking_pace)
  local followed = drawn.followed
  for id = 1, drawn.capacity do
    if newest.alive[id] ~= 1 then
      followed[id] = 0
    end
  end
  for index = 1, newest.live_count do
    local id = newest.live[index]
    if not walking_pace or was_placed(drawn, previous, newest, id) then
      snap(drawn, id, honest_x[id], honest_y[id])
    else
      M.follow(drawn, id, honest_x[id], honest_y[id], seconds)
    end
    followed[id] = 1
  end
end
-- }}}

return M
