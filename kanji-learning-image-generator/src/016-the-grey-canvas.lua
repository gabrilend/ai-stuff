-- 016-the-grey-canvas.lua
--
-- A rectangle of numbers, and the brush that puts ink on it.
--
-- For a general: this is a sheet of paper with no idea what is being drawn on
-- it. It can lay down a thick soft line, fill a straight-sided shape, blur
-- everything, squeeze the range of light and dark into a chosen band, and turn
-- itself upside down. Nothing in this file knows what a kanji is.
--
-- The numbers are kept as floating point rather than as bytes, because the
-- picture this eventually holds is built in four passes -- draw, then weaken by
-- writing order, then blur, then compress into a band. Doing that in eight bits
-- would round four separate times, and the rounding shows up as banding in
-- exactly the smooth gradients the blur exists to produce.

local M = {}

-- {{{ M.new(width, height, value)
-- A fresh surface, every pixel the same.
--
-- Pixels live in one flat array indexed y * width + x + 1, rather than a table
-- of rows. One allocation instead of several hundred, and the blur walks it in
-- straight lines either way.
function M.new(width, height, value)
  value = value or 0
  local pixels = {}
  local count = width * height
  for index = 1, count do pixels[index] = value end
  return { width = width, height = height, pixels = pixels }
end
-- }}}

-- {{{ M.clone(canvas)
function M.clone(canvas)
  local copy = { width = canvas.width, height = canvas.height, pixels = {} }
  local source, target = canvas.pixels, copy.pixels
  for index = 1, canvas.width * canvas.height do target[index] = source[index] end
  return copy
end
-- }}}

