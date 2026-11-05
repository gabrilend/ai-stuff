#!/usr/bin/env luajit
-- 009-test-words.lua
--
-- Finds the words on small canvases and checks each one's row, column,
-- length and text; then the cell-owner grid and the sentences. The cases the
-- issue names: words at the edges of a row, characters of more than one
-- byte, a row of only spaces ending a sentence, and punctuation inside a
-- word.
--
-- For a general: every change a voice makes is measured in words, and every
-- word written onto the shared canvas is checked against the words already
-- there. If a word were found one column off, the blit would cut the wrong
-- word. This proves where each word is.
--
-- usage:
--   luajit 009-test-words.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local words = dofile(DIR .. "/src/008-words.lua")
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

-- {{{ local function describe()
-- The words as one line, "row:column:length:text ...", for comparing.
local function describe(list)
    local parts = {}
    for _, word in ipairs(list) do
        parts[#parts + 1] = word.row .. ":" .. word.column .. ":" .. word.length .. ":" .. word.text
    end
    return table.concat(parts, " ")
end
-- }}}

-- {{{ local function groups()
-- Sentences as "1,2,3|4,5".
local function groups(sentences)
    local parts = {}
    for _, sentence in ipairs(sentences) do parts[#parts + 1] = table.concat(sentence, ",") end
    return table.concat(parts, "|")
end
-- }}}

io.write("\n=== finding words ===\n")
-- {{{
local function found(name, rows, expected)
    local got = describe(words.find(rows))
    check(name, got == expected, got)
end
found("words along a row", { "the cat sat" }, "1:1:3:the 1:5:3:cat 1:9:3:sat")
found("a word at the very first column and one at the last",
    { "edge      edge" }, "1:1:4:edge 1:11:4:edge")
found("a word filling the whole row", { "abcdef" }, "1:1:6:abcdef")
found("leading and runs of spaces", { "   a    b  " }, "1:4:1:a 1:9:1:b")
found("a row of only spaces has none", { "      " }, "")
found("an empty row has none", { "" }, "")
found("characters of two and three bytes count once",
    { "café → déjà" }, "1:1:4:café 1:6:1:→ 1:8:4:déjà")
found("a word after a wide character starts where the characters say",
    { "ééé x" }, "1:1:3:ééé 1:5:1:x")
found("punctuation is part of the word next to it",
    { "e.g. well,(maybe)" }, "1:1:4:e.g. 1:6:12:well,(maybe)")
found("a word never wraps: one ends at a row's end, the next starts a row",
    { "foo", "bar baz" }, "1:1:3:foo 2:1:3:bar 2:5:3:baz")
found("rows are numbered from the top", { "", "", "x" }, "3:1:1:x")
check("a row that is not UTF-8 is refused",
    not pcall(words.find, { "caf\233" }))
-- }}}

io.write("\n=== which word covers each cell ===\n")
-- {{{
local list = words.find({ "the cat", "  sat" })
local owner = words.owners(list, 8, 2)
check("each letter's cell names its word",
    owner[1][1] == 1 and owner[1][3] == 1 and owner[1][5] == 2 and owner[1][7] == 2
    and owner[2][3] == 3 and owner[2][5] == 3)
check("spaces belong to no word",
    owner[1][4] == nil and owner[1][8] == nil and owner[2][1] == nil and owner[2][6] == nil)
check("every row has a grid row, even an empty one",
    type(words.owners({}, 4, 3)[3]) == "table")
local wide = words.find({ "é→x y" })
local wide_owner = words.owners(wide, 5, 1)
check("cells are characters, not bytes",
    wide_owner[1][3] == 1 and wide_owner[1][4] == nil and wide_owner[1][5] == 2)
check("a word off the canvas is refused, not drawn half",
    not pcall(words.owners, words.find({ "abcdef" }), 5, 1))
-- }}}

io.write("\n=== sentences ===\n")
-- {{{
local function grouped(name, rows, expected)
    local got = groups((words.sentences(words.find(rows), #rows)))
    check(name, got == expected, got)
end
grouped("a full stop ends a sentence", { "one two. three four." }, "1,2|3,4")
grouped("! and ? end one too", { "go! why? yes" }, "1|2|3")
grouped("a sentence runs across rows", { "the cat", "sat. it" }, "1,2,3|4")
grouped("a row of only spaces ends a sentence", { "the cat", "     ", "sat" }, "1,2|3")
grouped("an empty row ends a sentence", { "the cat", "", "sat" }, "1,2|3")
grouped("several empty rows make no empty sentences", { "a", "", "", "b.", "", "" }, "1|2")
grouped("the last words are a sentence without a full stop", { "no stop here" }, "1,2,3")
grouped("a full stop inside a word does not end one", { "pi is 3.14 or so." }, "1,2,3,4,5")
grouped("a word ending in a full stop does, abbreviation or not",
    { "see e.g. this." }, "1,2|3")
grouped("closing quotes and brackets after the stop still end it",
    { 'he said "go." then (left!) and', "“yes?” ok" }, "1,2,3|4,5|6,7|8")
grouped("an opening bracket before a stop does not hide it", { "(a. b" }, "1|2")
grouped("a word of only a quote ends nothing", { 'a " b' }, "1,2,3")
grouped("no words, no sentences", { "", "   " }, "")
local _, sentence_of = words.sentences(words.find({ "a b. c" }), 1)
check("each word knows its sentence", sentence_of[1] == 1 and sentence_of[2] == 1
    and sentence_of[3] == 2)
-- }}}

io.write("\n=== a whole canvas ===\n")
-- {{{
local text = table.concat({
    "canvas: 3", "size: 12x4", "mode: newest", "project: guide-feature 9f2c1e0",
    "written: 2026-11-05T10:00:00Z", "voices: fg-sora-1", "",
    "The cat sat.", "", "  café is", "open", "marks:", "",
}, "\n")
local all = words.of_canvas(canvas.read(text, "for-viewers"))
check("the words of a canvas read by 102",
    describe(all.words) == "1:1:3:The 1:5:3:cat 1:9:4:sat. 3:3:4:café 3:8:2:is 4:1:4:open",
    describe(all.words))
check("its grid, padded rows and all", all.owner[3][6] == 4 and all.owner[1][12] == 3
    and all.owner[4][5] == nil)
check("its sentences", groups(all.sentences) == "1,2,3|4,5,6")
-- }}}

io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
