#!/usr/bin/env luajit
-- 021-test-marks.lua
--
-- Marks real blits (104, 106) and checks every mark run: a one-word change
-- marks that word and its sentence; a newer change by another voice replaces
-- part of an older sentence mark; the document's kitten example; erased
-- words and the sentences their blank cells belong to; marks expiring; orphan
-- marks; and marks through the canvas text and back. Then runs the blitter on
-- a throwaway project and checks the marks on its versions, its log and its
-- receipt.
--
-- For a general: marks are how a person skims the canvas and sees what each
-- voice just changed. This proves the right words and sentences light up, in
-- the right voice, and that they fade as the canvas moves on.
--
-- usage:
--   luajit 021-test-marks.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")

local marks = dofile(DIR .. "/src/020-marks.lua")
local blit = dofile(DIR .. "/src/014-blit.lua")
local changes = dofile(DIR .. "/src/010-changes.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
local blitter = dofile(DIR .. "/src/016-blitter.lua")
local goodbye = dofile(DIR .. "/src/002-goodbye.lua")

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
local WIDTH = 30
local function record(rows, height, run_marks)
    local made = canvas.blank(WIDTH, height or #rows, "to-voices")
    for number, row in ipairs(rows) do made.rows[number] = row .. string.rep(" ", WIDTH - #row) end
    made.marks = run_marks or {}
    return made
end
-- The blit of base -> voice onto current (with its marks), then the marks:
-- returns the new record (marks set), the mark result.
local function step(current, base, voice_rows, voice, version, lifetime)
    local height = #current.rows
    local found = changes.find(record(base, height), record(voice_rows, height))
    local new, report = blit.apply(current, found, "blank-whole")
    local result = marks.mark(current, new, report, voice, version, lifetime or 12)
    new.marks = result.marks
    return new, result
end
-- Whether any run is on a row.
local function on_row(runs, row)
    for _, run in ipairs(runs) do
        if run.row == row then return true end
    end
    return false
end
-- Runs as "row:column:length:voice:version:kind", space-separated.
local function show(runs)
    local parts = {}
    for _, run in ipairs(runs) do
        parts[#parts + 1] = string.format("%d:%d:%d:%s:%d:%s", run.row, run.column,
            run.length, run.voice, run.version, run.kind)
    end
    return table.concat(parts, " ")
end
-- }}}

io.write("\n=== a one-word change ===\n")
-- {{{
local start = record({ "the cat sat. a dog ran." })
local cow, cow_result = step(start, start.rows, { "the cow sat. a dog ran." }, "fg-sora-1", 2)
check("marks the word as written and the rest of its sentence, nothing else",
    show(cow.marks) == "1:1:3:fg-sora-1:2:sentence 1:5:3:fg-sora-1:2:word "
        .. "1:9:4:fg-sora-1:2:sentence", show(cow.marks))
check("and counts cells, not runs: 3 word, 7 sentence, none expired",
    cow_result.counts.word == 3 and cow_result.counts.sentence == 7
    and cow_result.counts.expired == 0 and cow_result.counts.orphan == 0)
check("the spaces between words are not marked as part of the sentence",
    marks.grid(cow)[1][4] == nil and marks.grid(cow)[1][8] == nil)
-- }}}

io.write("\n=== a newer change replaces part of an older sentence mark ===\n")
-- {{{
local two = record({ "the cat sat on", "the big mat." })
local first = step(two, two.rows, { "the cow sat on", "the big mat." }, "fg-sora-1", 2)
check("a sentence across two rows is marked on both",
    show(first.marks) == "1:1:3:fg-sora-1:2:sentence 1:5:3:fg-sora-1:2:word "
        .. "1:9:3:fg-sora-1:2:sentence 1:13:2:fg-sora-1:2:sentence "
        .. "2:1:3:fg-sora-1:2:sentence 2:5:3:fg-sora-1:2:sentence "
        .. "2:9:4:fg-sora-1:2:sentence", show(first.marks))
local second = step(first, first.rows, { "the cow sat ok.", "the big mat." }, "fg-sora-2", 3)
check("another voice ends the sentence early: its part is the newer voice's, "
    .. "the rest keeps the older marks",
    show(second.marks) == "1:1:3:fg-sora-2:3:sentence 1:5:3:fg-sora-2:3:sentence "
        .. "1:9:3:fg-sora-2:3:sentence 1:13:3:fg-sora-2:3:word "
        .. "2:1:3:fg-sora-1:2:sentence 2:5:3:fg-sora-1:2:sentence "
        .. "2:9:4:fg-sora-1:2:sentence", show(second.marks))
check("the older word mark on cow is replaced by the newer sentence mark",
    marks.grid(second)[1][5].voice == "fg-sora-2" and marks.grid(second)[1][5].kind == "sentence")
-- }}}

