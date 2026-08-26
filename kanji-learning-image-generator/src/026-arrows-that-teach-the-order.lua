-- 026-arrows-that-teach-the-order.lua
--
-- Draws the layer that says which stroke comes first, and which way the brush
-- went.
--
-- For a general: this is the part that makes the output a learning material
-- rather than a clever picture. From the vision --
--
--   if the strokes are the structure, then the stroke order is the intended
--   viewing order, as directed with arrows because it's a learning material.
--
-- A numbered arrow sits at the start of every stroke, pointing the way that
-- stroke is written. It is drawn on its own transparent sheet and laid over the
-- finished picture afterwards; it never goes into the grey field. Asking a
-- diffusion model to render arrows into a landscape both fails and is wrong in
-- principle -- an arrow is an annotation *about* the picture, not a thing in
-- the world the picture shows.
--
--   luajit src/026-arrows-that-teach-the-order.lua --chars 休語鬱

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local canvas = project.load("016-the-grey-canvas")
local flatten = project.load("015-flatten-the-curves")
local shape = project.load("021-the-shape-of-a-stroke")
local field_of = project.load("022-the-structure-field")

local M = {}

-- {{{ SEGMENTS -- which strokes of a seven-segment figure each digit lights
--
-- WHY DIGITS ARE DRAWN AND NOT TYPED. There is no font machinery anywhere in
-- this project, and adding one for ten shapes would be the largest dependency
-- here by a wide margin. A seven-segment figure is a handful of straight lines
-- on the surface that already draws straight lines, it stays readable when
-- small -- which is the whole requirement -- and it reads as part of a diagram
-- rather than as text, which is what it is.
--
-- The segments, in the order below: top, upper right, lower right, bottom,
-- lower left, upper left, middle.
local SEGMENTS = {
  [0] = { 1, 1, 1, 1, 1, 1, 0 },
  [1] = { 0, 1, 1, 0, 0, 0, 0 },
  [2] = { 1, 1, 0, 1, 1, 0, 1 },
  [3] = { 1, 1, 1, 1, 0, 0, 1 },
  [4] = { 0, 1, 1, 0, 0, 1, 1 },
  [5] = { 1, 0, 1, 1, 0, 1, 1 },
  [6] = { 1, 0, 1, 1, 1, 1, 1 },
  [7] = { 1, 1, 1, 0, 0, 0, 0 },
  [8] = { 1, 1, 1, 1, 1, 1, 1 },
  [9] = { 1, 1, 1, 1, 0, 1, 1 },
}
-- }}}

-- {{{ segment_line(digit_x, digit_y, width, height, which)
-- Where one segment of a figure runs, as two points.
local function segment_line(x, y, width, height, which)
  local half = height * 0.5
  if which == 1 then return x, y, x + width, y end
  if which == 2 then return x + width, y, x + width, y + half end
  if which == 3 then return x + width, y + half, x + width, y + height end
  if which == 4 then return x, y + height, x + width, y + height end
  if which == 5 then return x, y + half, x, y + height end
  if which == 6 then return x, y, x, y + half end
  return x, y + half, x + width, y + half
end
-- }}}

-- {{{ sheet(resolution)
-- Four surfaces: three colours and a transparency.
--
-- Four separate surfaces rather than one holding four numbers per pixel, so
-- everything in `016` works on them unchanged. The transparency is drawn into
-- exactly the way the colours are, and there is no second kind of canvas to
-- write and maintain.
local function sheet(resolution)
  return {
    canvas.new(resolution, resolution, 0),
    canvas.new(resolution, resolution, 0),
    canvas.new(resolution, resolution, 0),
    canvas.new(resolution, resolution, 0),
  }
end
-- }}}

-- {{{ line_on(surfaces, ax, ay, bx, by, width, colour)
-- One straight mark, in colour, on all four surfaces at once.
local function line_on(surfaces, ax, ay, bx, by, width, colour)
  local run = {
    xs = { ax, bx }, ys = { ay, by }, count = 2,
    at = { 0, math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) },
  }
  run.travel = run.at[2]
  for channel = 1, 3 do
    canvas.stroke(surfaces[channel], run,
                  { width = width, strength = colour[channel], softness = 1.2 })
  end
  canvas.stroke(surfaces[4], run, { width = width, strength = 1, softness = 1.2 })
end
-- }}}

