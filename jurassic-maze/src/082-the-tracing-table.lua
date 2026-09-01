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

-- 082-the-tracing-table.lua
--
-- A picture, a lattice over it, and the shapes somebody draws onto it. No buttons
-- anywhere.
--
-- Nothing on the screen but the picture, the lattice, the vertices and the lines
-- between them. Every action is a click, a drag, a wheel or a key, and the thing
-- being edited is the only thing drawn.
--
-- The lattice is the instrument, and it is what makes this possible at all. A
-- scene needs five numbers saying where the world sits in its picture, and for a
-- picture somebody else made they are not known -- so rather than measure them
-- with a ruler, the world's own cell grid is drawn over the painting and nudged
-- until the two agree. A half-pixel error in the cell width is a whole cell of
-- drift by the far corner: invisible in a number, obvious on a picture.
--
-- Elevation is chosen *before* a vertex is placed, and that is not a convenience.
-- A pixel of an isometric picture is a whole line of world points, one for every
-- height, and the only thing that picks one out is somebody saying which height
-- they meant. So there is no way here to place a vertex whose height is unknown.

local M = {}

local root
local Plan, SceneFile

local plan             -- the header and the structures
local field            -- what the plan rasterises to, kept fresh for the shading
local picture
local plan_path, scene_path

local pan_x, pan_y, zoom = 0, 0, 0.4
local panning, pan_from_x, pan_from_y

local elevation = 0
local drawing = {}     -- the points of the shape being traced, world coordinates
local held             -- {structure, index} being dragged, or nil for a drawing point
local held_drawing     -- index into `drawing` being dragged
local snap = true
-- Off to begin with, and that is the useful default rather than the timid one.
-- At the start every cell is untraced, so the shading is a wash over the whole
-- picture that hides the very thing being traced. It earns its place once there
-- is some work to compare against, which is what the key is for.
local show_gaps = false
local nudge = 1

-- A screenshot run saves a frame and leaves, which is how a change to what the
-- table looks like gets compared against the same frame from before it.
local shot_path, shot_delay = nil, 1.5

-- The tags a structure may carry, cycled with a key.
--
-- A closed list rather than typed text, because typing means a text field and a
-- text field is a panel by another name. What the words should be is open
-- question one of issue 1001; these are the ones the painting seems to want.
local TAGS = { "top", "vertical", "stair", "ignore" }

-- {{{ local function nearest_vertex(wx, wy, reach)
-- The vertex nearest a world point, out of everything drawn.
--
-- Returns a structure and an index, or the index into the shape being traced.
-- Distance is measured in world cells rather than in pixels, so the reach does
-- not change when the view is zoomed -- which matters, because a reach in pixels
-- makes every vertex unclickable when zoomed out and every click a grab when
-- zoomed in.
local function nearest_vertex(wx, wy, reach)
  local best, best_d2 = nil, reach * reach

  for i, p in ipairs(drawing) do
    local dx, dy = p[1] - wx, p[2] - wy
    local d2 = dx * dx + dy * dy
    if d2 < best_d2 then best_d2 = d2; best = { drawing = i } end
  end

  for _, s in ipairs(plan.structures) do
    for i, p in ipairs(s.points) do
      local dx, dy = p[1] - wx, p[2] - wy
      local d2 = dx * dx + dy * dy
      if d2 < best_d2 then best_d2 = d2; best = { structure = s, index = i } end
    end
  end

  return best
end
-- }}}

-- {{{ local function nearest_edge(wx, wy, reach)
-- The line nearest a world point, so that a click on one can put a vertex into it.
local function nearest_edge(wx, wy, reach)
  local best, best_d2 = nil, reach * reach

  for _, s in ipairs(plan.structures) do
    local n = #s.points
    for i = 1, n do
      local a = s.points[i]
      local b = s.points[(i % n) + 1]
      local vx, vy = b[1] - a[1], b[2] - a[2]
      local len2 = vx * vx + vy * vy
      if len2 > 1e-9 then
        -- How far along the segment the closest point is, clamped to its ends so
        -- that a click past the end of a line belongs to the vertex there rather
        -- than to the line.
        local t = ((wx - a[1]) * vx + (wy - a[2]) * vy) / len2
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
        local dx = wx - (a[1] + vx * t)
        local dy = wy - (a[2] + vy * t)
        local d2 = dx * dx + dy * dy
        if d2 < best_d2 then best_d2 = d2; best = { structure = s, after = i } end
      end
    end
  end

  return best
end
-- }}}

