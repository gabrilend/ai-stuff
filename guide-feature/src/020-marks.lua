-- 020-marks.lua - marks for skimming: which words and sentences changed, and
-- by whom.
--
-- In plain terms: the owner wants a person to skim the canvas and see what
-- the voices changed. After each blit (106), this marks every cell the blit
-- wrote or blanked as a changed `word`, and the rest of every sentence (103)
-- holding such a cell as a changed `sentence`, each with the voice and the
-- new version. A cell keeps only its newest mark, and a mark is dropped once
-- it is older than the mark lifetime, so the marks fade as the canvas moves
-- on (docs/canvas-format.md, "Marks"; docs/datapath-blit.md, step 4).
--
--   local marks = dofile(DIR .. "/src/020-marks.lua")
--   local result = marks.mark(current, new, report, "fg-sora-2", 7, 12)
--   new.marks = result.marks          -- mark runs, as the canvas text has them
--   result.counts.word, .sentence, .orphan, .expired     -- cells, not runs
--   result.expired_orphans            -- cells whose orphan mark ran out
--
--   marks.grid(record)                -- a record's mark runs as a cell grid
--   marks.runs(grid, width, height)   -- and back
--   marks.age(mark, version)          -- version minus the mark's version
--
-- Marks are kept per cell while marking and written as runs: a run is the
-- longest stretch of cells on one row with the same voice, version and kind.
-- LuaJIT-compatible.

-- {{{ local DIR
-- Sibling files are found next to this one (as in 006).
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local words = dofile(DIR .. "/src/008-words.lua")

local M = {}

-- {{{ function M.age()
-- How many versions old a mark is at `version`: a whole number, 0 for a mark
-- made at that version.
function M.age(mark, version)
    return version - mark.version
end
-- }}}

-- {{{ function M.grid()
-- A record's mark runs as a grid: grid[row][column] is { voice, version,
-- kind } or nil. A later run over the same cell wins, as in the text.
function M.grid(record)
    local grid = {}
    for row = 1, record.height do grid[row] = {} end
    for _, run in ipairs(record.marks or {}) do
        for column = run.column, run.column + run.length - 1 do
            grid[run.row][column] = { voice = run.voice, version = run.version, kind = run.kind }
        end
    end
    return grid
end
-- }}}

-- {{{ function M.runs()
-- A grid back into runs, row by row, left to right.
function M.runs(grid, width, height)
    local runs = {}
    for row = 1, height do
        local line = grid[row]
        local column = 1
        while column <= width do
            local mark = line[column]
            if mark then
                local last = column
                while last < width and line[last + 1]
                    and line[last + 1].voice == mark.voice
                    and line[last + 1].version == mark.version
                    and line[last + 1].kind == mark.kind do
                    last = last + 1
                end
                runs[#runs + 1] = { row = row, column = column, length = last - column + 1,
                                    voice = mark.voice, version = mark.version, kind = mark.kind }
                column = last + 1
            else
                column = column + 1
            end
        end
    end
    return runs
end
-- }}}

-- {{{ local function sentence_at()
-- The sentence a changed cell belongs to on the new canvas. A cell inside a
-- word belongs to that word's sentence. A blanked cell between words belongs
-- to the sentence of the word before it on its row, if that word does not
-- end its sentence; otherwise to the sentence of the word after it on its
-- row. (So a gap inside a sentence belongs to it, and a gap after a full stop
-- to the sentence that follows.) A cell with neither (its row is now empty)
-- belongs to none: it keeps its word mark alone.
local function sentence_at(found, row, column)
    local number = found.owner[row][column]
    if number then return found.sentence_of[number] end
    local before, after
    for index, word in ipairs(found.words) do
        if word.row < row or (word.row == row and word.column < column) then
            before = index
        elseif not after then
            after = index
        end
    end
    local word = before and found.words[before]
    if word and word.row == row and not words.ends_sentence(word.text) then
        return found.sentence_of[before]
    end
    word = after and found.words[after]
    if word and word.row == row then return found.sentence_of[after] end
    return nil
end
-- }}}

-- {{{ function M.mark()
-- The marks for a new version. In: the canvas the blit started from (its
-- marks are the old ones), the new canvas, the blit's report (106: its
-- `written` and `blanked` cells, and `orphans` if a collision rule leaves
-- fragments to fade), the voice, the new version's number, and the mark
-- lifetime in versions. Out: { marks = runs, counts = { word, sentence,
-- orphan, expired }, expired_orphans = { { row, column }, ... } }.
--
-- In order: the new word marks, the new sentence marks on the rest of each
-- sentence holding one, orphan marks, then every older mark left whose age
-- is over the lifetime is dropped. A cell keeps only its newest mark.
function M.mark(current, new, report, voice, version, lifetime)
    if type(lifetime) ~= "number" or lifetime < 0 or lifetime ~= math.floor(lifetime) then
        error("marks.mark: the mark lifetime must be a whole number of versions", 2)
    end
    local width, height = new.width, new.height
    local grid = M.grid(current)
    local counts = { word = 0, sentence = 0, orphan = 0, expired = 0 }
    local fresh = {}
    for row = 1, height do fresh[row] = {} end

    -- {{{ word marks: every cell written or blanked
    local changed = {}
    local function word_mark(cell)
        if not fresh[cell.row][cell.column] then
            fresh[cell.row][cell.column] = true
            counts.word = counts.word + 1
            changed[#changed + 1] = cell
        end
        grid[cell.row][cell.column] = { voice = voice, version = version, kind = "word" }
    end
    for _, cell in ipairs(report.written or {}) do word_mark(cell) end
    for _, cell in ipairs(report.blanked or {}) do word_mark(cell) end
    -- }}}

    -- {{{ sentence marks: the rest of each sentence holding a word mark
    local found = words.of_canvas(new)
    local touched = {}
    for _, cell in ipairs(changed) do
        local sentence = sentence_at(found, cell.row, cell.column)
        if sentence then touched[sentence] = true end
    end
    for sentence in pairs(touched) do
        for _, number in ipairs(found.sentences[sentence]) do
            local word = found.words[number]
            for column = word.column, word.column + word.length - 1 do
                if not fresh[word.row][column] then
                    fresh[word.row][column] = true
                    counts.sentence = counts.sentence + 1
                    grid[word.row][column] = { voice = voice, version = version,
                                               kind = "sentence" }
                end
            end
        end
    end
    -- }}}

    -- {{{ orphan marks: fragments a collision rule left to fade
    for _, cell in ipairs(report.orphans or {}) do
        if not fresh[cell.row][cell.column] then counts.orphan = counts.orphan + 1 end
        fresh[cell.row][cell.column] = true
        grid[cell.row][cell.column] = { voice = voice, version = version, kind = "orphan" }
    end
    -- }}}

    -- {{{ older marks over the lifetime are dropped
    local expired_orphans = {}
    for row = 1, height do
        for column = 1, width do
            local mark = grid[row][column]
            if mark and not fresh[row][column] and M.age(mark, version) > lifetime then
                grid[row][column] = nil
                counts.expired = counts.expired + 1
                if mark.kind == "orphan" then
                    expired_orphans[#expired_orphans + 1] = { row = row, column = column }
                end
            end
        end
    end
    -- }}}

    return { marks = M.runs(grid, width, height), counts = counts,
             expired_orphans = expired_orphans }
end
-- }}}

return M
