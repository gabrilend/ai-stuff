#!/usr/bin/env luajit
-- 007-test-canvas-text.lua
--
-- Reads every example in docs/canvas-format.md and docs/canvas-protocol.md,
-- made into whole canvases, and writes each back byte for byte. Then one
-- malformed canvas for each way a canvas can be wrong, checking each is
-- refused with the line that is wrong. Also the character counting (005) the
-- reader measures rows with.
--
-- For a general: three machines and every viewer pass this text around. If
-- the reader and the writer disagreed by one byte, or a wrong canvas were
-- quietly repaired, the machines would each see a different page. This proves
-- the text comes back exactly, and that a wrong one is stopped where it is
-- wrong.
--
-- The examples are taken from the documents themselves, so a document edited
-- into a form the reader refuses fails this test.
--
-- usage:
--   luajit 007-test-canvas-text.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local utf8 = dofile(DIR .. "/src/005-utf8.lua")
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

-- {{{ local function refused()
-- fn must raise an error starting with `start` and containing `part`.
local function refused(name, start, part, fn)
    local ok, message = pcall(fn)
    message = tostring(message)
    check(name, not ok and string.sub(message, 1, #start) == start
        and string.find(message, part, 1, true) ~= nil,
        ok and "it was accepted" or message)
end
-- }}}

-- {{{ local function code_block_after()
-- The first indented block (four spaces) after a heading in a document, with
-- the indent taken off. Blank lines inside the block are kept.
local function code_block_after(path, heading)
    local handle = assert(io.open(DIR .. "/" .. path, "r"))
    local text = handle:read("*a")
    handle:close()
    local start = assert(string.find(text, heading, 1, true), heading .. " not in " .. path)
    local lines, inside = {}, false
    for line in string.gmatch(string.sub(text, start) .. "\n", "([^\n]*)\n") do
        if string.sub(line, 1, 4) == "    " then
            inside = true
            lines[#lines + 1] = string.sub(line, 5)
        elseif inside and line == "" then
            lines[#lines + 1] = ""
        elseif inside then
            break
        end
    end
    while lines[#lines] == "" do lines[#lines] = nil end
    return lines
end
-- }}}

-- {{{ ROWS -- twenty rows that a 60x20 canvas could hold
-- Plain words, an empty row, a row of exactly sixty characters, characters
-- of two and three bytes, leading spaces, and punctuation.
local ROWS = {
    "The canvas is a page that three small computers keep",
    "rewriting. Each one changes as little as it can.",
    "",
    "  café, naïve → déjà vu: words with more than one byte.",
    string.rep("x", 60),
    string.rep("é", 60),
    "fg-sora-1 thinks the blitter loop comes first.",
    "",
    "Marks age as versions go by!",
    "Is a sentence over at a question mark?",
}
for index = #ROWS + 1, 20 do
    ROWS[index] = (index % 3 == 0) and "" or ("row " .. index .. " of twenty.")
end
local ROW_TEXT = table.concat(ROWS, "\n") .. "\n"
-- }}}

-- {{{ the examples, made whole
local TO_VOICES = table.concat(code_block_after("docs/canvas-format.md",
    "## Headers, kuvalu → voices"), "\n") .. "\n\n" .. ROW_TEXT
    .. "marks:\nmark: 3 12 7 fg-sora-2 18 word\n"
    .. "cuts:\ncut: fg-sora-3 17 7 11 blitter\ncut: fg-sora-1 18 4 3 café,\n"
local FROM_VOICE = table.concat(code_block_after("docs/canvas-format.md",
    "## Headers, voice → kuvalu"), "\n") .. "\n\n" .. ROW_TEXT .. "marks:\n"
local protocol = code_block_after("docs/canvas-protocol.md", "## The text")
for index, line in ipairs(protocol) do
    if string.match(line, "^<%d+ rows") then
        protocol[index] = string.gsub(ROW_TEXT, "\n$", "")
    end
end
local FOR_VIEWERS = table.concat(protocol, "\n") .. "\n"
-- }}}

io.write("\n=== characters (005) ===\n")
-- {{{
check("ASCII counts one a byte", utf8.length("canvas") == 6)
check("two- and three-byte characters count once", utf8.length("café→") == 5)
check("a four-byte character counts once", utf8.length("\240\159\152\128") == 1)
check("split gives each character", table.concat(utf8.split("a→b"), "|") == "a|→|b")
check("pad fills to the width", utf8.pad("é", 3) == "é  ")
for _, case in ipairs({
    { "a stray continuation byte", "ab\128", 3 },
    { "a cut sequence", "ab\226\134", 3 },
    { "a two-byte encoding of an ASCII letter", "\193\129", 1 },
    { "a three-byte encoding where two would do", "\224\130\129", 1 },
    { "a surrogate half", "\237\160\128", 1 },
    { "a code point past U+10FFFF", "\244\144\128\128", 1 },
    { "a byte UTF-8 never uses", "\255", 1 },
}) do
    local length, at = utf8.length(case[2])
    check("refused: " .. case[1] .. ", at its byte", length == nil and at == case[3],
        tostring(length) .. " " .. tostring(at))
end
-- }}}

io.write("\n=== the documents' examples, read and written back ===\n")
-- {{{
for _, example in ipairs({
    { "kuvalu -> voices", TO_VOICES, "to-voices" },
    { "voice -> kuvalu", FROM_VOICE, "from-voice" },
    { "kuvalu -> viewers", FOR_VIEWERS, "for-viewers" },
}) do
    local ok, record = pcall(canvas.read, example[2], example[3], example[1])
    check(example[1] .. ": read", ok, record)
    if ok then
        local back = canvas.write(record)
        check(example[1] .. ": written back byte for byte", back == example[2],
            back ~= example[2] and back or nil)
        check(example[1] .. ": every row is padded to the width",
            #record.rows == 20 and utf8.length(record.rows[1]) == 60
            and utf8.length(record.rows[3]) == 60 and utf8.length(record.rows[6]) == 60)
    end
end

local to = canvas.read(TO_VOICES, "to-voices")
check("headers are parsed: numbers, size, project, endpoint",
    to.headers.canvas == 18 and to.width == 60 and to.height == 20
    and to.headers.size.width == 60 and to.headers.mode == "newest"
    and to.headers.project.name == "guide-feature" and to.headers.project.commit == "9f2c1e0"
    and to.headers.endpoint.name == "voice-small"
    and to.headers.written == "2026-10-21T22:10:05Z")
check("a mark is read into its fields",
    to.marks[1].row == 3 and to.marks[1].column == 12 and to.marks[1].length == 7
    and to.marks[1].voice == "fg-sora-2" and to.marks[1].version == 18
    and to.marks[1].kind == "word")
check("cuts are read, with words of more than one byte",
    #to.cuts == 2 and to.cuts[2].text == "café," and to.cuts[1].column == 11)
check("rows keep their characters", to.rows[4] == utf8.pad(ROWS[4], 60))

local from = canvas.read(FROM_VOICE, "from-voice")
check("a voice's headers", from.headers.voice == "fg-sora-2" and from.headers.turn == 41
    and from.headers.base == 18)
check("a voice's canvas has no marks and none ignored", #from.marks == 0
    and from.ignored_marks == 0 and from.cuts == nil)

local viewers = canvas.read(FOR_VIEWERS, "for-viewers")
check("viewers get the voices, in order", table.concat(viewers.headers.voices, ",")
    == "fg-sora-1,fg-sora-2,fg-sora-3")
check("viewers get every mark", #viewers.marks == 3 and viewers.marks[2].kind == "sentence"
    and viewers.marks[2].length == 31)
-- }}}

io.write("\n=== what reads but writes back tidier ===\n")
-- {{{
local spaced = string.gsub(FROM_VOICE, "Marks age as versions go by!\n",
    "Marks age as versions go by!     \n")
local tidy = canvas.read(spaced, "from-voice")
check("trailing spaces in a row are read", tidy.rows[9] == utf8.pad(ROWS[9], 60))
check("and dropped when written", canvas.write(tidy) == FROM_VOICE)
local unended = string.gsub(TO_VOICES, "\n$", "")
check("a canvas missing its final newline is read",
    pcall(canvas.read, unended, "to-voices"))
check("a voice's marks are ignored and counted",
    canvas.read(FROM_VOICE .. "mark: 1 1 3 fg-sora-2 41 word\nmark: nonsense\n",
        "from-voice").ignored_marks == 2)
local no_cuts = string.gsub(TO_VOICES, "cuts:.*$", "")
local without = canvas.read(no_cuts, "to-voices")
check("a canvas to the voices may leave out cuts", without.cuts == nil
    and canvas.write(without) == no_cuts)
local empty_cuts = no_cuts .. "cuts:\n"
check("or carry an empty cuts section, written back as it came",
    canvas.write(canvas.read(empty_cuts, "to-voices")) == empty_cuts)
local blank = canvas.blank(5, 2, "from-voice")
blank.headers = { voice = "fg-sora-1", turn = 1, base = 1, written = "2026-11-05T10:00:00Z" }
local blank_text = canvas.write(blank)
check("a blank canvas is written with empty rows",
    blank_text == "voice: fg-sora-1\nturn: 1\nbase: 1\nsize: 5x2\n"
        .. "written: 2026-11-05T10:00:00Z\n\n\n\nmarks:\n", blank_text)
check("and reads back", canvas.read(blank_text, "from-voice").rows[2] == "     ")
-- }}}

io.write("\n=== each kind of malformed canvas is refused, at its line ===\n")
-- {{{
-- Line numbers: the voice example has 1-5 headers, 6 blank, 7-26 rows,
-- 27 marks:. The one to the voices has 1-6, 7, 8-27, 28 marks:, 29 its
-- mark, 30 cuts:, 31-32 its cuts. The viewers' has 28 marks:, 29-31 marks.
local function swap(text, old, new)
    local start, finish = string.find(text, old, 1, true)
    assert(start, "the test's own text lacks: " .. old)
    return string.sub(text, 1, start - 1) .. new .. string.sub(text, finish + 1)
end
local function bad(name, text, set, start, part)
    refused(name, start, part, function() return canvas.read(text, set, "c") end)
end

bad("a missing header", swap(FROM_VOICE, "turn: 41\n", ""), "from-voice",
    "c:2:", "expected 'turn' here, found 'base'")
bad("a missing last header", swap(FROM_VOICE, "written: 2026-10-21T22:10:48Z\n", ""),
    "from-voice", "c:5:", "the headers end without 'written'")
bad("a repeated header", swap(FROM_VOICE, "turn: 41\n", "turn: 41\nturn: 42\n"),
    "from-voice", "c:3:", "'turn' is here a second time")
bad("an unknown header", swap(FROM_VOICE, "turn: 41\n", "turn: 41\nmood: calm\n"),
    "from-voice", "c:3:", "'mood' is not a from-voice header")
bad("a header of another set", swap(FROM_VOICE, "turn: 41\n", "turn: 41\ncanvas: 18\n"),
    "from-voice", "c:3:", "'canvas' is not a from-voice header")
bad("headers out of order", swap(FROM_VOICE, "turn: 41\nbase: 18\n", "base: 18\nturn: 41\n"),
    "from-voice", "c:2:", "expected 'turn' here, found 'base'")
bad("a header line that is not one", swap(FROM_VOICE, "turn: 41\n", "turn 41\n"),
    "from-voice", "c:2:", "expected a header line")
bad("a number with a leading zero", swap(FROM_VOICE, "turn: 41\n", "turn: 041\n"),
    "from-voice", "c:2:", "'turn' should be a whole number")
bad("a size with no rows", swap(FROM_VOICE, "size: 60x20", "size: 60x0"),
    "from-voice", "c:4:", "'size' should be a size")
bad("a time that is not UTC", swap(FROM_VOICE, "22:10:48Z", "22:10:48+01:00"),
    "from-voice", "c:5:", "'written' should be a UTC time")
bad("a mode that is not one", swap(TO_VOICES, "mode: newest", "mode: oldest"),
    "to-voices", "c:3:", "'mode' should be newest or distill")
bad("a project with no commit", swap(TO_VOICES, "project: guide-feature 9f2c1e0",
    "project: guide-feature"), "to-voices", "c:4:", "'project' should be a name and a commit")
bad("voices named twice", swap(FOR_VIEWERS, "fg-sora-3", "fg-sora-1"),
    "for-viewers", "c:6:", "'voices' should be names")
bad("a canvas that ends in its headers", "voice: fg-sora-2\nturn: 41\n",
    "from-voice", "c:3:", "ends inside its headers")
bad("a row too long", swap(FROM_VOICE, string.rep("x", 60), string.rep("x", 61)),
    "from-voice", "c:11:", "row 5 is 61 characters, 1 over the width of 60")
bad("a row too long by one character of two bytes",
    swap(FROM_VOICE, string.rep("é", 60), string.rep("é", 61)),
    "from-voice", "c:12:", "row 6 is 61 characters")
bad("a row that is not UTF-8", swap(FROM_VOICE, "café", "caf\233"),
    "from-voice", "c:10:", "row 4 is not valid UTF-8")
bad("a row with a tab", swap(FROM_VOICE, "Marks age", "Marks\tage"),
    "from-voice", "c:15:", "row 9 holds a control character")
bad("too few rows", swap(FROM_VOICE, "row 20 of twenty.\n", ""),
    "from-voice", "c:27:", "line 26 reads `marks:`; are there fewer rows")
bad("too few rows, and nothing after", swap(FROM_VOICE, "row 20 of twenty.\nmarks:\n", ""),
    "from-voice", "c:26:", "ends after 19 of its 20 rows")
bad("too many rows", swap(FROM_VOICE, "row 20 of twenty.\n", "row 20 of twenty.\nrow 21\n"),
    "from-voice", "c:27:", "expected `marks:` after the 20 rows, found: row 21")
bad("no marks section", swap(FROM_VOICE, "marks:\n", ""),
    "from-voice", "c:27:", "found: the end of the canvas")
bad("a mark with a field missing", swap(TO_VOICES, "mark: 3 12 7 fg-sora-2 18 word",
    "mark: 3 12 7 fg-sora-2 18"), "to-voices", "c:29:", "a mark is `mark: ROW")
bad("a mark below the last row", swap(TO_VOICES, "mark: 3 12", "mark: 21 12"),
    "to-voices", "c:29:", "its row is not between 1 and 20")
bad("a mark running past the width", swap(TO_VOICES, "mark: 3 12 7", "mark: 3 55 7"),
    "to-voices", "c:29:", "runs past the width of 60")
bad("a mark of no kind", swap(TO_VOICES, "18 word", "18 letter"),
    "to-voices", "c:29:", "its kind is not word, sentence or orphan")
bad("a line among the marks that is not one", swap(TO_VOICES, "cuts:\n", "hello\ncuts:\n"),
    "to-voices", "c:30:", "a mark is `mark: ROW")
bad("a cut whose word runs past the width", swap(TO_VOICES, "cut: fg-sora-3 17 7 11 blitter",
    "cut: fg-sora-3 17 7 55 blitter"), "to-voices", "c:31:", "does not fit")
bad("a cut with two words", swap(TO_VOICES, "11 blitter", "11 the blitter"),
    "to-voices", "c:31:", "a cut is `cut: VOICE")
bad("cuts sent by a voice", FROM_VOICE .. "cuts:\n", "from-voice",
    "c:28:", "only a canvas sent to the voices has a `cuts:` section")
bad("cuts sent to viewers", FOR_VIEWERS .. "cuts:\n", "for-viewers",
    "c:32:", "only a canvas sent to the voices")
bad("a voice's line after marks that is no mark", FROM_VOICE .. "hello\n",
    "from-voice", "c:28:", "expected a `mark:` line or the end")
bad("a blank line after the marks", FOR_VIEWERS .. "\n", "for-viewers",
    "c:32:", "a mark is `mark: ROW")
refused("no such header set", "canvas.read:", "no header set called 'sideways'",
    function() return canvas.read(FROM_VOICE, "sideways") end)
-- }}}

io.write("\n=== the writer refuses what could not be read back ===\n")
-- {{{
local function bad_write(name, change, part)
    local record = canvas.read(TO_VOICES, "to-voices")
    change(record)
    refused(name, "canvas.write:", part, function() return canvas.write(record) end)
end
bad_write("a row too long", function(r) r.rows[2] = string.rep("y", 61) end,
    "row 2 is 61 characters")
bad_write("a missing header", function(r) r.headers.endpoint = nil end,
    "no 'endpoint' header")
bad_write("a mark off the canvas", function(r) r.marks[1].row = 40 end,
    "mark 1 cannot be on the canvas")
bad_write("rows that disagree with the height", function(r) r.rows[20] = nil end,
    "disagree")
bad_write("a header value that would not read back", function(r) r.headers.mode = "both" end,
    "'mode' would not read back")
bad_write("cuts on a canvas for viewers", function(r)
    r.set = "for-viewers"
    r.headers.voices = { "fg-sora-1" }
end, "only a canvas sent to the voices has cuts")
-- }}}

io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