-- {{{ local function structure_under(wx, wy)
-- The topmost structure enclosing a world point. Right-clicking inside one takes
-- it away, and "topmost" is what makes a block on a plaza removable.
local function structure_under(wx, wy)
  local found, best_z = nil, -math.huge
  for _, s in ipairs(plan.structures) do
    local inside = false
    local n = #s.points
    local j = n
    for i = 1, n do
      local xi, yi = s.points[i][1], s.points[i][2]
      local xj, yj = s.points[j][1], s.points[j][2]
      if (yi > wy) ~= (yj > wy) then
        if wx < xi + (wy - yi) / (yj - yi) * (xj - xi) then inside = not inside end
      end
      j = i
    end
    if inside and s.z >= best_z then found, best_z = s, s.z end
  end
  return found
end
-- }}}

-- {{{ local function refresh()
-- Rasterise, so that what has not been traced yet can be shaded.
--
-- After every change rather than on a timer. The count of uncovered cells is the
-- only progress there is on a job like this, and a progress figure that lags
-- behind the work is one nobody trusts.
local function refresh()
  field = Plan.rasterise(plan)
end
-- }}}

-- {{{ local function screen_to_world(sx, sy)
local function screen_to_world(sx, sy)
  local px = (sx - pan_x) / zoom
  local py = (sy - pan_y) / zoom
  return Plan.to_cell(plan, px, py, elevation)
end
-- }}}

-- {{{ function M.load(root_path, argv)
function M.load(root_path, argv)
  root = root_path

  local image_path, name
  local i = 1
  while i <= #argv do
    local a = argv[i]
    if     a == "--trace" then image_path = argv[i + 1]; i = i + 2
    elseif a == "--plan"  then plan_path = argv[i + 1]; i = i + 2
    elseif a == "--name"  then name = argv[i + 1]; i = i + 2
    elseif a == "--screenshot" then shot_path = argv[i + 1]; i = i + 2
    elseif a == "--after"      then shot_delay = tonumber(argv[i + 1]); i = i + 2
    else i = i + 1 end
  end

  Plan      = dofile(root .. "/src/081-the-plan.lua")
  SceneFile = dofile(root .. "/src/077-the-scene-file.lua")

  -- Reopening its own work is the difference between a tool and a stunt, so a
  -- plan that already exists is loaded and the picture comes from inside it.
  local f = plan_path and io.open(plan_path, "r")
  if f then
    f:close()
    plan = Plan.read(plan_path)
    image_path = image_path or (plan_path:match("^(.*)/[^/]*$") or ".") .. "/" .. plan.image
  else
    if not image_path then
      error("the tracing table needs a picture: --trace <file>.png", 0)
    end
    plan = Plan.new({
      name  = name or (image_path:match("([^/]+)%.%w+$") or "traced"),
      image = image_path,
      -- A two-to-one isometric to begin with, because essentially every
      -- hand-drawn isometric picture ever made is one. The lattice is what says
      -- whether this one is.
      half_width = 16, half_height = 8, layer_pixels = 10,
      origin_x = 0, origin_y = 0,
    })
    plan_path = plan_path or ((image_path:gsub("%.%w+$", "")) .. ".plan")
  end
  scene_path = plan_path:gsub("%.plan$", "") .. ".scene"

  -- Read with plain io and handed over as bytes. The engine's loader resolves a
  -- name inside its own sandbox, rooted at the game directory, so it cannot open
  -- a picture that lives anywhere else -- and the whole point is to trace a
  -- picture that was not made here.
  local img = io.open(image_path, "rb")
  if not img then
    error("there is no picture at " .. image_path, 0)
  end
  local bytes = img:read("*a")
  img:close()
  local data = love.filesystem.newFileData(bytes, "traced.png")
  picture = love.graphics.newImage(love.image.newImageData(data))
  picture:setFilter("linear", "linear")

  -- The origin starts in the middle of the picture, which is roughly where the
  -- far corner of a maze drawn to fill one tends to be, and is in any case a
  -- place somebody can see in order to move it.
  if plan.origin_x == 0 and plan.origin_y == 0 then
    plan.origin_x = picture:getWidth() * 0.5
    plan.origin_y = picture:getHeight() * 0.25
  end

  refresh()
  love.window.setTitle("jurassic-maze tracing table — " .. plan.name)
end
-- }}}

-- {{{ function M.update(dt)
function M.update(dt)
  if shot_path and love.timer.getTime() > shot_delay then
    local path = shot_path
    shot_path = nil
    love.graphics.captureScreenshot(function(image_data)
      local out = io.open(path, "wb")
      out:write(image_data:encode("png"):getString())
      out:close()
      love.event.quit()
    end)
  end
end
-- }}}

