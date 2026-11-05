#!/usr/bin/env luajit
-- 024-test-canvas-files.lua
--
-- Replays the phase-1 series (018) through the blitter on a throwaway
-- project and checks the canvas files it leaves for viewers
-- (docs/canvas-protocol.md, "On kuvalu: files"): every version in history/
-- with no gaps, never rewritten, each a canvas viewers can read with its
-- marks; `current` the same text as the last. Then that the blitter takes its
-- bases from those files, and what a restart does: the folder emptied, the
-- numbering carried on, and a voice's base from before refused.
--
-- For a general: these files are what every screen on kuvalu reads, and what
-- the HTTP server (204) hands to screens elsewhere. This proves each version
-- is there, whole, and the same everywhere.
--
-- usage:
--   luajit 024-test-canvas-files.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")

local blitter = dofile(DIR .. "/src/016-blitter.lua")
local series = dofile(DIR .. "/src/018-phase-1-series.lua")
local viewer = dofile(DIR .. "/src/022-viewer.lua")
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

-- {{{ helpers and the throwaway project (as in 017)
local function shell(command)
    local pipe = io.popen(command .. " 2>&1")
    local text = pipe:read("*a")
    pipe:close()
    return (string.gsub(text, "\n$", ""))
end
local function slurp(path)
    local handle = io.open(path, "r")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
local function write(path, text)
    local handle = assert(io.open(path, "w"))
    handle:write(text)
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
write(ROOT .. "/input/blitter", series.SETTINGS)
local ARRIVALS = ROOT .. "/tmp/shared-memory/arrivals"
local CANVAS = ROOT .. "/tmp/shared-memory/canvas"
local LOG = ROOT .. "/tmp/shared-memory/blitter.log"

local function voice_text(voice, turn, base, rows)
    local made = canvas.blank(series.WIDTH, series.HEIGHT, "from-voice")
    made.headers = { voice = voice, turn = turn, base = base, written = "2026-11-05T10:00:00Z" }
    for number, row in ipairs(rows) do made.rows[number] = row end
    return canvas.write(made)
end
-- }}}