-- {{{ M.stroke(canvas, flat, options)
-- One flattened line, laid down as a thick soft mark.
--
-- options.width     how wide the mark is, in pixels
-- options.strength  how dark, from zero to one
-- options.taper     fraction of the length over which the ends thin away
-- options.softness  how many pixels the edge fades over
-- options.scale     multiply the line's coordinates by this
-- options.offset_x, options.offset_y  and then shift them
--
-- COVERAGE IS COMPUTED, NOT PAINTED. For every pixel near a segment, the
-- distance from that pixel's centre to the segment is worked out, and how much
-- ink it receives falls off over the last pixel or so of the brush's half
-- width. That gives a smooth edge without drawing anything more than once,
-- which matters for the next paragraph.
--
-- INK COMBINES BY MAXIMUM, NOT BY ADDING. Strokes cross. If ink accumulated,
-- every crossing would be darker than either stroke that formed it, and a
-- character would grow a dark knot at each of its joints -- which the structure
-- field would then hand to a diffusion model as an instruction to put something
-- solid exactly where two strokes meet. Taking the greater of the two is what
-- ink on saturated paper does, and it is why the whole stroke is drawn at one
-- strength rather than built up.
function M.stroke(canvas, flat, options)
  local width = options.width or 4
  local strength = options.strength or 1
  local taper = options.taper or 0
  local softness = options.softness or 1.0
  local scale = options.scale or 1
  local offset_x = options.offset_x or 0
  local offset_y = options.offset_y or 0

  local pixels = canvas.pixels
  local canvas_width = canvas.width
  local canvas_height = canvas.height
  local half = width * 0.5
  local travel = flat.travel * scale

  -- {{{ width_at(distance)
  -- How wide the brush is, this far along the stroke.
  --
  -- Measured along the arc rather than by which point we are on. Flattening
  -- puts more points where the stroke bends, so tapering by point index thins
  -- the curved parts of a stroke and leaves the straight parts blunt -- which
  -- looks like a mistake and is one.
  local function width_at(distance)
    if taper <= 0 or travel <= 0 then return half end
    local edge = travel * taper
    if edge <= 0 then return half end
    local from_start = distance
    local from_end = travel - distance
    local nearest = from_start < from_end and from_start or from_end
    if nearest >= edge then return half end
    -- squared, so the thinning is gentle near the middle and quick at the very
    -- tip, which is what a brush leaving the paper actually does
    local part = nearest / edge
    return half * (0.25 + 0.75 * part * part)
  end
  -- }}}

  for index = 1, flat.count - 1 do
    local ax = flat.xs[index] * scale + offset_x
    local ay = flat.ys[index] * scale + offset_y
    local bx = flat.xs[index + 1] * scale + offset_x
    local by = flat.ys[index + 1] * scale + offset_y

    local segment_x, segment_y = bx - ax, by - ay
    local length_squared = segment_x * segment_x + segment_y * segment_y
    local segment_length = math.sqrt(length_squared)
    local started_at = flat.at[index] * scale

    -- The bounding box below is sized from the *untapered* half width, because
    -- the taper only ever narrows and never widens. Sizing it from the widths
    -- at the segment's two ends looks tighter and is wrong: a straight stroke
    -- is a single segment spanning the whole thing, so both of its ends are at
    -- the tapered tips while its middle is at full width -- and the box then
    -- clips the middle of every straight stroke, asymmetrically, because
    -- rounding up and rounding down do not cut the same amount off each side.
    local widest = half

    -- Only the pixels that could possibly be touched. Sweeping the whole canvas
    -- for every segment is the difference between a batch that takes minutes
    -- and one that takes hours; there are over a million segments in the
    -- archive.
    local reach = widest + softness + 1
    local left = math.floor(math.min(ax, bx) - reach)
    local right = math.ceil(math.max(ax, bx) + reach)
    local top = math.floor(math.min(ay, by) - reach)
    local bottom = math.ceil(math.max(ay, by) + reach)
    if left < 0 then left = 0 end
    if top < 0 then top = 0 end
    if right > canvas_width - 1 then right = canvas_width - 1 end
    if bottom > canvas_height - 1 then bottom = canvas_height - 1 end

    for py = top, bottom do
      local row = py * canvas_width
      local point_y = py + 0.5
      for px = left, right do
        local point_x = px + 0.5
        local along = 0
        if length_squared > 0 then
          along = ((point_x - ax) * segment_x + (point_y - ay) * segment_y)
                  / length_squared
          if along < 0 then along = 0 elseif along > 1 then along = 1 end
        end
        local near_x = ax + segment_x * along
        local near_y = ay + segment_y * along
        local gap_x, gap_y = point_x - near_x, point_y - near_y
        local distance = math.sqrt(gap_x * gap_x + gap_y * gap_y)

        -- The brush width is asked for at this pixel's own place along the
        -- stroke, not interpolated between the ends of the segment.
        --
        -- WHY. Flattening only puts points where a stroke bends, so a straight
        -- stroke -- and many kanji strokes are straight -- becomes exactly two
        -- points, both of which are at the tapered tips. Interpolating between
        -- them drew the entire stroke at tip width: every horizontal and every
        -- vertical came out a quarter of the thickness it should have been,
        -- while curved strokes were fine. The character still looked like the
        -- character, in a thin and slightly wrong hand.
        local edge = width_at(started_at + along * segment_length)
        local coverage = (edge + softness * 0.5 - distance) / softness
        if coverage > 0 then
          if coverage > 1 then coverage = 1 end
          local value = coverage * strength
          local place = row + px + 1
          if value > pixels[place] then pixels[place] = value end
        end
      end
    end
  end
end
-- }}}

