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

-- 040-the-projection.lua
--
-- World to screen and back. Two-to-one isometric.
--
-- Pure arithmetic. It does not import the engine, and the headless runner loads
-- it, because the culling range is useful without a window.

local M = {}

-- A cell's diamond is twice as wide as it is tall. Measured off the reference
-- picture, and recorded in inspiration/NOTICE.md beside the other measurements.
--
-- Two-to-one rather than a true thirty-degree isometric because at two-to-one
-- every diamond edge advances exactly two pixels across for one down. Diagonals
-- land on whole pixels and the stone reads as stone instead of as a stack of
-- slightly wrong staircases. It is why essentially every hand-drawn isometric
-- picture ever made is two-to-one, including the one this is copying.
M.HALF_WIDTH  = 16
M.HALF_HEIGHT = 8

-- How many pixels tall one stone layer is. Independent of the cell size on
-- purpose: it is what lets the maze be squat or towering without the floor plan
-- changing underneath it.
M.LAYER_PIXELS = 10

-- {{{ function M.to_screen(camera, x, y, height)
-- Three numbers in, two out.
function M.to_screen(camera, x, y, height)
  local hw = M.HALF_WIDTH  * camera.scale
  local hh = M.HALF_HEIGHT * camera.scale
  local lp = M.LAYER_PIXELS * camera.scale
  return (x - y) * hw + camera.pan_x,
         (x + y) * hh - height * lp + camera.pan_y
end
-- }}}

-- {{{ function M.to_cell(camera, sx, sy)
-- The inverse, at height zero.
--
-- Exact only at height zero, and that matters: a tall column's top face is drawn
-- height * layer_pixels further up the screen than its ground position, so a
-- click landing on a wall's top reports the cell *behind* the one being looked
-- at. M.pick marches the ray to fix that; this is the cheap version the culling
-- uses, where being a few cells wrong is harmless.
function M.to_cell(camera, sx, sy)
  local hw = M.HALF_WIDTH  * camera.scale
  local hh = M.HALF_HEIGHT * camera.scale
  local u = (sx - camera.pan_x) / hw    -- x - y
  local v = (sy - camera.pan_y) / hh    -- x + y, at height zero
  return (u + v) * 0.5, (v - u) * 0.5
end
-- }}}

-- {{{ function M.visible_range(camera, store, screen_w, screen_h)
-- The cell bounds worth sweeping. Everything outside is skipped without being
-- considered at all.
--
-- The range is extended in the direction of increasing x + y by the tallest a
-- column can reach, converted from pixels into cells. Without that, a column
-- whose base is below the window but whose top face is inside it gets dropped,
-- and walls vanish off the bottom edge of the screen while you scroll. The
-- extension overestimates for a maze that is mostly short, and overestimating
-- costs a few skipped cells, which is the correct direction to be wrong in.
function M.visible_range(camera, store, screen_w, screen_h)
  local x0, y0 = M.to_cell(camera, 0, 0)
  local x1, y1 = M.to_cell(camera, screen_w, 0)
  local x2, y2 = M.to_cell(camera, 0, screen_h)
  local x3, y3 = M.to_cell(camera, screen_w, screen_h)

  local minx = math.floor(math.min(x0, x1, x2, x3)) - 1
  local maxx = math.ceil (math.max(x0, x1, x2, x3)) + 1
  local miny = math.floor(math.min(y0, y1, y2, y3)) - 1
  local maxy = math.ceil (math.max(y0, y1, y2, y3)) + 1

  local reach = math.ceil(store.layers * M.LAYER_PIXELS / M.HALF_HEIGHT) + 1
  maxx = maxx + reach
  maxy = maxy + reach

  if minx < 0 then minx = 0 end
  if miny < 0 then miny = 0 end
  if maxx > store.width  - 1 then maxx = store.width  - 1 end
  if maxy > store.depth  - 1 then maxy = store.depth  - 1 end

  return minx, miny, maxx, maxy
end
-- }}}

-- {{{ function M.pick(Stone, camera, store, sx, sy)
-- Which cell and layer a screen point is actually pointing at.
--
-- Marches down through the layers from the top of the world. At each layer, ask
-- which cell would have to be there for its top face to land under the pointer,
-- and whether that cell really is solid at that layer. The first that is, is
-- what is being looked at.
--
-- The cheap inversion above is wrong on anything tall, and a mouse that lies
-- about tall geometry is worse than no mouse. This costs a handful of iterations
-- once per click.
function M.pick(Stone, camera, store, sx, sy)
  local lp = M.LAYER_PIXELS * camera.scale
  for layer = store.layers - 1, 0, -1 do
    local fx, fy = M.to_cell(camera, sx, sy + layer * lp)
    local x, y = math.floor(fx), math.floor(fy)
    if Stone.in_bounds(store, x, y) then
      local i = Stone.index(store, x, y)
      if Stone.is_stone(store, i, layer) then
        return i, layer
      end
    end
  end
  return nil, nil
end
-- }}}

-- {{{ function M.centre_on(camera, x, y, height, screen_w, screen_h)
-- Sets the pan so a world point lands in the middle of the window.
function M.centre_on(camera, x, y, height, screen_w, screen_h)
  camera.pan_x = 0
  camera.pan_y = 0
  local sx, sy = M.to_screen(camera, x, y, height)
  camera.pan_x = screen_w * 0.5 - sx
  camera.pan_y = screen_h * 0.5 - sy
end
-- }}}

return M
