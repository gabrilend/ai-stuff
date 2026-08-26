-- 019-the-kanji-record.lua
--
-- Puts the two archives together, and is the only shape the rest of the project
-- ever sees a kanji in.
--
-- For a general: one archive knows what a character looks like and the other
-- knows what it means, and neither knows about the other. This joins them on the
-- character itself and hands out a single record holding both -- the strokes in
-- writing order, the pieces the character is built from, the English glosses,
-- the readings, and the few numbers that say who learns it and when.
--
-- It also says what did not join, and that half matters as much. One archive
-- describes about twice as many characters as the other draws, so a plain join
-- silently discards thousands of entries. Silently is the problem: a set that
-- shrinks without saying so is a set nobody notices has shrunk.
--
--   luajit src/019-the-kanji-record.lua [--dir ROOT] [--report] [--chars 木火水]

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local xml = project.load("011-scan-xml")
local strokes_archive = project.load("012-read-the-strokes")
local meanings_archive = project.load("013-read-the-meanings")
local fetch = project.load("010-fetch-the-archives")

local M = {}

-- {{{ archive_stamp()
-- A short string that changes when either archive does.
--
-- Size and modification time of both files. Not a checksum of their contents:
-- checksumming thirty megabytes to decide whether to skip a four-second parse
-- would cost more than the parse. Size-and-time is the ordinary answer and it
-- is wrong only for an edit that preserved both, which does not happen to files
-- that arrive by download.
local function archive_stamp()
  local parts = {}
  for _, name in ipairs({ "kanjivg", "kanjidic2" }) do
    local path = fetch.require_archive(name)
    local pipe = io.popen("stat -c '%s:%Y' '" .. path .. "' 2>/dev/null")
    local line = pipe and pipe:read("*l") or ""
    if pipe then pipe:close() end
    parts[#parts + 1] = name .. "=" .. tostring(line)
  end
  return table.concat(parts, ",")
end
-- }}}

-- {{{ FIELD, RECORD_TAGS -- the flat form a store is cached in
--
-- WHY NOT LUA SOURCE. The first version of this cache wrote the store as a Lua
-- table literal, on the reasoning that the interpreter already has a fast
-- reader for Lua and a second format means a second parser. Measured, it was
-- *slower than re-reading the XML it came from* -- thirty-two megabytes of
-- source, because the standard quoter escapes every byte of every kanji, and
-- compiling that costs more than parsing thirty megabytes of tags.
--
-- So: a flat text format, one line per thing, fields separated by tabs. It
-- parses in a single pass with no compilation and no escaping, because none of
-- the data can contain a tab or a newline -- path text is digits and letters,
-- glosses are dictionary English, and characters are characters.
--
-- The tags are one letter each, at the start of each line:
--   K  a character, and its numbers
--   M  its English glosses
--   O  its borrowed readings
--   U  its native readings
--   S  one stroke, in writing order
--   C  one component
local SEPARATOR = "\t"

-- {{{ split(line)
-- One cache line's fields, including the empty ones.
--
-- gmatch on a pattern that can match nothing loops forever or skips empties
-- depending on how it is written, and an empty field here means "this
-- character has no school grade" -- dropping it shifts every field after it.
local function split(line)
  local out = {}
  local position = 1
  while true do
    local tab = line:find(SEPARATOR, position, true)
    if not tab then
      out[#out + 1] = line:sub(position)
      return out
    end
    out[#out + 1] = line:sub(position, tab - 1)
    position = tab + 1
  end
end
-- }}}

-- {{{ blank(value)
-- nil written as nothing, so an absent number stays absent.
local function blank(value)
  if value == nil then return "" end
  if value == true then return "1" end
  if value == false then return "" end
  return tostring(value)
end
-- }}}

-- {{{ write_cache(store, path)
-- The store, as flat lines.
local function write_cache(store, path)
  local out = {}
  local function line(...)
    out[#out + 1] = table.concat({ ... }, SEPARATOR)
    out[#out + 1] = "\n"
  end

  line("V", "1", store.stamp)
  line("R", tostring(store.report.glossed_only))
  for _, character in ipairs(store.report.drawn_only) do
    line("D", character)
  end
  for _, character in ipairs(store.report.not_ideographs) do
    line("N", character)
  end
  for _, character in ipairs(store.report.duplicate_forms) do
    line("F", character)
  end
  for _, row in ipairs(store.report.stroke_count_disagreements) do
    line("X", row.character, tostring(row.drawn), tostring(row.dictionary))
  end

  -- written in the store's own order, so reading it back restores that order
  -- without a sort
  for _, record in ipairs(store.order) do
    line("K", record.character, blank(record.codepoint), blank(record.grade),
         blank(record.jlpt), blank(record.frequency), blank(record.stroke_count),
         blank(record.radical), blank(record.stroke_count_disputed))
    line("M", unpack(record.meanings))
    line("O", unpack(record.readings_on))
    line("U", unpack(record.readings_kun))
    for _, stroke in ipairs(record.strokes) do
      line("S", blank(stroke.class), blank(stroke.group), stroke.d)
    end
    for _, component in ipairs(record.components) do
      line("C", blank(component.element), blank(component.position),
           blank(component.phonetic), blank(component.radical),
           blank(component.variant), blank(component.original),
           blank(component.part), blank(component.depth),
           blank(component.stroke_first), blank(component.stroke_last))
    end
  end

  project.write_file(path, table.concat(out))
end
-- }}}

-- {{{ read_cache(path, stamp)
-- The store, read back, or nil if the file is absent or stale.
local function read_cache(path, stamp)
  local text = project.read_file(path)
  if not text then return nil end

  local records, order = {}, {}
  local report = { drawn_only = {}, not_ideographs = {}, duplicate_forms = {},
                   glossed_only = 0, stroke_count_disagreements = {} }
  local current = nil
  local first_line = true

  for line in text:gmatch("([^\n]*)\n") do
    local tag = line:sub(1, 1)
    local fields = split(line:sub(3))

    if first_line then
      -- the version and the archive stamp. a cache written by an older shape of
      -- this file, or from archives that have since changed, is not a cache --
      -- it is a wrong answer that would be believed
      if tag ~= "V" or fields[1] ~= "1" or fields[2] ~= stamp then return nil end
      first_line = false

    elseif tag == "K" then
      current = {
        character = fields[1],
        codepoint = tonumber(fields[2]),
        grade = tonumber(fields[3]),
        jlpt = tonumber(fields[4]),
        frequency = tonumber(fields[5]),
        stroke_count = tonumber(fields[6]),
        radical = tonumber(fields[7]),
        stroke_count_disputed = fields[8] == "1" or nil,
        meanings = {}, readings_on = {}, readings_kun = {},
        strokes = {}, components = {},
      }
      records[current.character] = current
      order[#order + 1] = current

    elseif tag == "M" then current.meanings = fields
    elseif tag == "O" then current.readings_on = fields
    elseif tag == "U" then current.readings_kun = fields

    elseif tag == "S" then
      current.strokes[#current.strokes + 1] = {
        class = fields[1] ~= "" and fields[1] or nil,
        group = tonumber(fields[2]),
        d = fields[3],
      }

    elseif tag == "C" then
      current.components[#current.components + 1] = {
        element = fields[1] ~= "" and fields[1] or nil,
        position = fields[2] ~= "" and fields[2] or nil,
        phonetic = fields[3] == "1",
        radical = fields[4] ~= "" and fields[4] or nil,
        variant = fields[5] == "1",
        original = fields[6] ~= "" and fields[6] or nil,
        part = fields[7] ~= "" and fields[7] or nil,
        depth = tonumber(fields[8]),
        stroke_first = tonumber(fields[9]),
        stroke_last = tonumber(fields[10]),
      }

    elseif tag == "R" then report.glossed_only = tonumber(fields[1]) or 0
    elseif tag == "D" then report.drawn_only[#report.drawn_only + 1] = fields[1]
    elseif tag == "N" then
      report.not_ideographs[#report.not_ideographs + 1] = fields[1]
    elseif tag == "F" then
      report.duplicate_forms[#report.duplicate_forms + 1] = fields[1]
    elseif tag == "X" then
      report.stroke_count_disagreements[#report.stroke_count_disagreements + 1] =
        { character = fields[1], drawn = tonumber(fields[2]),
          dictionary = tonumber(fields[3]) }
    end
  end

  -- an empty line list means a truncated write, and a store with no characters
  -- in it would be believed by everything downstream
  if #order == 0 then return nil end
  return { records = records, order = order, report = report, stamp = stamp }
end
-- }}}
-- }}}

-- {{{ is_ideograph(codepoint)
-- Whether a character number is a Chinese character at all.
--
-- WHY THIS EXISTS. The stroke archive draws more than kanji. It draws the Latin
-- alphabet, the digits, ordinary punctuation and both Japanese syllabaries --
-- reasonably, since it is a stroke-order archive and those are things people
-- learn to write. None of them appear in a kanji dictionary, so all of them
-- turned up in the join's leftovers, and the report said several hundred
-- characters were "drawn but not glossed" as though that many kanji were being
-- lost. Almost none of them were kanji.
--
-- Two ranges: the main block and the extension before it.
--
-- The compatibility block at F900 is deliberately not here, and leaving it in
-- was the second thing this report caught. Those characters are duplicate
-- encodings -- the same glyph given a second number so that older Korean text
-- could be converted to Unicode and back without loss. The stroke archive draws
-- them; no kanji dictionary lists them, because to a dictionary they are not
-- separate characters. Counted as ideographs, they made nine ordinary kanji
-- look like gaps in the dictionary, including "cold" and "territory".
local function is_ideograph(codepoint)
  return (codepoint >= 0x4E00 and codepoint <= 0x9FFF)
      or (codepoint >= 0x3400 and codepoint <= 0x4DBF)
end
-- }}}

-- {{{ is_duplicate_form(codepoint)
-- Whether a character number is in the compatibility block.
local function is_duplicate_form(codepoint)
  return codepoint >= 0xF900 and codepoint <= 0xFAFF
end
-- }}}

-- {{{ WHAT IS AND IS NOT KNOWN ABOUT THE COMPATIBILITY BLOCK
--
-- These characters are excluded and this project cannot say what each one
-- duplicates. That is a limitation, not an oversight, and it is written here
-- because two attempts to remove it both produced a check that quietly passed
-- while being wrong about the world.
--
-- What is known. Unicode's compatibility block exists so that text in older
-- Korean encodings can be converted to Unicode and back without loss. Every
-- character in it is defined by Unicode as canonically equivalent to a
-- character in the main block. The kanji dictionary lists only the main-block
-- one, which is why these arrive with no gloss.
--
-- What is not known here: which main-block character each one pairs with.
--
--   The first attempt compared the two drawings' path text, assuming a
--   duplicate is drawn identically. Every comparison failed -- correctly. A
--   compatibility character exists precisely so a glyph drawn *differently*
--   can round-trip, and the two forms of "cold" share a byte-identical left
--   half and draw the right half two different ways.
--
--   The second attempt read the identity out of the archive, since every
--   drawing's outermost group carries a kvg:element naming the character it
--   spells. It names itself. The two entries look identical on screen and are
--   two different characters, which is the entire point of the block and is
--   also why staring at the file did not reveal it.
--
-- The pairing is in Unicode's own character database and in neither archive
-- here. Fetching a third dataset to resolve nine characters that nobody is
-- learning is not worth it, so they are set aside, counted, and named. docs/007
-- holds the question in case that judgement changes.
-- }}}

-- {{{ M.build()
-- Read both archives, join them, and describe what did not join.
--
-- Returns the store. Slow -- it parses thirty megabytes -- so callers should go
-- through M.store, which caches this.
function M.build()
  local drawn = strokes_archive.read(fetch.require_archive("kanjivg"))
  local glossed = meanings_archive.read(fetch.require_archive("kanjidic2"))

  local records = {}
  local order = {}
  local report = {
    drawn_only = {},        -- a kanji with strokes and no English gloss
    not_ideographs = {},    -- drawn, but never was a kanji: letters, digits, kana
    duplicate_forms = {},   -- a second encoding of a character already here
    glossed_only = 0,       -- has a gloss, is not drawn: nothing to draw
    stroke_count_disagreements = {},
  }

  for character, drawing in pairs(drawn) do
    local gloss = glossed[character]
    -- Both halves are required and neither is negotiable. A character with no
    -- gloss has nothing for a picture to be *of*; a character with no strokes
    -- has nothing for the picture to be *shaped like*. Either way there is no
    -- reduced version of this project's output to fall back to.
    if not gloss or #gloss.meanings == 0 then
      -- Three very different reasons to be here, kept apart. A kanji with no
      -- gloss is a gap in the dictionary and might be worth rescuing by hand.
      -- A second encoding of a character already in the set is not a gap. A
      -- capital Q is not a gap in anything.
      if is_duplicate_form(drawing.codepoint) then
        report.duplicate_forms[#report.duplicate_forms + 1] = character
      elseif is_ideograph(drawing.codepoint) then
        report.drawn_only[#report.drawn_only + 1] = character
      else
        report.not_ideographs[#report.not_ideographs + 1] = character
      end
    else
      local record = {
        character = character,
        codepoint = drawing.codepoint,
        strokes = drawing.strokes,
        components = drawing.components,
        meanings = gloss.meanings,
        readings_on = gloss.readings_on,
        readings_kun = gloss.readings_kun,
        grade = gloss.grade,
        jlpt = gloss.jlpt,
        frequency = gloss.frequency,
        stroke_count = gloss.stroke_count,
        radical = gloss.radical,
      }
      -- The archives are checked against each other rather than one being
      -- preferred. Where they disagree they are describing different forms of
      -- the character, and that is a fact about the data worth surfacing --
      -- not a number to quietly pick a winner for.
      if gloss.stroke_count and gloss.stroke_count ~= #drawing.strokes then
        record.stroke_count_disputed = true
        report.stroke_count_disagreements[#report.stroke_count_disagreements + 1] = {
          character = character,
          drawn = #drawing.strokes,
          dictionary = gloss.stroke_count,
        }
      end
      records[character] = record
      order[#order + 1] = record
    end
  end

  for character in pairs(glossed) do
    if not drawn[character] then report.glossed_only = report.glossed_only + 1 end
  end

  table.sort(report.drawn_only)
  table.sort(report.not_ideographs)
  table.sort(report.duplicate_forms)
  table.sort(report.stroke_count_disagreements,
             function(a, b) return a.character < b.character end)

  -- The default order is by how often a character is actually met, commonest
  -- first, with the ones the dictionary gives no frequency for after them in
  -- codepoint order. That makes "the first two hundred" mean something without
  -- anybody having to ask for a sort.
  table.sort(order, function(a, b)
    local left = a.frequency or math.huge
    local right = b.frequency or math.huge
    if left ~= right then return left < right end
    return a.codepoint < b.codepoint
  end)

  return { records = records, order = order, report = report,
           stamp = archive_stamp() }
end
-- }}}

-- {{{ M.store(options)
-- The joined store, from the cache if the archives have not changed.
--
-- The cache lives in the RAM tier rather than in the repository: it is derived
-- from two files that are themselves not committed, it is rebuildable in a few
-- seconds, and a batch run spawns a worker per processor -- each of which would
-- otherwise re-parse thirty megabytes to look at its own share of the set.
function M.store(options)
  options = options or {}
  local cache_path = project.scratch("kanji-record-cache.tsv")
  local stamp = archive_stamp()

  if not options.rebuild then
    local cached = read_cache(cache_path, stamp)
    if cached then return cached end
  end

  local store = M.build()
  write_cache(store, cache_path)
  return store
end
-- }}}

-- {{{ SELECTORS -- the ways a person asks for a set of characters
--
-- A dispatch table rather than a chain of tests, so that adding a way to choose
-- characters is adding a row. Each takes the store and the argument the person
-- gave, and returns an array of records in the store's own order.
local SELECTORS = {}

SELECTORS.all = function(store)
  return store.order
end

SELECTORS.grade = function(store, value)
  local wanted = tonumber(value)
  if not wanted then error("--grade wants a school year, got " .. tostring(value)) end
  local out = {}
  for _, record in ipairs(store.order) do
    if record.grade == wanted then out[#out + 1] = record end
  end
  return out
end

SELECTORS.jlpt = function(store, value)
  local wanted = tonumber(value)
  if not wanted then error("--jlpt wants a level, got " .. tostring(value)) end
  local out = {}
  for _, record in ipairs(store.order) do
    if record.jlpt == wanted then out[#out + 1] = record end
  end
  return out
end

SELECTORS.frequent = function(store, value)
  local howmany = tonumber(value)
  if not howmany then error("--frequent wants a count, got " .. tostring(value)) end
  local out = {}
  for _, record in ipairs(store.order) do
    -- the store's order is already commonest-first, so this is a prefix -- but
    -- only of the characters that have a frequency at all
    if record.frequency and #out < howmany then out[#out + 1] = record end
  end
  return out
end

SELECTORS.chars = function(store, value)
  local out = {}
  local missing = {}
  for _, character in ipairs(xml.characters(tostring(value))) do
    local record = store.records[character]
    if record then
      out[#out + 1] = record
    else
      missing[#missing + 1] = character
    end
  end
  -- A character that was asked for by name and is not here is a mistake worth
  -- stopping for. Asking for four characters and getting three back without
  -- being told is how a demo comes out one picture short.
  if #missing > 0 then
    error("not in the joined set: " .. table.concat(missing, " ") ..
          "\n  either the stroke archive does not draw it, or the dictionary" ..
          "\n  gives it no English meaning. run with --report to see both lists.")
  end
  return out
end
-- }}}

-- {{{ M.select(store, query)
-- Characters, chosen the way the command line asked.
--
-- The query is the parsed argument table. Selectors are tried in a fixed order
-- so that two of them given at once behave the same way every time rather than
-- depending on which the hash happened to offer first.
function M.select(store, query)
  for _, name in ipairs({ "chars", "grade", "jlpt", "frequent", "all" }) do
    if query[name] ~= nil then
      return SELECTORS[name](store, query[name]), name
    end
  end
  return nil, nil
end
-- }}}

-- {{{ M.selector_names()
-- The ways of choosing that exist, for a program printing its own usage.
function M.selector_names()
  local names = {}
  for name in pairs(SELECTORS) do names[#names + 1] = name end
  table.sort(names)
  return names
end
-- }}}

-- {{{ M.describe(store)
-- What the join produced and what it cost, as lines of text.
function M.describe(store)
  local lines = {}
  lines[#lines + 1] = string.format("%d characters have both strokes and meaning",
                                    #store.order)
  lines[#lines + 1] = string.format("%d kanji are drawn but have no English " ..
                                    "gloss, so there is nothing for a picture " ..
                                    "to be about", #store.report.drawn_only)
  lines[#lines + 1] = string.format("%d drawn characters are not kanji at all " ..
                                    "-- letters, digits, kana -- and were never " ..
                                    "this project's to make",
                                    #store.report.not_ideographs)
  lines[#lines + 1] = string.format("%d are in the compatibility block, so the " ..
                                    "dictionary glosses them under another " ..
                                    "number that nothing here can name",
                                    #store.report.duplicate_forms)
  lines[#lines + 1] = string.format("%d are glossed but not drawn, so there is " ..
                                    "nothing to shape a picture like",
                                    store.report.glossed_only)
  lines[#lines + 1] = string.format("%d have a stroke count the two archives " ..
                                    "disagree about",
                                    #store.report.stroke_count_disagreements)
  return lines
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  project.hello("019-the-kanji-record")

  local started = os.clock()
  local store = M.store({ rebuild = options.rebuild })
  local elapsed = os.clock() - started

  local lines = M.describe(store)
  for _, line in ipairs(lines) do io.write(line .. "\n") end
  io.write(string.format("(%.2fs)\n", elapsed))

  if options.report then
    io.write("\nkanji drawn but not glossed, first forty:\n  ")
    for index = 1, math.min(40, #store.report.drawn_only) do
      io.write(store.report.drawn_only[index], " ")
    end
    io.write("\n\ndrawn and not kanji, first forty:\n  ")
    for index = 1, math.min(40, #store.report.not_ideographs) do
      io.write(store.report.not_ideographs[index], " ")
    end
    io.write("\n\nin the compatibility block, glossed elsewhere under a number\n" ..
             "this project cannot work out:\n  ")
    for index = 1, #store.report.duplicate_forms do
      io.write(store.report.duplicate_forms[index], " ")
    end
    io.write("\n")
    io.write("\n\nstroke counts the archives disagree about, first twenty:\n")
    for index = 1, math.min(20, #store.report.stroke_count_disagreements) do
      local row = store.report.stroke_count_disagreements[index]
      io.write(string.format("  %s  drawn %d, dictionary %d\n",
               row.character, row.drawn, row.dictionary))
    end
  end

  local chosen, how = M.select(store, options)
  if chosen then
    io.write(string.format("\n%s selected %d characters\n", how, #chosen))
    for index = 1, math.min(24, #chosen) do
      local record = chosen[index]
      io.write(string.format("  %s  %-28s %d strokes, grade %s\n",
               record.character, table.concat(record.meanings, ", "):sub(1, 28),
               #record.strokes, tostring(record.grade)))
    end
  end

  project.goodbye("019-the-kanji-record", lines)
end
-- }}}

if arg and arg[0] and arg[0]:find("019%-the%-kanji%-record") then
  main(arg)
end

return M
