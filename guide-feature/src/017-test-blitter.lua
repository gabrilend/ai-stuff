#!/usr/bin/env luajit
-- 017-test-blitter.lua
--
-- Drops a scripted series of voice canvases into the blitter's arrivals
-- folder: good edits, a stale base, a conflict, one of each kind of bad
-- arrival, a skipped turn, a temporary file, settings changed while it runs,
-- and the stop file. Checks the final canvas, every version in the history,
-- the refused folder, the log and the goodbye receipt. Then runs the real
-- program through scripts/run-blitter and stops it with a TERM signal.
--
-- For a general: the blitter is the one program every edit passes through.
-- This proves it takes edits in the order they came, keeps another voice's
-- later work, puts every bad arrival aside with a reason instead of losing it,
-- and says goodbye with counts that match what happened.
--
-- usage:
--   luajit 017-test-blitter.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local ffi = require("ffi")
ffi.cdef([[
int setenv(const char *name, const char *value, int overwrite);
int poll(void *fds, unsigned long nfds, int timeout);
]])

local blitter = dofile(DIR .. "/src/016-blitter.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
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

-- {{{ local function shell(), slurp(), write()
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
-- }}}

-- {{{ the throwaway project (as in 003)
local BASE = shell("mktemp -d")
local ROOT = BASE .. "/project/guide-feature"
shell("mkdir -p '" .. ROOT .. "/input' '" .. ROOT .. "/output' '"
    .. BASE .. "/exec' '" .. BASE .. "/shm'")
for _, link in ipairs({ "src", "libs", "scripts" }) do
    shell("ln -s '" .. DIR .. "/" .. link .. "' '" .. ROOT .. "/" .. link .. "'")
end
ffi.C.setenv("EXEC_TIER_ROOT", BASE .. "/exec", 1)
ffi.C.setenv("ARTIFACT_TIER_ROOT", BASE .. "/shm", 1)

local function settings_file(mode, rule)
    write(ROOT .. "/input/blitter", "canvas-size = 20x3\nmerge-mode = \"" .. mode
        .. "\"\ncollision-rule = \"" .. rule .. "\"\nmark-lifetime = 12\n"
        .. "project = \"guide-feature\"\nvoices = \"fg-sora-1 fg-sora-2 fg-sora-3\"\n")
end
settings_file("newest", "blank-whole")
local ARRIVALS = ROOT .. "/tmp/shared-memory/arrivals"
local REFUSED = ROOT .. "/tmp/shared-memory/arrivals-refused"
-- }}}

-- {{{ local function arrive()
-- One voice canvas dropped into the arrivals folder, written by 006 as a
-- voice would send it. `time` orders the arrivals.
local function voice_text(voice, turn, base, rows, size)
    local record = canvas.blank(size and size.width or 20, size and size.height or 3, "from-voice")
    record.headers = { voice = voice, turn = turn, base = base,
                       written = "2026-11-05T10:00:00Z" }
    for number, row in ipairs(rows) do record.rows[number] = row end
    return canvas.write(record)
end
local function arrive(name, text)
    write(ARRIVALS .. "/" .. name, text)
end
local function rows_now(b)
    local rows = {}
    for number, row in ipairs(b.current.rows) do rows[number] = (string.gsub(row, " +$", "")) end
    return table.concat(rows, "|")
end
-- }}}

-- {{{ a clock that counts
local minute = 0
local function clock()
    minute = minute + 1
    return string.format("2026-11-05T%02d:%02d:00Z", 10 + math.floor(minute / 60), minute % 60)
end
-- }}}

io.write("\n=== starting ===\n")
-- {{{
local b = blitter.new({ root = ROOT, clock = clock, wait = function() end })
check("it starts from an empty canvas, version 1", b.version == 1 and rows_now(b) == "||")
check("its folders are made", shell("ls -d '" .. ARRIVALS .. "' '" .. REFUSED .. "'")
    == ARRIVALS .. "\n" .. REFUSED)
check("nothing waiting, no stop: a step takes nothing", b:step() == false and b.version == 1)
-- }}}

io.write("\n=== a scripted series ===\n")
-- {{{
local EMPTY = { "", "", "" }
arrive("fg-sora-1-1000-a", voice_text("fg-sora-1", 1, 1, { "the cat sat.", "", "" }))
arrive("fg-sora-2-1001-b", voice_text("fg-sora-2", 1, 1, { "", "a dog ran.", "" }))
arrive("fg-sora-1-1002-c", voice_text("fg-sora-1", 2, 2, { "the kitten  .", "", "" }))
arrive("fg-sora-3-1003-d", voice_text("fg-sora-3", 1, 2, { "the     sat.", "", "" }))
b:step()
check("good edits become versions, oldest first", b.version == 4,
    "version " .. b.version)
check("a stale base still lands only its own change", b.history[3].rows[1]
    == "the cat sat.        " and b.history[3].rows[2] == "a dog ran.          ")
check("kitten over cat, under blank-whole, leaves no fragment of sat",
    rows_now(b) == "the kitten  .|a dog ran.|", rows_now(b))
check("a removal of a word another voice changed is a conflict, and no version",
    b.reports[4].report.counts.conflicts == 1 and b.reports[4].report.changed == false)
check("taken arrivals are deleted", shell("ls -A '" .. ARRIVALS .. "'") == "")
-- }}}

io.write("\n=== every kind of bad arrival is put aside with its reason ===\n")
-- {{{
arrive("nonsense", voice_text("fg-sora-1", 3, 4, EMPTY))
arrive("fg-sora-1-2001-a", "this is not a canvas\n")
arrive("fg-sora-2-2002-a", voice_text("fg-sora-1", 3, 4, EMPTY))
arrive("fg-sora-1-2003-a", voice_text("fg-sora-1", 2, 4, EMPTY))
arrive("fg-sora-1-2004-a", voice_text("fg-sora-1", 3, 99, EMPTY))
arrive("fg-sora-1-2005-a", voice_text("fg-sora-1", 3, 4, { "", "", "", "" },
    { width = 20, height = 4 }))
arrive(".fg-sora-1-2006-a", "still being written")
b:step()
local refused = shell("ls -A '" .. REFUSED .. "'")
check("each bad arrival is moved, not dropped",
    refused == "fg-sora-1-2001-a\nfg-sora-1-2003-a\nfg-sora-1-2004-a\nfg-sora-1-2005-a\n"
        .. "fg-sora-2-2002-a\nnonsense", refused)
check("a file still being written is left alone",
    shell("ls -A '" .. ARRIVALS .. "'") == ".fg-sora-1-2006-a")
local c = b.run.counters
check("each reason is counted", c["refused-bad-name"] == 1 and c["refused-unreadable"] == 1
    and c["refused-wrong-sender"] == 1 and c["refused-turn-not-newer"] == 1
    and c["refused-base-not-in-history"] == 1 and c["refused-wrong-size"] == 1)
check("and no version was made", b.version == 4)
local log = slurp(ROOT .. "/tmp/shared-memory/blitter.log")
check("each refusal's log line names the reason", string.find(log,
    "refused fg-sora-2-2002-a (wrong-sender): sent by fg-sora-2, but its voice: header says "
    .. "fg-sora-1", 1, true) and string.find(log, "refused fg-sora-1-2005-a (wrong-size): "
    .. "the canvas has 4 rows; it must have exactly 3", 1, true)
    and string.find(log, "(unreadable): fg-sora-1-2001-a:1: expected a header line", 1, true)
    and string.find(log, "(base-not-in-history): base 99 is not in the history "
    .. "(versions 1 to 4)", 1, true), log)
-- }}}

io.write("\n=== while it runs ===\n")
-- {{{
os.remove(ARRIVALS .. "/.fg-sora-1-2006-a")
arrive("fg-sora-2-3000-a", voice_text("fg-sora-2", 4, 4,
    { "the kitten  .", "a cow ran.", "" }))
b:step()
check("a jump in a voice's turns counts the turns rmail skipped",
    b.run.counters["turns-skipped"] == 2 and b.version == 5)

settings_file("newest", "keep-fragments")
arrive("fg-sora-3-3001-a", voice_text("fg-sora-3", 2, 5,
    { "the dog     .", "a cow ran.", "" }))
b:step()
check("a collision rule changed in input/blitter is used at the next arrival",
    rows_now(b) == "the dogten  .|a cow ran.|", rows_now(b))

write(ROOT .. "/input/blitter", "canvas-size = 20x3\nmerge-mode = newest\n")
arrive("fg-sora-1-3002-a", voice_text("fg-sora-1", 3, 6,
    { "the dogten  .", "a cow ran.", "end." }))
b:step()
check("a settings file that no longer reads keeps the last good settings",
    b.run.counters["settings-not-read"] == 1 and b.version == 7
    and b.settings["collision-rule"] == "keep-fragments")

settings_file("distill", "blank-whole")
arrive("fg-sora-2-3003-a", voice_text("fg-sora-2", 5, 7, { "x", "", "" }))
b:step()
check("a merge mode not built yet refuses the arrival rather than blit it",
    b.run.counters["refused-mode-not-built"] == 1 and b.version == 7)
settings_file("newest", "blank-whole")
-- }}}

io.write("\n=== the stop ===\n")
-- {{{
arrive("fg-sora-3-4000-a", voice_text("fg-sora-3", 3, 7,
    { "the dogten  .", "a cow ran.", "the end." }))
write(ARRIVALS .. "/stop", "")
check("the stop file is seen after the arrivals before it", b:step() == true
    and b.version == 8)
check("and removed", slurp(ARRIVALS .. "/stop") == nil)
local receipt_path = b:finish()
local receipt = goodbye.read(receipt_path)
local expected_counts = {
    ["arrivals-taken"] = 15, ["versions-made"] = 7, ["versions-in-history"] = 8,
    ["words-written"] = 13, ["removals-applied"] = 0, ["conflicts"] = 1,
    ["unchanged-turns"] = 1, ["turns-skipped"] = 2, ["cut-blanked"] = 2, ["cut-kept"] = 1,
    ["refused-bad-name"] = 1, ["refused-unreadable"] = 1, ["refused-wrong-sender"] = 1,
    ["refused-turn-not-newer"] = 1, ["refused-base-not-in-history"] = 1,
    ["refused-wrong-size"] = 1, ["refused-mode-not-built"] = 1, ["settings-not-read"] = 1,
}
local wrong = {}
for name, value in pairs(expected_counts) do
    if receipt.counters[name] ~= value then
        wrong[#wrong + 1] = name .. "=" .. tostring(receipt.counters[name]) .. " not " .. value
    end
end
for name in pairs(receipt.counters) do
    -- words-covered is the blit's (015); the marks' counters are 201's (021)
    if expected_counts[name] == nil and name ~= "words-covered"
        and not string.match(name, "^cells%-marked%-") and name ~= "marks-expired" then
        wrong[#wrong + 1] = name .. " not expected"
    end
end
check("the goodbye receipt counts what happened", #wrong == 0, table.concat(wrong, "; "))
local final_log = slurp(ROOT .. "/tmp/shared-memory/blitter.log")
check("the log publisher wrote the last version, row by row",
    string.find(final_log, "version 8:\n[^\n]* | the dogten  .\n[^\n]* | a cow ran.\n"
        .. "[^\n]* | the end.\n", 1, false) ~= nil, final_log)
check("the log says how it waits", string.find(final_log, "waiting for arrivals", 1, true))
-- }}}

io.write("\n=== the real program, stopped by a signal ===\n")
-- {{{
write(ROOT .. "/input/to-voices", 'send = "off"\nmailbox = "~/guide-mail"\n'
    .. 'tell-the-voice = "off"\nendpoint = "none none"\nproject-checkout = "."\n')
local pid = shell("cd '" .. ROOT .. "' && (scripts/run-blitter '" .. ROOT
    .. "' > /dev/null 2>&1 & echo $!)")
local function wait_until(test, seconds)
    for _ = 1, seconds * 10 do
        if test() then return true end
        ffi.C.poll(nil, 0, 100)
    end
    return test()
end
check("it starts and says hello in its log", wait_until(function()
    local text = slurp(ROOT .. "/tmp/shared-memory/blitter.log") or ""
    local _, starts = string.gsub(text, " started", "")
    return starts == 2
end, 10))
-- The first run ended at version 8, so this run numbers on from 9 (203).
arrive("fg-sora-1-5000-a", voice_text("fg-sora-1", 1, 9, { "hello.", "", "" }))
check("it takes an arrival within a couple of seconds", wait_until(function()
    return slurp(ARRIVALS .. "/fg-sora-1-5000-a") == nil
end, 5))
shell("kill -TERM " .. pid)
check("a TERM signal stops it cleanly, with a goodbye", wait_until(function()
    local again = goodbye.read(ROOT .. "/output/goodbye-blitter")
    return again ~= nil and again.counters["versions-made"] == 1
end, 5))
check("the previous run's receipt was kept beside it",
    goodbye.read(ROOT .. "/output/goodbye-blitter.previous").counters["arrivals-taken"] == 15)
check("the wrapper has ended", wait_until(function()
    return shell("kill -0 " .. pid .. " 2>/dev/null && echo alive") == ""
end, 3))
-- }}}

shell("rm -rf '" .. BASE .. "'")
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
