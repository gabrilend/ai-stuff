-- 046-two-ways-of-saying-it-is-good.lua
--
-- A machine that squints at a picture, and a person who clicks a number.
--
-- For a general: `docs/007` asked, in the second phase, whether *did the
-- illusion work* could be measured at all -- and left it open, because
-- answering it needed generated pictures and there were none. There are now.
--
-- The machine's answer: shrink the finished picture to thumbnail size, blur it,
-- and see how well its light and dark line up with the grey field that produced
-- it. High agreement means the strokes really did land where they were asked
-- to. That is the whole of it, and it works because thumbnail size is the size
-- the illusion is specified at.
--
-- BOTH OF ITS LIMITS ARE REAL AND NEITHER IS FATAL. It measures agreement with
-- the *field*, not legibility as a *character* -- a picture can agree closely
-- and still be unreadable because two strokes merged. And it is blind to the
-- other failure, where the model painted the character onto a wall in the scene
-- and scored beautifully. A grader wrong in known ways beats no grader, because
-- it can be measured against a person's ratings. A grader nobody has measured
-- is not a grader, it is a rumour.
--
--   luajit src/046-two-ways-of-saying-it-is-good.lua --calibrate
--   luajit src/046-two-ways-of-saying-it-is-good.lua --rate <file>=<tier> ...

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local canvas = project.load("016-the-grey-canvas")
local reader = project.load("017a-read-a-picture")
local pool = project.load("045-the-pool-that-remembers")

local M = {}

-- {{{ M.squint(picture, field, settings)
-- How much of the character survived into the picture, from zero to one.
--
-- Both are shrunk to the size the illusion is specified at and softened, then
-- compared value by value. The comparison is a correlation rather than a
-- difference, because a picture that is uniformly brighter than the field has
-- not failed at anything -- what matters is whether the light and dark move
-- *together*, not whether they are the same numbers.
--
-- A negative correlation means the picture came out inverted with respect to
-- the field, which is a failure and not a near miss, so it reports as nothing.
function M.squint(picture, field, settings)
  local size = settings.field.thumbnail
  local wide = math.floor(size * field.width / field.height + 0.5)

  local small_picture = canvas.resample(picture, wide, size)
  local small_field = canvas.resample(field, wide, size)

  -- Softened after shrinking, so that a picture whose strokes are a pixel or
  -- two off the field's is not punished for it. The illusion does not require
  -- the model to trace the strokes; it requires the darkness to be about there.
  canvas.blur(small_picture, 2, 2)
  canvas.blur(small_field, 2, 2)

  local count = wide * size
  local sum_a, sum_b = 0, 0
  for index = 1, count do
    sum_a = sum_a + small_picture.pixels[index]
    sum_b = sum_b + small_field.pixels[index]
  end
  local mean_a, mean_b = sum_a / count, sum_b / count

  local together, spread_a, spread_b = 0, 0, 0
  for index = 1, count do
    local a = small_picture.pixels[index] - mean_a
    local b = small_field.pixels[index] - mean_b
    together = together + a * b
    spread_a = spread_a + a * a
    spread_b = spread_b + b * b
  end

  -- A field with no variation in it -- which would mean no strokes were drawn
  -- -- has nothing to correlate against, and saying "perfect agreement" there
  -- would be the most confident possible way of being wrong.
  if spread_a < 1e-12 or spread_b < 1e-12 then return 0 end

  local r = together / math.sqrt(spread_a * spread_b)
  if r < 0 then return 0 end
  if r > 1 then return 1 end
  return r
end
-- }}}

-- {{{ M.tier_for(agreement, settings)
-- One number, as one of the five steps.
--
-- The cuts are in settings and are a starting position rather than a finding --
-- `--calibrate` is the thing that measures where they should be, kept for the
-- reason `strategems/037` gives.
function M.tier_for(agreement, settings)
  local cuts = settings.pool.cuts
  for index, cut in ipairs(cuts) do
    if agreement >= cut then return 6 - index end
  end
  return 1
end
-- }}}

