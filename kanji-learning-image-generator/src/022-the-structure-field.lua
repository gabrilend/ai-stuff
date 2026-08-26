-- 022-the-structure-field.lua
--
-- Builds the grey image that makes a picture secretly be a character.
--
-- For a general: a diffusion model can be handed a grey picture and told to
-- make its finished image dark where that picture is dark. Hand it a spiral and
-- it paints a photograph that is secretly a spiral. This hands it a kanji.
--
-- The whole trick is in how the strokes are prepared. Drawn hard-edged, the
-- model satisfies the instruction the cheapest way available, which is to paint
-- a black bar across the sky. Softened until they stop being lines and become
-- *regions of darkness*, the same instruction can be satisfied by a tree
-- standing there instead -- and then the character is made out of the scenery
-- rather than drawn on top of it.
--
-- `docs/003` is the design. This is the five steps it names, in the order it
-- names them, and the order is not negotiable: blurring before the weakening
-- would smear each stroke's darkness into its neighbours before the weakening
-- could tell them apart, and compressing before the blur would compress a range
-- the blur then narrows again.
--
--   luajit src/022-the-structure-field.lua --chars 森休川 [--out DIR]

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local canvas = project.load("016-the-grey-canvas")
local shape = project.load("021-the-shape-of-a-stroke")

local M = {}

-- {{{ CANVAS -- the box the archive draws in
local CANVAS = 109
-- }}}

-- {{{ M.placement(settings)
-- How the archive's box maps onto the picture.
--
-- The margin is applied to the *box*, not to the character's own ink, and this
-- is the one decision here that is easy to get backwards. Centring each
-- character on its own extent would make 一 -- a single horizontal line -- fill
-- the frame exactly as densely as 田 does. Every character would come out the
-- same visual size, and a learner would lose the one signal they have for how
-- much is in a character before they can read it.
function M.placement(settings)
  local resolution = settings.field.resolution
  local margin = settings.field.margin
  local scale = resolution * (1 - 2 * margin) / CANVAS
  local offset = resolution * margin
  return scale, offset, resolution
end
-- }}}

-- {{{ M.blur_for(count, settings)
-- How far to soften a character with this many strokes.
--
-- WHY THIS IS NOT ONE NUMBER. The blur has one job with two edges: a stroke
-- must stop being a line and become a neighbourhood, without merging into the
-- neighbourhood next to it. How much room there is between those two depends
-- entirely on how crowded the character is -- and characters run from one
-- stroke to nearly thirty in the same box.
--
-- Set flat, the radius that turns a six-stroke character into a proper field
-- welds a twenty-nine-stroke one into a grey smudge that is unreadable at
-- thumbnail size, which is the one size the whole project is specified at. The
-- symptom is visible only by looking, which is what the phase demonstration is
-- for.
--
-- Stroke count is a proxy for stroke spacing, not a measurement of it: strokes
-- crowd together roughly as the square root of how many there are in a fixed
-- box, so the exponent is somewhere below a half. The honest measurement would
-- be the distance from each piece of ink to the nearest ink belonging to a
-- different stroke, which costs a great deal more and would move the number by
-- less than turning the dial does.
function M.blur_for(count, settings)
  local field = settings.field
  local falloff = field.blur_falloff or 0
  if falloff <= 0 then return field.blur_radius end
  local reference = field.blur_reference or 8
  local radius = field.blur_radius * (reference / math.max(count, 1)) ^ falloff
  local floor = field.blur_minimum or 1
  if radius < floor then radius = floor end
  return radius
end
-- }}}

-- {{{ M.build(record, settings, options)
-- One character's structure field.
--
-- options.polarity   "dark_ink" (default) or "light_ink"
-- options.measured   the stroke measurements, if the caller already has them
--
-- Returns the canvas, and a table of what was done to it, which the run report
-- and the card both quote.
function M.build(record, settings, options)
  options = options or {}
  local field = settings.field
  local scale, offset, resolution = M.placement(settings)

  local measured = options.measured or shape.measure_record(record)
  local surface = canvas.new(resolution, resolution, 0)
  local count = #measured

  for index, one in ipairs(measured) do
    -- Stroke one is laid down at full strength and the last a little weaker, so
    -- the composition itself pulls the eye along the writing order underneath
    -- the arrows that state it outright. Deliberately a small effect: it costs
    -- contrast from exactly the strokes most likely to be lost, and whether any
    -- of it survives sampling is an open question (docs/007 Q5).
    --
    -- A one-stroke character has no order to ramp along, and the fraction below
    -- would divide by zero.
    local ramp = 1
    if count > 1 and field.order_ramp > 0 then
      ramp = 1 - field.order_ramp * (index - 1) / (count - 1)
    end

    canvas.stroke(surface, one.flat, {
      width = field.stroke_width,
      strength = ramp,
      taper = field.taper,
      scale = scale,
      offset_x = offset,
      offset_y = offset,
    })
  end

  local radius = M.blur_for(count, settings)
  canvas.blur(surface, radius, field.blur_passes)
  canvas.compress(surface, field.range_low, field.range_high)

  -- Written by hand, kanji are dark ink on light paper, and that is the
  -- default. It is not always right: a night scene, or anything whose subject
  -- is bright things against dark, wants the stroke to be the lit part. The
  -- biome decides (docs/004); this obeys, and it is one inversion.
  local polarity = options.polarity or "dark_ink"
  if polarity == "dark_ink" then
    canvas.invert(surface)
  end

  return surface, {
    resolution = resolution,
    polarity = polarity,
    strokes = count,
    blur_radius = radius,
    stroke_width = field.stroke_width,
    range = { field.range_low, field.range_high },
    order_ramp = field.order_ramp,
  }
end
-- }}}