-- {{{ M.convex(canvas, points, value, softness)
-- A straight-sided shape with no dents in it, filled.
--
-- Used for arrowheads. Coverage comes from the distance to the nearest edge,
-- which for a shape with no dents is simply the smallest of the distances to
-- each edge's line -- so one loop over the edges gives both whether a pixel is
-- inside and how close to the boundary it is, and the edges come out smooth for
-- free.
--
-- The points must go round the shape in one direction. A shape whose points
-- zigzag is not one this can fill, and it will quietly produce nothing rather
-- than something wrong.
function M.convex(canvas, points, value, softness)
  softness = softness or 1.0
  local pixels = canvas.pixels
  local count = #points

  local left, right = math.huge, -math.huge
  local top, bottom = math.huge, -math.huge
  for _, point in ipairs(points) do
    if point[1] < left then left = point[1] end
    if point[1] > right then right = point[1] end
    if point[2] < top then top = point[2] end
    if point[2] > bottom then bottom = point[2] end
  end
  left = math.max(0, math.floor(left - softness - 1))
  right = math.min(canvas.width - 1, math.ceil(right + softness + 1))
  top = math.max(0, math.floor(top - softness - 1))
  bottom = math.min(canvas.height - 1, math.ceil(bottom + softness + 1))

  -- Which way round the points go decides the sign of every edge test, so it
  -- is measured once from the shape's own area rather than assumed.
  local twice_area = 0
  for index = 1, count do
    local a = points[index]
    local b = points[(index % count) + 1]
    twice_area = twice_area + (a[1] * b[2] - b[1] * a[2])
  end
  local facing = twice_area >= 0 and 1 or -1

  for py = top, bottom do
    local row = py * canvas.width
    local point_y = py + 0.5
    for px = left, right do
      local point_x = px + 0.5
      local nearest = math.huge
      for index = 1, count do
        local a = points[index]
        local b = points[(index % count) + 1]
        local edge_x, edge_y = b[1] - a[1], b[2] - a[2]
        local size = math.sqrt(edge_x * edge_x + edge_y * edge_y)
        if size > 1e-9 then
          local side = ((point_x - a[1]) * edge_y - (point_y - a[2]) * edge_x)
                       / size * -facing
          if side < nearest then nearest = side end
        end
      end
      local coverage = (nearest + softness * 0.5) / softness
      if coverage > 0 then
        if coverage > 1 then coverage = 1 end
        local place = row + px + 1
        local ink = coverage * value
        if ink > pixels[place] then pixels[place] = ink end
      end
    end
  end
end
-- }}}

-- {{{ M.blur(canvas, radius, passes)
-- Softened, by running a box average over it several times.
--
-- Three box averages approximate a gaussian closely enough that nothing
-- downstream could tell, and a box average is separable and costs the same per
-- pixel whatever the radius -- a running sum along each row, then down each
-- column. A true gaussian at the radius this project uses would be several
-- hundred multiplies per pixel to produce a result that the range compression
-- afterwards would flatten the difference out of anyway.
--
-- Edges are handled by pretending the surface continues outward with its own
-- edge pixel repeated. That is the choice that makes blurring a uniform
-- surface give back the same uniform surface -- treating the outside as zero
-- would darken every border, and the field's border is where the character's
-- margin is.
function M.blur(canvas, radius, passes)
  radius = math.floor(radius or 0)
  if radius < 1 then return canvas end
  passes = passes or 3

  local width, height = canvas.width, canvas.height
  local window = radius * 2 + 1
  local scratch = {}

  for _ = 1, passes do
    local pixels = canvas.pixels

    -- along each row
    for y = 0, height - 1 do
      local row = y * width
      local total = 0
      for offset = -radius, radius do
        local x = offset
        if x < 0 then x = 0 elseif x > width - 1 then x = width - 1 end
        total = total + pixels[row + x + 1]
      end
      for x = 0, width - 1 do
        scratch[row + x + 1] = total / window
        local leaving = x - radius
        local entering = x + radius + 1
        if leaving < 0 then leaving = 0 end
        if entering > width - 1 then entering = width - 1 end
        total = total - pixels[row + leaving + 1] + pixels[row + entering + 1]
      end
    end

    -- and then down each column
    for x = 0, width - 1 do
      local total = 0
      for offset = -radius, radius do
        local y = offset
        if y < 0 then y = 0 elseif y > height - 1 then y = height - 1 end
        total = total + scratch[y * width + x + 1]
      end
      for y = 0, height - 1 do
        pixels[y * width + x + 1] = total / window
        local leaving = y - radius
        local entering = y + radius + 1
        if leaving < 0 then leaving = 0 end
        if entering > height - 1 then entering = height - 1 end
        total = total - scratch[leaving * width + x + 1]
                      + scratch[entering * width + x + 1]
      end
    end
  end
  return canvas
end
-- }}}