-- {{{ M.grade(settings, picture_path, field_path)
-- One picture, looked at. Returns the tier and the number behind it.
function M.grade(settings, picture_path, field_path)
  local picture, why = reader.read(picture_path)
  if not picture then return nil, why end
  local field, field_why = reader.read(field_path)
  if not field then return nil, field_why end

  -- A picture and a field of different shapes cannot be compared value by
  -- value. The picture program is asked for the field's exact size, so a
  -- mismatch means something upstream disagreed with something else, and
  -- guessing which to trust would bury that.
  local picture_shape = picture.width / picture.height
  local field_shape = field.width / field.height
  if math.abs(picture_shape - field_shape) > 0.02 then
    return nil, string.format(
      "the picture is %dx%d and the field is %dx%d; those are different shapes " ..
      "and cannot be compared", picture.width, picture.height,
      field.width, field.height)
  end

  local agreement = M.squint(picture, field, settings)
  return M.tier_for(agreement, settings), agreement
end
-- }}}

-- {{{ M.rate_on_arrival(settings, companion_path, picture_path, field_path)
-- Every picture gets a tier the moment it exists.
--
-- WHY EVERYTHING, RATHER THAN WAITING FOR SOMEBODY. If everything made is kept
-- and only a little is ever looked at, the pool is overwhelmingly unrated -- and
-- a floor of "tier four or better" would exclude almost the whole library from
-- the first day. Rating on arrival means floors work immediately, and a
-- person's later correction simply wins.
function M.rate_on_arrival(settings, companion_path, picture_path, field_path)
  local tier, agreement = M.grade(settings, picture_path, field_path)
  if not tier then return nil, agreement end
  pool.rate(companion_path, tier,
            string.format("machine:squint %.3f", agreement))
  return tier, agreement
end
-- }}}