-- {{{ M.thumbnail(surface, settings)
-- The same field at the size the illusion is supposed to work at.
--
-- The specification of this whole project is that a person sees the character
-- in the thumbnail and not at full size (`docs/003`). This is the same
-- computation at a different size rather than a second implementation, so the
-- thing being looked at is the thing that was made.
function M.thumbnail(surface, settings)
  local size = settings.field.thumbnail
  return canvas.resample(surface, size, size)
end
-- }}}

-- {{{ M.inspect(surface, measured, settings)
-- What the field looks like from the outside, as numbers a test can assert on.
--
-- Per stroke: the average darkness of the pixels along that stroke's own line.
-- That is how "did this stroke put ink anywhere" and "is the weakening actually
-- monotonic along the writing order" get answered without looking at a picture.
function M.inspect(surface, measured, settings)
  local scale, offset = M.placement(settings)
  local out = {}
  for index, one in ipairs(measured) do
    local total, samples = 0, 0
    local steps = 24
    for step = 0, steps do
      local flatten = project.load("015-flatten-the-curves")
      local x, y = flatten.locate(one.flat, one.flat.travel * step / steps)
      local px = math.floor(x * scale + offset)
      local py = math.floor(y * scale + offset)
      if px >= 0 and py >= 0 and px < surface.width and py < surface.height then
        total = total + surface.pixels[py * surface.width + px + 1]
        samples = samples + 1
      end
    end
    out[index] = (samples > 0) and (total / samples) or nil
  end
  return out
end
-- }}}

-- {{{ M.edge_ink(surface)
-- The most extreme value found anywhere on the outer border.
--
-- A character whose ink reaches the border has been scaled wrongly, and the
-- illusion loses whatever fell off. Cheaper to ask than to look.
function M.edge_ink(surface)
  local width, height = surface.width, surface.height
  local middle = 0
  for index = 1, width * height do middle = middle + surface.pixels[index] end
  middle = middle / (width * height)
  local worst = 0
  local function consider(index)
    local away = math.abs(surface.pixels[index] - middle)
    if away > worst then worst = away end
  end
  for x = 0, width - 1 do
    consider(x + 1)
    consider((height - 1) * width + x + 1)
  end
  for y = 0, height - 1 do
    consider(y * width + 1)
    consider(y * width + width)
  end
  return worst
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  local settings = project.hello("022-the-structure-field")
  local store = project.load("019-the-kanji-record").store()
  local xml = project.load("011-scan-xml")
  local png = project.load("017-write-a-picture")

  local out_dir = options.out or project.scratch("fields")
  project.ensure_directory(out_dir)

  local said = {}
  for _, character in ipairs(xml.characters(options.chars or "森休川一")) do
    local record = store.records[character]
    if not record then error(character .. " is not in the joined set") end
    local measured = shape.measure_record(record)
    local started = os.clock()
    local surface, made = M.build(record, settings, { measured = measured })
    local small = M.thumbnail(surface, settings)
    local bytes = png.write_grey(out_dir .. "/" .. character .. ".png", surface, canvas)
    png.write_grey(out_dir .. "/" .. character .. "-thumb.png", small, canvas)
    local line = string.format("%s  %2d strokes, blur %.1f, %d bytes, edge %.3f, %.2fs",
      character, made.strokes, made.blur_radius, bytes, M.edge_ink(surface),
      os.clock() - started)
    io.write(line, "\n")
    said[#said + 1] = line
  end
  io.write("written to " .. out_dir .. "\n")
  project.goodbye("022-the-structure-field", said)
end
-- }}}

if arg and arg[0] and arg[0]:find("022%-the%-structure%-field") then
  main(arg)
end

return M
