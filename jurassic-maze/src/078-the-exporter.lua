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

-- 078-the-exporter.lua
--
-- Draws the world once, at its own size, and writes the picture and the datafile
-- together.
--
-- The mountain does not move. Nothing about it changes between one frame and the
-- next or between one run and the next, and the viewer has been rebuilding
-- sixteen thousand polygons of it sixty times a second to produce the same
-- picture every time. Once the picture exists as a picture, the only thing left
-- to draw is the balls.
--
-- **Both files come out of one run, from the same numbers.** An exporter that
-- wrote the picture and left somebody to work out where the world sits in it
-- afterwards would produce scenes that are subtly wrong in a way nothing catches
-- until a ball is seen floating a foot above the ground.

local M = {}

-- A margin around the mountain, in pixels. Small: the bounds are exact, and this
-- is only so that the outline along the silhouette is not clipped by the edge of
-- the image.
local MARGIN = 8

-- {{{ function M.export(deps, world, into, name, love_graphics)
-- Writes `into/name.png` and `into/name.scene`, and returns what it did.
--
-- `deps` carries the modules this needs and does not load: Stone, Projection,
-- Palette, Renderer, SceneFile, Sightlines. Handed in for the same reason
-- everything else in this project is -- loading them again makes a second copy of
-- every table, and the one that matters is the palette.
function M.export(deps, world, into, name, love_graphics)
  local Stone      = deps.Stone
  local Projection = deps.Projection
  local Palette    = deps.Palette
  local Renderer   = deps.Renderer
  local SceneFile  = deps.SceneFile
  local Sightlines = deps.Sightlines

  local store = world.store

  -- Heights in planes, which is what a scene speaks. The store keeps the index of
  -- the topmost solid layer and a layer L occupies L to L + 1, so the plane a
  -- body stands on is one higher than the stored number.
  local planes = {}
  local highest = 0
  for i = 0, store.cells - 1 do
    local p = store.height[i] + 1
    planes[i] = p
    if p > highest then highest = p end
  end

  local b = SceneFile.bounds(store.width, store.depth, highest,
                             Projection.HALF_WIDTH, Projection.HALF_HEIGHT,
                             Projection.LAYER_PIXELS)

  local canvas_w = math.ceil(b.width)  + MARGIN * 2
  local canvas_h = math.ceil(b.height) + MARGIN * 2
  local origin_x = b.origin_x + MARGIN
  local origin_y = b.origin_y + MARGIN

  -- The same mesh, the same palette, the same everything the viewer draws with.
  -- The only difference between this and an ordinary frame is where it lands and
  -- how big the surface is.
  local baked = Renderer.build(Stone, Projection, Palette, store, love_graphics)

  local canvas = love_graphics.newCanvas(canvas_w, canvas_h)
  love_graphics.setCanvas(canvas)
  love_graphics.clear(0, 0, 0, 0)
  love_graphics.push()
  love_graphics.translate(origin_x, origin_y)
  love_graphics.setColor(1, 1, 1, 1)
  love_graphics.draw(baked.outline)
  love_graphics.draw(baked.fill)
  love_graphics.pop()
  love_graphics.setCanvas()

  local image_name = name .. ".png"
  local data = canvas:newImageData()
  local png = data:encode("png")
  local out = io.open(into .. "/" .. image_name, "wb")
  if not out then
    error("cannot write the picture to " .. into .. "/" .. image_name, 0)
  end
  out:write(png:getString())
  out:close()

  SceneFile.write(into .. "/" .. name .. ".scene", {
    name         = name,
    image        = image_name,
    width        = store.width,
    depth        = store.depth,
    half_width   = Projection.HALF_WIDTH,
    half_height  = Projection.HALF_HEIGHT,
    layer_pixels = Projection.LAYER_PIXELS,
    origin_x     = origin_x,
    origin_y     = origin_y,
    spawn_x      = math.floor(store.width  * 0.05),
    spawn_y      = math.floor(store.depth  * 0.05),
    spawn_z      = highest,
    height       = planes,
  })

  -- How much of the world the camera can actually see.
  --
  -- The number that says whether a scene is usable at all. A client has a
  -- photograph and some sprites -- it cannot draw a body *behind* stone, it can
  -- only decline to draw it. So a scene that hides a third of its own floor will
  -- hide a third of its bodies, and that is a property of the world rather than a
  -- fault in anything, which is exactly the sort of thing that has to be a number
  -- somebody reads rather than a surprise somebody meets.
  local seen = Sightlines.survey(
    { width = store.width, depth = store.depth, layers = highest + 2,
      height = planes, walkable = (function()
        local w = {}
        for i = 0, store.cells - 1 do w[i] = true end
        return w
      end)() },
    Sightlines.climb(Projection))

  return {
    image   = into .. "/" .. image_name,
    scene   = into .. "/" .. name .. ".scene",
    width   = canvas_w,
    height  = canvas_h,
    faces   = baked.faces,
    highest = highest,
    visible = seen.floor_any / math.max(1, seen.floor_cells),
  }
end
-- }}}

return M