-- {{{ local function draw_lattice()
-- The world's cell grid at the current elevation, as lines over the picture.
--
-- Lines rather than filled diamonds, because the point is the alignment between
-- the lattice and the stonework underneath it, and a fill hides the very thing
-- being aligned against.
local function draw_lattice()
  local sw, sh = love.graphics.getDimensions()
  local x0, y0 = screen_to_world(0, 0)
  local x1, y1 = screen_to_world(sw, 0)
  local x2, y2 = screen_to_world(0, sh)
  local x3, y3 = screen_to_world(sw, sh)

  -- Bounded by the view and by nothing else. There is no world extent to clip
  -- against, because there is no world until something has been traced -- the
  -- lattice is a ruler laid over a picture rather than the edge of a place.
  local minx = math.floor(math.min(x0, x1, x2, x3)) - 1
  local maxx = math.ceil (math.max(x0, x1, x2, x3)) + 1
  local miny = math.floor(math.min(y0, y1, y2, y3)) - 1
  local maxy = math.ceil (math.max(y0, y1, y2, y3)) + 1

  -- Zoomed far out the lattice is a grey wash that hides the painting, which is
  -- the opposite of what it is for.
  if (maxx - minx) > 400 or (maxy - miny) > 400 then return end

  love.graphics.setColor(0.2, 0.9, 1.0, 0.30)
  love.graphics.setLineWidth(1 / zoom)

  for x = minx, maxx do
    local ax, ay = Plan.to_pixels(plan, x, miny, elevation)
    local bx, by = Plan.to_pixels(plan, x, maxy, elevation)
    love.graphics.line(ax, ay, bx, by)
  end
  for y = miny, maxy do
    local ax, ay = Plan.to_pixels(plan, minx, y, elevation)
    local bx, by = Plan.to_pixels(plan, maxx, y, elevation)
    love.graphics.line(ax, ay, bx, by)
  end
end
-- }}}

-- {{{ local function draw_gaps()
-- What has been traced around but not traced, shaded at the current elevation.
--
-- The only progress there is on a job like this. A hundred stragglers scattered
-- across a painting are hard to find by looking, so they are also counted.
local function draw_gaps()
  if not show_gaps or field.uncovered == 0 then return end
  -- Inside the traced region, and there is no other kind of gap.
  --
  -- Before anything was drawn the whole plane was "untraced", which shaded the
  -- entire painting red and hid the thing being traced. A hole between two shapes
  -- is a real gap somebody has to go back and fill; the rest of the world is not
  -- missing, it is simply not part of the world.
  love.graphics.setColor(1.0, 0.25, 0.25, 0.18)
  for y = 0, field.depth - 1 do
    for x = 0, field.width - 1 do
      if not field.covered[x + y * field.width] then
        local wx, wy = x + field.min_x, y + field.min_y
        local a, b = Plan.to_pixels(plan, wx,     wy,     elevation)
        local c, d = Plan.to_pixels(plan, wx + 1, wy,     elevation)
        local e, g = Plan.to_pixels(plan, wx + 1, wy + 1, elevation)
        local h, k = Plan.to_pixels(plan, wx,     wy + 1, elevation)
        love.graphics.polygon("fill", a, b, c, d, e, g, h, k)
      end
    end
  end
end
-- }}}

