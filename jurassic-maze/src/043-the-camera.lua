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

-- 043-the-camera.lua
--
-- Pan, zoom, and following a body.
--
-- Four numbers and nothing else. Pure arithmetic -- it does not import the
-- engine, so the headless runner can construct one to compute a culling range
-- without a window being anywhere near it.

local M = {}

M.MIN_SCALE = 0.12
M.MAX_SCALE = 4.0

-- {{{ function M.new()
function M.new()
  return {
    pan_x = 0,
    pan_y = 0,
    -- Zoom multiplies all three projection constants by this one number. Scaling
    -- the cell size and the layer height independently would change the apparent
    -- angle of the world as you zoom, which reads as the maze leaning.
    scale = 0.5,
    -- Who is being followed, or zero for nobody. Held with the body's generation
    -- so that a subject whose slot was recycled is caught being gone rather than
    -- silently becoming whoever moved in.
    subject = 0,
    subject_generation = 0,
  }
end
-- }}}

-- {{{ function M.pan_by(camera, dx, dy)
function M.pan_by(camera, dx, dy)
  camera.pan_x = camera.pan_x + dx
  camera.pan_y = camera.pan_y + dy
end
-- }}}

-- {{{ function M.zoom_at(Projection, camera, factor, sx, sy)
-- Zooms, keeping the world point under (sx, sy) exactly where it was.
--
-- Invert the projection at the pointer, change the scale, invert again, and add
-- the difference to the pan. Zooming toward the middle of the window instead
-- means that whenever the thing you care about is not in the middle -- which is
-- most of the time, because you are zooming in order to look at it -- you chase
-- it back to the centre after every notch of the wheel.
function M.zoom_at(Projection, camera, factor, sx, sy)
  local before_x, before_y = Projection.to_cell(camera, sx, sy)

  local s = camera.scale * factor
  if s < M.MIN_SCALE then s = M.MIN_SCALE end
  if s > M.MAX_SCALE then s = M.MAX_SCALE end
  camera.scale = s

  local after_x, after_y = Projection.to_cell(camera, sx, sy)

  -- The correction is in world cells, so it goes back through the projection to
  -- become pixels. Doing it in screen pixels directly gets the sign right and
  -- the magnitude wrong at every scale but one.
  local zero = { pan_x = 0, pan_y = 0, scale = camera.scale }
  local ax, ay = Projection.to_screen(zero, after_x - before_x, after_y - before_y, 0)
  camera.pan_x = camera.pan_x + ax
  camera.pan_y = camera.pan_y + ay
end
-- }}}

-- {{{ function M.clamp(Projection, camera, store, screen_w, screen_h)
-- Keeps the maze from being scrolled entirely off the screen.
--
-- Not to keep it centred -- panning freely is the point -- but because a person
-- who has scrolled into empty space has no cue about which way to come back, and
-- the only recovery is to guess.
--
-- Clamped in world coordinates rather than screen ones. A clamp in pixels
-- behaves differently at every zoom level, which reads as the maze becoming
-- sticky as you zoom in.
function M.clamp(Projection, camera, store, screen_w, screen_h)
  local cx, cy = Projection.to_cell(camera, screen_w * 0.5, screen_h * 0.5)
  local margin = 8
  local moved = false

  if cx < -margin then cx, moved = -margin, true end
  if cy < -margin then cy, moved = -margin, true end
  if cx > store.width  + margin then cx, moved = store.width  + margin, true end
  if cy > store.depth  + margin then cy, moved = store.depth  + margin, true end

  if moved then
    Projection.centre_on(camera, cx, cy, 0, screen_w, screen_h)
  end
end
-- }}}

-- {{{ function M.ease_toward(Projection, camera, x, y, height, screen_w, screen_h, ease)
-- Slides the pan toward a world point instead of snapping to it.
--
-- Snapping a camera to a body that is stepping between cells makes the whole
-- maze jitter by a cell every step, which is unwatchable. Easing by a fraction of
-- the remaining distance each tick means the camera always arrives and never
-- gets there abruptly.
function M.ease_toward(Projection, camera, x, y, height, screen_w, screen_h, ease)
  local want = { pan_x = 0, pan_y = 0, scale = camera.scale }
  local sx, sy = Projection.to_screen(want, x, y, height)
  local target_x = screen_w * 0.5 - sx
  local target_y = screen_h * 0.5 - sy

  camera.pan_x = camera.pan_x + (target_x - camera.pan_x) * ease
  camera.pan_y = camera.pan_y + (target_y - camera.pan_y) * ease
end
-- }}}

-- {{{ function M.fit(Projection, camera, store, screen_w, screen_h)
-- Sets the scale and pan so the whole maze is on screen.
--
-- The projected width of a w by d maze is (w + d) * half_width, and its height
-- is (w + d) * half_height plus whatever the tallest column reaches. Solving for
-- the scale that fits both is two divisions, and taking the smaller is what
-- makes it fit rather than merely fit one way.
function M.fit(Projection, camera, store, screen_w, screen_h)
  local span = store.width + store.depth
  local wide = span * Projection.HALF_WIDTH
  local tall = span * Projection.HALF_HEIGHT + store.layers * Projection.LAYER_PIXELS

  local s = math.min(screen_w / wide, screen_h / tall) * 0.95
  if s < M.MIN_SCALE then s = M.MIN_SCALE end
  if s > M.MAX_SCALE then s = M.MAX_SCALE end
  camera.scale = s

  Projection.centre_on(camera, store.width * 0.5, store.depth * 0.5,
                       store.layers * 0.35, screen_w, screen_h)
end
-- }}}

return M