io.write("\n=== a replay of the phase-1 series ===\n")
-- {{{
local b = blitter.new({ root = ROOT, commit = "abc1234", wait = function() end })
for number = 1, #series.ROUNDS do
    local versions = {}
    for version = 1, b.version do versions[version] = b.history[version].rows end
    for _, one in ipairs(series.arrivals(number, versions, b.version)) do
        write(ARRIVALS .. "/" .. one.name, one.text)
    end
    b:step()
end
check("the series makes versions 1 to 8", b.version == 8, b.version)

local names = shell("ls -A '" .. CANVAS .. "/history'")
check("history/ holds every version, six digits, no gaps, nothing else",
    names == "000001\n000002\n000003\n000004\n000005\n000006\n000007\n000008", names)
check("no file is left half written: the canvas folder holds current and history only",
    shell("ls -A '" .. CANVAS .. "'") == "current\nhistory")
check("current is the last version, byte for byte",
    slurp(CANVAS .. "/current") == slurp(CANVAS .. "/history/000008"))
check("and is the blitter's own current canvas, written for viewers",
    slurp(CANVAS .. "/current") == canvas.write(b.current, "for-viewers"))

local all_read, numbered, headed = true, true, true
local views = {}
for version = 1, 8 do
    local ok, view = pcall(viewer.read, slurp(string.format("%s/history/%06d", CANVAS, version)))
    if not ok then all_read = false else
        views[version] = view
        if view.version ~= version then numbered = false end
        if view.headers.project.name ~= "guide-feature" or view.headers.project.commit ~= "abc1234"
            or table.concat(view.voices, " ") ~= "fg-sora-1 fg-sora-2 fg-sora-3"
            or view.headers.mode ~= "newest" then
            headed = false
        end
    end
end
check("every history file is a canvas viewers can read (022)", all_read)
check("each says its own version", numbered)
check("each has the viewers' headers: project and commit, mode, voices", headed)
check("the files carry the marks (201)", views[5] and views[5].cells[1][5].mark ~= nil
    and views[5].cells[1][5].mark.voice == "fg-sora-1" and views[5].cells[1][5].mark.kind == "word")
check("version 1, the empty canvas, has no marks", views[1] and #views[1].record.marks == 0)
check("the rows in the files are the canvas: the last version's first row",
    views[8] and views[8].record.rows[1] == "the dog     on the mat."
        .. string.rep(" ", series.WIDTH - 23))
-- }}}

io.write("\n=== the history is the blitter's memory ===\n")
-- {{{
check("no version is held in memory: b.history reads its file each time",
    rawget(b.history, 3) == nil and b.history[3].rows[3] == "it was a windy day."
        .. string.rep(" ", series.WIDTH - 19))
check("a version not in history is nil", b.history[9] == nil and b.history[0] == nil)
check("a history file is never rewritten", not pcall(b.write_files, b, b.current)
    and select(2, pcall(b.write_files, b, b.current)):find("never rewritten", 1, true) ~= nil)
os.remove(CANVAS .. "/history/000004")
write(ARRIVALS .. "/fg-sora-3-2000-a", voice_text("fg-sora-3", 9, 4, { "x" }))
b:step()
check("a base is looked up in its file: with history/000004 gone, base 4 is refused",
    slurp(ROOT .. "/tmp/shared-memory/arrivals-refused/fg-sora-3-2000-a") ~= nil
    and b.run.counters["refused-base-not-in-history"] == 1)
check("the refusal names the versions this run has",
    string.find(slurp(LOG), "base 4 is not in the history (versions 1 to 8)", 1, true) ~= nil)
b:finish()
-- }}}

io.write("\n=== a restart ===\n")
-- {{{
-- With the number on disk lost, the previous run's `current` still says 8.
os.remove(ROOT .. "/output/blitter-version")
local again = blitter.new({ root = ROOT, wait = function() end })
check("the new run numbers on from current: its empty canvas is version 9", again.version == 9
    and again.first_version == 9)
check("the previous run's files are gone; history starts at 000009",
    shell("ls -A '" .. CANVAS .. "/history'") == "000009")
check("current is the empty version 9", viewer.read(slurp(CANVAS .. "/current")).version == 9
    and #viewer.changed(viewer.read(slurp(CANVAS .. "/current"))) == 0)
check("the log says where the previous run ended",
    string.find(slurp(LOG), "the previous run ended at version 8; its canvas files are removed, "
        .. "and this run starts at version 9", 1, true) ~= nil)
check("outside a git checkout the commit is written as 0000000, and logged",
    again.current.headers.project.commit == "0000000"
    and string.find(slurp(LOG), "is not a git checkout", 1, true) ~= nil)
write(ARRIVALS .. "/fg-sora-1-3000-a", voice_text("fg-sora-1", 9, 7, { "the end." }))
write(ARRIVALS .. "/fg-sora-2-3001-b", voice_text("fg-sora-2", 9, 9, { "a new start." }))
again:step()
check("a voice's base from before the restart is refused, never taken for a new version",
    slurp(ROOT .. "/tmp/shared-memory/arrivals-refused/fg-sora-1-3000-a") ~= nil
    and string.find(slurp(LOG), "base 7 is not in the history (versions 9 to 9)", 1, true) ~= nil)
check("a voice on the new run's version is taken: version 10",
    again.version == 10 and viewer.read(slurp(CANVAS .. "/current")).version == 10
    and slurp(CANVAS .. "/history/000010") == slurp(CANVAS .. "/current"))
local receipt = dofile(DIR .. "/src/002-goodbye.lua").read(again:finish())
check("the receipt counts this run's versions only", receipt.counters["versions-in-history"] == 2
    and receipt.counters["versions-made"] == 1)
check("the last version's number is kept on disk too", slurp(ROOT .. "/output/blitter-version")
    == "10\n")
-- }}}

io.write("\n=== a reboot ===\n")
-- {{{
-- A reboot empties the RAM tiers: the canvas folder is gone with them.
shell("rm -rf '" .. BASE .. "/shm/'*")
local rebooted = blitter.new({ root = ROOT, wait = function() end })
check("after a reboot the numbering still carries on, from the disk: version 11",
    rebooted.version == 11 and shell("ls -A '" .. CANVAS .. "/history'") == "000011",
    rebooted.version)
rebooted:finish()
-- }}}

shell("rm -rf '" .. BASE .. "'")
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