io.write("\n=== the document's example ===\n")
-- {{{
local mat = record({ "the cat sat on the mat." })
local kitten, kitten_result = step(mat, mat.rows, { "the kitten  on the mat." }, "fg-sora-1", 2)
check("kitten and the blanked t of sat are one word run; the rest is its sentence",
    show(kitten.marks) == "1:1:3:fg-sora-1:2:sentence 1:5:7:fg-sora-1:2:word "
        .. "1:13:2:fg-sora-1:2:sentence 1:16:3:fg-sora-1:2:sentence "
        .. "1:20:4:fg-sora-1:2:sentence", show(kitten.marks))
check("the blanked cell is counted as a word cell", kitten_result.counts.word == 7)
local dog = step(kitten, kitten.rows, { "the dog     on the mat." }, "fg-sora-2", 3)
check("dog over kitten: the cells written and blanked are fg-sora-2's at version 3; "
    .. "the cell blank since version 2 keeps its older mark",
    string.find(show(dog.marks), "1:5:6:fg-sora-2:3:word 1:11:1:fg-sora-1:2:word", 1, true) ~= nil,
    show(dog.marks))
-- }}}

io.write("\n=== erased words, and whose sentence their cells are ===\n")
-- {{{
local door = record({ "the cat sat.", "a dog slept by the door.", "it ran." })
local middle = step(door, door.rows, { "the cat sat.", "a dog       by the door.", "it ran." },
    "fg-sora-1", 2)
check("a word erased mid-sentence: the sentence around it",
    show(middle.marks) == "2:1:1:fg-sora-1:2:sentence 2:3:3:fg-sora-1:2:sentence "
        .. "2:7:5:fg-sora-1:2:word 2:13:2:fg-sora-1:2:sentence 2:16:3:fg-sora-1:2:sentence "
        .. "2:20:5:fg-sora-1:2:sentence", show(middle.marks))
local opening = step(door, door.rows, { "the cat sat.", "  dog slept by the door.", "it ran." },
    "fg-sora-1", 2)
check("a sentence's first word erased: the sentence after, not the one before",
    not on_row(opening.marks, 1)
    and string.find(show(opening.marks), "2:1:1:fg-sora-1:2:word 2:3:3:fg-sora-1:2:sentence",
        1, true) == 1, show(opening.marks))
local ending = step(door, door.rows, { "the cat sat.", "a dog slept by the", "it ran." },
    "fg-sora-1", 2)
check("a sentence's last word erased: it runs on into the next, all marked",
    string.find(show(ending.marks), "2:20:5:fg-sora-1:2:word", 1, true) ~= nil
    and string.find(show(ending.marks), "3:1:2:fg-sora-1:2:sentence 3:4:4:fg-sora-1:2:sentence",
        1, true) ~= nil
    and not on_row(ending.marks, 1), show(ending.marks))
local mid = record({ "the cat sat. a dog ran." })
local after_stop = step(mid, mid.rows, { "the cat sat.   dog ran." }, "fg-sora-1", 2)
check("a word erased just after a full stop: the sentence after it, not the one before",
    show(after_stop.marks) == "1:14:1:fg-sora-1:2:word 1:16:3:fg-sora-1:2:sentence "
        .. "1:20:4:fg-sora-1:2:sentence", show(after_stop.marks))
local rows3 = record({ "go.", "now.", "stop." })
local alone = step(rows3, rows3.rows, { "go.", "", "stop." }, "fg-sora-1", 2)
check("a word erased leaving its row empty: its cells alone are marked",
    show(alone.marks) == "2:1:4:fg-sora-1:2:word", show(alone.marks))
-- }}}