-- {{{ M.extremes(canvas)
-- The darkest and lightest values present.
function M.extremes(canvas)
  local pixels = canvas.pixels
  local low, high = math.huge, -math.huge
  for index = 1, canvas.width * canvas.height do
    local value = pixels[index]
    if value < low then low = value end
    if value > high then high = value end
  end
  return low, high
end
-- }}}

-- {{{ M.compress(canvas, low, high)
-- Everything squeezed into a chosen band.
--
-- `docs/003` says why the band is not the full range: a field containing true
-- black and true white asks for a picture containing true black and true white,
-- and the sampler obliges by crushing the scene. Narrowing the field is what
-- turns it from a demand into a bias.
--
-- A surface that is entirely one value has no range to map, and stretching it
-- would turn a blank sheet into something. It is set to the middle of the band
-- instead, and that is the honest answer rather than a special case.
function M.compress(canvas, low, high)
  local found_low, found_high = M.extremes(canvas)
  local pixels = canvas.pixels
  local spread = found_high - found_low
  if spread < 1e-9 then
    local middle = (low + high) * 0.5
    for index = 1, canvas.width * canvas.height do pixels[index] = middle end
    return canvas
  end
  local size = high - low
  for index = 1, canvas.width * canvas.height do
    pixels[index] = low + (pixels[index] - found_low) / spread * size
  end
  return canvas
end
-- }}}

-- {{{ M.invert(canvas)
-- Light for dark. What polarity does (`docs/004`).
function M.invert(canvas)
  local pixels = canvas.pixels
  for index = 1, canvas.width * canvas.height do
    pixels[index] = 1 - pixels[index]
  end
  return canvas
end
-- }}}

-- {{{ M.resample(canvas, width, height)
-- The same picture at a different size, by averaging.
--
-- Averaging every source pixel that falls in a target pixel, rather than
-- picking the nearest one. The thumbnail is the size at which the whole
-- illusion is supposed to work (`docs/003`), so a thumbnail made by throwing
-- pixels away would be testing a different image than the one a person shrinks
-- in their browser.
function M.resample(canvas, width, height)
  local out = M.new(width, height, 0)
  local scale_x = canvas.width / width
  local scale_y = canvas.height / height
  for y = 0, height - 1 do
    local from_y = math.floor(y * scale_y)
    local to_y = math.ceil((y + 1) * scale_y) - 1
    if to_y < from_y then to_y = from_y end
    if to_y > canvas.height - 1 then to_y = canvas.height - 1 end
    for x = 0, width - 1 do
      local from_x = math.floor(x * scale_x)
      local to_x = math.ceil((x + 1) * scale_x) - 1
      if to_x < from_x then to_x = from_x end
      if to_x > canvas.width - 1 then to_x = canvas.width - 1 end
      local total, count = 0, 0
      for sy = from_y, to_y do
        local row = sy * canvas.width
        for sx = from_x, to_x do
          total = total + canvas.pixels[row + sx + 1]
          count = count + 1
        end
      end
      out.pixels[y * width + x + 1] = total / count
    end
  end
  return out
end
-- }}}

-- {{{ M.bytes(canvas)
-- The surface as one string of 8-bit values, row by row.
--
-- Where the floating point finally becomes a picture. Rounding rather than
-- truncating, and clamped, because compression and blurring can both leave a
-- value a hair outside the range and a wrapped byte is a bright speck in a dark
-- field.
function M.bytes(canvas)
  local out = {}
  local pixels = canvas.pixels
  local count = canvas.width * canvas.height
  for index = 1, count do
    local value = pixels[index]
    if value < 0 then value = 0 elseif value > 1 then value = 1 end
    out[index] = string.char(math.floor(value * 255 + 0.5))
  end
  return table.concat(out)
end
-- }}}

return M