-- {{{ wedge_on(surfaces, points, colour)
-- One arrowhead, in colour.
local function wedge_on(surfaces, points, colour)
  for channel = 1, 3 do
    canvas.convex(surfaces[channel], points, colour[channel], 1.2)
  end
  canvas.convex(surfaces[4], points, 1, 1.2)
end
-- }}}

-- {{{ digit_on(surfaces, value, x, y, width, height, thickness, colour)
-- One figure, drawn as lit segments.
local function digit_on(surfaces, value, x, y, width, height, thickness, colour)
  local lit = SEGMENTS[value]
  if not lit then return end
  for which = 1, 7 do
    if lit[which] == 1 then
      local ax, ay, bx, by = segment_line(x, y, width, height, which)
      line_on(surfaces, ax, ay, bx, by, thickness, colour)
    end
  end
end
-- }}}

-- {{{ number_on(surfaces, value, x, y, size, thickness, colour)
-- A whole number, right of the given point, centred on it vertically.
local function number_on(surfaces, value, x, y, size, thickness, colour)
  local text = tostring(value)
  local width = size * 0.62
  local gap = size * 0.30
  local whole = #text * width + (#text - 1) * gap
  local left = x - whole * 0.5
  for index = 1, #text do
    digit_on(surfaces, tonumber(text:sub(index, index)),
             left + (index - 1) * (width + gap), y - size * 0.5,
             width, size, thickness, colour)
  end
end
-- }}}

