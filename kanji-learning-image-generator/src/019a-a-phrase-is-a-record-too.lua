-- 019a-a-phrase-is-a-record-too.lua
--
-- Several characters, joined into one record that behaves exactly like a single
-- character's.
--
-- For a general: a learner is not trying to hold 時 and 間 separately. They are
-- trying to hold 時間, which means *time*, and that is one thing. This builds a
-- record for a whole word out of the records for the characters in it, in the
-- same shape, so that everything downstream keeps working without being told
-- that anything changed.
--
-- Numbered to sit beside `019`, the store it extends, rather than after it.
--
--   luajit src/019a-a-phrase-is-a-record-too.lua --phrases 時間 山口

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local xml = project.load("011-scan-xml")

local M = {}

-- {{{ M.cells(record)
-- Which characters a record covers, and which strokes belong to each.
--
-- A single character is one cell, and saying so here rather than at every call
-- site is what lets the field, the arrows and the scene grammar treat a word
-- and a character as the same kind of thing. Everything asks this; nothing
-- checks whether it was given a phrase.
function M.cells(record)
  if record.cells then return record.cells end
  return { {
    character = record.character, codepoint = record.codepoint,
    stroke_first = 1, stroke_last = #record.strokes, index = 1,
    meanings = record.meanings,
  } }
end
-- }}}

-- {{{ M.is_phrase(record)
function M.is_phrase(record)
  return record.cells ~= nil and #record.cells > 1
end
-- }}}

