#!/usr/bin/env luajit
-- 011-test-changes.lua
--
-- Compares a base canvas with a voice's edit and checks what was kept,
-- written, erased and overwritten, and the two counts the fit check reads.
-- The cases the issue names: no change, one word replaced, a word moved one
-- column, a word erased, a whole sentence rewritten, a word overwritten by a
-- longer one; then a few more.
--
-- For a general: only what a voice changed is applied to the shared canvas.
-- If an untouched word were taken for a change, the voice would undo another
-- voice's work; if a change were missed, its edit would be lost. This proves
-- the comparison is exact.
--
-- usage:
--   luajit 011-test-changes.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

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

-- {{{ local function texts()
-- A list of words as "text@row:column" joined by spaces.
local function texts(list)
    local parts = {}
    for _, word in ipairs(list) do
        parts[#parts + 1] = word.text .. "@" .. word.row .. ":" .. word.column
    end
    return table.concat(parts, " ")
end
-- }}}

-- {{{ local function compare()
-- Checks one case: the four lists and the two counts, as one line each.
local function compare(name, base, voice, expect)
    local found = changes.find(base, voice)
    local got = {
        kept = texts(found.kept), written = texts(found.written),
        removed = texts(found.removed), overwritten = texts(found.overwritten),
        counts = found.words_changed .. " " .. found.sentences_rewritten,
    }
    for _, field in ipairs({ "kept", "written", "removed", "overwritten", "counts" }) do
        check(name .. ": " .. field, got[field] == expect[field],
            "got '" .. got[field] .. "', expected '" .. expect[field] .. "'")
    end
    return found
end
-- }}}

local BASE = { "the cat sat on the mat.", "", "it was very happy." }

io.write("\n=== the issue's cases ===\n")
-- {{{
compare("no change", BASE, BASE, {
    kept = "the@1:1 cat@1:5 sat@1:9 on@1:13 the@1:16 mat.@1:20 it@3:1 was@3:4 very@3:8 happy.@3:13",
    written = "", removed = "", overwritten = "", counts = "0 0" })

compare("one word replaced, the same length",
    BASE, { "the dog sat on the mat.", "", "it was very happy." }, {
    kept = "the@1:1 sat@1:9 on@1:13 the@1:16 mat.@1:20 it@3:1 was@3:4 very@3:8 happy.@3:13",
    written = "dog@1:5", removed = "", overwritten = "cat@1:5", counts = "1 0" })

compare("a word moved one column",
    { "a cat" }, { "a  cat" }, {
    kept = "a@1:1", written = "cat@1:4", removed = "", overwritten = "cat@1:3",
    counts = "1 0" })

compare("every word after a space added moves, and each counts",
    BASE, { "the  cat sat on the mat.", "", "it was very happy." }, {
    kept = "the@1:1 it@3:1 was@3:4 very@3:8 happy.@3:13",
    written = "cat@1:6 sat@1:10 on@1:14 the@1:17 mat.@1:21",
    removed = "", overwritten = "cat@1:5 sat@1:9 on@1:13 the@1:16 mat.@1:20",
    counts = "5 0" })

compare("a word erased",
    BASE, { "the cat sat on the mat.", "", "it was      happy." }, {
    kept = "the@1:1 cat@1:5 sat@1:9 on@1:13 the@1:16 mat.@1:20 it@3:1 was@3:4 happy.@3:13",
    written = "", removed = "very@3:8", overwritten = "", counts = "1 0" })

compare("an operative word changed: very to not very",
    BASE, { "the cat sat on the mat.", "", "it was not very happy." }, {
    kept = "the@1:1 cat@1:5 sat@1:9 on@1:13 the@1:16 mat.@1:20 it@3:1 was@3:4",
    written = "not@3:8 very@3:12 happy.@3:17", removed = "",
    overwritten = "very@3:8 happy.@3:13", counts = "3 0" })

compare("a whole sentence rewritten",
    BASE, { "the cat sat on the mat.", "", "everything ended badly." }, {
    kept = "the@1:1 cat@1:5 sat@1:9 on@1:13 the@1:16 mat.@1:20",
    written = "everything@3:1 ended@3:12 badly.@3:18", removed = "",
    overwritten = "it@3:1 was@3:4 very@3:8 happy.@3:13", counts = "3 1" })

compare("a word overwritten by a longer one",
    BASE, { "the kitten  on the mat.", "", "it was very happy." }, {
    kept = "the@1:1 on@1:13 the@1:16 mat.@1:20 it@3:1 was@3:4 very@3:8 happy.@3:13",
    written = "kitten@1:5", removed = "", overwritten = "cat@1:5 sat@1:9",
    counts = "1 0" })
-- }}}

io.write("\n=== more ===\n")
-- {{{
compare("a whole sentence erased counts as rewritten whole",
    BASE, { "the cat sat on the mat.", "", "" }, {
    kept = "the@1:1 cat@1:5 sat@1:9 on@1:13 the@1:16 mat.@1:20",
    written = "", removed = "it@3:1 was@3:4 very@3:8 happy.@3:13", overwritten = "",
    counts = "4 1" })

compare("a sentence with one word kept is not rewritten whole",
    BASE, { "the cat sat on the mat.", "", "it felt sad." }, {
    kept = "the@1:1 cat@1:5 sat@1:9 on@1:13 the@1:16 mat.@1:20 it@3:1",
    written = "felt@3:4 sad.@3:9", removed = "happy.@3:13",
    overwritten = "was@3:4 very@3:8", counts = "3 0" })

compare("words written into empty space",
    { "", "" }, { "", "  hello there." }, {
    kept = "", written = "hello@2:3 there.@2:9", removed = "", overwritten = "",
    counts = "2 0" })

compare("a word's punctuation changed is a different word",
    { "done." }, { "done!" }, {
    kept = "", written = "done!@1:1", removed = "", overwritten = "done.@1:1",
    counts = "1 1" })

compare("rows written without trailing spaces compare as padded",
    { "a b    " }, { "a" }, {
    kept = "a@1:1", written = "", removed = "b@1:3", overwritten = "", counts = "1 0" })

compare("the same word on another row is written there and erased here",
    { "word", "" }, { "", "word" }, {
    kept = "", written = "word@2:1", removed = "word@1:1", overwritten = "", counts = "2 1" })

compare("characters of two bytes are compared in characters",
    { "café olé" }, { "café  olé" }, {
    kept = "café@1:1", written = "olé@1:7", removed = "", overwritten = "olé@1:6",
    counts = "1 0" })

local found = changes.find(BASE, { "the dog sat on the mat.", "", "it was very happy." })
check("each written word carries its place in the voice's list", found.written[1].number == 2)
check("each kept word carries both places", found.kept[2].base == 3 and found.kept[2].voice == 3)
check("each base word carries its place in the base's list", found.overwritten[1].number == 2)

local function canvas_text(rows)
    return "voice: fg-sora-1\nturn: 2\nbase: 1\nsize: 24x3\nwritten: 2026-11-05T10:00:00Z\n\n"
        .. table.concat(rows, "\n") .. "\nmarks:\n"
end
local records = changes.find(canvas.read(canvas_text(BASE), "from-voice"),
    canvas.read(canvas_text({ "the dog sat on the mat.", "", "it was very happy." }), "from-voice"))
check("canvas records read by 102 compare the same as rows",
    texts(records.written) == "dog@1:5" and records.words_changed == 1)

check("canvases of different heights are refused",
    not pcall(changes.find, { "a", "b" }, { "a" }))
-- }}}

io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
