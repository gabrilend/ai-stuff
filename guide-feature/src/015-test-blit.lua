#!/usr/bin/env luajit
-- 015-test-blit.lua
--
-- Blits voices' changes onto shared canvases and checks the canvas that
-- results and the report, under both rules built. First the example in
-- docs/datapath-blit.md (`kitten` over `the cat sat on the mat`, then `dog`
-- over `kitten`), taken from the document itself; then the issue's cases: a
-- write exactly covering a word, a write spanning three words, a removal of a
-- word another voice already changed, and two writes in one blit that touch.
--
-- For a general: this is the moment three voices' edits meet on one page.
-- It proves that a voice's edit lands where it meant, that it never undoes
-- another voice's later change, and that under the owner's rule no broken
-- piece of a word is ever left on screen.
--
-- usage:
--   luajit 015-test-blit.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local blit = dofile(DIR .. "/src/014-blit.lua")
local changes = dofile(DIR .. "/src/010-changes.lua")
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

-- {{{ local function record()
-- A canvas record of rows, padded to `width`.
local function record(rows, width)
    local made = canvas.blank(width, #rows, "to-voices")
    for number, row in ipairs(rows) do made.rows[number] = row .. string.rep(" ", width - #row) end
    return made
end
-- }}}

-- {{{ local function run()
-- The blit of what a voice changed (base -> voice) onto `current`, under a
-- rule. Returns the new rows with trailing spaces dropped, and the report.
local function run(current, base, voice, rule, width)
    width = width or 30
    local found = changes.find(record(base, width), record(voice, width))
    local new, report = blit.apply(record(current, width), found, rule)
    local rows = {}
    for number, row in ipairs(new.rows) do rows[number] = (string.gsub(row, " +$", "")) end
    return rows, report
end
-- }}}

-- {{{ local function cuts()
-- The report's cut words as "text:lost:outcome".
local function cuts(report)
    local parts = {}
    for _, cut in ipairs(report.cut) do
        parts[#parts + 1] = cut.text .. ":" .. cut.lost .. ":" .. cut.outcome
    end
    return table.concat(parts, " ")
end
-- }}}

-- {{{ the document's example
local DOC
do
    local handle = assert(io.open(DIR .. "/docs/datapath-blit.md", "r"))
    DOC = handle:read("*a")
    handle:close()
end
local BEFORE = assert(string.match(DOC, "\n    before: +([^\n]+)\n"))
local AFTER = assert(string.match(DOC, "\n    after: +([^\n]+)\n"))
-- }}}

io.write("\n=== the document's example ===\n")
-- {{{
check("the example is in the document", BEFORE == "the cat sat on the mat"
    and AFTER == "the kitten  on the mat", BEFORE .. " / " .. AFTER)

local kitten, kitten_report = run({ BEFORE }, { BEFORE }, { "the kitten  on the mat" }, "blank-whole")
check("blank-whole: kitten over cat leaves the document's after-line", kitten[1] == AFTER,
    kitten[1])
check("blank-whole: cat covered, sat cut and blanked",
    #kitten_report.covered == 1 and kitten_report.covered[1].text == "cat"
    and cuts(kitten_report) == "sat:2:blanked", cuts(kitten_report))
check("blank-whole: the blanked cell is reported with its word",
    #kitten_report.blanked == 1 and kitten_report.blanked[1].column == 11
    and kitten_report.blanked[1].word == "sat" and kitten_report.blanked[1].why == "cut")
check("blank-whole: every cell written is reported with its word",
    #kitten_report.written == 6 and kitten_report.written[1].column == 5
    and kitten_report.written[6].word == "kitten")

local kept, kept_report = run({ BEFORE }, { BEFORE }, { "the kitten  on the mat" }, "keep-fragments")
check("keep-fragments: the t of sat stays, glued on like a terminal leaves it",
    kept[1] == "the kittent on the mat", kept[1])
check("keep-fragments: sat cut and kept", cuts(kept_report) == "sat:2:kept"
    and #kept_report.blanked == 0)

local dog = run({ AFTER }, { AFTER }, { "the dog     on the mat" }, "blank-whole")
check("blank-whole: dog over the start of kitten blanks its ten", dog[1] == "the dog     on the mat",
    dog[1])
local dogten, dog_report = run({ AFTER }, { AFTER }, { "the dog     on the mat" }, "keep-fragments")
check("keep-fragments: kitten's ten stays", dogten[1] == "the dogten  on the mat", dogten[1])
check("kitten lost three letters", cuts(dog_report) == "kitten:3:kept")
-- }}}

io.write("\n=== the issue's cases ===\n")
-- {{{
local exact, exact_report = run({ "the cat sat" }, { "the cat sat" }, { "the dog sat" })
check("a write exactly covering a word: covered, nothing cut",
    exact[1] == "the dog sat" and #exact_report.cut == 0 and #exact_report.covered == 1)

local span = run({ "ab cd ef gh" }, { "ab cd ef gh" }, { " XXXXXX  gh" }, "blank-whole")
check("a write spanning three words under blank-whole: both ends blanked, the middle covered",
    span[1] == " XXXXXX  gh", span[1])
local span_kept, span_report = run({ "ab cd ef gh" }, { "ab cd ef gh" }, { " XXXXXX  gh" },
    "keep-fragments")
check("the same under keep-fragments: the plain overwrite", span_kept[1] == "aXXXXXXf gh",
    span_kept[1])
check("ab and ef cut, cd covered", cuts(span_report) == "ab:1:kept ef:1:kept"
    and span_report.covered[1].text == "cd", cuts(span_report))

local conflict, conflict_report = run({ "the dog" }, { "the cat" }, { "the" })
check("a removal of a word another voice already changed is left alone",
    conflict[1] == "the dog" and #conflict_report.conflicts == 1
    and conflict_report.conflicts[1].text == "cat" and conflict_report.counts.conflicts == 1)
check("and, nothing else changing, the canvas did not change", conflict_report.changed == false)

local removed, removed_report = run({ "the cat sat" }, { "the cat sat" }, { "the     sat" })
check("a removal still there is blanked", removed[1] == "the     sat"
    and removed_report.counts["removals-applied"] == 1
    and removed_report.blanked[1].why == "removed" and #removed_report.blanked == 3)

local touch, touch_report = run({ "the cat sat on" }, { "the cat sat on" }, { "the big red on" })
check("two writes in one blit that touch leave both whole",
    touch[1] == "the big red on" and #touch_report.cut == 0 and #touch_report.covered == 2
    and touch_report.counts["words-written"] == 2, touch[1])
-- }}}

io.write("\n=== more ===\n")
-- {{{
local later, later_report = run({ "the cat sat. it ran." }, { "the cat sat." },
    { "the dog sat." }, "blank-whole")
check("another voice's later words are left alone", later[1] == "the dog sat. it ran."
    and later_report.counts["words-written"] == 1)

local glued = run({ "the    xyz" }, { "the" }, { "the cat" }, "blank-whole")
check("a word touching the write is not left glued to it under blank-whole",
    glued[1] == "the cat", glued[1])
local glued_kept, glued_report = run({ "the    xyz" }, { "the" }, { "the cat" }, "keep-fragments")
check("under keep-fragments the two run together, as a terminal would",
    glued_kept[1] == "the catxyz" and cuts(glued_report) == "xyz:0:kept", glued_kept[1])

local before_glue = run({ "abc    " }, { "" }, { "   def" }, "blank-whole")
check("a word touching the write's start is handled the same", before_glue[1] == "   def",
    before_glue[1])

local wide = run({ "café olé" }, { "café olé" }, { "cafX olé" }, "blank-whole")
check("characters of two bytes are cells like any other", wide[1] == "cafX olé", wide[1])

local same, same_report = run({ "a cat" }, { "a dog" }, { "a cat" })
check("a write of what is already there changes nothing",
    same[1] == "a cat" and same_report.changed == false)

local rows2, report2 = run({ "one two.", "three" }, { "one two.", "three" },
    { "one 2.", "four" }, "blank-whole")
check("writes on several rows, each in reading order",
    rows2[1] == "one 2." and rows2[2] == "four" and report2.counts["words-written"] == 2,
    rows2[1] .. "|" .. rows2[2])

local current = record({ "the cat" }, 10)
local found = changes.find(record({ "the cat" }, 10), record({ "the dog" }, 10))
local new = blit.apply(current, found, "blank-whole")
check("the current canvas is not changed; a new one comes back",
    current.rows[1] == "the cat   " and new.rows[1] == "the dog   " and new ~= current)
check("its headers and marks are carried over", new.headers == current.headers
    and new.marks == current.marks)
check("the default rule is blank-whole", select(2, blit.apply(current, found)).rule
    == "blank-whole")
check("an unknown rule is refused, naming those built",
    not pcall(blit.apply, current, found, "push-aside")
    and string.find(select(2, pcall(blit.apply, current, found, "push-aside")),
        "blank-whole, keep-fragments", 1, true) ~= nil)
check("a written word off the canvas is refused",
    not pcall(blit.apply, current, { written = { { row = 1, column = 9, length = 3,
        text = "abc" } } }, "blank-whole"))
-- }}}

io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
