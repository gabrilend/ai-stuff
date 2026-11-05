-- 014-blit.lua - writing a voice's changes onto the shared canvas.
--
-- In plain terms: a voice edited its copy of the canvas, and the change
-- finder (104) worked out which words it erased and which it wrote. This puts
-- those changes onto the shared canvas as it is now, which other voices may
-- have changed since. An erased word is blanked only if it is still there. A
-- written word goes into its cells, and any word it cuts into is handed to the
-- collision rule, which decides what happens to the letters that are left
-- (docs/datapath-blit.md, steps 2 and 3).
--
--   local blit = dofile(DIR .. "/src/014-blit.lua")
--   local found = changes.find(base, voice)
--   local new, report = blit.apply(current, found, "blank-whole")
--   report.changed, report.counts.words_written, report.cut[1].outcome
--
-- The current canvas is not changed; a new record comes back, with the same
-- headers and marks. The blit does not mark: marks (201) and the cut lines
-- told to a voice (303) are made from the report.
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

-- {{{ local function blank_cells()
-- Blanks a word's cells that are not in `spared` (a set of columns), noting
-- each in the report as blanked, with the word it belonged to and why.
local function blank_cells(grid, word, spared, why, report)
    for column = word.column, word.column + word.length - 1 do
        if not spared[column] then
            local row = grid[word.row]
            if row[column] ~= " " then
                row[column] = " "
                report.blanked[#report.blanked + 1] = { row = word.row, column = column,
                    word = word.text, why = why }
            end
        end
    end
end
-- }}}

