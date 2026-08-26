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

-- {{{ M.run(options)
function M.run(options)
  local ink = project.load("020-test-the-ink")
  local groups = {
    { "measuring a stroke", test_measuring_a_stroke },
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
