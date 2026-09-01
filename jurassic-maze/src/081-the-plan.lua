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

-- 081-the-plan.lua
--
-- Polygons at elevations, drawn over a picture, and the height field they
-- rasterise to.
--
-- A world that already exists as a picture cannot be typed. The reference
-- painting is a mountain with a real shape covered in a maze somebody drew, and
-- the simulation has to agree with it -- so the shape has to be *traced*, and a
-- traced shape has corners rather than a width and a depth.
--
-- A structure here is flat, and that is not a limitation of the format. It is
-- what the painting is made of: every surface in it is either a flat top or the
-- vertical side of a higher flat top, and the sides follow from the tops without
-- anybody drawing them.
--
-- The plan is the source and the scene is the output. A scene is rasterised and
-- cannot be edited back into shapes, so throwing the shapes away after the first
-- save would make every later correction a retrace.

local M = {}

-- {{{ local function refuse(where, fmt, ...)
local function refuse(where, fmt, ...)
  error(string.format("plan '%s': " .. fmt, where, ...), 0)
end
-- }}}

-- {{{ function M.new(header)
-- An empty plan over a picture.
function M.new(header)
  return {
    name         = header.name,
    image        = header.image,
    half_width   = header.half_width,
    half_height  = header.half_height,
    layer_pixels = header.layer_pixels,
    origin_x     = header.origin_x,
    origin_y     = header.origin_y,
    base         = header.base or 0,
    structures   = {},
  }
end
-- }}}

-- {{{ function M.write(path, plan)
-- Plain text, one structure per block, so a person can read a diff of it.
function M.write(path, plan)
  local f, err = io.open(path, "w")
  if not f then refuse(path, "cannot be written: %s", tostring(err)) end

  f:write("# a jurassic-maze plan: shapes traced over a picture.\n")
  f:write("# a structure is a closed loop of world points, all at one elevation.\n")
  f:write("# where two overlap the higher wins, and the order here does not matter.\n")
  f:write(string.format("plan %s\n", plan.name))
  f:write(string.format("image %s\n", plan.image))
  f:write(string.format("projection %.6g %.6g %.6g\n",
                        plan.half_width, plan.half_height, plan.layer_pixels))
  f:write(string.format("origin %.6g %.6g\n", plan.origin_x, plan.origin_y))
  f:write(string.format("base %d\n", plan.base))

  for _, s in ipairs(plan.structures) do
    f:write(string.format("structure %d %s\n", s.z, s.tag or "top"))
    for _, v in ipairs(s.points) do
      f:write(string.format("  %.4f %.4f\n", v[1], v[2]))
    end
  end

  f:close()
end
-- }}}

