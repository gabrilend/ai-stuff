-- 012-fit-check.lua - the check every edited canvas passes, reporting like a
-- compiler.
--
-- In plain terms: a language model is asked to write the whole canvas again
-- with its edit in it. Before that reply goes anywhere, this measures it: the
-- right number of rows, none too wide. A reply that does not fit goes back to
-- the model with a report written like a compiler's errors, and the model
-- tries again (docs/fit-check.md). It also counts how much the reply changed,
-- for a note of advice. The note never refuses anything: the owner made the
-- change budget soft.
--
--   local fit = dofile(DIR .. "/src/012-fit-check.lua")
--   local result = fit.check(reply_text, base_record, { words = 12, sentences = 1 })
--   if result.fits then use(result.rows) else send(fit.report(result.problems,
--       base_record.width, base_record.height)) end
--   result.counts.words_changed, result.counts.sentences_rewritten, result.note
--
--   fit.arrival(voice_record, base_record)   -- the blitter's size-only check
--
-- It never trims or mends a reply; it only measures and reports. The change
-- counts come from the change finder (104), so the fit check and the blit
-- cannot disagree about what changed. Width is counted in UTF-8 code points
-- (005); whether to count terminal columns is open question 4.
-- LuaJIT-compatible.

-- {{{ local DIR
-- Sibling files are found next to this one (as in 006).
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local utf8 = dofile(DIR .. "/src/005-utf8.lua")
local changes = dofile(DIR .. "/src/010-changes.lua")

local M = {}

-- {{{ M.LINES
-- What each kind of problem says, as a table from kind to a function of the
-- problem. These are the lines the model reads; the first two are word for
-- word from docs/fit-check.md.
M.LINES = {
    ["wrong-height"] = function(p)
        return string.format("the canvas has %d rows; it must have exactly %d",
            p.measured, p.allowed)
    end,
    ["too-wide"] = function(p)
        return string.format("row %d: %d characters, %d over the width of %d",
            p.row, p.measured, p.measured - p.allowed, p.allowed)
    end,
    ["bad-character"] = function(p)
        if p.column then
            return string.format("row %d: a tab or other control character at column %d; "
                .. "use spaces", p.row, p.column)
        end
        return string.format("row %d: not valid UTF-8 text at byte %d", p.row, p.byte)
    end,
    -- A reply that copied the ruler the turn prompt draws around the canvas
    -- (issue 403; found by src/049-turn-prompt.lua's ruler_problem).
    ["ruler"] = function(p)
        return string.format("%s %s: the ruler was copied (the row numbers, the | at "
            .. "each end, or the column numbers); write only the canvas's own rows",
            #p.rows == 1 and "row" or "rows", table.concat(p.rows, ", "))
    end,
    ["wrong-width"] = function(p)
        return string.format("the canvas is %d characters wide; it must be exactly %d",
            p.measured, p.allowed)
    end,
}
-- }}}

-- {{{ local function whole()
local function whole(value)
    return type(value) == "number" and value >= 0 and value == math.floor(value)
end
-- }}}

-- {{{ function M.lines_of()
-- A reply's text as its rows. A line ends at "\n", or "\r\n" (some servers
-- send those); a final line ending does not start another row. The rows are
-- otherwise exactly as the model wrote them.
function M.lines_of(text)
    local rows = {}
    if text == "" then
        return rows
    end
    for line in string.gmatch(text, "([^\n]*)\n") do
        rows[#rows + 1] = (string.gsub(line, "\r$", ""))
    end
    local tail = string.match(text, "([^\n]+)$")
    if tail then
        rows[#rows + 1] = (string.gsub(tail, "\r$", ""))
    end
    return rows
end
-- }}}

-- {{{ local function row_problems()
-- What is wrong with one row of a canvas `width` wide: a character that has
-- no width (a control character, or bytes that are not UTF-8), or too many
-- characters. A row with a character problem is not measured for width.
local function row_problems(row, number, width)
    local characters, bad_byte = utf8.split(row)
    if not characters then
        return { { kind = "bad-character", row = number, byte = bad_byte } }
    end
    for column, character in ipairs(characters) do
        if string.find(character, "^[%z\1-\31\127]$") then
            return { { kind = "bad-character", row = number, column = column } }
        end
    end
    if #characters > width then
        return { { kind = "too-wide", row = number, measured = #characters, allowed = width } }
    end
    return {}
end
-- }}}

-- {{{ function M.advice()
-- The advisory note for a voice's next canvas, or nil when it changed no
-- more than recommended (docs/fit-check.md, "The change budget is soft").
function M.advice(counts, recommended)
    if counts.words_changed <= recommended.words
        and counts.sentences_rewritten <= recommended.sentences then
        return nil
    end
    local function many(count, one, more)
        return count .. " " .. (count == 1 and one or more)
    end
    return string.format("last turn you changed %s (%d recommended) and rewrote %s "
        .. "(%d recommended). smaller changes to the operative words keep more of "
        .. "what is already here.",
        many(counts.words_changed, "word", "words"), recommended.words,
        many(counts.sentences_rewritten, "whole sentence", "whole sentences"),
        recommended.sentences)
end
-- }}}

-- {{{ function M.check()
-- A model's reply (the canvas's rows as text), the base canvas the turn
-- started from (a record from 006), and the recommended change counts
-- ({ words, sentences }, whole numbers) in. Out:
--   fits       true when nothing is wrong with the size
--   rows       (when it fits) the reply's rows, padded to the width
--   problems   (when it does not) a list of { kind, row, measured, allowed },
--              the height first, then by row
--   counts     { words_changed, sentences_rewritten } against the base, when
--              the reply has the right number of rows of readable text; nil
--              when it cannot be compared
--   note       the advisory note when the counts are over the recommendation
function M.check(reply, base, recommended)
    if type(reply) ~= "string" then
        error("fit.check: the reply is not text", 2)
    end
    if type(base) ~= "table" or not base.rows or not base.width or not base.height then
        error("fit.check: the base is not a canvas record", 2)
    end
    if type(recommended) ~= "table" or not whole(recommended.words)
        or not whole(recommended.sentences) then
        error("fit.check: the recommended counts must be whole numbers, "
            .. "{ words = N, sentences = N }", 2)
    end

    local rows = M.lines_of(reply)
    local problems, unreadable = {}, false
    if #rows ~= base.height then
        problems[#problems + 1] = { kind = "wrong-height", measured = #rows,
                                    allowed = base.height }
    end
    for number, row in ipairs(rows) do
        for _, problem in ipairs(row_problems(row, number, base.width)) do
            problems[#problems + 1] = problem
            if problem.kind == "bad-character" then unreadable = true end
        end
    end

    local result = { fits = #problems == 0 }
    if #rows == base.height and not unreadable then
        local found = changes.find(base.rows, rows)
        result.counts = { words_changed = found.words_changed,
                          sentences_rewritten = found.sentences_rewritten }
        result.note = M.advice(result.counts, recommended)
    end
    if result.fits then
        result.rows = {}
        for number, row in ipairs(rows) do
            result.rows[number] = utf8.pad(row, base.width)
        end
    else
        result.problems = problems
    end
    return result
end
-- }}}

-- {{{ function M.report()
-- The problems as the text the model is given: one line per problem, then the
-- closing line restating every limit, word for word as docs/fit-check.md has
-- it (the document wraps the closing line; it is one line here).
function M.report(problems, width, height)
    local lines = { "the canvas does not fit:" }
    for _, problem in ipairs(problems) do
        local line = M.LINES[problem.kind]
        if not line then
            error("fit.report: no report line for a problem of kind '"
                .. tostring(problem.kind) .. "'", 2)
        end
        lines[#lines + 1] = "  " .. line(problem)
    end
    lines[#lines + 1] = string.format("write the whole canvas again: exactly %d rows, each "
        .. "at most %d characters. keep everything you did not mean to change exactly "
        .. "as it was.", height, width)
    return table.concat(lines, "\n") .. "\n"
end
-- }}}

-- {{{ function M.arrival()
-- The blitter's check on a voice's canvas as it arrives: its size only, which
-- must equal its base's, since a canvas of another size cannot be compared
-- with its base at all. The canvas reader (102) has already held each row to
-- the size the voice declared. Returns a list of problems, empty when it fits.
function M.arrival(voice, base)
    local problems = {}
    if voice.height ~= base.height then
        problems[#problems + 1] = { kind = "wrong-height", measured = voice.height,
                                    allowed = base.height }
    end
    if voice.width ~= base.width then
        problems[#problems + 1] = { kind = "wrong-width", measured = voice.width,
                                    allowed = base.width }
    end
    return problems
end
-- }}}

return M
