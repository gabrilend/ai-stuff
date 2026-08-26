-- 021-the-shape-of-a-stroke.lua
--
-- Measures one stroke: which way it goes, how long it is, how much it bends,
-- whether it ends in a flick, and where in the frame it sits.
--
-- For a general: the picture this project describes puts an object along every
-- stroke -- a trunk along a vertical, a fallen log along a low horizontal, a
-- bird on a dot. Choosing which object needs a description of the stroke that
-- is coarser than its coordinates and finer than "it is a stroke". This
-- produces that description.
--
-- Every number in the tables below was measured off the archive rather than
-- chosen, and the thing that measured them is still here:
--
--   luajit src/021-the-shape-of-a-stroke.lua --calibrate
--
-- which prints, for every calligraphic class the archive uses, the average
-- direction of strokes in that class and how sharply they turn at the end. The
-- boundaries are set between the clusters that report shows.

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local paths = project.load("014-the-path-language")
local flatten = project.load("015-flatten-the-curves")

local M = {}

-- {{{ CANVAS -- the box the archive draws in
local CANVAS = 109
-- }}}

-- {{{ DIRECTIONS -- the five ways a brush travels, as ranges of angle
--
-- Angles are measured with zero pointing right and increasing downward, since
-- that is the direction the archive's vertical axis runs. So ninety is straight
-- down and two hundred and seventy is straight up.
--
-- The boundaries sit in the gaps between what the archive actually contains.
-- Measured averages, from --calibrate:
--
--   rising          ㇀  326°     horizontal      ㇐  356°
--   falling right   ㇏   40°     vertical        ㇑   85°
--   falling left    ㇒  124°
--
-- THE HORIZONTAL RANGE IS NOT CENTRED ON ZERO, and that is the point of
-- measuring rather than guessing. A Japanese horizontal is written with a
-- deliberate slight rise, so the whole class sits a few degrees above level.
-- A symmetric range would have thrown the shallower ones into "rising".
--
-- A table scanned in order rather than a chain of tests, so that adding a class
-- is adding a row.
local DIRECTIONS = {
  { name = "falling_right", from = 20,  to = 68 },
  { name = "vertical",      from = 68,  to = 108 },
  { name = "falling_left",  from = 108, to = 200 },
  -- Leftward and upward. Almost nothing travels this way overall -- a few
  -- strokes that hook back hard enough to end left of where they began. Named
  -- rather than folded into a neighbour, so that a scene asking for an object
  -- to lie along one is told there is something unusual here.
  { name = "reversing",     from = 200, to = 300 },
  { name = "rising",        from = 300, to = 345 },
  { name = "horizontal",    from = 345, to = 360 },
  { name = "horizontal",    from = 0,   to = 20 },
}
-- }}}

-- {{{ SIZES -- how much of the frame a stroke crosses
--
-- Length matters separately from direction, and conflating them was the first
-- thing --calibrate corrected. A dot travels about a seventh of the frame and
-- points down and right -- the same direction as a long sweeping stroke that
-- travels half of it. Bucketing by angle alone would put a bird and a river in
-- the same place.
local SIZES = {
  { name = "dot",   below = 0.18 },
  { name = "short", below = 0.40 },
  { name = "long",  below = math.huge },
}
-- }}}

-- {{{ HOOK_TURN -- how sharp a turn at the end counts as a flick
--
-- Seventy degrees, and the number is not a judgement call: the archive splits
-- cleanly in two either side of it. Measured average turn over the last fifth
-- of a stroke, by class --
--
--   hooked:      ㇂ 139°   ㇖b 132°   ㇃ 135°   ㇆a 129°   ㇚ 122°
--                ㇆ 115°   ㇁ 102°    ㇟  76°
--   everything else:  below 26°, and most below 14°
--
-- WHICH CORRECTS THE PLAN. `docs/004` said a hook could not be seen by
-- measurement and had to be read out of the archive's own label, on the
-- reasoning that a hook barely moves a stroke's endpoint. That reasoning is
-- true and the conclusion did not follow: a hook barely moves the endpoint and
-- sharply changes the *direction*, and direction is exactly what is easy to
-- measure. The label agrees with the measurement everywhere, so the measurement
-- is used -- it also works for the strokes the archive left unlabelled, and for
-- the ones it labelled ambiguously.
local HOOK_TURN = 70
-- }}}

-- {{{ PLACES -- the ninth of the frame a stroke sits in
local COLUMNS = { { name = "left", below = 1/3 }, { name = "centre", below = 2/3 },
                  { name = "right", below = math.huge } }
local ROWS = { { name = "top", below = 1/3 }, { name = "middle", below = 2/3 },
               { name = "bottom", below = math.huge } }
-- }}}

