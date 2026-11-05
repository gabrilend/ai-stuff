#!/usr/bin/env luajit
-- 013-test-fit-check.lua
--
-- Checks replies against a base canvas: one that fits, one for each kind of
-- problem, several at once. The report and the advisory note are checked
-- word for word against docs/fit-check.md, since they are what the model
-- reads. Then the blitter's size check on arrival.
--
-- For a general: a model that writes a canvas of the wrong shape is told
-- exactly what is wrong, in the same words every time, and tries again. A
-- model that changes too much is only advised. This proves the shape is
-- enforced, the advice is only advice, and the words match the document.
--
-- usage:
--   luajit 013-test-fit-check.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local fit = dofile(DIR .. "/src/012-fit-check.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, ok, detail)
    if ok then
        passed = passed + 1
        io.write("  ok    ", name, "\n")
    else
        failed = failed + 1
        io.write("  FAIL  ", name, detail and ("\n        " .. tostring(detail)) or "", "\n")
    end
end
-- }}}

-- {{{ local function words_of()
-- Text with every run of white space made one space, for comparing wording
-- regardless of where a document wrapped it.
local function words_of(text)
    return (string.gsub(string.gsub(text, "%s+", " "), "^ ?(.-) ?$", "%1"))
end
-- }}}

-- {{{ local function doc_block()
-- The first indented block after a heading in docs/fit-check.md (as in 007).
local DOC
do
    local handle = assert(io.open(DIR .. "/docs/fit-check.md", "r"))
    DOC = handle:read("*a")
    handle:close()
end
local function doc_block(after)
    local start = assert(string.find(DOC, after, 1, true), after .. " not in docs/fit-check.md")
    local lines, inside = {}, false
    for line in string.gmatch(string.sub(DOC, start) .. "\n", "([^\n]*)\n") do
        if string.sub(line, 1, 4) == "    " then
            inside = true
            lines[#lines + 1] = string.sub(line, 5)
        elseif inside then
            break
        end
    end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ local function kinds()
-- Problems as "kind@row" in order.
local function kinds(problems)
    local parts = {}
    for _, problem in ipairs(problems or {}) do
        parts[#parts + 1] = problem.kind .. (problem.row and ("@" .. problem.row) or "")
    end
    return table.concat(parts, " ")
end
-- }}}

-- {{{ the base: 20 rows of a 60-wide canvas, a little written on it
local BASE_ROWS = { "the cat sat on the mat.", "", "it was very happy." }
for index = 4, 20 do BASE_ROWS[index] = "" end
local BASE = canvas.blank(60, 20, "to-voices")
for index, row in ipairs(BASE_ROWS) do BASE.rows[index] = row .. string.rep(" ", 60 - #row) end
local RECOMMENDED = { words = 12, sentences = 1 }

local function reply(rows)
    return table.concat(rows, "\n") .. "\n"
end
local function edited(changes_by_row)
    local rows = {}
    for index = 1, 20 do rows[index] = changes_by_row[index] or BASE_ROWS[index] end
    return rows
end
-- }}}

io.write("\n=== a reply that fits ===\n")
-- {{{
local result = fit.check(reply(edited({ [3] = "it was not very happy." })), BASE, RECOMMENDED)
check("it fits", result.fits and result.problems == nil)
check("its rows come back padded to the width, never trimmed",
    #result.rows == 20 and #result.rows[3] == 60
    and string.sub(result.rows[3], 1, 22) == "it was not very happy.")
check("its change counts come from the change finder",
    result.counts.words_changed == 3 and result.counts.sentences_rewritten == 0)
check("within the recommendation there is no note", result.note == nil)
check("an unchanged reply changes nothing",
    fit.check(reply(BASE_ROWS), BASE, RECOMMENDED).counts.words_changed == 0)
check("a row exactly at the width fits",
    fit.check(reply(edited({ [5] = string.rep("é", 60) })), BASE, RECOMMENDED).fits)
check("lines ending in \\r\\n are rows like any other",
    fit.check(table.concat(edited({}), "\r\n") .. "\r\n", BASE, RECOMMENDED).fits)
check("a reply with no final newline still has its last row",
    fit.check(table.concat(edited({ [20] = "the end." }), "\n"), BASE, RECOMMENDED).fits)
-- }}}

io.write("\n=== one of each kind of problem ===\n")
-- {{{
local wide = fit.check(reply(edited({ [7] = string.rep("x", 64) })), BASE, RECOMMENDED)
check("a row too wide", not wide.fits and kinds(wide.problems) == "too-wide@7"
    and wide.problems[1].measured == 64 and wide.problems[1].allowed == 60)
check("a misfit has no rows to use", wide.rows == nil)
check("too wide is counted in characters, not bytes",
    fit.check(reply(edited({ [7] = string.rep("é", 61) })), BASE, RECOMMENDED)
        .problems[1].measured == 61)
check("a misfit of the right height still has its counts, for the log",
    wide.counts and wide.counts.words_changed == 1)

local rows22 = edited({})
rows22[21], rows22[22] = "", "extra"
local tall = fit.check(reply(rows22), BASE, RECOMMENDED)
check("too many rows", kinds(tall.problems) == "wrong-height"
    and tall.problems[1].measured == 22 and tall.problems[1].allowed == 20)
check("a misfit of the wrong height has no counts", tall.counts == nil and tall.note == nil)
local short = edited({})
short[20] = nil
check("too few rows", fit.check(reply(short), BASE, RECOMMENDED).problems[1].measured == 19)
check("an extra blank line at the end is a row: nothing is trimmed",
    fit.check(reply(edited({})) .. "\n", BASE, RECOMMENDED).problems[1].measured == 21)
check("an empty reply has no rows",
    fit.check("", BASE, RECOMMENDED).problems[1].measured == 0)

local tab = fit.check(reply(edited({ [4] = "a\tb" })), BASE, RECOMMENDED)
check("a tab", kinds(tab.problems) == "bad-character@4" and tab.problems[1].column == 2)
check("a reply with a character that has no width cannot be counted", tab.counts == nil)
local broken = fit.check(reply(edited({ [6] = "caf\233" })), BASE, RECOMMENDED)
check("bytes that are not UTF-8", kinds(broken.problems) == "bad-character@6"
    and broken.problems[1].byte == 4)
-- }}}

io.write("\n=== several at once ===\n")
-- {{{
local many = edited({ [2] = string.rep("y", 70), [9] = "a\tb", [12] = string.rep("z", 61) })
many[21] = "one too many"
local several = fit.check(reply(many), BASE, RECOMMENDED)
check("the height first, then each row in order",
    kinds(several.problems) == "wrong-height too-wide@2 bad-character@9 too-wide@12",
    kinds(several.problems))
local text = fit.report(several.problems, 60, 20)
check("the report has one line per problem, then the closing line",
    text == "the canvas does not fit:\n"
        .. "  the canvas has 21 rows; it must have exactly 20\n"
        .. "  row 2: 70 characters, 10 over the width of 60\n"
        .. "  row 9: a tab or other control character at column 2; use spaces\n"
        .. "  row 12: 61 characters, 1 over the width of 60\n"
        .. "write the whole canvas again: exactly 20 rows, each at most 60 characters. "
        .. "keep everything you did not mean to change exactly as it was.\n", text)
-- }}}

io.write("\n=== the words the model reads, as the document has them ===\n")
-- {{{
local doc_report = doc_block("## The report")
check("the report, word for word",
    words_of(fit.report(wide.problems, 60, 20)) == words_of(doc_report),
    fit.report(wide.problems, 60, 20) .. "\n        vs\n" .. doc_report)
check("the too-wide line exactly as the document's table has it",
    string.find(DOC, "`" .. fit.LINES["too-wide"](wide.problems[1]) .. "`", 1, true) ~= nil)
local tall22 = { kind = "wrong-height", measured = 22, allowed = 20 }
check("the wrong-height line exactly as the document's table has it",
    string.find(DOC, "`" .. fit.LINES["wrong-height"](tall22) .. "`", 1, true) ~= nil)

local doc_note = doc_block("as a plain note, not an\nerror:")
check("the advisory note, word for word",
    words_of(fit.advice({ words_changed = 31, sentences_rewritten = 3 },
        { words = 12, sentences = 1 })) == words_of(doc_note), doc_note)
-- }}}

io.write("\n=== the change budget is soft ===\n")
-- {{{
local rewrite = {}
for index = 1, 20 do rewrite[index] = "every single row is now completely different from before." end
local big = fit.check(reply(rewrite), BASE, RECOMMENDED)
check("a reply far over the recommendation still fits", big.fits)
check("and carries the note", big.note ~= nil
    and string.find(big.note, "last turn you changed 180 words (12 recommended)", 1, true) ~= nil
    and string.find(big.note, "rewrote 2 whole sentences (1 recommended)", 1, true) ~= nil,
    big.note)
check("over on sentences alone is still noted",
    fit.advice({ words_changed = 3, sentences_rewritten = 2 }, RECOMMENDED) ~= nil)
check("one of each reads in the singular",
    fit.advice({ words_changed = 1, sentences_rewritten = 1 }, { words = 0, sentences = 0 })
        == "last turn you changed 1 word (0 recommended) and rewrote 1 whole sentence "
        .. "(0 recommended). smaller changes to the operative words keep more of what "
        .. "is already here.")
check("exactly at the recommendation is no note",
    fit.advice({ words_changed = 12, sentences_rewritten = 1 }, RECOMMENDED) == nil)
-- }}}

io.write("\n=== the blitter's size check on arrival ===\n")
-- {{{
local voice = canvas.blank(60, 20, "from-voice")
check("the same size as the base passes", #fit.arrival(voice, BASE) == 0)
local other = fit.arrival(canvas.blank(64, 21, "from-voice"), BASE)
check("another size is refused, height and width", kinds(other) == "wrong-height wrong-width")
check("and reported in the same form", fit.report(other, 60, 20)
    == "the canvas does not fit:\n"
    .. "  the canvas has 21 rows; it must have exactly 20\n"
    .. "  the canvas is 64 characters wide; it must be exactly 60\n"
    .. "write the whole canvas again: exactly 20 rows, each at most 60 characters. "
    .. "keep everything you did not mean to change exactly as it was.\n")
-- }}}

io.write("\n=== what it refuses to be called with ===\n")
-- {{{
check("recommended counts that are not whole numbers",
    not pcall(fit.check, reply(BASE_ROWS), BASE, { words = 1.5, sentences = 1 }))
check("no base", not pcall(fit.check, reply(BASE_ROWS), nil, RECOMMENDED))
check("a problem of a kind it cannot report", not pcall(fit.report, { { kind = "odd" } }, 60, 20))
-- }}}

io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