-- {{{ M.build(record, settings, options)
-- The whole stroke-order sheet for one character.
--
-- Returns the four surfaces and a description of every arrow placed, which the
-- card in `302` carries so that the overlay can be checked without looking at
-- the picture.
function M.build(record, settings, options)
  options = options or {}
  local measured = options.measured or shape.measure_record(record)
  local scale, offset, resolution = field_of.placement(settings)
  local arrows = settings.arrows

  local surfaces = sheet(resolution)
  local placed = {}
  local crowded = 0

  for index, one in ipairs(measured) do
    local flat = one.flat
    local start_x = flat.xs[1] * scale + offset
    local start_y = flat.ys[1] * scale + offset

    -- The direction the stroke *leaves* by, not the direction to where it ends
    -- up. On a stroke that bends, those are nothing alike, and an arrow aimed
    -- at the far end of a curving stroke points straight through the bend and
    -- teaches the wrong exit.
    local dx, dy = flatten.direction(flat, 1)
    local nx, ny = -dy, dx

    -- Twenty-stroke characters begin strokes a few pixels apart, and arrows
    -- placed where they belong pile into an unreadable knot. Each is pushed
    -- sideways along its own stroke's normal until it clears what is already
    -- down. Sideways rather than backwards, because backwards would move it off
    -- the stroke it is labelling.
    -- The clearance has to cover the arrow *and* the number beside it. Sized to
    -- the arrow alone, two strokes beginning close together produced two
    -- numbers printed one on top of the other -- and the placement reported
    -- that it had found room for both, because the anchors really were far
    -- enough apart.
    local clearance = arrows.clearance
                      or (arrows.shaft_length + arrows.number_size)
    local limit = arrows.nudges or 16
    local shift = 0
    local tries = 0
    local x, y = start_x, start_y
    while tries < limit do
      local clash = false
      for _, other in ipairs(placed) do
        local gap = math.sqrt((x - other.x) ^ 2 + (y - other.y) ^ 2)
        if gap < clearance then clash = true break end
      end
      if not clash then break end
      tries = tries + 1
      shift = (math.ceil(tries / 2)) * arrows.shaft_length * 0.55
      if tries % 2 == 0 then shift = -shift end
      x = start_x + nx * shift
      y = start_y + ny * shift
    end

    -- Nothing cleared. Keep the number where it belongs and shorten the arrow:
    -- a number in the right place beats an arrow in the wrong one. A character
    -- with thirty strokes in one box has nowhere for thirty labels to go, and
    -- saying so is better than pretending.
    local squeezed = (tries >= limit)
    if squeezed then
      crowded = crowded + 1
      x, y = start_x, start_y
    end

    local shaft = squeezed and (arrows.shaft_length * 0.45) or arrows.shaft_length
    local head = squeezed and (arrows.head_length * 0.7) or arrows.head_length

    local tip_x = x + dx * (shaft + head)
    local tip_y = y + dy * (shaft + head)
    local base_x = x + dx * shaft
    local base_y = y + dy * shaft

    -- Outline first and fill second, both from the same geometry at different
    -- widths. One description of an arrow drawn twice, rather than two
    -- descriptions that drift apart the first time somebody changes one.
    --
    -- The outline is what makes this survive whatever colour the generated
    -- scene turns out to be underneath. A layer designed against a white page
    -- disappears over a bright sky.
    for pass = 1, 2 do
      local colour = (pass == 1) and arrows.outline_col or arrows.colour
      local grow = (pass == 1) and arrows.outline or 0

      line_on(surfaces, x, y, base_x, base_y, arrows.line_width + grow * 2, colour)
      local half = (arrows.head_width + grow) * 0.5
      wedge_on(surfaces, {
        { tip_x + dx * grow, tip_y + dy * grow },
        { base_x + nx * half, base_y + ny * half },
        { base_x - nx * half, base_y - ny * half },
      }, colour)

      -- The figure sits behind the arrow's tail, off to one side, so it never
      -- covers the stroke it is naming.
      number_on(surfaces, index,
                x - dx * arrows.number_size * 0.85 + nx * arrows.number_size * 0.60,
                y - dy * arrows.number_size * 0.85 + ny * arrows.number_size * 0.60,
                arrows.number_size, arrows.line_width + grow * 2, colour)
    end

    placed[#placed + 1] = {
      index = index, x = x, y = y,
      at_x = start_x, at_y = start_y,
      direction_x = dx, direction_y = dy,
      shifted = shift, squeezed = squeezed,
    }
  end

  return surfaces, { arrows = #placed, crowded = crowded, placed = placed,
                     resolution = resolution }
end
-- }}}

-- {{{ M.write(path, surfaces)
-- The sheet, written as a picture with transparency in it.
function M.write(path, surfaces)
  local png = project.load("017-write-a-picture")
  return png.write_rgba(path, surfaces[1], surfaces[2], surfaces[3],
                        surfaces[4], canvas)
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  local settings = project.hello("026-arrows-that-teach-the-order")
  local store = project.load("019-the-kanji-record").store()
  local xml = project.load("011-scan-xml")
  local png = project.load("017-write-a-picture")

  local out_dir = options.out or project.scratch("arrows")
  project.ensure_directory(out_dir)

  local said = {}
  for _, character in ipairs(xml.characters(options.chars or "休語鬱")) do
    local record = store.records[character]
    if not record then error(character .. " is not in the joined set") end
    local measured = shape.measure_record(record)
    local surfaces, made = M.build(record, settings, { measured = measured })
    M.write(out_dir .. "/" .. character .. "-arrows.png", surfaces)

    -- and the same character's field beside it, so the two can be laid over
    -- one another by eye
    local surface = field_of.build(record, settings, { measured = measured })
    png.write_grey(out_dir .. "/" .. character .. "-field.png", surface, canvas)

    local line = string.format("%s  %d arrows, %d could not be given room",
                               character, made.arrows, made.crowded)
    io.write(line, "\n")
    said[#said + 1] = line
  end
  io.write("written to " .. out_dir .. "\n")
  project.goodbye("026-arrows-that-teach-the-order", said)
end
-- }}}

if arg and arg[0] and arg[0]:find("026%-arrows%-that%-teach%-the%-order") then
  main(arg)
end

return M
