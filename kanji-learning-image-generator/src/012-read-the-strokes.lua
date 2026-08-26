-- 012-read-the-strokes.lua
--
-- Reads the stroke archive: what every character is drawn with, in the order a
-- hand draws it, and what pieces it is built out of.
--
-- For a general: this is the file that makes the whole project possible. The
-- archive does not merely hold an outline of each character -- it holds the
-- individual brush strokes, in writing order, wrapped in groups that say which
-- smaller character each stroke belongs to. So the archive states outright that
-- the character for "rest" is a person standing next to a tree, and it states
-- which of those two was written first.
--
-- Both of those facts survive into the record this produces. The picture the
-- project eventually describes is built out of them.

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local xml = project.load("011-scan-xml")

local M = {}

-- {{{ M.read(path, wanted)
-- The whole stroke archive, as a table keyed by character.
--
-- `wanted`, if given, is a set of characters to keep. Everything else is parsed
-- and thrown away rather than skipped -- the scan is a single forward pass and
-- there is nowhere to skip to -- but nothing is retained, which is what matters
-- when a caller wants four characters out of six thousand.
--
-- Each entry holds:
--   character   the character itself
--   codepoint   its number
--   strokes     an array, in writing order
--   components  an array, outermost first
--
-- A stroke holds its raw path text, the calligraphic class the archive assigned
-- it, and the index of the innermost component that owns it. A component holds
-- the character it is, where it sits, whether it is there for its sound, and
-- the range of strokes it covers.
function M.read(path, wanted)
  local text = project.read_file(path)
  if not text then
    error("cannot read the stroke archive at " .. path ..
          "\n  get it with:  luajit src/010-fetch-the-archives.lua")
  end

  local out = {}
  local count = 0

  -- what is being assembled right now, and nil between characters
  local current = nil
  local stack = nil
  local keeping = true

  -- {{{ finish_group(frame)
  -- A group has closed: record it as a component if it named one.
  --
  -- A group with no kvg:element is structural -- the archive uses them to bind
  -- strokes that belong together without claiming they spell anything. Those
  -- have no meaning to contribute and are not components.
  local function finish_group(frame)
    if not frame.element then return end
    frame.stroke_last = #current.strokes
    -- a group that closed without any strokes inside it describes nothing
    if frame.stroke_last < frame.stroke_first then return end
    current.components[#current.components + 1] = frame
  end
  -- }}}

  local handlers = {}

  -- {{{ handlers.open(name, attribute_text, self_closing)
  function handlers.open(name, attribute_text, self_closing)
    if name == "kanji" then
      local attributes = xml.attributes(attribute_text)
      local hex = tostring(attributes.id):match("^kvg:kanji_(%x+)$")
      -- ids with a suffix are alternate renderings of a character that already
      -- has an entry. taking them would overwrite the ordinary form with a
      -- calligraphic variant, silently, for whichever came last.
      if not hex then
        keeping = false
        current = nil
        return
      end
      local codepoint = tonumber(hex, 16)
      local character = xml.utf8(codepoint)
      keeping = (wanted == nil) or (wanted[character] == true)
      current = {
        character = character,
        codepoint = codepoint,
        strokes = {},
        components = {},
      }
      stack = {}

    elseif name == "g" and current then
      local attributes = xml.attributes(attribute_text)
      stack[#stack + 1] = {
        element = attributes["kvg:element"],
        position = attributes["kvg:position"],
        -- present at all means this piece is here for how it sounds, not for
        -- what it means. docs/004 demotes it out of being a subject.
        phonetic = attributes["kvg:phon"] ~= nil,
        radical = attributes["kvg:radical"],
        -- a combining form: the shape written here is a squeezed version of
        -- some other character, and that other character is where its meaning
        -- is. the lexicon in 023 follows this rather than needing an entry.
        variant = attributes["kvg:variant"] ~= nil,
        original = attributes["kvg:original"],
        part = attributes["kvg:part"],
        depth = #stack + 1,
        stroke_first = #current.strokes + 1,
      }
      if self_closing then
        -- an empty group encloses nothing; pop it straight back off
        stack[#stack] = nil
      end

    elseif name == "path" and current then
      local attributes = xml.attributes(attribute_text)
      if not attributes.d then
        error("a stroke of " .. current.character .. " has no path")
      end
      -- the innermost enclosing group that names a character is the piece this
      -- stroke belongs to. walking outward stops at the first one, because a
      -- stroke inside 木 inside 休 belongs to the tree, not to the resting.
      local owner = nil
      for index = #stack, 1, -1 do
        if stack[index].element then owner = index break end
      end
      current.strokes[#current.strokes + 1] = {
        d = attributes.d,
        class = attributes["kvg:type"],
        group = owner,
      }
    end
  end
  -- }}}

  -- {{{ handlers.close(name)
  function handlers.close(name)
    if name == "g" and current and stack and #stack > 0 then
      local frame = stack[#stack]
      stack[#stack] = nil
      finish_group(frame)

    elseif name == "kanji" then
      if current and keeping and #current.strokes > 0 then
        -- Components were appended as their groups *closed*, so the array is
        -- in innermost-first, last-finished-first order -- which is neither of
        -- the two orders anybody wants.
        --
        -- Sorted rather than reversed. Reversing gets the depth right and gets
        -- pieces at the same depth backwards: the left half of a character
        -- closes before the right half, so reversing lists the right half
        -- first. Sorting by depth and then by first stroke gives outermost
        -- first and, within a level, the order the character is written and
        -- read in.
        table.sort(current.components, function(a, b)
          if a.depth ~= b.depth then return a.depth < b.depth end
          return a.stroke_first < b.stroke_first
        end)
        out[current.character] = current
        count = count + 1
      end
      current = nil
      stack = nil
      keeping = true
    end
  end
  -- }}}

  xml.scan(text, handlers)

  if count == 0 then
    error("the stroke archive at " .. path .. " yielded no characters at all;" ..
          "\n  it is the wrong file, or its format has changed")
  end
  return out, count
end
-- }}}

-- {{{ M.component_owner(entry, stroke_index)
-- Which component a given stroke belongs to, as a component table.
--
-- The stroke records the position of its group on the stack at the time it was
-- read, which is not the position of that component in the finished array --
-- the array was reversed. This does the lookup by stroke range instead, taking
-- the innermost match, which does not depend on either ordering surviving.
function M.component_owner(entry, stroke_index)
  local best = nil
  for _, component in ipairs(entry.components) do
    if stroke_index >= component.stroke_first
       and stroke_index <= component.stroke_last then
      if not best or component.depth > best.depth then best = component end
    end
  end
  return best
end
-- }}}

return M
