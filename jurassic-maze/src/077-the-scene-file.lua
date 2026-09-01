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

-- 077-the-scene-file.lua
--
-- Reads and writes a scene: five numbers, a height field, and the name of a
-- picture.
--
-- A scene is the whole interface between the thing that builds a world and the
-- thing that draws one. Two files -- a picture with nothing alive in it, and this
-- -- and anything that can read them can run the simulation. No generator, no
-- plate list, no mesh, no renderer.
--
-- **The five numbers are the point of the format.** A world position becomes a
-- pixel of the picture by
--
--     px = origin_x + (x - y) * half_width
--     py = origin_y + (x + y) * half_height - z * layer_pixels
--
-- and there is nothing else to know. That is what makes the picture
-- interchangeable: the one this project's exporter writes is a picture of the
-- mountain it built, and a painting somebody made by hand would do just as well.
-- The work of using one is measuring those five numbers off it -- the width and
-- height of a cell's diamond, the height of one step, and where a known corner
-- lands. The projection therefore lives in the file rather than being assumed,
-- which is the single decision this format is built around.
--
-- The reader and the writer are in one file on purpose. Split across two, a
-- format drifts, and it drifts silently, because each half stays consistent with
-- itself.

local M = {}

-- {{{ local function refuse(where, fmt, ...)
-- Every complaint names the file and the line. A scene is a text file somebody
-- may well have edited, and "malformed scene" sends them looking through all of
-- it.
local function refuse(where, fmt, ...)
  error(string.format("scene '%s': " .. fmt, where, ...), 0)
end
-- }}}

-- {{{ function M.write(path, scene)
-- A scene to a file.
--
-- Plain text, line-oriented, one number per cell. A binary format would be a
-- twentieth of the size and nobody could open one and see what was wrong with it.
function M.write(path, scene)
  local f, err = io.open(path, "w")
  if not f then refuse(path, "cannot be written: %s", tostring(err)) end

  f:write("# a jurassic-maze scene: a picture, and where the world sits in it.\n")
  f:write("# px = origin_x + (x - y) * half_width\n")
  f:write("# py = origin_y + (x + y) * half_height - z * layer_pixels\n")
  f:write(string.format("scene %s\n", scene.name))
  f:write(string.format("image %s\n", scene.image))
  f:write(string.format("size %d %d\n", scene.width, scene.depth))
  f:write(string.format("projection %g %g %g\n",
                        scene.half_width, scene.half_height, scene.layer_pixels))
  f:write(string.format("origin %g %g\n", scene.origin_x, scene.origin_y))
  f:write(string.format("spawn %d %d %d\n",
                        scene.spawn_x, scene.spawn_y, scene.spawn_z))
  f:write("height\n")

  -- One row per line, so a person can see the shape of the mountain in the file.
  -- Heights are **planes**: a cell of 22 is ground you stand on at 22. The stone
  -- store's off-by-one belongs to a bitmask this format does not have.
  local row = {}
  for y = 0, scene.depth - 1 do
    for x = 0, scene.width - 1 do
      row[x + 1] = scene.height[x + y * scene.width]
    end
    f:write(table.concat(row, " ", 1, scene.width), "\n")
  end

  f:close()
end
-- }}}