-- {{{ M.apply_ratings(settings, given)
-- A batch of ratings from a person, applied.
--
-- The gallery is a page on a filesystem and cannot write to the pool, which is
-- deliberate -- it is a viewer, and a viewer that could reach back into the
-- store would stop being one. So it collects clicks and hands back a line to
-- run, and this is what runs it.
function M.apply_ratings(settings, given)
  local applied, missing = 0, {}
  local root = pool.root(settings)
  for _, one in ipairs(given) do
    local stem, tier = one:match("^(.-)=(%d)$")
    if not stem then
      error("a rating looks like <name>=<tier>, not '" .. one .. "'")
    end
    -- Found by name rather than by path, because what the page knows is the
    -- name it was shown and it should not have to know where the pool lives.
    local listing = io.popen('find "' .. root .. '" -name "' .. stem ..
                             '.info.md" 2>/dev/null')
    local path = listing and listing:read("*l") or nil
    if listing then listing:close() end
    if not path then
      missing[#missing + 1] = stem
    else
      pool.rate(path, tonumber(tier), "person")
      applied = applied + 1
    end
  end
  return applied, missing
end
-- }}}

-- {{{ M.anchored(settings)
-- Whether a person's ratings are still frequent enough to mean anything.
--
-- THE FLOOR THAT STOPS IT DRIFTING. A generator improved against a grader that
-- is itself being tuned is a loop with no anchor. Let a person's ratings become
-- rare and the whole apparatus converges smoothly on the *grader's* taste
-- rather than theirs, with no error raised anywhere, and it is discovered
-- months later by not liking the output.
function M.anchored(settings)
  local counts = pool.counts(settings)
  if counts.total == 0 then return true, 0, 0 end
  local share = counts.rated_by_a_person / counts.total
  local wanted = settings.pool.human_floor or 0.05
  return share >= wanted, share, wanted
end
-- }}}

-- {{{ M.calibrate(settings, store)
-- Where the cuts between tiers should sit.
--
-- Two questions, and the second is the one that matters.
--
-- A field compared with itself must score at the very top, and with a different
-- character's field near the bottom. Those need no generated pictures at all
-- and they check the arithmetic, which is the half that can be wrong quietly.
--
-- Then, if there are real pictures in the pool, the distribution of what the
-- machine actually scored -- because cuts chosen against no data are cuts
-- somebody made up.
function M.calibrate(settings, store)
  local shape = project.load("021-the-shape-of-a-stroke")
  local field_of = project.load("022-the-structure-field")
  local png = project.load("017-write-a-picture")

  local scratch = project.scratch("calibrate")
  project.ensure_directory(scratch)

  local sample = { "\230\156\168", "\229\183\157", "\229\177\177", "\231\129\171",
                   "\228\188\145", "\230\163\174", "\232\170\158", "\233\172\177" }
  local fields = {}
  for _, character in ipairs(sample) do
    local record = store.records[character]
    if record then
      local surface = field_of.build(record, settings)
      local path = scratch .. "/" .. string.format("%05X", record.codepoint) .. ".png"
      png.write_grey(path, surface, canvas)
      fields[#fields + 1] = { character = character, path = path }
    end
  end

  io.write("a field against itself, and against every other:\n\n")
  io.write("      ")
  for _, one in ipairs(fields) do io.write(string.format("%6s", one.character)) end
  io.write("\n")

  local same, different, different_count = 0, 0, 0
  for _, row in ipairs(fields) do
    io.write(string.format("  %2s  ", row.character))
    for _, column in ipairs(fields) do
      local agreement = M.squint(reader.read(row.path), reader.read(column.path),
                                 settings)
      io.write(string.format("%6.2f", agreement))
      if row.character == column.character then
        same = same + agreement
      else
        different = different + agreement
        different_count = different_count + 1
      end
    end
    io.write("\n")
  end

  io.write(string.format("\na field against itself averages %.3f\n",
           same / math.max(#fields, 1)))
  io.write(string.format("against a different character, %.3f\n",
           different / math.max(different_count, 1)))
  io.write("\nThe gap between those two is the whole range the tiers have to\n")
  io.write("divide up. The cuts in input/settings.lua are currently:\n  ")
  for index, cut in ipairs(settings.pool.cuts) do
    io.write(string.format("tier %d at %.2f   ", 6 - index, cut))
  end
  io.write("\n")

  local entries = pool.walk(settings, {})
  if #entries == 0 then
    io.write("\nThere are no real pictures in the pool yet, so those cuts are\n")
    io.write("still a guess. Generate some and run this again -- the numbers\n")
    io.write("above only prove the arithmetic works.\n")
    return
  end

  local scores = {}
  for _, entry in ipairs(entries) do
    for _, rating in ipairs(entry.ratings) do
      local agreement = rating.who:match("machine:squint ([%d%.]+)")
      if agreement then scores[#scores + 1] = tonumber(agreement) end
    end
  end
  table.sort(scores)
  if #scores > 0 then
    io.write(string.format("\n%d real pictures have been squinted at:\n", #scores))
    for _, share in ipairs({ 0.1, 0.25, 0.5, 0.75, 0.9 }) do
      local at = math.max(1, math.floor(#scores * share))
      io.write(string.format("  %3d%% of them score at or below %.3f\n",
               share * 100, scores[at]))
    end
  end
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  local settings = project.hello("046-two-ways-of-saying-it-is-good")

  if options.rate then
    local given = {}
    for one in tostring(options.rate):gmatch("%S+") do given[#given + 1] = one end
    for _, word in ipairs(options.words) do given[#given + 1] = word end
    local applied, missing = M.apply_ratings(settings, given)
    io.write(applied, " ratings applied\n")
    for _, stem in ipairs(missing) do
      io.write("  nothing in the pool is called ", stem, "\n")
    end
    local anchored, share, wanted = M.anchored(settings)
    io.write(string.format("%.0f%% of the pool now carries a person's rating\n",
             share * 100))
    if not anchored then
      io.write(string.format("which is below the %.0f%% this project asks for. " ..
               "Under that,\nthe machine's ratings are training the machine.\n",
               wanted * 100))
    end
    project.goodbye("046-two-ways-of-saying-it-is-good",
                    { applied .. " ratings applied" })
    return
  end

  local store = project.load("019-the-kanji-record").store()
  M.calibrate(settings, store)
  project.goodbye("046-two-ways-of-saying-it-is-good", { "calibrated" })
end
-- }}}

if arg and arg[0] and arg[0]:find("046%-two%-ways%-of%-saying") then
  main(arg)
end

return M
