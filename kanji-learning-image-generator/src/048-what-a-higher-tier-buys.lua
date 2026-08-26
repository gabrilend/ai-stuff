-- 048-what-a-higher-tier-buys.lua
--
-- A picture somebody liked earns an animation of itself being written.
--
-- For a general: the tier is not only a filter deciding which pictures get
-- used. It is also a budget deciding how much more work each one deserves.
-- Effort concentrates where quality already is, and the library gets *deeper*
-- rather than merely wider.
--
-- What it buys here is the thing this project has been claiming all along and
-- never shown: the stroke order is the viewing order. One frame per stroke, the
-- character being written over the picture that hides it. It is the most useful
-- thing a study tool can own, and it is expensive enough to be worth reserving
-- for pictures somebody has already said were good.
--
-- ELABORATION EXTENDS, NEVER REGENERATES. Same picture, same seed, one thing
-- differing -- here, how many strokes have been drawn. If it re-rolled, what
-- came back would be a different picture wearing the old one's tier, and after
-- a few rounds every tier in the pool would be a statement about something that
-- no longer exists.
--
-- The encoder is ours, as the still-picture one is. This format has not moved
-- since 1989, it is a few hundred lines, and its compression is a cousin of the
-- one already written for PNG. A borrowed encoder turns our mistakes into
-- somebody else's silence.
--
--   luajit src/048-what-a-higher-tier-buys.lua --owed
--   luajit src/048-what-a-higher-tier-buys.lua --do-the-work

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local canvas = project.load("016-the-grey-canvas")
local reader = project.load("017a-read-a-picture")
local pool = project.load("045-the-pool-that-remembers")
local shape = project.load("021-the-shape-of-a-stroke")
local field_of = project.load("022-the-structure-field")
local arrows_of = project.load("026-arrows-that-teach-the-order")

local M = {}