-- {{{ function M.read(path)
-- A file to a scene. Refuses rather than guesses.
--
-- Every missing line is a refusal and no field has a default. A scene that loads
-- with a plausible substitute is a simulation running on a world nobody
-- described, and the symptom is bodies in the wrong place by an amount nobody can
-- account for.
function M.read(path)
  local f, err = io.open(path, "r")
  if not f then refuse(path, "cannot be read: %s", tostring(err)) end

  local scene = {}
  local heights = nil
  local row = 0
  local line_no = 0

  for line in f:lines() do
    line_no = line_no + 1
    if not (line:match("^%s*#") or line:match("^%s*$")) then
      if heights then
        -- Inside the grid. Every row has to be exactly as wide as the header
        -- said, because a short row would otherwise leave the rest of the
        -- mountain at whatever the array happened to hold.
        local n = 0
        for word in line:gmatch("%S+") do
          local v = tonumber(word)
          if not v then
            refuse(path, "line %d: '%s' is not a height", line_no, word)
          end
          if n >= scene.width then
            refuse(path, "line %d: the row is longer than the %d cells declared",
                   line_no, scene.width)
          end
          heights[n + row * scene.width] = v
          n = n + 1
        end
        if n ~= scene.width then
          refuse(path, "line %d: the row has %d cells and the header said %d",
                 line_no, n, scene.width)
        end
        row = row + 1
        if row > scene.depth then
          refuse(path, "line %d: more rows than the %d declared", line_no, scene.depth)
        end
      else
        local word, rest = line:match("^(%S+)%s*(.*)$")
        if word == "scene" then
          scene.name = rest
        elseif word == "image" then
          scene.image = rest
        elseif word == "size" then
          scene.width, scene.depth = rest:match("^(%S+)%s+(%S+)$")
          scene.width, scene.depth = tonumber(scene.width), tonumber(scene.depth)
        elseif word == "projection" then
          local a, b, c = rest:match("^(%S+)%s+(%S+)%s+(%S+)$")
          scene.half_width  = tonumber(a)
          scene.half_height = tonumber(b)
          scene.layer_pixels = tonumber(c)
        elseif word == "origin" then
          local a, b = rest:match("^(%S+)%s+(%S+)$")
          scene.origin_x, scene.origin_y = tonumber(a), tonumber(b)
        elseif word == "spawn" then
          local a, b, c = rest:match("^(%S+)%s+(%S+)%s+(%S+)$")
          scene.spawn_x, scene.spawn_y, scene.spawn_z =
            tonumber(a), tonumber(b), tonumber(c)
        elseif word == "height" then
          if not (scene.width and scene.depth) then
            refuse(path, "line %d: the grid begins before the size is known",
                   line_no)
          end
          heights = {}
        else
          refuse(path, "line %d: '%s' is not something a scene says", line_no, word)
        end
      end
    end
  end
  f:close()

  for _, field in ipairs({ "name", "image", "width", "depth", "half_width",
                           "half_height", "layer_pixels", "origin_x", "origin_y",
                           "spawn_x", "spawn_y", "spawn_z" }) do
    if scene[field] == nil then
      refuse(path, "says nothing about '%s'", field)
    end
  end
  if not heights then refuse(path, "has no height field in it") end
  if row ~= scene.depth then
    refuse(path, "has %d rows of height and declares %d", row, scene.depth)
  end
  -- A projection with a zero in it collapses the world onto a line, and every
  -- body in the scene lands on the same pixel.
  if scene.half_width <= 0 or scene.half_height <= 0 or scene.layer_pixels <= 0 then
    refuse(path, "has a projection with a zero in it: %g, %g, %g",
           scene.half_width, scene.half_height, scene.layer_pixels)
  end

  scene.height = heights
  return scene
end
-- }}}

-- {{{ function M.to_pixels(scene, x, y, z)
-- Where a world position lands in the picture.
--
-- The whole of the interface, in two lines, kept here so that nothing else has to
-- know it. Anything that writes this arithmetic out for itself is a second place
-- for it to be wrong.
function M.to_pixels(scene, x, y, z)
  return scene.origin_x + (x - y) * scene.half_width,
         scene.origin_y + (x + y) * scene.half_height - z * scene.layer_pixels
end
-- }}}

-- {{{ function M.bounds(width, depth, highest, half_width, half_height, layer_pixels)
-- How large a picture of a world this size has to be, and where its origin goes.
--
-- Arithmetic rather than a guess, and each of the four extremes is a named corner
-- of the world: the leftmost point is the far end of the y axis, the rightmost
-- the far end of x, the topmost the summit, and the lowest the near corner at
-- ground level. A canvas sized by guesswork crops the summit, and nobody notices
-- until the scene has been loaded and a ball rolls off the top of the picture.
function M.bounds(width, depth, highest, half_width, half_height, layer_pixels)
  local min_x = -depth * half_width
  local max_x =  width * half_width
  local min_y = -highest * layer_pixels
  local max_y = (width + depth) * half_height

  return {
    width  = max_x - min_x,
    height = max_y - min_y,
    origin_x = -min_x,
    origin_y = -min_y,
  }
end
-- }}}

return M
