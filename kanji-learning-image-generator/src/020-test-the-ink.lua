-- 020-test-the-ink.lua
--
-- Everything phase one claims, checked.
--
-- For a general: phase one turns two archives into geometry and pixels and has
-- no idea what a kanji means. This checks that half of the machine on its own
-- terms -- that the tag reader survives what these documents actually contain,
-- that every stroke in the archive parses, that curves become lines that land
-- where they should, that the drawing surface behaves like ink on paper, and
-- that a picture written to disk can be read back and is the same picture.
--
-- It also carries the handful of assertion helpers the other test files borrow.
-- The first test file owns them because a separate file holding twenty lines of
-- helpers is a file nobody opens and everybody duplicates.
--
--   luajit src/020-test-the-ink.lua [--dir ROOT] [--quick]

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")

local M = {}

-- {{{ M.harness()
-- A fresh set of counters and the four ways of asserting into them.
--
-- Returned rather than global so two harnesses can run in one process without
-- adding each other's failures up, which is what `run-tests` does.
function M.harness()
  local self = { passed = 0, failed = 0, notes = {}, failures = {} }

  -- {{{ self.ok(condition, description, detail)
  function self.ok(condition, description, detail)
    if condition then
      self.passed = self.passed + 1
    else
      self.failed = self.failed + 1
      self.failures[#self.failures + 1] = description ..
        (detail and ("\n      " .. tostring(detail)) or "")
    end
    return condition
  end
  -- }}}

  -- {{{ self.same(actual, expected, description)
  function self.same(actual, expected, description)
    return self.ok(actual == expected, description,
                   "got " .. tostring(actual) .. ", wanted " .. tostring(expected))
  end
  -- }}}

  -- {{{ self.near(actual, expected, slack, description)
  -- For anything computed in floating point, where exact equality is a
  -- statement about the arithmetic rather than about the answer.
  function self.near(actual, expected, slack, description)
    local difference = math.abs(actual - expected)
    return self.ok(difference <= slack, description,
                   string.format("got %.6f, wanted %.6f within %.6f",
                                 actual, expected, slack))
  end
  -- }}}

  -- {{{ self.note(text)
  -- A measurement worth printing that is not a pass or a failure.
  --
  -- Coverage numbers, distributions, timings. A test that turns a measurement
  -- into a threshold makes somebody adjust the threshold; a test that prints it
  -- makes somebody look at it.
  function self.note(text)
    self.notes[#self.notes + 1] = text
  end
  -- }}}

  -- {{{ self.finish(title)
  function self.finish(title)
    io.write(string.format("%-28s %3d passed", title, self.passed))
    if self.failed > 0 then
      io.write(string.format(", %d FAILED", self.failed))
    end
    io.write("\n")
    for _, note in ipairs(self.notes) do io.write("    " .. note .. "\n") end
    for _, failure in ipairs(self.failures) do io.write("    ! " .. failure .. "\n") end
    return self.failed == 0
  end
  -- }}}

  return self
end
-- }}}

-- {{{ test_the_tag_reader(t)
local function test_the_tag_reader(t)
  local xml = project.load("011-scan-xml")

  local seen = {}
  xml.scan('<?xml version="1.0"?><!DOCTYPE r [<!ENTITY a "b>c">]>' ..
           '<r><i n="1"/>text</r>', {
    open = function(name, attributes, self_closing)
      seen[#seen + 1] = "open:" .. name .. (self_closing and "/" or "")
    end,
    close = function(name) seen[#seen + 1] = "close:" .. name end,
    text = function(raw) seen[#seen + 1] = "text:" .. raw end,
  })
  -- The document type declaration here contains a > inside an entity value.
  -- A reader that scanned for the next > would cut it in half and read the
  -- rest of the document as garbage, which is exactly what KANJIDIC2 would do
  -- to it.
  t.same(table.concat(seen, " "), "open:r open:i/ text:text close:r",
         "a doctype with a > inside it does not derail the reader")

  t.same(xml.decode("a &amp; b &lt; c &#x6728; &#26408;"), "a & b < c 木 木",
         "named and numbered character references both decode")
  t.same(xml.utf8(0x6728), "木", "a character number becomes its bytes")
  t.same(#xml.characters("木火水"), 3, "a string splits into characters, not bytes")

  local attributes = xml.attributes([[id="a" kvg:element="木" n='2']])
  t.same(attributes["kvg:element"], "木", "an attribute name may contain a colon")
  t.same(attributes.n, "2", "single quotes work as well as double")

  local ok = pcall(xml.decode, "&nosuch;")
  t.ok(not ok, "an entity the document never declared is an error, not a passthrough")
end
-- }}}

-- {{{ test_the_path_language(t)
local function test_the_path_language(t)
  local paths = project.load("014-the-path-language")

  local simple = paths.parse("M10,20c1,2,3,4,5,6", "a made-up stroke")
  t.same(simple.x, 10, "a move sets the starting point")
  t.same(#simple.curves, 1, "one curve instruction makes one curve")
  t.same(simple.curves[1][5], 15, "relative coordinates accumulate from the start")

  -- Numbers in this format run together with no separator. A minus sign both
  -- ends one number and starts the next; a second decimal point does the same.
  -- Reading these as one number each would silently halve the coordinate count
  -- and every stroke would go somewhere else.
  local packed = paths.parse("M0,0c-1.5-2.3.5.5-3-4", "a packed stroke")
  local got = table.concat(packed.curves[1], " ")
  t.same(got, "-1.5 -2.3 0.5 0.5 -3 -4", "numbers packed without separators split")

  -- A smooth curve does not write its first control point down: it is the
  -- previous curve's second control point mirrored through the join. Getting
  -- this wrong puts a kink at every smooth joint and the character still looks
  -- like a character, so nothing announces it.
  local smooth = paths.parse("M0,0c1,0,2,1,3,1s2,1,3,1", "a smooth stroke")
  t.same(smooth.curves[2][1] .. "," .. smooth.curves[2][2], "4,1",
         "a smooth curve mirrors the previous control point")

  local first = paths.parse("M0,0s1,1,2,2", "a leading smooth stroke")
  t.same(first.curves[1][1] .. "," .. first.curves[1][2], "0,0",
         "a smooth curve with nothing before it uses the current point")

  for _, bad in ipairs({ "L10,10", "M0,0z", "M0,0q1,1,2,2", "10,10c1,1,2,2,3,3" }) do
    t.ok(not pcall(paths.parse, bad, "a stroke"),
         "an instruction this archive never uses is refused: " .. bad)
  end
end
-- }}}

-- {{{ test_flattening(t)
local function test_flattening(t)
  local paths = project.load("014-the-path-language")
  local flatten = project.load("015-flatten-the-curves")

  -- A curve whose control points sit on the straight line between its ends is
  -- a straight line, and should not be chopped up at all.
  local straight = flatten.flatten(paths.parse("M0,0C10,0,20,0,30,0", "straight"))
  t.same(straight.count, 2, "a curve that is already straight becomes one piece")
  t.near(straight.travel, 30, 1e-9, "its length is its length")
  t.near(straight.span, 30, 1e-9, "and its span is the same")

  local bent = flatten.flatten(paths.parse("M0,0C0,20,20,20,20,0", "bent"))
  t.ok(bent.count > 4, "a curve that bends is chopped into several pieces")
  t.ok(bent.travel > bent.span,
       "travelling along a bend is further than crossing it")

  -- The direction a stroke leaves its start is not the direction of its chord.
  -- This curve starts by going straight down and ends level with where it
  -- began, so the chord points sideways and the true exit points down.
  local dx, dy = flatten.direction(bent, 1)
  t.ok(dy > 0.9, "the direction at the start follows the curve, not the chord",
       string.format("start direction is %.2f,%.2f", dx, dy))

  local mx, my = flatten.locate(bent, bent.travel * 0.5)
  t.near(mx, 10, 0.5, "the middle by distance is halfway across")
  t.ok(my > 5, "and is down in the bend", string.format("y = %.2f", my))

  local ex = flatten.locate(bent, bent.travel * 10)
  t.near(ex, 20, 1e-6, "asking past the end gives the end")
end
-- }}}

-- {{{ test_every_stroke_in_the_archive(t, quick)
-- The test the whole of phase one exists for.
--
-- Not a sample. Every stroke of every character that joined, parsed and
-- flattened, with two things asserted: that nothing errored, and that every
-- point landed inside the box the archive draws in.
--
-- The second is the one that matters. A mistake in how relative coordinates
-- accumulate, or in the mirrored control point, produces strokes that are
-- plausible for most characters and drift out of the frame for some -- and a
-- character drawn wrong looks like bad handwriting rather than bad arithmetic.
-- Nothing else in this project would notice.
local function test_every_stroke_in_the_archive(t, quick)
  local paths = project.load("014-the-path-language")
  local flatten = project.load("015-flatten-the-curves")
  local store = project.load("019-the-kanji-record").store()

  local limit = quick and 400 or #store.order
  local strokes, points = 0, 0
  local broken, outside, degenerate = {}, {}, {}
  local started = os.clock()

  for index = 1, math.min(limit, #store.order) do
    local record = store.order[index]
    for number, stroke in ipairs(record.strokes) do
      local where = "stroke " .. number .. " of " .. record.character
      local ok, result = pcall(function()
        return flatten.flatten(paths.parse(stroke.d, where))
      end)
      if not ok then
        if #broken < 8 then broken[#broken + 1] = tostring(result) end
      else
        strokes = strokes + 1
        points = points + result.count
        if result.count < 2 and #degenerate < 8 then
          degenerate[#degenerate + 1] = where
        end
        local box = result.bbox
        if (box[1] < -1 or box[2] < -1 or box[3] > 110 or box[4] > 110)
           and #outside < 8 then
          outside[#outside + 1] = string.format("%s at %.1f,%.1f..%.1f,%.1f",
            where, box[1], box[2], box[3], box[4])
        end
      end
    end
  end

  t.same(#broken, 0, "every stroke in the archive parses", broken[1])
  t.same(#degenerate, 0, "every stroke makes at least two points", degenerate[1])
  t.same(#outside, 0, "every point lands inside the archive's own box", outside[1])
  t.note(string.format("%d strokes, %d points, %.1f points each, %.2fs",
         strokes, points, points / math.max(strokes, 1), os.clock() - started))
end
-- }}}

-- {{{ test_the_store(t)
local function test_the_store(t)
  local store = project.load("019-the-kanji-record").store()
  local records = project.load("019-the-kanji-record")

  t.ok(#store.order > 5000, "the join produced a set worth generating",
       #store.order .. " characters")

  local rest = store.records["休"]
  t.ok(rest ~= nil, "a common character is in the set")
  t.same(#rest.strokes, 6, "and has the strokes it should")
  t.same(rest.meanings[1], "rest", "and the meaning it should")

  -- The etymology is the whole reason this project can be more than a filter.
  -- If the group tree ever stopped coming through, every scene would fall back
  -- on keywords alone and no test elsewhere would notice.
  local elements = {}
  for _, component in ipairs(rest.components) do
    if component.depth == 2 then elements[#elements + 1] = component.element end
  end
  t.same(table.concat(elements, ""), "亻木",
         "and is still made of a person and a tree, in writing order")

  -- The half of a character chosen for its sound must stay marked, because
  -- docs/004 demotes it out of being a subject and a picture that painted it
  -- would be about the wrong thing entirely.
  local time = store.records["時"]
  local phonetic = 0
  for _, component in ipairs(time.components) do
    if component.phonetic then phonetic = phonetic + 1 end
  end
  t.ok(phonetic >= 1, "a phono-semantic compound still marks its phonetic half")

  local chosen = records.select(store, { grade = 1 })
  t.ok(#chosen > 50, "the first school year selects a real set", #chosen)
  for _, record in ipairs(chosen) do
    if record.grade ~= 1 then
      t.ok(false, "a selector returned something outside its own filter")
      break
    end
  end
  t.ok(true, "and nothing outside it")

  t.ok(not pcall(records.select, store, { chars = "\240\159\152\128" }),
       "asking for a character that is not in the set is an error, not a short answer")

  t.note(string.format("%d joined, %d unglossed kanji, %d not kanji, %d compatibility",
         #store.order, #store.report.drawn_only, #store.report.not_ideographs,
         #store.report.duplicate_forms))
end
-- }}}

-- {{{ test_the_canvas(t)
local function test_the_canvas(t)
  local canvas = project.load("016-the-grey-canvas")
  local paths = project.load("014-the-path-language")
  local flatten = project.load("015-flatten-the-curves")

  -- Strokes cross. If ink accumulated, every crossing would be darker than
  -- either stroke that made it, and the field would tell a diffusion model to
  -- put something solid at every joint of every character.
  local crossing = canvas.new(40, 40, 0)
  local across = flatten.flatten(paths.parse("M2,20C12,20,28,20,38,20", "across"))
  local down = flatten.flatten(paths.parse("M20,2C20,12,20,28,20,38", "down"))
  canvas.stroke(crossing, across, { width = 6, strength = 1 })
  canvas.stroke(crossing, down, { width = 6, strength = 1 })
  local low, high = canvas.extremes(crossing)
  t.near(high, 1, 1e-9, "a crossing is no darker than the strokes that made it")
  t.near(low, 0, 1e-9, "and the paper around them is untouched")

  -- Asymmetry between the two would mean the distance from a pixel to a line is
  -- being computed wrongly, and every character would come out with its
  -- horizontals a different weight from its verticals.
  local flat_h = canvas.new(40, 40, 0)
  local flat_v = canvas.new(40, 40, 0)
  canvas.stroke(flat_h, across, { width = 6, strength = 1 })
  canvas.stroke(flat_v, down, { width = 6, strength = 1 })
  local worst = 0
  for offset = -5, 5 do
    local horizontal = flat_h.pixels[(20 + offset) * 40 + 20 + 1]
    local vertical = flat_v.pixels[20 * 40 + (20 + offset) + 1]
    local gap = math.abs(horizontal - vertical)
    if gap > worst then worst = gap end
  end
  t.near(worst, 0, 1e-9, "a horizontal mark weighs the same as a vertical one")

  -- Blurring treats the outside as more of the edge. Treating it as black would
  -- darken every border, and the border is exactly where a character's margin is.
  local uniform = canvas.new(50, 50, 0.42)
  canvas.blur(uniform, 5, 3)
  local flat_low, flat_high = canvas.extremes(uniform)
  t.near(flat_low, 0.42, 1e-9, "blurring a flat surface changes nothing")
  t.near(flat_high, 0.42, 1e-9, "including at its edges")

  local banded = canvas.new(20, 20, 0)
  banded.pixels[1] = 0
  banded.pixels[400] = 1
  canvas.compress(banded, 0.16, 0.86)
  local band_low, band_high = canvas.extremes(banded)
  t.near(band_low, 0.16, 1e-9, "compression puts the darkest value on the floor")
  t.near(band_high, 0.86, 1e-9, "and the lightest on the ceiling")

  -- A blank sheet has no range to stretch, and stretching it would turn nothing
  -- into something.
  local blank = canvas.new(8, 8, 0.3)
  canvas.compress(blank, 0.2, 0.8)
  local blank_low, blank_high = canvas.extremes(blank)
  t.near(blank_low, 0.5, 1e-9, "a surface with no range goes to the middle of the band")
  t.near(blank_high, 0.5, 1e-9, "everywhere, not just somewhere")

  -- The taper is measured along the arc, not by point index. Flattening puts
  -- more points where a stroke bends, so tapering by index thins the curves and
  -- leaves the straight parts blunt.
  -- A perfectly straight stroke flattens to exactly two points, and both of
  -- them are at the tapered tips. Asking the brush how wide it is only at those
  -- two places drew the whole stroke at tip width -- so every horizontal and
  -- every vertical in the archive came out a quarter of its proper thickness,
  -- while curved strokes, which flatten to many points, were correct.
  --
  -- Measured as actual widths rather than as one pixel being darker than
  -- another, because the failure was a matter of degree and a spot check
  -- happened to agree at the centre line.
  local tapered = canvas.new(60, 20, 0)
  local line = flatten.flatten(paths.parse("M4,10C20,10,40,10,56,10", "line"))
  t.same(line.count, 2, "a straight stroke really does flatten to two points")
  canvas.stroke(tapered, line, { width = 8, strength = 1, taper = 0.25 })

  local function ink_height(x)
    local total = 0
    for y = 0, 19 do total = total + tapered.pixels[y * 60 + x + 1] end
    return total
  end
  local middle = ink_height(30)
  local tip = ink_height(5)
  t.near(middle, 8, 0.6, "the middle of a tapered stroke is its full width")
  t.ok(tip < middle * 0.5, "and its tip is much narrower",
       string.format("tip %.2f against middle %.2f", tip, middle))
  t.ok(tip > 0.5, "but is still drawn", string.format("tip %.2f", tip))

  local small = canvas.resample(uniform, 10, 10)
  t.same(small.width, 10, "resampling gives the size asked for")
  local small_low, small_high = canvas.extremes(small)
  t.near(small_low, 0.42, 1e-9, "and averaging a flat surface keeps it flat")
  t.near(small_high, 0.42, 1e-9, "at both extremes")
end
-- }}}

-- {{{ inflate_fixed(text)
-- Enough of a decompressor to check the compressor, and no more.
--
-- It lives in the test rather than in `017` because nothing in this project
-- reads a picture -- and because a round trip through code written from the
-- same misunderstanding would prove nothing. This is written from the format
-- description, reading the stream the way an outside program would.
--
-- Only the standard code table is handled, which is all `017` emits.
local function inflate_fixed(text)
  local bit = require("bit")
  local band, rshift = bit.band, bit.rshift

  local position = 3          -- past the two header bytes
  local held, count = 0, 0

  local function take(width)
    while count < width do
      held = held + (text:byte(position) or 0) * (2 ^ count)
      position = position + 1
      count = count + 8
    end
    local value = band(held, (2 ^ width) - 1)
    held = math.floor(held / (2 ^ width))
    count = count - width
    return value
  end

  local LENGTH_BASE = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
    35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 }
  local LENGTH_EXTRA = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3,
    3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 }
  local DISTANCE_BASE = { 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129,
    193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289,
    16385, 24577 }
  local DISTANCE_EXTRA = { 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7,
    8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 }

  local final = take(1)
  local kind = take(2)
  if kind ~= 1 then error("this reader only knows the standard code table") end

  local out = {}
  while true do
    -- Codes are stored highest bit first, while everything else in the stream
    -- is lowest bit first. Both are true at once, which is the single easiest
    -- thing to get wrong about this format.
    local code = 0
    for _ = 1, 7 do code = code * 2 + take(1) end
    local symbol
    if code <= 0x17 then
      symbol = 256 + code
    else
      code = code * 2 + take(1)
      if code >= 0x30 and code <= 0xBF then
        symbol = code - 0x30
      elseif code >= 0xC0 and code <= 0xC7 then
        symbol = 280 + code - 0xC0
      else
        code = code * 2 + take(1)
        symbol = 144 + code - 0x190
      end
    end

    if symbol == 256 then break end
    if symbol < 256 then
      out[#out + 1] = string.char(symbol)
    else
      local index = symbol - 256
      local length = LENGTH_BASE[index] + (LENGTH_EXTRA[index] > 0
                     and take(LENGTH_EXTRA[index]) or 0)
      local distance_code = 0
      for _ = 1, 5 do distance_code = distance_code * 2 + take(1) end
      distance_code = distance_code + 1
      local distance = DISTANCE_BASE[distance_code] +
                       (DISTANCE_EXTRA[distance_code] > 0
                        and take(DISTANCE_EXTRA[distance_code]) or 0)
      local so_far = table.concat(out)
      out = { so_far }
      local start = #so_far - distance + 1
      for step = 0, length - 1 do
        -- a repeat may reach into itself; copying one byte at a time is what
        -- makes that work and is why this is not a substring operation
        local piece = table.concat(out)
        out = { piece .. piece:sub(start + step, start + step) }
      end
    end
  end
  return table.concat(out)
end
-- }}}

-- {{{ test_writing_a_picture(t)
local function test_writing_a_picture(t)
  local canvas = project.load("016-the-grey-canvas")
  local png = project.load("017-write-a-picture")

  -- A picture with structure in it, so the compressor has both repeats and
  -- literals to get wrong. A flat one would compress to almost nothing and
  -- would exercise none of the matching.
  local surface = canvas.new(64, 48, 0)
  for y = 0, 47 do
    for x = 0, 63 do
      surface.pixels[y * 64 + x + 1] = ((x * 3 + y * 5) % 71) / 71
    end
  end
  local raw = canvas.bytes(surface)
  local file = png.encode(raw, 64, 48, 1)

  t.same(file:sub(1, 8), "\137PNG\13\10\26\10", "the file starts the way one does")

  -- Pull the compressed part back out the way an outside reader would, and
  -- check the chunk checksums on the way past. A wrong checksum makes a file
  -- some viewers open and others refuse, which is the worst of both.
  local position = 9
  local compressed, chunks = {}, {}
  local bit = require("bit")
  while position <= #file do
    local length = 0
    for offset = 0, 3 do length = length * 256 + file:byte(position + offset) end
    local kind = file:sub(position + 4, position + 7)
    local body = file:sub(position + 8, position + 7 + length)
    local stated = 0
    for offset = 0, 3 do
      stated = stated * 256 + file:byte(position + 8 + length + offset)
    end
    local computed = bit.band(bit.bxor(png.crc32(kind .. body), 0xFFFFFFFF),
                              0xFFFFFFFF)
    if computed < 0 then computed = computed + 4294967296 end
    t.same(stated, computed, "the checksum on the " .. kind .. " chunk is right")
    chunks[#chunks + 1] = kind
    if kind == "IDAT" then compressed[#compressed + 1] = body end
    position = position + 12 + length
  end
  t.same(table.concat(chunks, " "), "IHDR IDAT IEND", "the chunks are the ones needed")

  local recovered = inflate_fixed(table.concat(compressed))
  t.same(#recovered, 48 * (64 + 1),
         "what comes back is one filter byte plus one row, per row")

  -- Undo the row transformations, and what is left must be the pixels that went
  -- in. This is the assertion the whole file exists for: a wrong code table
  -- produces a stream of the right length that decodes to something else.
  local rebuilt = {}
  local previous = {}
  for index = 1, 64 do previous[index] = 0 end
  local at = 1
  for _ = 1, 48 do
    local filter = recovered:byte(at)
    at = at + 1
    local row = {}
    for index = 1, 64 do
      local value = recovered:byte(at + index - 1)
      local left = index > 1 and row[index - 1] or 0
      local up = previous[index]
      local upleft = index > 1 and previous[index - 1] or 0
      if filter == 1 then value = (value + left) % 256
      elseif filter == 2 then value = (value + up) % 256
      elseif filter == 3 then value = (value + math.floor((left + up) / 2)) % 256
      elseif filter == 4 then
        local estimate = left + up - upleft
        local from_left = math.abs(estimate - left)
        local from_up = math.abs(estimate - up)
        local from_upleft = math.abs(estimate - upleft)
        local guess
        if from_left <= from_up and from_left <= from_upleft then guess = left
        elseif from_up <= from_upleft then guess = up
        else guess = upleft end
        value = (value + guess) % 256
      end
      row[index] = value
      rebuilt[#rebuilt + 1] = string.char(value)
    end
    previous = row
    at = at + 64
  end
  t.same(table.concat(rebuilt), raw,
         "the picture that comes back out is the picture that went in")

  t.ok(#file < #raw * 0.75, "and it is meaningfully smaller than the pixels",
       string.format("%d bytes from %d raw", #file, #raw))

  -- An outside opinion, if the machine has one. Reported either way: a check
  -- that was skipped and counted as a pass is worse than no check at all.
  local scratch = project.scratch("test-picture.png")
  local handle = io.open(scratch, "wb")
  handle:write(file)
  handle:close()
  local probe = io.popen("identify -quiet " .. scratch .. " 2>/dev/null")
  local said = probe and probe:read("*l") or nil
  if probe then probe:close() end
  if said and said ~= "" then
    t.ok(said:find("64x48", 1, true) ~= nil,
         "an outside decoder agrees about the picture", said)
    t.note("outside decoder: " .. said:gsub("^%S+%s+", ""))
  else
    t.note("no outside decoder on this machine; only the round trip was checked")
  end
  os.remove(scratch)
end
-- }}}

-- {{{ test_the_numbers(t)
local function test_the_numbers(t)
  local json = project.load("018-write-the-numbers")

  local node = json.object("class_type", "KSampler")
  node.inputs = json.object("seed", 41011, "steps", 24, "cfg", 6.5)
  node.flags = json.object()
  node.links = {}

  -- Two runs of the same program must produce the same bytes, or a comparison
  -- between two workflows is noise and nobody will read one.
  local once = json.encode(node)
  for _ = 1, 40 do
    if json.encode(node) ~= once then
      t.ok(false, "key order is not stable between runs")
      break
    end
  end
  t.ok(true, "key order is the order keys were given, every time")

  t.ok(once:find('"class_type"') < once:find('"inputs"'),
       "and it is insertion order, not alphabetical")

  -- A seed or a step count with a decimal point on it is a type error at the
  -- far end, and printing one that way is this language's default behaviour.
  t.ok(once:find('"seed": 41011') ~= nil, "a whole number has no decimal point")
  t.ok(once:find('"cfg": 6.5') ~= nil, "and one that is not whole keeps its point")

  -- Both empty things exist in the format the far end reads and mean different
  -- things there. A writer that had to guess would be wrong about one of them.
  t.ok(once:find('"flags": {}') ~= nil, "an empty object stays an object")
  t.ok(once:find('"links": %[%]') ~= nil, "and an empty array stays an array")

  local awkward = json.object("text", 'a "grove", 木\nwith a tab\there')
  local written = json.encode(awkward)
  t.ok(written:find('\\"', 1, true) ~= nil, "quotes are escaped")
  t.ok(written:find("\\n", 1, true) ~= nil, "newlines are escaped")
  t.ok(written:find("木", 1, true) ~= nil,
       "and kanji are left as themselves, because a person reads these")

  node.inputs = nil
  t.ok(json.encode(node):find('"inputs"') == nil,
       "removing a key removes it from the order as well")
end
-- }}}

-- {{{ M.run(options)
-- Every test in this file. Returns true if they all passed.
function M.run(options)
  options = options or {}
  local groups = {
    { "the tag reader", test_the_tag_reader },
    { "the path language", test_the_path_language },
    { "flattening", test_flattening },
    { "the store", test_the_store },
    { "the canvas", test_the_canvas },
    { "writing a picture", test_writing_a_picture },
    { "the numbers", test_the_numbers },
    { "every stroke in the archive",
      function(t) test_every_stroke_in_the_archive(t, options.quick) end },
  }
  local all_passed = true
  for _, group in ipairs(groups) do
    local t = M.harness()
    group[2](t)
    if not t.finish(group[1]) then all_passed = false end
  end
  return all_passed
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  project.hello("020-test-the-ink")
  io.write("phase one -- the ink\n")
  local passed = M.run({ quick = options.quick })
  project.goodbye("020-test-the-ink", { passed and "all passed" or "SOMETHING FAILED" })
  os.exit(passed and 0 or 1)
end
-- }}}

if arg and arg[0] and arg[0]:find("020%-test%-the%-ink") then
  main(arg)
end

return M
