-- 013-read-the-meanings.lua
--
-- Reads the dictionary archive: what each character means, how it is said, and
-- the handful of numbers that say who learns it and when.
--
-- For a general: the stroke archive knows what a character looks like and
-- nothing about what it is for. This is the other half. It is an ordinary
-- dictionary in XML -- one entry per character, holding English glosses in
-- order of importance, Japanese readings split by where they came from, and
-- some catalogue numbers.
--
-- Most of the entry is thrown away. The archive carries a few dozen references
-- into specific paper dictionaries so a person can look a character up in a
-- book, and nothing here is looking anything up in a book.

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local xml = project.load("011-scan-xml")

local M = {}

-- {{{ M.read(path, wanted)
-- The whole dictionary, as a table keyed by character.
--
-- `wanted`, if given, is a set of characters to keep.
--
-- Each entry holds:
--   character      the character itself
--   meanings       English glosses, primary first
--   readings_on    borrowed-from-Chinese readings, in katakana
--   readings_kun   native Japanese readings, in hiragana
--   grade          the school year it is taught in, or nil
--   jlpt           the proficiency level it appears at, or nil
--   frequency      its rank by newspaper frequency, or nil
--   stroke_count   how many strokes the dictionary says it has
--   radical        its classical radical number
function M.read(path, wanted)
  local text = project.read_file(path)
  if not text then
    error("cannot read the dictionary archive at " .. path ..
          "\n  get it with:  luajit src/010-fetch-the-archives.lua")
  end

  local out = {}
  local count = 0

  local current = nil
  local buffer = nil          -- the text collected inside the open element
  local attributes = nil      -- that element's attributes, if it had any
  local in_reading_meaning = false

  -- {{{ take -- what to do with each element that closes, by name
  --
  -- A dispatch table rather than a chain of comparisons. Every closing tag in a
  -- fifteen-megabyte document is tested against this, so the difference between
  -- one lookup and twenty string compares is the difference in how long the
  -- read takes; and adding a field later is adding a row.
  local take = {}

  take.literal = function(value)
    current.character = value
  end

  take.grade = function(value)
    current.grade = tonumber(value)
  end

  take.jlpt = function(value)
    current.jlpt = tonumber(value)
  end

  take.freq = function(value)
    current.frequency = tonumber(value)
  end

  take.stroke_count = function(value)
    -- The archive gives the accepted count first and then any counts that
    -- people commonly get wrong. Taking the last would be taking a mistake.
    if not current.stroke_count then current.stroke_count = tonumber(value) end
  end

  take.rad_value = function(value)
    if attributes and attributes.rad_type == "classical" then
      current.radical = tonumber(value)
    end
  end

  take.meaning = function(value)
    -- A gloss with a language on it is a gloss in some other language. The
    -- English ones are the ones with no language stated, which is a slightly
    -- surprising rule and is the archive's, not ours.
    if attributes and attributes.m_lang then return end
    -- nanori and other sections sit outside reading_meaning; a meaning found
    -- there would not be a meaning of the character
    if not in_reading_meaning then return end
    current.meanings[#current.meanings + 1] = value
  end

  take.reading = function(value)
    if not attributes then return end
    if attributes.r_type == "ja_on" then
      current.readings_on[#current.readings_on + 1] = value
    elseif attributes.r_type == "ja_kun" then
      current.readings_kun[#current.readings_kun + 1] = value
    end
    -- pinyin, korean and vietnamese readings are in here too and are of no use
    -- to somebody learning Japanese from pictures
  end
  -- }}}

  local handlers = {}

  -- {{{ handlers.open(name, attribute_text, self_closing)
  function handlers.open(name, attribute_text, self_closing)
    if name == "character" then
      current = {
        meanings = {}, readings_on = {}, readings_kun = {},
      }
      in_reading_meaning = false
      return
    end
    if not current then return end
    if name == "reading_meaning" then in_reading_meaning = true end
    -- Attributes are only parsed for the elements that have ones worth having.
    -- This runs half a million times; parsing every tag's attributes here was
    -- most of the reading time and almost all of it was thrown away.
    if name == "reading" or name == "meaning" or name == "rad_value" then
      attributes = xml.attributes(attribute_text)
    else
      attributes = nil
    end
    buffer = {}
  end
  -- }}}

  -- {{{ handlers.text(raw)
  function handlers.text(raw)
    if buffer then buffer[#buffer + 1] = raw end
  end
  -- }}}

  -- {{{ handlers.close(name)
  function handlers.close(name)
    if name == "character" then
      if current and current.character then
        local keep = (wanted == nil) or (wanted[current.character] == true)
        -- a character with no English gloss has nothing for a picture to be
        -- about, and docs/002 drops it at the join rather than here -- the
        -- reader's job is to report the archive, not to judge it
        if keep then
          out[current.character] = current
          count = count + 1
        end
      end
      current, buffer, attributes = nil, nil, nil
      in_reading_meaning = false
      return
    end
    if name == "reading_meaning" then in_reading_meaning = false end
    if not current or not buffer then return end
    local handler = take[name]
    if handler then
      local value = xml.decode(table.concat(buffer)):gsub("^%s+", ""):gsub("%s+$", "")
      if value ~= "" then handler(value) end
    end
    buffer = nil
  end
  -- }}}

  xml.scan(text, handlers)

  if count == 0 then
    error("the dictionary archive at " .. path .. " yielded no characters;" ..
          "\n  it is the wrong file, or its format has changed")
  end
  return out, count
end
-- }}}

return M