-- {{{ local function draw_structure(s, is_current)
local function draw_structure(s, is_current)
  local n = #s.points
  if n == 0 then return end

  -- Elevation is shown as colour, because it cannot be shown as position: every
  -- height of one pixel column projects to the same place, which is the whole
  -- difficulty this tool exists to get around. Cool for low, warm for high.
  local t = 0.5
  if field.highest > field.lowest then
    t = (s.z - field.lowest) / (field.highest - field.lowest)
  end
  local r, g, b = 0.3 + 0.7 * t, 0.9 - 0.5 * t, 1.0 - 0.8 * t

  local pts = {}
  for i = 1, n do
    local px, py = Plan.to_pixels(plan, s.points[i][1], s.points[i][2], s.z)
    pts[#pts + 1] = px
    pts[#pts + 1] = py
  end

  love.graphics.setLineWidth(2 / zoom)
  love.graphics.setColor(r, g, b, 0.85)
  if n >= 2 then
    for i = 1, n - 1 do
      love.graphics.line(pts[i * 2 - 1], pts[i * 2], pts[i * 2 + 1], pts[i * 2 + 2])
    end
    if not is_current then
      love.graphics.line(pts[n * 2 - 1], pts[n * 2], pts[1], pts[2])
    end
  end

  local dot = 4 / zoom
  for i = 1, n do
    love.graphics.setColor(r, g, b, 1)
    love.graphics.circle("fill", pts[i * 2 - 1], pts[i * 2], dot)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.circle("line", pts[i * 2 - 1], pts[i * 2], dot)
  end
end
-- }}}

-- {{{ function M.draw()
function M.draw()
  love.graphics.clear(0.10, 0.11, 0.13)

  love.graphics.push()
  love.graphics.translate(pan_x, pan_y)
  love.graphics.scale(zoom, zoom)

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(picture, 0, 0)

  draw_gaps()
  draw_lattice()

  for _, s in ipairs(plan.structures) do draw_structure(s, false) end
  if #drawing > 0 then
    draw_structure({ z = elevation, points = drawing }, true)
  end

  love.graphics.pop()

  -- A strip behind the words. Not a panel and nothing to click -- the painting is
  -- pale stone and white text on it is unreadable, which is the whole of the
  -- reason.
  love.graphics.setColor(0.06, 0.07, 0.09, 0.72)
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), 78)

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(string.format(
    "%s   elevation %d   %d structures   world %d x %d   %d holes in it   %s",
    plan.name, elevation, #plan.structures, field.width, field.depth,
    field.uncovered, snap and "snapping" or "free"), 8, 8)
  love.graphics.print(string.format(
    "cell %g x %g   layer %g   origin %g, %g   nudge %g",
    plan.half_width, plan.half_height, plan.layer_pixels,
    plan.origin_x, plan.origin_y, nudge), 8, 26)
  love.graphics.print(
    "click corners, click the first again to close  |  right click: a vertex, or " ..
    "inside a shape  |  [ ] elevation  |  s saves", 8, 44)
  love.graphics.print(
    "arrows move origin  |  - = cell  |  , . layer  |  n nudge  |  g holes  |  " ..
    "tab snap  |  t tag  |  backspace undoes a point", 8, 62)
end
-- }}}