-- {{{ function M.read(path)
function M.read(path)
  local f, err = io.open(path, "r")
  if not f then refuse(path, "cannot be read: %s", tostring(err)) end

  local plan = { structures = {} }
  local current = nil
  local line_no = 0

  for line in f:lines() do
    line_no = line_no + 1
    if not (line:match("^%s*#") or line:match("^%s*$")) then
      -- An indented line is a point of the structure above it. That is the whole
      -- of the nesting, and it means a point cannot be orphaned by a typo without
      -- the file saying so.
      local indented = line:match("^%s")
      local word, rest = line:match("^%s*(%S+)%s*(.*)$")

      if indented then
        if not current then
          refuse(path, "line %d: a point before any structure", line_no)
        end
        local a, b = line:match("^%s*(%S+)%s+(%S+)%s*$")
        local x, y = tonumber(a), tonumber(b)
        if not (x and y) then
          refuse(path, "line %d: '%s' is not a point", line_no, line)
        end
        current.points[#current.points + 1] = { x, y }
      elseif word == "plan"  then plan.name = rest
      elseif word == "image" then plan.image = rest
      elseif word == "projection" then
        local a, b, c = rest:match("^(%S+)%s+(%S+)%s+(%S+)$")
        plan.half_width, plan.half_height, plan.layer_pixels =
          tonumber(a), tonumber(b), tonumber(c)
      elseif word == "origin" then
        local a, b = rest:match("^(%S+)%s+(%S+)$")
        plan.origin_x, plan.origin_y = tonumber(a), tonumber(b)
      elseif word == "base" then
        plan.base = tonumber(rest)
      elseif word == "structure" then
        local z, tag = rest:match("^(%S+)%s*(%S*)$")
        z = tonumber(z)
        if not z then
          refuse(path, "line %d: a structure with no elevation", line_no)
        end
        current = { z = z, tag = (tag ~= "" and tag or "top"), points = {} }
        plan.structures[#plan.structures + 1] = current
      else
        refuse(path, "line %d: '%s' is not something a plan says", line_no, word)
      end
    end
  end
  f:close()

  for _, field in ipairs({ "name", "image", "half_width",
                           "half_height", "layer_pixels", "origin_x", "origin_y" }) do
    if plan[field] == nil then refuse(path, "says nothing about '%s'", field) end
  end
  plan.base = plan.base or 0

  for n, s in ipairs(plan.structures) do
    -- Two points is a line and a line encloses nothing. A structure that cannot
    -- cover a cell is a trace somebody abandoned, and it would rasterise to
    -- silence.
    if #s.points < 3 then
      refuse(path, "structure %d at elevation %d has %d points; three is the least "
             .. "that encloses anything", n, s.z, #s.points)
    end
  end

  return plan
end
-- }}}

-- {{{ local function encloses(points, px, py)
-- Whether a closed loop encloses a point. Even-odd, by counting the crossings of
-- a ray heading in +x.
--
-- Even-odd rather than winding, because it handles a shape with a hole traced
-- into it without anybody having to say that holes exist -- and a traced painting
-- is full of them: a plaza with a block standing in the middle is exactly that.
local function encloses(points, px, py)
  local inside = false
  local n = #points
  local j = n
  for i = 1, n do
    local xi, yi = points[i][1], points[i][2]
    local xj, yj = points[j][1], points[j][2]
    if (yi > py) ~= (yj > py) then
      -- Where the edge crosses this row, in x. Only a crossing to the right of
      -- the point counts.
      local at = xi + (py - yi) / (yj - yi) * (xj - xi)
      if px < at then inside = not inside end
    end
    j = i
  end
  return inside
end
-- }}}

-- {{{ function M.rasterise(plan)
-- The height field a plan describes, over whatever ground it happens to cover.
--
-- **The world is as big as what was traced, and not one cell bigger.** Nothing
-- declares a width and a depth. Declaring them first means choosing how much of a
-- picture is going to be the world before knowing what is in it, and then fitting
-- the trace into that box -- which is backwards, and which makes the box a thing
-- that has to be got right in advance and adjusted afterwards. The extent falls
-- out of the shapes instead.
--
-- Where two structures overlap the higher wins, and the order they were written
-- in does not matter. A block standing on a plaza is the plaza and then the
-- block, rather than the plaza cut into a ring around it.
--
-- **Cells no structure covers are holes, and they are counted rather than
-- filled.** Inside the traced region a hole is a real gap between two shapes and
-- is exactly what somebody needs to see; outside it there is no region at all, so
-- there is nothing to be missing.
function M.rasterise(plan)
  if #plan.structures == 0 then
    return { width = 0, depth = 0, min_x = 0, min_y = 0, height = {},
             covered = {}, uncovered = 0, lowest = 0, highest = 0 }
  end

  local min_x, min_y = math.huge, math.huge
  local max_x, max_y = -math.huge, -math.huge
  for _, s in ipairs(plan.structures) do
    for _, v in ipairs(s.points) do
      if v[1] < min_x then min_x = v[1] end
      if v[1] > max_x then max_x = v[1] end
      if v[2] < min_y then min_y = v[2] end
      if v[2] > max_y then max_y = v[2] end
    end
  end

  min_x, min_y = math.floor(min_x), math.floor(min_y)
  local width  = math.max(1, math.ceil(max_x) - min_x)
  local depth  = math.max(1, math.ceil(max_y) - min_y)

  local height, covered = {}, {}
  for i = 0, width * depth - 1 do
    height[i] = plan.base
    covered[i] = false
  end

  for _, s in ipairs(plan.structures) do
    local sx0, sy0 = math.huge, math.huge
    local sx1, sy1 = -math.huge, -math.huge
    for _, v in ipairs(s.points) do
      if v[1] < sx0 then sx0 = v[1] end
      if v[1] > sx1 then sx1 = v[1] end
      if v[2] < sy0 then sy0 = v[2] end
      if v[2] > sy1 then sy1 = v[2] end
    end

    -- The bounding box first. A structure covering nine cells of a six thousand
    -- cell world should cost nine tests and not six thousand.
    local x0 = math.max(0, math.floor(sx0) - min_x)
    local x1 = math.min(width - 1, math.ceil(sx1) - min_x)
    local y0 = math.max(0, math.floor(sy0) - min_y)
    local y1 = math.min(depth - 1, math.ceil(sy1) - min_y)

    for y = y0, y1 do
      for x = x0, x1 do
        -- The cell's middle, not its corner. A cell belongs to the shape that
        -- covers most of it, and testing a corner puts a cell in whichever of
        -- four shapes happens to touch that corner.
        if encloses(s.points, x + min_x + 0.5, y + min_y + 0.5) then
          local i = x + y * width
          if not covered[i] or s.z > height[i] then height[i] = s.z end
          covered[i] = true
        end
      end
    end
  end

  local uncovered = 0
  local lowest, highest = math.huge, -math.huge
  for i = 0, width * depth - 1 do
    if not covered[i] then uncovered = uncovered + 1 end
    if height[i] < lowest  then lowest  = height[i] end
    if height[i] > highest then highest = height[i] end
  end

  return { width = width, depth = depth, min_x = min_x, min_y = min_y,
           height = height, covered = covered, uncovered = uncovered,
           lowest = lowest, highest = highest }
end
-- }}}

-- {{{ function M.to_scene(plan, field, spawn)
-- The plan as a scene, ready for the client.
function M.to_scene(plan, field, spawn)
  -- The traced world does not begin at cell zero -- it begins wherever the first
  -- shape happened to land -- and a scene's height field does. So the world is
  -- shifted to the origin, and the picture's origin is shifted the opposite way
  -- by exactly as much, which leaves every pixel where it was.
  --
  -- Working it through once, so nobody has to again. A world point is drawn at
  -- `origin_x + (x - y) * half_width`. Substituting `x = x_scene + min_x` gives
  -- `[origin_x + (min_x - min_y) * half_width] + (x_scene - y_scene) *
  -- half_width`, and the bracket is the scene's origin. The vertical works the
  -- same way with a plus instead of a minus, because the screen's y is the sum of
  -- the world's two axes rather than their difference.
  return {
    name         = plan.name,
    image        = plan.image,
    width        = field.width,
    depth        = field.depth,
    half_width   = plan.half_width,
    half_height  = plan.half_height,
    layer_pixels = plan.layer_pixels,
    origin_x     = plan.origin_x + (field.min_x - field.min_y) * plan.half_width,
    origin_y     = plan.origin_y + (field.min_x + field.min_y) * plan.half_height,
    spawn_x      = spawn and spawn[1] or math.floor(field.width * 0.5),
    spawn_y      = spawn and spawn[2] or math.floor(field.depth * 0.5),
    spawn_z      = spawn and spawn[3] or field.highest,
    height       = field.height,
  }
end
-- }}}

-- {{{ function M.to_cell(plan, px, py, z)
-- Where a pixel of the picture is in the world, at a chosen elevation.
--
-- The inverse of the scene's projection, and it needs the elevation because it
-- cannot be had otherwise: a pixel of an isometric picture is a whole line of
-- world points, one for every height, and the only thing that picks one out is
-- somebody saying which height they meant. That is the entire reason the tracing
-- tool makes you choose an elevation before you may place a vertex.
function M.to_cell(plan, px, py, z)
  local u = (px - plan.origin_x) / plan.half_width                       -- x - y
  local v = (py - plan.origin_y + z * plan.layer_pixels) / plan.half_height  -- x + y
  return (u + v) * 0.5, (v - u) * 0.5
end
-- }}}

-- {{{ function M.to_pixels(plan, x, y, z)
function M.to_pixels(plan, x, y, z)
  return plan.origin_x + (x - y) * plan.half_width,
         plan.origin_y + (x + y) * plan.half_height - z * plan.layer_pixels
end
-- }}}

return M
