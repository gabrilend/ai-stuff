-- 010-changes.lua - what a voice changed, measured against its base.
--
-- In plain terms: a voice starts its turn from one version of the canvas (its
-- base) and sends back an edited copy. This compares the two, word by word,
-- and says which words the voice kept, which it wrote, and which it erased.
-- Only those words are applied to the shared canvas (106), so an edit another
-- voice made in the meantime is never undone. The owner's choice: changes are
-- measured against the base, never against the shared canvas as it is now,
-- which this file never sees.
--
--   local changes = dofile(DIR .. "/src/010-changes.lua")
--   local found = changes.find(base, voice)   -- canvas records or lists of rows
--   found.kept, found.written, found.removed, found.overwritten
--   found.words_changed            -- written plus removed
--   found.sentences_rewritten      -- base sentences with no word kept
--
-- Every word in the lists is a word record from 008 (row, column, length,
-- text) with `number`, its place in its own canvas's word list. A kept entry
-- has `base` and `voice`, the two numbers. The fit check (105) takes its
-- counts from here, so it and the blit cannot disagree about what changed.
-- LuaJIT-compatible.

-- {{{ local DIR
-- Sibling files are found next to this one (as in 006).
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local utf8 = dofile(DIR .. "/src/005-utf8.lua")
local words = dofile(DIR .. "/src/008-words.lua")

local M = {}

-- {{{ local function rows_of()
-- A canvas record's rows, or the list of rows itself.
local function rows_of(canvas, which)
    if type(canvas) ~= "table" then
        error("changes.find: the " .. which .. " canvas is not a canvas or a list of rows", 3)
    end
    return canvas.rows or canvas
end
-- }}}

-- {{{ local function with_number()
-- A copy of a word with its place in its canvas's list.
local function with_number(word, number)
    return { row = word.row, column = word.column, length = word.length,
             text = word.text, number = number }
end
-- }}}

-- {{{ local function all_spaces()
-- Whether a word's cells hold only spaces in a canvas's characters. A cell
-- past the end of a row is a space (rows may be written without trailing
-- spaces).
local function all_spaces(characters, word)
    local row = characters[word.row]
    for column = word.column, word.column + word.length - 1 do
        local character = row[column]
        if character ~= nil and character ~= " " then
            return false
        end
    end
    return true
end
-- }}}

-- {{{ function M.find()
-- The base and the voice's canvas in (canvas records, or lists of rows, with
-- the same number of rows), what the voice changed out:
--   kept         the same text at the same row and column in both
--   written      in the voice's canvas but not identically in the base: new,
--                different or moved
--   removed      in the base, not identically in the voice's canvas, and its
--                cells there all spaces: the voice erased it
--   overwritten  in the base, not kept, and not all spaces in the voice's
--                canvas: a written word covers some of it. Not a change of its
--                own; what happens to it on the shared canvas is the blit's
--                collision rule (106)
-- and the counts words_changed (written plus removed) and
-- sentences_rewritten (sentences of the base in which no word was kept).
function M.find(base, voice)
    local base_rows, voice_rows = rows_of(base, "base"), rows_of(voice, "voice")
    if #base_rows ~= #voice_rows then
        error("changes.find: the base has " .. #base_rows .. " rows and the voice's canvas "
            .. #voice_rows .. "; they cannot be compared", 2)
    end
    local height = #base_rows

    local base_words, voice_words = words.find(base_rows), words.find(voice_rows)

    -- {{{ the base's words by place
    local at_place = {}
    for number, word in ipairs(base_words) do
        at_place[word.row .. ":" .. word.column] = number
    end
    -- }}}

    -- {{{ walk the voice's words
    local found = { kept = {}, written = {}, removed = {}, overwritten = {} }
    local kept_base = {}
    for number, word in ipairs(voice_words) do
        local base_number = at_place[word.row .. ":" .. word.column]
        if base_number and base_words[base_number].text == word.text then
            kept_base[base_number] = true
            local entry = with_number(word, number)
            entry.base, entry.voice = base_number, number
            found.kept[#found.kept + 1] = entry
        else
            found.written[#found.written + 1] = with_number(word, number)
        end
    end
    -- }}}

    -- {{{ the base's words the voice did not keep
    local voice_characters = {}
    for row = 1, height do
        voice_characters[row] = utf8.split(voice_rows[row])
    end
    for number, word in ipairs(base_words) do
        if not kept_base[number] then
            local list = all_spaces(voice_characters, word) and found.removed or found.overwritten
            list[#list + 1] = with_number(word, number)
        end
    end
    -- }}}

    -- {{{ the counts
    found.words_changed = #found.written + #found.removed
    local sentences = words.sentences(base_words, height)
    local rewritten = 0
    for _, sentence in ipairs(sentences) do
        local any_kept = false
        for _, number in ipairs(sentence) do
            if kept_base[number] then any_kept = true break end
        end
        if not any_kept then rewritten = rewritten + 1 end
    end
    found.sentences_rewritten = rewritten
    -- }}}
    return found
end
-- }}}

return M
