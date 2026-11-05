-- 008-words.lua - the words on a canvas, which cell each covers, and the
-- sentences they make.
--
-- In plain terms: the canvas is a grid of characters, but the voices change
-- it a word at a time. This finds the words: every run of characters with no
-- space in it, with the row and column where it starts. It also says which
-- word covers each cell (so the blit, 106, can see what a write cuts into),
-- and how the words group into sentences (so marks, 201, can show "this
-- sentence changed").
--
--   local words = dofile(DIR .. "/src/008-words.lua")
--   local list = words.find(record.rows)
--   list[1].row, list[1].column, list[1].length, list[1].text
--   local owner = words.owners(list, record.width, record.height)
--   owner[3][12]                -- the number of the word on that cell, or nil
--   local sentences, sentence_of = words.sentences(list, record.height)
--   sentences[2]                -- { 4, 5, 6 }: word numbers, in reading order
--   sentence_of[5]              -- 2
--   local all = words.of_canvas(record)   -- all three at once
--
-- A word never wraps across rows: one that reaches the end of a row ends
-- there. Only the space character separates words; the canvas reader (102)
-- has already refused tabs and other control characters. Columns and lengths
-- are in characters, counted by 005. LuaJIT-compatible.

-- {{{ local DIR
-- Sibling files are found next to this one (as in 006).
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local utf8 = dofile(DIR .. "/src/005-utf8.lua")

local M = {}

-- {{{ M.SENTENCE_ENDS, M.CLOSERS
-- A word ends its sentence when its last character is one of SENTENCE_ENDS,
-- looking past any closing quotes and brackets: `done.` and `"done."` and
-- `(done!)` all end one. A full stop anywhere else in a word (`3.5`, `e.g`)
-- does not.
M.SENTENCE_ENDS = { ["."] = true, ["!"] = true, ["?"] = true }
M.CLOSERS = { ['"'] = true, ["'"] = true, [")"] = true, ["]"] = true,
              ["”"] = true, ["’"] = true, ["»"] = true }
-- }}}

-- {{{ function M.find()
-- Rows in (strings, padded or not), words out in reading order: left to
-- right along each row, rows from the top. Refuses a row that is not UTF-8.
function M.find(rows)
    local list = {}
    for row_number, row in ipairs(rows) do
        local characters, bad_at = utf8.split(row)
        if not characters then
            error("words.find: row " .. row_number .. " is not valid UTF-8 (at byte "
                .. bad_at .. ")", 2)
        end
        local start, parts = nil, nil
        for column = 1, #characters + 1 do
            local character = characters[column]
            if character ~= nil and character ~= " " then
                if not start then
                    start, parts = column, {}
                end
                parts[#parts + 1] = character
            elseif start then
                list[#list + 1] = { row = row_number, column = start,
                                    length = #parts, text = table.concat(parts) }
                start = nil
            end
        end
    end
    return list
end
-- }}}

-- {{{ function M.owners()
-- A grid, owner[row][column], holding the number of the word covering that
-- cell, or nil for a space. Every row has a table even when it is empty.
-- Refuses a word that does not fit the size, since then the grid would lie.
function M.owners(list, width, height)
    local owner = {}
    for row = 1, height do owner[row] = {} end
    for number, word in ipairs(list) do
        if word.row < 1 or word.row > height or word.column < 1
            or word.column + word.length - 1 > width then
            error("words.owners: word " .. number .. " ('" .. word.text .. "') at row "
                .. word.row .. ", column " .. word.column .. " is off a "
                .. width .. "x" .. height .. " canvas", 2)
        end
        for column = word.column, word.column + word.length - 1 do
            owner[word.row][column] = number
        end
    end
    return owner
end
-- }}}

-- {{{ function M.ends_sentence()
-- Whether a word's text ends its sentence (see SENTENCE_ENDS).
function M.ends_sentence(text)
    local characters = utf8.split(text) or {}
    local at = #characters
    while at > 0 and M.CLOSERS[characters[at]] do
        at = at - 1
    end
    return at > 0 and M.SENTENCE_ENDS[characters[at]] == true
end
-- }}}

-- {{{ function M.sentences()
-- The words, which must be in reading order (as find gives them), grouped
-- into sentences. A sentence ends after a word that ends one, and at an
-- entirely empty row; a canvas's last words are a sentence even with no full
-- stop. Returns the sentences (lists of word numbers) and, for each word
-- number, its sentence's number.
function M.sentences(list, height)
    local by_row = {}
    for row = 1, height do by_row[row] = {} end
    for number, word in ipairs(list) do
        local on_row = by_row[word.row]
        if not on_row then
            error("words.sentences: word " .. number .. " is on row " .. word.row
                .. ", past the height of " .. height, 2)
        end
        on_row[#on_row + 1] = number
    end

    local sentences, sentence_of, current = {}, {}, {}
    local function close()
        if #current > 0 then
            sentences[#sentences + 1] = current
            for _, number in ipairs(current) do sentence_of[number] = #sentences end
            current = {}
        end
    end
    for row = 1, height do
        if #by_row[row] == 0 then
            close()
        end
        for _, number in ipairs(by_row[row]) do
            current[#current + 1] = number
            if M.ends_sentence(list[number].text) then
                close()
            end
        end
    end
    close()
    return sentences, sentence_of
end
-- }}}

-- {{{ function M.of_canvas()
-- A canvas record (006) in; its words, owner grid and sentences out.
function M.of_canvas(record)
    local list = M.find(record.rows)
    local sentences, sentence_of = M.sentences(list, record.height)
    return { words = list, owner = M.owners(list, record.width, record.height),
             sentences = sentences, sentence_of = sentence_of }
end
-- }}}

return M