-- {{{ pick(table, value)
-- The first row whose range contains this value.
local function pick(rows, value)
  for _, row in ipairs(rows) do
    if value < row.below then return row.name end
  end
  return rows[#rows].name
end
-- }}}

-- {{{ M.terminal_turn(flat)
-- How far the stroke swings in its last stretch, in degrees.
--
-- The direction over the final fifth compared against the direction of the very
-- last piece. A stroke that runs straight out to its end scores near zero; one
-- that flicks scores upward of a hundred.
function M.terminal_turn(flat)
  if flat.count < 3 or flat.travel <= 0 then return 0 end
  local before_x, before_y = flatten.direction_at(flat, flat.travel * 0.80)
  local last_x, last_y = flatten.direction(flat, flat.count - 1)
  local dot = before_x * last_x + before_y * last_y
  if dot > 1 then dot = 1 elseif dot < -1 then dot = -1 end
  return math.deg(math.acos(dot))
end
-- }}}

-- {{{ M.measure(flat, class, whole)
-- One flattened stroke, described.
--
-- `class` is the archive's own label for the stroke, or nil. `whole` is the
-- total distance travelled by every stroke of the character, used to work out
-- this one's share; leave it out and the share comes back as nil.
--
-- Returns a table holding:
--   direction   horizontal, vertical, falling_left, falling_right, rising,
--               reversing
--   angle       the same thing in degrees, for anything that wants it finer
--   size        dot, short or long
--   length      end to end, as a fraction of the frame
--   travel      the distance actually walked, same units
--   bend        travel divided by length; one is straight, more is curved
--   hooked      whether it ends in a flick
--   turn        how many degrees it swings at the end
--   place       { column, row, name }
--   weight      this stroke's share of the character's ink
--   class       the archive's label, carried through untouched
function M.measure(flat, class, whole)
  local from_x, from_y = flat.xs[1], flat.ys[1]
  local to_x, to_y = flat.xs[flat.count], flat.ys[flat.count]
  local span_x, span_y = to_x - from_x, to_y - from_y

  local angle = math.deg(math.atan2(span_y, span_x)) % 360
  local length = flat.span / CANVAS
  local travel = flat.travel / CANVAS

  -- A stroke that ends where it began has no overall direction to speak of, and
  -- the angle of a zero-length span is whatever the arithmetic happens to
  -- produce. Reported as reversing, which is what it is.
  local direction
  if flat.span < 1e-6 then
    direction = "reversing"
  else
    -- the ranges cover the whole circle, so the loop always finds one; the
    -- default is here so that a future edit which leaves a gap fails visibly
    -- as a wrong classification rather than invisibly as a nil
    direction = "horizontal"
    for _, row in ipairs(DIRECTIONS) do
      if angle >= row.from and angle < row.to then direction = row.name break end
    end
  end

  local middle_x = (flat.bbox[1] + flat.bbox[3]) * 0.5 / CANVAS
  local middle_y = (flat.bbox[2] + flat.bbox[4]) * 0.5 / CANVAS
  local column = pick(COLUMNS, middle_x)
  local row = pick(ROWS, middle_y)

  local turn = M.terminal_turn(flat)

  return {
    direction = direction,
    angle = angle,
    size = pick(SIZES, travel),
    length = length,
    travel = travel,
    bend = (flat.span > 1e-6) and (flat.travel / flat.span) or math.huge,
    hooked = turn >= HOOK_TURN,
    turn = turn,
    place = {
      column = column, row = row,
      name = (row == "middle" and column == "centre") and "the middle"
             or (row .. " " .. column),
    },
    weight = whole and whole > 0 and (flat.travel / whole) or nil,
    class = class,
  }
end
-- }}}

-- {{{ M.measure_record(record)
-- Every stroke of one character, flattened and measured, in writing order.
--
-- The flattened line is kept alongside the measurement, because everything that
-- consumes a measurement also needs to draw the stroke it describes and
-- flattening it twice would be work done twice.
function M.measure_record(record)
  local flats = {}
  local whole = 0
  for index, stroke in ipairs(record.strokes) do
    local flat = flatten.flatten(paths.parse(stroke.d,
                  "stroke " .. index .. " of " .. record.character))
    flats[index] = flat
    whole = whole + flat.travel
  end
  local out = {}
  for index, flat in ipairs(flats) do
    out[index] = M.measure(flat, record.strokes[index].class, whole)
    out[index].flat = flat
    out[index].index = index
  end
  return out
end
-- }}}

-- {{{ M.structural(measured, howmany)
-- The strokes that decide the composition, heaviest first.
--
-- By share of ink rather than by end-to-end length, because a long curling
-- stroke occupies more of the picture than a straight one of the same span --
-- and the picture is what is being composed.
function M.structural(measured, howmany)
  local ordered = {}
  for index, one in ipairs(measured) do ordered[index] = one end
  table.sort(ordered, function(a, b)
    if a.travel ~= b.travel then return a.travel > b.travel end
    -- writing order breaks ties, so two strokes of identical length come out
    -- in the same order every run
    return a.index < b.index
  end)
  local out = {}
  for index = 1, math.min(howmany or #ordered, #ordered) do
    out[index] = ordered[index]
  end
  return out
end
-- }}}

-- {{{ calibrate()
-- The report the tables above were built from.
--
-- Kept rather than thrown away, because the numbers in this file are claims
-- about a dataset that gets new releases. Re-running this is how somebody finds
-- out that a boundary has drifted into the middle of a cluster.
local function calibrate()
  local store = project.load("019-the-kanji-record").store()
  local by_class = {}
  local by_direction = {}
  local agreements, disagreements = 0, 0

  for _, record in ipairs(store.order) do
    local measured = M.measure_record(record)
    for _, one in ipairs(measured) do
      local class = one.class or "(unlabelled)"
      local entry = by_class[class]
      if not entry then
        entry = { count = 0, x = 0, y = 0, turn = 0, travel = 0, hooked = 0 }
        by_class[class] = entry
      end
      entry.count = entry.count + 1
      entry.x = entry.x + math.cos(math.rad(one.angle))
      entry.y = entry.y + math.sin(math.rad(one.angle))
      entry.turn = entry.turn + one.turn
      entry.travel = entry.travel + one.travel
      if one.hooked then entry.hooked = entry.hooked + 1 end
      by_direction[one.direction] = (by_direction[one.direction] or 0) + 1
    end
  end

  -- Whether the measured hook agrees with the archive's label. A class where
  -- nearly all or nearly none of the strokes measure as hooked is a class the
  -- measurement understands; one that splits down the middle is a class where
  -- the two disagree and somebody should look.
  local rows = {}
  for class, entry in pairs(by_class) do
    if entry.count >= 100 then
      local share = entry.hooked / entry.count
      if share > 0.9 or share < 0.1 then agreements = agreements + 1
      else disagreements = disagreements + 1 end
      rows[#rows + 1] = {
        class = class, count = entry.count,
        angle = math.deg(math.atan2(entry.y / entry.count,
                                    entry.x / entry.count)) % 360,
        turn = entry.turn / entry.count,
        travel = entry.travel / entry.count,
        hooked = share,
      }
    end
  end
  table.sort(rows, function(a, b) return a.count > b.count end)

  io.write("every calligraphic class the archive uses more than a hundred times\n\n")
  io.write(string.format("%-12s %7s %8s %8s %8s %8s\n",
           "class", "count", "angle", "endturn", "hooked", "length"))
  for _, row in ipairs(rows) do
    io.write(string.format("%-12s %7d %8.1f %8.1f %7.0f%% %8.3f\n",
             row.class, row.count, row.angle, row.turn, row.hooked * 100,
             row.travel))
  end

  io.write("\nwhere the measurement put them:\n")
  local names = {}
  for name in pairs(by_direction) do names[#names + 1] = name end
  table.sort(names, function(a, b) return by_direction[a] > by_direction[b] end)
  for _, name in ipairs(names) do
    io.write(string.format("  %-14s %7d\n", name, by_direction[name]))
  end

  io.write(string.format("\n%d classes agree with the measured hook, %d are split\n",
           agreements, disagreements))
  return rows
end
M.calibrate = calibrate
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  project.hello("021-the-shape-of-a-stroke")
  if options.calibrate then
    calibrate()
  else
    local store = project.load("019-the-kanji-record").store()
    local which = options.chars or "休"
    local xml = project.load("011-scan-xml")
    for _, character in ipairs(xml.characters(which)) do
      local record = store.records[character]
      if not record then error(character .. " is not in the joined set") end
      io.write("\n", character, "  ", table.concat(record.meanings, ", "), "\n")
      for _, one in ipairs(M.measure_record(record)) do
        io.write(string.format("  %2d  %-14s %-6s %-14s bend %.2f  %s%s\n",
          one.index, one.direction, one.size, one.place.name, one.bend,
          string.format("%3.0f%% of the ink", (one.weight or 0) * 100),
          one.hooked and "  hooked" or ""))
      end
    end
  end
  project.goodbye("021-the-shape-of-a-stroke", { "measured" })
end
-- }}}

if arg and arg[0] and arg[0]:find("021%-the%-shape%-of%-a%-stroke") then
  main(arg)
end

return M