io.write("\n=== marks expire ===\n")
-- {{{
local tall = record({ "the cat sat.", "", "" })
local v2 = step(tall, tall.rows, { "the cow sat.", "", "" }, "fg-sora-1", 2, 2)
local v3 = step(v2, v2.rows, { "the cow sat.", "a dog.", "" }, "fg-sora-2", 3, 2)
local v4, r4 = step(v3, v3.rows, { "the cow sat.", "a dog.", "go." }, "fg-sora-3", 4, 2)
check("with a lifetime of 2, a mark two versions old stays",
    string.find(show(v4.marks), "1:5:3:fg-sora-1:2:word", 1, true) ~= nil and r4.counts.expired == 0)
local v5, r5 = step(v4, v4.rows, { "the cow sat.", "a dog.", "go on." }, "fg-sora-1", 5, 2)
check("and is dropped once it is three: its 10 cells counted as expired",
    string.find(show(v5.marks), ":2:", 1, true) == nil and r5.counts.expired == 10,
    show(v5.marks) .. " / " .. r5.counts.expired)
check("the newer marks stay",
    string.find(show(v5.marks), "2:1:1:fg-sora-2:3:word 2:3:4:fg-sora-2:3:word", 1, true) == 1,
    show(v5.marks))
local zero = step(v2, v2.rows, { "the cow sat.", "a dog.", "" }, "fg-sora-2", 3, 0)
check("with a lifetime of 0 a mark lasts only for its own version",
    show(zero.marks) == "2:1:1:fg-sora-2:3:word 2:3:4:fg-sora-2:3:word", show(zero.marks))
check("a mark's age is the version minus its version",
    marks.age({ version = 4 }, 9) == 5 and marks.age({ version = 9 }, 9) == 0)
check("a lifetime that is not a whole number of versions is refused",
    not pcall(marks.mark, tall, tall, {}, "fg-sora-1", 2, -1)
    and not pcall(marks.mark, tall, tall, {}, "fg-sora-1", 2, 1.5)
    and not pcall(marks.mark, tall, tall, {}, "fg-sora-1", 2, nil))
-- }}}

