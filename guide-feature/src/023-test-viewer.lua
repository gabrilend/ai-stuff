#!/usr/bin/env luajit
-- 023-test-viewer.lua
--
-- Holds the viewer-side reader (022) to the test canvases every viewer
-- shares (assets/test-canvases/): each grid cell by cell, each mark's age,
-- the changed cells against the version drawn before, and each canvas that
-- must be refused. Checks that the kitten and dog canvases there are what the
-- real change finder, blit and marks make. Then the reader's other answers:
-- a screen too small, the voices' colour order, and changes of size or of
-- marks alone.
--
-- For a general: every screen that shows the canvas reads it through this,
-- or through a copy in its own language checked against the same files. This
-- proves they will all show the same characters and the same marks.
--
-- usage:
--   luajit 023-test-viewer.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local viewer = dofile(DIR .. "/src/022-viewer.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
local changes = dofile(DIR .. "/src/010-changes.lua")
local blit = dofile(DIR .. "/src/014-blit.lua")
local marks = dofile(DIR .. "/src/020-marks.lua")

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

-- {{{ helpers
local TESTS = DIR .. "/assets/test-canvases/"
local function slurp(path)
    local handle = assert(io.open(path, "r"))
    local text = handle:read("*a")
    handle:close()
    return text
end
-- One UTF-8 character's code point.
local function code_point(character)
    local b = { string.byte(character, 1, -1) }
    if b[1] < 0x80 then return b[1] end
    if b[1] < 0xE0 then return (b[1] - 0xC0) * 64 + (b[2] - 0x80) end
    if b[1] < 0xF0 then return ((b[1] - 0xE0) * 64 + (b[2] - 0x80)) * 64 + (b[3] - 0x80) end
    return (((b[1] - 0xF0) * 64 + (b[2] - 0x80)) * 64 + (b[3] - 0x80)) * 64 + (b[4] - 0x80)
end
-- The reader's answer for a test canvas, written as its .expected file is.
local function answer(name)
    local ok, view = pcall(viewer.read, slurp(TESTS .. name .. ".canvas"), name .. ".canvas")
    if not ok then
        return { "refused " .. (string.match(view, "^[^:]+:(%d+):") or "?") }
    end
    local out = { "version " .. view.version, "size " .. view.width .. "x" .. view.height,
                  "voices " .. table.concat(view.voices, " ") }
    for row = 1, view.height do
        for column = 1, view.width do
            local cell = view.cells[row][column]
            local line = string.format("cell %d %d %d", row, column, code_point(cell.character))
            if cell.mark then
                line = line .. string.format(" %s %d %s %d", cell.mark.voice, cell.mark.version,
                    cell.mark.kind, cell.mark.age)
            end
            out[#out + 1] = line
        end
    end
    return out, view
end
local function expected(name)
    local lines = {}
    for line in string.gmatch(slurp(TESTS .. name .. ".expected"), "([^\n]*)\n") do
        if string.sub(line, 1, 1) ~= "#" then lines[#lines + 1] = line end
    end
    return lines
end
-- The first line where two lists differ, or nil.
local function first_difference(a, b)
    for index = 1, math.max(#a, #b) do
        if a[index] ~= b[index] then
            return index .. ": got " .. tostring(a[index]) .. ", expected " .. tostring(b[index])
        end
    end
    return nil
end
-- }}}

io.write("\n=== the test canvases every viewer shares ===\n")
-- {{{
local NAMES = {}
for name in string.gmatch(io.popen("ls '" .. TESTS .. "'"):read("*a"), "([^\n]+)%.canvas\n") do
    NAMES[#NAMES + 1] = name
end
check("there are six test canvases, each with its expected answer", #NAMES == 6
    and io.open(TESTS .. NAMES[6] .. ".expected") ~= nil, table.concat(NAMES, " "))

local views = {}
for _, name in ipairs(NAMES) do
    local got, view = answer(name)
    views[name] = view
    local want = expected(name)
    if view then
        -- the changed cells, against the version named in the file
        local previous_name
        for _, line in ipairs(want) do
            previous_name = previous_name or string.match(line, "^previous (.+)%.canvas$")
        end
        got[#got + 1] = "previous " .. (previous_name and (previous_name .. ".canvas") or "none")
        local previous = previous_name and viewer.read(slurp(TESTS .. previous_name .. ".canvas"))
        for _, cell in ipairs(viewer.changed(view, previous)) do
            got[#got + 1] = string.format("changed %d %d %s %d", cell.row, cell.column,
                cell.was and tostring(code_point(cell.was)) or "-", code_point(cell.now))
        end
    end
    check(name .. ": the reader's answer matches, line for line",
        first_difference(got, want) == nil, first_difference(got, want))
end
-- }}}

io.write("\n=== read by hand ===\n")
-- {{{
local kitten, dog, aging = views["02-kitten"], views["03-dog"], views["04-aging"]
check("a blanked cell is a space that still carries its word mark",
    kitten.cells[1][11].character == " " and kitten.cells[1][11].mark.kind == "word")
check("a cell with no mark has none", kitten.cells[1][4].mark == nil)
check("a two-byte character is one cell, as a string",
    aging.cells[3][4].character == "é" and aging.cells[3][5].character == " "
    and aging.cells[3][8].character == "é")
check("ages: the canvas version minus the mark's",
    aging.cells[1][1].mark.age == 0 and aging.cells[2][1].mark.age == 2
    and aging.cells[2][8].mark.age == 6 and aging.cells[3][4].mark.age == 1)
check("the reader never changes a character: its rows are the canvas's rows", (function()
    for row = 1, aging.height do
        local text = {}
        for column = 1, aging.width do text[column] = aging.cells[row][column].character end
        if table.concat(text) ~= aging.record.rows[row] then return false end
    end
    return true
end)())
check("dog against kitten: the six cells whose letter changed, in reading order",
    #viewer.changed(dog, kitten) == 6 and viewer.changed(dog, kitten)[1].was == "k"
    and viewer.changed(dog, kitten)[1].now == "d" and viewer.changed(dog, kitten)[6].now == " ")
check("a refusal names the line of the mark from the future",
    not pcall(viewer.read, slurp(TESTS .. "05-refused-future-mark.canvas"), "current")
    and select(2, pcall(viewer.read, slurp(TESTS .. "05-refused-future-mark.canvas"), "current"))
        == "current:11: this mark is from version 5, newer than the canvas's version 4")
check("a canvas meant for the voices is not one for viewers", not pcall(viewer.read,
    (string.gsub(slurp(TESTS .. "01-empty.canvas"), "voices: [^\n]*\n", ""))))
-- }}}

io.write("\n=== the kitten and dog canvases are real ===\n")
-- {{{
-- Made again here by the change finder (104), the blit (106) and the marks
-- (201), and written as viewers receive them (102).
local function blank_record(rows)
    local made = canvas.blank(24, 2, "for-viewers")
    for number, row in ipairs(rows) do made.rows[number] = row .. string.rep(" ", 24 - #row) end
    return made
end
local function viewers_text(record, version)
    record.set = "for-viewers"
    record.headers = { canvas = version, mode = "newest",
        project = { name = "guide-feature", commit = "9f2c1e0" },
        written = "2026-11-05T10:00:00Z", voices = { "fg-sora-1", "fg-sora-2", "fg-sora-3" } }
    return canvas.write(record)
end
local mat = blank_record({ "the cat sat on the mat." })
local new2, report2 = blit.apply(mat, changes.find(mat, blank_record({ "the kitten  on the mat." })),
    "blank-whole")
new2.marks = marks.mark(mat, new2, report2, "fg-sora-1", 2, 12).marks
check("02-kitten.canvas is what the blitter makes", viewers_text(new2, 2)
    == slurp(TESTS .. "02-kitten.canvas"), viewers_text(new2, 2))
local new3, report3 = blit.apply(new2, changes.find(new2, blank_record({ "the dog     on the mat." })),
    "blank-whole")
new3.marks = marks.mark(new2, new3, report3, "fg-sora-2", 3, 12).marks
check("03-dog.canvas is what the blitter makes next", viewers_text(new3, 3)
    == slurp(TESTS .. "03-dog.canvas"), viewers_text(new3, 3))
-- }}}

io.write("\n=== the reader's other answers ===\n")
-- {{{
check("a screen smaller than the canvas gets an error naming both sizes",
    viewer.too_small(kitten, 20, 5) == "the canvas is 24x2; this screen is 20x5"
    and viewer.too_small(kitten, 24, 1) == "the canvas is 24x2; this screen is 24x1")
check("a screen the canvas fits gets none", viewer.too_small(kitten, 24, 2) == nil
    and viewer.too_small(kitten, 80, 25) == nil)
check("a voice's colour is its place in the voices header; kuvalu has none",
    viewer.colour_of(aging, "fg-sora-1") == 1 and viewer.colour_of(aging, "fg-sora-3") == 3
    and viewer.colour_of(aging, "kuvalu") == nil)
check("against itself, nothing changed", #viewer.changed(dog, dog) == 0)
check("against a canvas of another size, every letter is new",
    #viewer.changed(kitten, aging) == 18 and viewer.changed(kitten, aging)[1].was == nil)
local taller = viewer.read((string.gsub(string.gsub(slurp(TESTS .. "02-kitten.canvas"),
    "size: 24x2", "size: 24x3"), "\nmarks:", "\n\nmarks:")))
check("against a canvas as wide but taller, every letter is new too",
    #viewer.changed(kitten, taller) == 18 and #viewer.changed(taller, kitten) == 18)
local remarked = viewer.read((string.gsub(slurp(TESTS .. "03-dog.canvas"), "mark: [^\n]*\n", "")))
check("a change of marks alone is not a changed cell", #viewer.changed(remarked, dog) == 0
    and remarked.cells[1][5].mark == nil)
local overlap = viewer.read((string.gsub(slurp(TESTS .. "02-kitten.canvas"), "marks:\n",
    "marks:\nmark: 1 1 23 fg-sora-3 1 sentence\n")))
check("where mark lines overlap, the later line wins on the cells they share",
    overlap.cells[1][1].mark.voice == "fg-sora-1" and overlap.cells[1][4].mark.voice == "fg-sora-3"
    and overlap.cells[1][4].mark.age == 1)
-- }}}

io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