-- {{{ M.build(characters, meanings, store)
-- One record for a whole word.
--
-- The strokes of every character, in order, each remembering which cell it came
-- from. The components of every character, with their stroke ranges shifted so
-- they still point at the right strokes. And the meanings, which had to be
-- supplied, because the archives gloss characters and not words.
function M.build(characters, meanings, store)
  local pieces = xml.characters(characters)
  if #pieces == 0 then error("a phrase with no characters in it") end

  local records = {}
  local missing = {}
  for index, character in ipairs(pieces) do
    local record = store.records[character]
    if not record then
      missing[#missing + 1] = character
    else
      records[index] = record
    end
  end
  if #missing > 0 then
    error("not in the joined set: " .. table.concat(missing, " ") ..
          "\n  a phrase can only be drawn out of characters this project can" ..
          "\n  already draw. run src/019 --report to see what is missing and why.")
  end

  if not meanings or #meanings == 0 then
    error("the phrase " .. characters .. " has no meaning given.\n" ..
          "  The archives gloss characters, not words -- so a word's meaning\n" ..
          "  has to be supplied, either on the command line as\n" ..
          "    --phrase " .. characters .. "=time,an hour\n" ..
          "  or in input/phrases.lua.")
  end

  local strokes, components, cells = {}, {}, {}
  local codepoint = 0

  for index, record in ipairs(records) do
    local first = #strokes + 1

    for _, stroke in ipairs(record.strokes) do
      strokes[#strokes + 1] = {
        d = stroke.d, class = stroke.class, group = stroke.group,
        -- which character this stroke belongs to. the field and the arrows use
        -- it to work out which box on the canvas to draw it in.
        cell = index,
      }
    end

    for _, component in ipairs(record.components) do
      components[#components + 1] = {
        element = component.element, position = component.position,
        phonetic = component.phonetic, radical = component.radical,
        variant = component.variant, original = component.original,
        part = component.part,
        -- Depth is pushed down by one. The whole phrase is now the outermost
        -- thing, so each character becomes a piece of it, and each character's
        -- own pieces sit one level further in than they did. Without this, two
        -- characters' outermost groups would both claim to be the whole record.
        depth = component.depth + 1,
        stroke_first = component.stroke_first + first - 1,
        stroke_last = component.stroke_last + first - 1,
        cell = index,
      }
    end

    cells[#cells + 1] = {
      character = record.character, codepoint = record.codepoint,
      stroke_first = first, stroke_last = #strokes, index = index,
      meanings = record.meanings,
    }
    -- A number that is this phrase's and no other's, for the seed. Shifted
    -- rather than added, so 山口 and 口山 do not get the same picture.
    codepoint = (codepoint * 1103515245 + record.codepoint) % 2147483647
  end

  table.sort(components, function(a, b)
    if a.depth ~= b.depth then return a.depth < b.depth end
    return a.stroke_first < b.stroke_first
  end)

  -- The commonest grade and level among the characters, since a word is about
  -- as hard as its hardest character. Taken as the maximum, and absent if any
  -- character has none.
  local grade, jlpt, frequency
  for _, record in ipairs(records) do
    if record.grade then grade = math.max(grade or 0, record.grade) end
    -- JLPT counts down, so the hardest character has the smallest number
    if record.jlpt then jlpt = math.min(jlpt or 99, record.jlpt) end
    if record.frequency then
      frequency = math.max(frequency or 0, record.frequency)
    end
  end

  local readings_on, readings_kun = {}, {}
  for _, record in ipairs(records) do
    for _, reading in ipairs(record.readings_on) do
      readings_on[#readings_on + 1] = reading
    end
    for _, reading in ipairs(record.readings_kun) do
      readings_kun[#readings_kun + 1] = reading
    end
  end

  return {
    character = characters,
    codepoint = codepoint,
    strokes = strokes,
    components = components,
    cells = cells,
    meanings = meanings,
    readings_on = readings_on,
    readings_kun = readings_kun,
    grade = grade, jlpt = jlpt, frequency = frequency,
    stroke_count = #strokes,
    radical = records[1].radical,
  }
end
-- }}}

-- {{{ M.from_argument(text, store)
-- One phrase off a command line: 時間=time,an hour
function M.from_argument(text, store)
  local characters, glosses = tostring(text):match("^([^=]+)=(.+)$")
  if not characters then
    characters, glosses = tostring(text), nil
  end
  local meanings = {}
  for gloss in (glosses or ""):gmatch("([^,]+)") do
    meanings[#meanings + 1] = (gloss:gsub("^%s+", ""):gsub("%s+$", ""))
  end
  return M.build(characters, meanings, store)
end
-- }}}

-- {{{ M.from_input(store)
-- The phrases somebody has written down in input/, if any.
--
-- This is where a course's vocabulary list goes, and it is the reason phrases
-- are worth having at all -- one word typed on a command line is a
-- demonstration, and a list of the four hundred a chapter covers is a study
-- set.
function M.from_input(store)
  local file = project.path("input", "phrases.lua")
  if not project.exists(file) then return {} end

  -- A file that is there and will not load is a different thing from a file
  -- that is not there, and treating them the same is how a typo in a
  -- vocabulary list becomes "you have no vocabulary list" -- reported as
  -- nothing to do, cheerfully, with no error anywhere.
  local chunk, why = loadfile(file)
  if not chunk then
    error("input/phrases.lua is there and will not load:\n  " .. tostring(why))
  end
  local listed = chunk()
  if type(listed) ~= "table" then
    error("input/phrases.lua must return a table of phrase = { meanings }")
  end
  local out = {}
  local keys = {}
  for characters in pairs(listed) do keys[#keys + 1] = characters end
  -- sorted, so a set built from this file comes out in the same order every
  -- run and two runs can be compared
  table.sort(keys)
  for _, characters in ipairs(keys) do
    out[#out + 1] = M.build(characters, listed[characters], store)
  end
  return out
end
-- }}}

-- {{{ M.select(store, query)
-- The phrases a command line asked for, or nil if it asked for none.
function M.select(store, query)
  local out = {}
  if query.phrase then
    out[#out + 1] = M.from_argument(query.phrase, store)
  end
  if query.phrases then
    if query.phrases == true then
      for _, record in ipairs(M.from_input(store)) do out[#out + 1] = record end
    else
      for one in tostring(query.phrases):gmatch("%S+") do
        out[#out + 1] = M.from_argument(one, store)
      end
    end
  end
  if #out == 0 then return nil end
  return out
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  project.hello("019a-a-phrase-is-a-record-too")
  local store = project.load("019-the-kanji-record").store()

  local chosen = M.select(store, options)
  if not chosen then
    io.write("say which phrases. one of:\n")
    io.write("  --phrase 時間=time,an hour\n")
    io.write("  --phrases '時間=time 山口=a mountain pass'\n")
    io.write("  --phrases           (everything in input/phrases.lua)\n")
    os.exit(1)
  end

  for _, record in ipairs(chosen) do
    io.write("\n", record.character, "  ", table.concat(record.meanings, ", "),
             "\n")
    io.write(string.format("  %d characters, %d strokes altogether\n",
             #record.cells, #record.strokes))
    for _, cell in ipairs(record.cells) do
      io.write(string.format("    %s  strokes %d-%d   %s\n", cell.character,
               cell.stroke_first, cell.stroke_last,
               table.concat(cell.meanings, ", ")))
    end
    -- The pieces below the characters themselves. A word made of characters
    -- that have no parts -- 人口, a person and a mouth -- has nothing at that
    -- level, and saying "made of:" followed by nothing is worse than saying
    -- that the characters are the pieces.
    local pieces = {}
    for _, component in ipairs(record.components) do
      if component.depth > 2 then
        pieces[#pieces + 1] = component.element
      end
    end
    if #pieces > 0 then
      io.write("  made of: ", table.concat(pieces, " "), "\n")
    else
      io.write("  made of: nothing smaller than its own characters\n")
    end
  end
  project.goodbye("019a-a-phrase-is-a-record-too", { #chosen .. " phrases" })
end
-- }}}

if arg and arg[0] and arg[0]:find("019a%-a%-phrase%-is%-a%-record") then
  main(arg)
end

return M