io.write("\n=== orphans ===\n")
-- {{{
-- No collision rule built yet leaves fragments to fade, so a report with
-- orphan cells stands in for fade-fragments.
local frag = record({ "ab cd" })
local orphaned = marks.mark(frag, frag, { orphans = { { row = 1, column = 4 }, { row = 1, column = 5 } } },
    "fg-sora-1", 2, 1)
check("orphan cells get orphan marks, in the voice that cut them",
    show(orphaned.marks) == "1:4:2:fg-sora-1:2:orphan" and orphaned.counts.orphan == 2)
frag.marks = orphaned.marks
local later = marks.mark(frag, frag, {}, "fg-sora-2", 4, 1)
check("an orphan mark that runs out is listed, for its cells to be blanked",
    #later.expired_orphans == 2 and later.expired_orphans[1].column == 4
    and later.counts.expired == 2 and #later.marks == 0)
-- }}}

io.write("\n=== through the canvas text ===\n")
-- {{{
kitten.headers = { canvas = 2, mode = "newest", project = { name = "guide-feature", commit = "abc123" },
    endpoint = { name = "voice-small", address = "http://192.168.1.100:20166" },
    written = "2026-11-05T10:00:00Z" }
local text = canvas.write(kitten)
check("the marks are written as mark lines",
    string.find(text, "\nmark: 1 5 7 fg-sora-1 2 word\n", 1, true) ~= nil, text)
local back = canvas.read(text, "to-voices")
check("and read back to the same runs", show(back.marks) == show(kitten.marks))
local grid = marks.grid(back)
check("runs to a grid and back give the same runs",
    show(marks.runs(grid, WIDTH, 1)) == show(kitten.marks))
check("cells of different voices next to each other are separate runs",
    show(marks.runs({ { { voice = "a", version = 1, kind = "word" },
        { voice = "b", version = 1, kind = "word" } } }, 2, 1)) == "1:1:1:a:1:word 1:2:1:b:1:word")
-- }}}

io.write("\n=== in the blitter ===\n")
-- {{{
local function shell(command)
    local pipe = io.popen(command .. " 2>&1")
    local out = pipe:read("*a")
    pipe:close()
    return (string.gsub(out, "\n$", ""))
end
local function write(path, body)
    local handle = assert(io.open(path, "w"))
    handle:write(body)
    handle:close()
end
local BASE = shell("mktemp -d")
local ROOT = BASE .. "/project/guide-feature"
shell("mkdir -p '" .. ROOT .. "/input' '" .. ROOT .. "/output' '" .. BASE .. "/exec' '"
    .. BASE .. "/shm'")
for _, link in ipairs({ "src", "libs", "scripts" }) do
    shell("ln -s '" .. DIR .. "/" .. link .. "' '" .. ROOT .. "/" .. link .. "'")
end
ffi.C.setenv("EXEC_TIER_ROOT", BASE .. "/exec", 1)
ffi.C.setenv("ARTIFACT_TIER_ROOT", BASE .. "/shm", 1)
write(ROOT .. "/input/blitter", "canvas-size = 20x3\nmerge-mode = \"newest\"\n"
    .. "collision-rule = \"blank-whole\"\nmark-lifetime = 1\n"
    .. "project = \"guide-feature\"\nvoices = \"fg-sora-1 fg-sora-2 fg-sora-3\"\n")
local ARRIVALS = ROOT .. "/tmp/shared-memory/arrivals"
local function voice_text(voice, turn, base, rows)
    local made = canvas.blank(20, 3, "from-voice")
    made.headers = { voice = voice, turn = turn, base = base, written = "2026-11-05T10:00:00Z" }
    for number, row in ipairs(rows) do made.rows[number] = row end
    return canvas.write(made)
end

local b = blitter.new({ root = ROOT, wait = function() end })
check("version 1, the empty canvas, has no marks", #b.history[1].marks == 0)
write(ARRIVALS .. "/fg-sora-1-1000-a", voice_text("fg-sora-1", 1, 1, { "the cat sat.", "", "" }))
write(ARRIVALS .. "/fg-sora-2-1001-b", voice_text("fg-sora-2", 1, 2, { "the cat sat.", "a dog.", "" }))
write(ARRIVALS .. "/fg-sora-3-1002-c", voice_text("fg-sora-3", 1, 3,
    { "the cat sat.", "a dog.", "go." }))
b:step()
check("each version carries its marks", b.version == 4
    and show(b.history[2].marks) == "1:1:3:fg-sora-1:2:word 1:5:3:fg-sora-1:2:word "
        .. "1:9:4:fg-sora-1:2:word"
    and string.find(show(b.history[3].marks), "2:1:1:fg-sora-2:3:word", 1, true) ~= nil,
    show(b.history[3].marks))
check("with a lifetime of 1, version 2's marks are gone from version 4",
    show(b.history[4].marks) == "2:1:1:fg-sora-2:3:word 2:3:4:fg-sora-2:3:word "
        .. "3:1:3:fg-sora-3:4:word", show(b.history[4].marks))
check("and the earlier versions are not changed by it", #b.history[2].marks == 3)
local log = io.open(ROOT .. "/tmp/shared-memory/blitter.log"):read("*a")
check("each version's marks are counted in the log",
    string.find(log, "marks: 10 cells word, 0 cells sentence, 0 expired, 3 runs", 1, true) ~= nil
    and string.find(log, "marks: 3 cells word, 0 cells sentence, 10 expired, 3 runs", 1, true) ~= nil,
    log)
local receipt = goodbye.read(b:finish())
check("and in the receipt: cells marked word and sentence, marks expired",
    receipt.counters["cells-marked-word"] == 18 and receipt.counters["cells-marked-sentence"] == 0
    and receipt.counters["marks-expired"] == 10)
shell("rm -rf '" .. BASE .. "'")
-- }}}

io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
