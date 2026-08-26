-- 027-test-the-meaning.lua
--
-- Everything phase two claims, checked.
--
-- For a general: phase two decides what a picture is *of*. It measures each
-- stroke, works out what world the character belongs to, which of its pieces
-- are subjects and which are only sounds, and builds the grey image that
-- carries the illusion.
--
-- Almost none of that can be tested against the thing it is for. The
-- specification is that a person squints at a thumbnail and sees the character,
-- and no assertion here observes that. So these tests check that the machinery
-- did what it was told, and the demonstration in phase two exists to let
-- somebody check whether what it was told was right.
--
-- The assertion helpers come from `020`, which owns them.
--
--   luajit src/027-test-the-meaning.lua [--dir ROOT]

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")

local M = {}

-- {{{ test_measuring_a_stroke(t)
-- Characters whose answers are known by looking at them.
--
-- 一 is one horizontal. 十 is a horizontal and a vertical. 川 is three
-- verticals. 人 is a fall to the left and a fall to the right. If those four
-- come out wrong the direction boundaries are wrong, and they are assertions
-- that need no judgement from anybody.
local function test_measuring_a_stroke(t)
  local shape = project.load("021-the-shape-of-a-stroke")
  local store = project.load("019-the-kanji-record").store()

  local function directions(character)
    local measured = shape.measure_record(store.records[character])
    local out = {}
    for index, one in ipairs(measured) do out[index] = one.direction end
    return table.concat(out, " ")
  end

  t.same(directions("一"), "horizontal", "one is a single horizontal")
  t.same(directions("十"), "horizontal vertical", "ten is a cross")
  t.same(directions("川"), "vertical vertical vertical", "river is three verticals")
  t.same(directions("人"), "falling_left falling_right", "person falls both ways")

  -- The horizontal range is deliberately not centred on level, because a
  -- Japanese horizontal is written with a slight rise and a symmetric range
  -- throws the shallower ones into "rising". This is that rise, measured.
  local one = shape.measure_record(store.records["一"])[1]
  t.ok(one.angle > 340 and one.angle < 360,
       "and a horizontal really does rise slightly", string.format("%.1f degrees", one.angle))

  -- A hook is a sharp turn at the very end. The archive labels which strokes
  -- have one, and the measurement agrees -- see --calibrate on `021`.
  local hooked = shape.measure_record(store.records["丁"])
  local any_hooked = false
  for _, stroke in ipairs(hooked) do
    if stroke.hooked then any_hooked = true end
  end
  t.ok(any_hooked, "a character written with a hook measures as hooked")

  local straight = shape.measure_record(store.records["一"])[1]
  t.ok(not straight.hooked, "and one written without a hook does not")
  t.near(straight.bend, 1, 0.15, "a straight stroke barely bends")

  -- Size is measured apart from direction, because a dot and a long sweeping
  -- stroke point the same way and are not the same thing.
  local dots = shape.measure_record(store.records["犬"])
  local found_dot = false
  for _, stroke in ipairs(dots) do
    if stroke.size == "dot" then found_dot = true end
  end
  t.ok(found_dot, "a character with a dot in it has a stroke measured as a dot")

  local shares = shape.measure_record(store.records["川"])
  local total = 0
  for _, stroke in ipairs(shares) do total = total + stroke.weight end
  t.near(total, 1, 1e-6, "every stroke's share of the ink adds up to all of it")

  local heaviest = shape.structural(shares, 1)
  t.same(#heaviest, 1, "asking for the structural strokes gives that many")
  t.ok(heaviest[1].weight >= shares[1].weight,
       "and the heaviest really is the heaviest")
end
-- }}}

-- {{{ test_the_structure_field(t)
local function test_the_structure_field(t)
  local field = project.load("022-the-structure-field")
  local shape = project.load("021-the-shape-of-a-stroke")
  local canvas = project.load("016-the-grey-canvas")
  local store = project.load("019-the-kanji-record").store()
  local settings = project.settings()

  local record = store.records["川"]
  local measured = shape.measure_record(record)
  local surface, made = field.build(record, settings, { measured = measured })

  t.same(surface.width, settings.field.resolution, "the field is the size asked for")

  local low, high = canvas.extremes(surface)
  local wanted_low = 1 - settings.field.range_high
  local wanted_high = 1 - settings.field.range_low
  t.near(low, wanted_low, 0.01, "the darkest value sits on the band's floor")
  t.near(high, wanted_high, 0.01, "and the lightest on its ceiling")

  -- Every stroke has to have put ink somewhere. A stroke that vanished means
  -- the scaling is wrong for that character, and the illusion silently loses a
  -- line while the picture still looks fine.
  local along = field.inspect(surface, measured, settings)
  local missing = 0
  for index = 1, #measured do
    if not along[index] or along[index] > (wanted_low + wanted_high) / 2 then
      missing = missing + 1
    end
  end
  t.same(missing, 0, "every stroke left ink along its own line")

  -- Ink reaching the border means the character has been scaled wrongly and
  -- whatever fell off the edge is lost from the illusion.
  t.ok(field.edge_ink(surface) < 0.15, "and none of it reached the border",
       string.format("%.3f away from the background at the worst point",
                     field.edge_ink(surface)))

  -- The weakening along the writing order. 川 is three separate verticals that
  -- do not touch, so each stroke's darkness is its own -- on a character whose
  -- strokes cross, the blur mixes them and the ordering is not readable back
  -- out of the finished field.
  if settings.field.order_ramp > 0 then
    t.ok(along[1] < along[#along],
         "the first stroke is darker than the last, so the composition carries the order",
         string.format("%.4f then %.4f", along[1], along[#along]))
  else
    t.note("the writing-order ramp is turned off in settings; not checked")
  end

  -- The margin is applied to the archive's box, not to the character's own ink.
  -- Centring each character on its own extent would make a single horizontal
  -- line fill the frame as densely as a crowded character does, and a learner
  -- would lose the only signal they have for how much is in a character.
  local one = store.records["\228\184\128"]
  local one_field = field.build(one, settings)
  local ink_rows = 0
  for y = 0, one_field.height - 1 do
    local darkest = 1
    for x = 0, one_field.width - 1 do
      local value = one_field.pixels[y * one_field.width + x + 1]
      if value < darkest then darkest = value end
    end
    if darkest < 0.5 then ink_rows = ink_rows + 1 end
  end
  t.ok(ink_rows < one_field.height * 0.5,
       "a one-stroke character does not fill the frame",
       string.format("%d of %d rows hold ink", ink_rows, one_field.height))

  -- The blur has to shrink as a character gets crowded, or the dense ones weld
  -- shut at exactly the size the whole project is specified at.
  local sparse = field.blur_for(3, settings)
  local middling = field.blur_for(8, settings)
  local dense = field.blur_for(29, settings)
  t.ok(sparse > middling and middling > dense,
       "a crowded character is softened less than a sparse one",
       string.format("%.1f, %.1f, %.1f at 3, 8 and 29 strokes", sparse, middling, dense))
  t.ok(dense >= settings.field.blur_minimum,
       "and never below the floor where softening stops working")

  local small = field.thumbnail(surface, settings)
  t.same(small.width, settings.field.thumbnail,
         "the thumbnail is the size the illusion is specified at")

  t.note(string.format("river at %d strokes was blurred by %.1f",
         made.strokes, made.blur_radius))
end
-- }}}

-- {{{ M.run(options)
function M.run(options)
  local ink = project.load("020-test-the-ink")
  local groups = {
    { "measuring a stroke", test_measuring_a_stroke },
    { "the structure field", test_the_structure_field },
  }
  local all_passed = true
  for _, group in ipairs(groups) do
    local t = ink.harness()
    group[2](t)
    if not t.finish(group[1]) then all_passed = false end
  end
  return all_passed
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  project.arguments(argv)
  project.hello("027-test-the-meaning")
  io.write("phase two -- the meaning\n")
  local passed = M.run({})
  project.goodbye("027-test-the-meaning",
                  { passed and "all passed" or "SOMETHING FAILED" })
  os.exit(passed and 0 or 1)
end
-- }}}

if arg and arg[0] and arg[0]:find("027%-test%-the%-meaning") then
  main(arg)
end

return M