-- {{{ M.RULES
-- The collision rules: a table from rule name to a function that takes the
-- canvas (a grid of characters, grid[row][column]), the cut word (a word
-- record with `lost`, how many of its letters the write took, and `cells`,
-- the set of its columns the write covered), the write (the written word),
-- and the report, changes the canvas, and returns what it did to the cut word.
--
-- Built here: blank-whole (the owner's rule and the default) and
-- keep-fragments (the plain overwrite the others are measured against).
-- fade-fragments, push-aside, refuse-cut and blank-sentence are added as
-- their own issues once picked (docs/datapath-blit.md, "Collision rules").
M.RULES = {
    -- {{{ blank-whole
    -- "if any letter in a word is overwritten and can't fit, then that word is
    -- deleted entirely": every letter the write left is blanked.
    ["blank-whole"] = function(grid, cut, write, report)
        blank_cells(grid, cut, cut.cells, "cut", report)
        return "blanked"
    end,
    -- }}}

    -- {{{ keep-fragments
    -- The letters the write left stay where they are, as a terminal would
    -- leave them.
    ["keep-fragments"] = function()
        return "kept"
    end,
    -- }}}
}
M.DEFAULT_RULE = "blank-whole"
-- }}}

-- {{{ local function grid_of()
-- A canvas record's rows as a grid of characters, each row padded to the
-- width.
local function grid_of(record)
    local grid = {}
    for number, row in ipairs(record.rows) do
        local characters = utf8.split(row)
        if not characters then
            error("blit: row " .. number .. " of the current canvas is not valid UTF-8", 3)
        end
        for column = #characters + 1, record.width do characters[column] = " " end
        grid[number] = characters
    end
    return grid
end
-- }}}

-- {{{ local function rows_of()
local function rows_of(grid)
    local rows = {}
    for number, characters in ipairs(grid) do rows[number] = table.concat(characters) end
    return rows
end
-- }}}

-- {{{ local function holds_word()
-- Whether the canvas's words (found at the start of the blit) include exactly
-- this word at this place.
local function holds_word(at_place, word)
    local there = at_place[word.row .. ":" .. word.column]
    return there ~= nil and there.text == word.text
end
-- }}}

-- {{{ local function write_word()
-- Writes one word into the grid, then hands each word it cut to the rule.
-- A word the write hits is found on the canvas as it is just before this
-- write: covered if it lost every letter, cut if it lost some. A word directly
-- touching the written word, with no space between, has lost no letters but
-- would be glued to it as one word; it is cut too, with `lost` 0, so the rule
-- decides (blank-whole leaves no glued fragment).
local function write_word(grid, write, rule_name, report, width, height)
    if write.row < 1 or write.row > height or write.column < 1
        or write.column + write.length - 1 > width then
        error("blit: the written word '" .. write.text .. "' at row " .. write.row
            .. ", column " .. write.column .. " is off the canvas", 3)
    end
    local before = words.find(rows_of(grid))
    local owner = words.owners(before, width, height)

    -- {{{ which words the write reaches, and how many letters each loses
    local reached, order = {}, {}
    local function reach(column, takes)
        local number = owner[write.row][column]
        if number then
            if not reached[number] then
                reached[number] = { lost = 0, cells = {} }
                order[#order + 1] = number
            end
            if takes then
                reached[number].lost = reached[number].lost + 1
                reached[number].cells[column] = true
            end
        end
    end
    for column = write.column, write.column + write.length - 1 do reach(column, true) end
    if write.column > 1 then reach(write.column - 1, false) end
    if write.column + write.length <= width then reach(write.column + write.length, false) end
    table.sort(order)
    -- }}}

    -- {{{ the write itself
    local characters = utf8.split(write.text)
    for offset, character in ipairs(characters) do
        local column = write.column + offset - 1
        grid[write.row][column] = character
        report.written[#report.written + 1] = { row = write.row, column = column,
            word = write.text }
    end
    -- }}}

    -- {{{ what became of each word it reached
    for _, number in ipairs(order) do
        local word, hit = before[number], reached[number]
        if hit.lost == word.length then
            report.covered[#report.covered + 1] = { row = word.row, column = word.column,
                text = word.text, by = write.text }
        else
            local cut = { row = word.row, column = word.column, length = word.length,
                          text = word.text, lost = hit.lost, cells = hit.cells }
            local outcome = M.RULES[rule_name](grid, cut, write, report)
            report.cut[#report.cut + 1] = { row = word.row, column = word.column,
                text = word.text, lost = hit.lost, by = write.text, outcome = outcome }
            report.counts["cut-" .. outcome] = (report.counts["cut-" .. outcome] or 0) + 1
        end
    end
    -- }}}
end
-- }}}

-- {{{ function M.apply()
-- The current canvas (a record from 006), a voice's changes (from 104's
-- find: its `removed` and `written` lists) and the collision rule's name in.
-- Out: the new canvas record, and the report:
--   changed      whether any cell is different from the current canvas
--   written      every cell written: { row, column, word }
--   blanked      every cell blanked: { row, column, word, why = removed|cut }
--   covered      every word that lost all its letters: { row, column, text, by }
--   cut          every cut word: { row, column, text, lost, by, outcome }
--   conflicts    every removal not applied: { row, column, text }
--   counts       words-written, removals-applied, conflicts, words-covered,
--                and cut-<outcome> for each outcome (cut-blanked, cut-kept)
function M.apply(current, found, rule_name)
    rule_name = rule_name or M.DEFAULT_RULE
    if not M.RULES[rule_name] then
        local known = {}
        for name in pairs(M.RULES) do known[#known + 1] = name end
        table.sort(known)
        error("blit: no collision rule called '" .. tostring(rule_name) .. "' (built: "
            .. table.concat(known, ", ") .. ")", 2)
    end
    local width, height = current.width, current.height
    local grid = grid_of(current)
    local report = { written = {}, blanked = {}, covered = {}, cut = {}, conflicts = {},
                     counts = {} }

    -- {{{ step 2: removals, against the canvas as the blit found it
    local at_place = {}
    for _, word in ipairs(words.find(current.rows)) do
        at_place[word.row .. ":" .. word.column] = word
    end
    local removals = 0
    for _, word in ipairs(found.removed or {}) do
        if holds_word(at_place, word) then
            blank_cells(grid, word, {}, "removed", report)
            removals = removals + 1
        else
            report.conflicts[#report.conflicts + 1] = { row = word.row, column = word.column,
                text = word.text }
        end
    end
    -- }}}

    -- {{{ step 3: writes, in reading order
    local writes = {}
    for _, word in ipairs(found.written or {}) do writes[#writes + 1] = word end
    table.sort(writes, function(a, b)
        if a.row ~= b.row then return a.row < b.row end
        return a.column < b.column
    end)
    for _, write in ipairs(writes) do
        write_word(grid, write, rule_name, report, width, height)
    end
    -- }}}

    local rows = rows_of(grid)
    local changed = false
    for number, row in ipairs(rows) do
        if row ~= utf8.pad(current.rows[number], width) then changed = true end
    end
    report.changed = changed
    report.counts["words-written"] = #writes
    report.counts["removals-applied"] = removals
    report.counts["conflicts"] = #report.conflicts
    report.counts["words-covered"] = #report.covered
    report.rule = rule_name

    local new = { set = current.set, headers = current.headers, width = width,
                  height = height, rows = rows, marks = current.marks, cuts = current.cuts }
    return new, report
end
-- }}}

return M