-- {{{ PALETTE -- 176 greys and 80 steps of the arrow colour
--
-- WHY NOT A QUANTISER. This format holds at most 256 colours and a picture is
-- reduced to them by choosing the nearest, which is a whole apparatus and a
-- source of banding. It is unnecessary here because these frames are made of
-- exactly two things: a grey picture, and arrows in one colour over it. So the
-- palette is built to be exactly those two things and each pixel is placed in
-- it directly, with no nearest-colour search and no error at all.
--
-- 176 greys is finer than the eye resolves in a small animation; the remaining
-- 80 are the arrow colour fading into whatever is under it.
local GREYS = 176
local ARROW_STEPS = 80

-- {{{ M.palette(settings)
-- The 256 colours a frame may use, as bytes.
function M.palette(settings)
  local colour = settings.arrows.colour
  local outline = settings.arrows.outline_col
  local out = {}
  for index = 0, GREYS - 1 do
    local level = math.floor(index * 255 / (GREYS - 1) + 0.5)
    out[#out + 1] = string.char(level, level, level)
  end
  -- The arrow colour, and the dark outline under it, each fading from a mid
  -- grey so that a partly covered pixel has somewhere to land.
  for index = 0, ARROW_STEPS - 1 do
    local part = index / (ARROW_STEPS - 1)
    local which = (index < ARROW_STEPS / 2) and colour or outline
    local blend = (index < ARROW_STEPS / 2)
                  and (index / (ARROW_STEPS / 2 - 1))
                  or ((index - ARROW_STEPS / 2) / (ARROW_STEPS / 2 - 1))
    local grey = 0.55
    local function mix(channel)
      return math.floor((grey * (1 - blend) + channel * blend) * 255 + 0.5)
    end
    out[#out + 1] = string.char(mix(which[1]), mix(which[2]), mix(which[3]))
  end
  return table.concat(out)
end
-- }}}

-- {{{ M.index_of(grey, arrow_alpha, arrow_colour)
-- Which palette entry one pixel is, exactly.
function M.index_of(grey, alpha, is_outline)
  if alpha < 0.02 then
    local level = math.floor(grey * (GREYS - 1) + 0.5)
    if level < 0 then level = 0 elseif level > GREYS - 1 then level = GREYS - 1 end
    return level
  end
  local half = math.floor(ARROW_STEPS / 2)
  local step = math.floor(alpha * (half - 1) + 0.5)
  if step < 0 then step = 0 elseif step > half - 1 then step = half - 1 end
  return GREYS + (is_outline and (half + step) or step)
end
-- }}}
-- }}}

-- {{{ lzw(indices, count)
-- The compression this format uses, which is not the one PNG uses.
--
-- It builds a dictionary as it goes: every time it emits a code it adds "that
-- run plus the next byte" as a new entry, so a repeated pattern is a single
-- code the second time it appears. The width of a code grows as the dictionary
-- fills -- nine bits, then ten, then eleven, then twelve -- and both sides
-- agree on when that happens by counting entries.
--
-- THE PLACE THIS GOES WRONG. The width has to grow *before* the code that needs
-- it is written, not after, and a compressor that grows it one entry late
-- produces a file that decodes correctly for a while and then falls apart --
-- which looks like a corrupt download rather than a bug. That is why the test
-- decodes what this writes.
local function lzw(indices, count)
  local CLEAR, STOP = 256, 257
  local out = {}
  local held, bits = 0, 0

  -- {{{ emit(code, width)
  local function emit(code, width)
    held = held + code * (2 ^ bits)
    bits = bits + width
    while bits >= 8 do
      out[#out + 1] = string.char(held % 256)
      held = math.floor(held / 256)
      bits = bits - 8
    end
  end
  -- }}}

  local dictionary, next_code, width
  local function reset()
    dictionary = {}
    next_code = 258
    width = 9
  end
  reset()

  emit(CLEAR, width)

  local run = indices[1]
  for position = 2, count do
    local byte = indices[position]
    local candidate = run .. "," .. byte
    local found = dictionary[candidate]
    if found then
      run = candidate
    else
      -- the run so far, as a code: either a single byte or something already in
      -- the dictionary
      local code = tonumber(run) or dictionary[run]
      emit(code, width)
      if next_code < 4096 then
        dictionary[candidate] = next_code
        next_code = next_code + 1
        -- Before the next code is written, not after. One entry late here and
        -- the file decodes for a while and then falls apart.
        if next_code > (2 ^ width) and width < 12 then
          width = width + 1
        end
      else
        emit(CLEAR, width)
        reset()
      end
      run = tostring(byte)
    end
  end
  emit(tonumber(run) or dictionary[run], width)
  emit(STOP, width)
  if bits > 0 then out[#out + 1] = string.char(held % 256) end

  return table.concat(out)
end
-- }}}

-- {{{ blocks(text)
-- The data, cut into the short runs this format wants.
--
-- Everything of any length is written as a chain of pieces, each preceded by
-- its own length in one byte -- so nothing may exceed 255 -- and ended by a
-- length of zero.
local function blocks(text)
  local out = {}
  local at = 1
  while at <= #text do
    local piece = text:sub(at, at + 254)
    out[#out + 1] = string.char(#piece) .. piece
    at = at + #piece
  end
  out[#out + 1] = "\0"
  return table.concat(out)
end
-- }}}

-- {{{ two_bytes(value)
local function two_bytes(value)
  return string.char(value % 256, math.floor(value / 256) % 256)
end
-- }}}

-- {{{ M.encode(frames, width, height, palette, hundredths)
-- A whole animation, as the bytes of a file.
--
-- frames is a list of index arrays, one entry per pixel.
function M.encode(frames, width, height, palette, hundredths)
  local out = {}
  local function put(text) out[#out + 1] = text end

  put("GIF89a")
  put(two_bytes(width))
  put(two_bytes(height))
  -- a global colour table is present, eight bits per colour, 256 entries
  put(string.char(0xF7, 0, 0))
  put(palette)

  -- The block that says to loop forever. It is an application extension with a
  -- particular name in it, which is how a 1989 format acquired a feature it was
  -- never given: one company put it in their browser and everyone followed.
  put("\33\255\11NETSCAPE2.0\3\1\0\0\0")

  for _, frame in ipairs(frames) do
    -- how long to hold this frame, and what to do afterwards
    put("\33\249\4\4")
    put(two_bytes(hundredths))
    put("\0\0")

    put("\44")
    put(two_bytes(0))
    put(two_bytes(0))
    put(two_bytes(width))
    put(two_bytes(height))
    put("\0")

    put("\8")            -- how many bits a colour takes
    put(blocks(lzw(frame, width * height)))
  end

  put("\59")
  return table.concat(out)
end
-- }}}

-- {{{ M.frames_for(record, settings, background)
-- One frame per stroke, each showing one more of them arrowed.
--
-- The background is the finished picture -- or, before there is one, the field
-- that will produce it, which is the same shape and the same size and is what
-- makes this buildable and testable before any picture has ever been generated.
function M.frames_for(record, settings, background)
  local measured = shape.measure_record(record)
  local frames = {}

  -- The arrows are drawn once per frame with a growing number of them, rather
  -- than once and revealed, because the layer decides where each arrow goes by
  -- what is already placed -- so drawing three arrows and drawing six and
  -- keeping the first three are different pictures, and the second is the
  -- honest one.
  for count = 1, #measured do
    local partial = {}
    for index = 1, count do partial[index] = measured[index] end
    local sheets = arrows_of.build(record, settings, { measured = partial })

    local width, height = background.width, background.height
    local indices = {}
    for position = 1, width * height do
      local alpha = sheets[4].pixels[position]
      -- The arrow colour is bright and the outline is dark; which one a pixel
      -- belongs to is decided by which it is closer to, since the layer draws
      -- the outline wider and the fill over it.
      local is_outline = (sheets[1].pixels[position] < 0.4)
      indices[position] = M.index_of(background.pixels[position], alpha, is_outline)
    end
    frames[#frames + 1] = indices
  end

  -- and a last frame holding all of them, so the finished character sits still
  -- for a moment before it starts again
  if #frames > 0 then
    frames[#frames + 1] = frames[#frames]
  end
  return frames
end
-- }}}

-- {{{ M.animate(settings, entry, store)
-- The animation one rendering earned, written beside it.
function M.animate(settings, entry, store)
  local record = store.records[entry.character]
  if not record then
    -- A phrase, whose record is not in the store because it was built rather
    -- than read. Not attempted rather than attempted badly.
    return nil, entry.character .. " is not a single character; " ..
           "animating a phrase needs its record rebuilt, which nothing here does yet"
  end

  local background, why = reader.read(entry.picture)
  if not background then return nil, why end

  local frames = M.frames_for(record, settings, background)
  if #frames == 0 then return nil, "no strokes to animate" end

  local bytes = M.encode(frames, background.width, background.height,
                         M.palette(settings),
                         settings.animation and settings.animation.hundredths or 45)

  local target = entry.picture:gsub("%.png$", "-strokes.gif")
  project.write_file(target, bytes)
  pool.elaborate(entry.path, target:gsub(".*/", ""),
                 #frames .. " frames, one per stroke")
  return target, #frames
end
-- }}}

-- {{{ M.owed(settings)
-- Which pictures deserve work they have not had.
--
-- PROMOTION CREATES WORK. Moving a picture up means it now deserves an
-- animation it does not have, so the rating system is the generator's task
-- queue and not only its curator. Demotion never destroys: it stops further
-- investment and leaves what was already made where it is.
function M.owed(settings)
  local floor = (settings.animation and settings.animation.floor) or 4
  local out = {}
  for _, entry in ipairs(pool.walk(settings, { floor = floor })) do
    if #entry.elaborations == 0 then out[#out + 1] = entry end
  end
  return out, floor
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  local settings = project.hello("048-what-a-higher-tier-buys")
  local store = project.load("019-the-kanji-record").store()

  local owed, floor = M.owed(settings)
  io.write(string.format("%d pictures are at tier %d or better and have no " ..
           "animation yet\n", #owed, floor))

  if not options.do_the_work then
    for index = 1, math.min(12, #owed) do
      local tier, who = pool.tier_of(owed[index])
      io.write(string.format("  %s  %-9s tier %d by %s\n", owed[index].character,
               owed[index].category, tier, who))
    end
    if #owed > 0 then
      io.write("\n  luajit src/048-what-a-higher-tier-buys.lua --do-the-work\n")
    end
    project.goodbye("048-what-a-higher-tier-buys", { #owed .. " owed" })
    return
  end

  local made, failed = 0, {}
  for _, entry in ipairs(owed) do
    local target, why = M.animate(settings, entry, store)
    if target then
      made = made + 1
      io.write(string.format("  %s  %d frames  %s\n", entry.character, why,
               target:gsub(".*/", "")))
    else
      failed[#failed + 1] = entry.character .. ": " .. tostring(why)
    end
  end
  io.write(string.format("\n%d animations made, %d could not be\n", made, #failed))
  for _, note in ipairs(failed) do io.write("  ", note, "\n") end
  project.goodbye("048-what-a-higher-tier-buys", { made .. " animations" })
end
-- }}}

if arg and arg[0] and arg[0]:find("048%-what%-a%-higher%-tier%-buys") then
  main(arg)
end

return M