-- {{{ function M.mousepressed(sx, sy, button)
function M.mousepressed(sx, sy, button)
  -- Middle drag pans, so that the left button is only ever about vertices. A tool
  -- whose main button does two things depending on where you are is a tool that
  -- deletes work by accident.
  if button == 3 then
    panning = true; pan_from_x, pan_from_y = sx, sy
    return
  end

  local wx, wy = screen_to_world(sx, sy)
  -- A grab reach of a third of a cell, in world units, so it does not change when
  -- the view is zoomed.
  local reach = 0.34

  if button == 2 then
    local v = nearest_vertex(wx, wy, reach)
    if v and v.drawing then
      table.remove(drawing, v.drawing)
      return
    end
    if v then
      local s = v.structure
      if #s.points <= 3 then
        -- Below three points a shape encloses nothing, so taking one out is
        -- taking the shape out.
        for i, other in ipairs(plan.structures) do
          if other == s then table.remove(plan.structures, i) break end
        end
      else
        table.remove(s.points, v.index)
      end
      refresh()
      return
    end

    local s = structure_under(wx, wy)
    if s then
      for i, other in ipairs(plan.structures) do
        if other == s then table.remove(plan.structures, i) break end
      end
      refresh()
    end
    return
  end

  if button ~= 1 then return end

  if snap then
    wx, wy = math.floor(wx + 0.5), math.floor(wy + 0.5)
  end

  -- Closing the shape: clicking the first vertex again.
  if #drawing >= 3 then
    local first = drawing[1]
    local dx, dy = first[1] - wx, first[2] - wy
    if dx * dx + dy * dy < reach * reach then
      plan.structures[#plan.structures + 1] =
        { z = elevation, tag = "top", points = drawing }
      drawing = {}
      refresh()
      return
    end
  end

  -- Picking up something already drawn.
  local v = nearest_vertex(wx, wy, reach)
  if v then
    if v.drawing then held_drawing = v.drawing else held = v end
    return
  end

  -- A click on a line puts a vertex into it, which is how a shape traced too
  -- coarsely gets a corner it was missing without being traced again.
  local e = nearest_edge(wx, wy, reach)
  if e then
    table.insert(e.structure.points, e.after + 1, { wx, wy })
    held = { structure = e.structure, index = e.after + 1 }
    refresh()
    return
  end

  drawing[#drawing + 1] = { wx, wy }
end
-- }}}

-- {{{ function M.mousemoved(sx, sy)
function M.mousemoved(sx, sy)
  if panning then
    pan_x = pan_x + (sx - pan_from_x)
    pan_y = pan_y + (sy - pan_from_y)
    pan_from_x, pan_from_y = sx, sy
    return
  end

  if held or held_drawing then
    local wx, wy = screen_to_world(sx, sy)
    if snap then wx, wy = math.floor(wx + 0.5), math.floor(wy + 0.5) end
    if held_drawing then
      drawing[held_drawing][1], drawing[held_drawing][2] = wx, wy
    else
      held.structure.points[held.index][1] = wx
      held.structure.points[held.index][2] = wy
      refresh()
    end
  end
end
-- }}}

-- {{{ function M.mousereleased(sx, sy, button)
function M.mousereleased(sx, sy, button)
  if button == 3 then panning = false end
  held, held_drawing = nil, nil
end
-- }}}

-- {{{ function M.wheelmoved(dx, dy)
function M.wheelmoved(dx, dy)
  if dy == 0 then return end
  local mx, my = love.mouse.getPosition()
  local bx = (mx - pan_x) / zoom
  local by = (my - pan_y) / zoom
  zoom = zoom * ((dy > 0) and 1.15 or (1 / 1.15))
  if zoom < 0.05 then zoom = 0.05 elseif zoom > 12 then zoom = 12 end
  pan_x = mx - bx * zoom
  pan_y = my - by * zoom
end
-- }}}

-- {{{ local function save()
-- The plan and the scene beside each other, so the result walks straight into
-- the client.
local function save()
  Plan.write(plan_path, plan)
  SceneFile.write(scene_path, Plan.to_scene(plan, field, nil))
  print(string.format("wrote %s and %s  (%d structures, %d cells untraced)",
                      plan_path, scene_path, #plan.structures, field.uncovered))
end
-- }}}

-- {{{ function M.keypressed(key)
function M.keypressed(key)
  local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")

  if key == "escape" then love.event.quit()
  elseif key == "s" then save()

  -- Elevation. Chosen before a vertex is placed, because a pixel of an isometric
  -- picture is a line of world points and nothing else picks one out.
  elseif key == "[" then elevation = elevation - 1
  elseif key == "]" then elevation = elevation + 1

  elseif key == "tab" then snap = not snap
  elseif key == "g"   then show_gaps = not show_gaps
  elseif key == "n"   then nudge = (nudge == 1) and 0.1 or ((nudge == 0.1) and 10 or 1)

  -- Calibration. The lattice is drawn over the painting and these move it until
  -- the two agree, which is the measurement -- see issue 1002.
  elseif key == "left"  then plan.origin_x = plan.origin_x - nudge
  elseif key == "right" then plan.origin_x = plan.origin_x + nudge
  elseif key == "up"    then plan.origin_y = plan.origin_y - nudge
  elseif key == "down"  then plan.origin_y = plan.origin_y + nudge

  elseif key == "-" then
    plan.half_width = plan.half_width - nudge
    -- Two-to-one unless somebody says otherwise, because the ratio is the one
    -- thing about an isometric picture that is nearly always the same, and
    -- keeping it means one key to calibrate instead of two that must agree.
    if not shift then plan.half_height = plan.half_width * 0.5 end
  elseif key == "=" then
    plan.half_width = plan.half_width + nudge
    if not shift then plan.half_height = plan.half_width * 0.5 end
  elseif key == "," then plan.layer_pixels = plan.layer_pixels - nudge
  elseif key == "." then plan.layer_pixels = plan.layer_pixels + nudge

  elseif key == "t" then
    -- Cycles the tag of the shape under the pointer. A closed list rather than
    -- typed text: typing means a text field, and a text field is a panel by
    -- another name.
    local mx, my = love.mouse.getPosition()
    local wx, wy = screen_to_world(mx, my)
    local s = structure_under(wx, wy)
    if s then
      local at = 1
      for i, tag in ipairs(TAGS) do if tag == s.tag then at = i end end
      s.tag = TAGS[(at % #TAGS) + 1]
    end

  elseif key == "backspace" then
    if #drawing > 0 then table.remove(drawing) end
  end

  if plan.half_width < 1 then plan.half_width = 1 end
  if plan.half_height < 1 then plan.half_height = 1 end
  if plan.layer_pixels < 1 then plan.layer_pixels = 1 end
end
-- }}}

-- {{{ function M.resize(w, h) end
function M.resize(w, h) end
-- }}}

return M
