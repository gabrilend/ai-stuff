#!/usr/bin/env luajit
-- 004-test-goodbye.lua
--
-- Starts a program's run, counts, logs and says goodbye; reads the receipt
-- back and checks every line. Then the things around it: the last receipt
-- moved aside at the next start, a crash leaving no receipt, two receipts
-- compared with diff, and the names and numbers a receipt refuses.
--
-- For a general: when a program stops, its receipt says what it did. When a
-- program dies, there is no receipt, and that absence is the report. This
-- proves both, so nobody mistakes a dead program's old receipt for a new one.
--
-- usage:
--   luajit 004-test-goodbye.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local ffi = require("ffi")
ffi.cdef("int setenv(const char *name, const char *value, int overwrite);")

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

-- {{{ local function refused()
local function refused(name, part, fn)
    local ok, message = pcall(fn)
    check(name, not ok and string.find(tostring(message), part, 1, true) ~= nil,
        ok and "it was accepted" or message)
end
-- }}}

-- {{{ local function shell()
local function shell(command)
    local pipe = io.popen(command .. " 2>&1")
    local text = pipe:read("*a")
    pipe:close()
    return (string.gsub(text, "\n$", ""))
end
-- }}}

-- {{{ local function slurp()
local function slurp(path)
    local handle = io.open(path, "r")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
-- }}}

-- {{{ the throwaway project (as in 003)
local BASE = shell("mktemp -d")
local ROOT = BASE .. "/project/guide-feature"
shell("mkdir -p '" .. ROOT .. "/input' '" .. ROOT .. "/output' '"
    .. BASE .. "/exec' '" .. BASE .. "/shm'")
shell("ln -s '" .. DIR .. "/src' '" .. ROOT .. "/src'")
shell("ln -s '" .. DIR .. "/libs' '" .. ROOT .. "/libs'")
ffi.C.setenv("EXEC_TIER_ROOT", BASE .. "/exec", 1)
ffi.C.setenv("ARTIFACT_TIER_ROOT", BASE .. "/shm", 1)
local RECEIPT = ROOT .. "/output/goodbye-blitter"
local LOG = ROOT .. "/tmp/shared-memory/blitter.log"
-- }}}

-- {{{ a clock that counts, so each line's time is known
local function clock_from(minute)
    return function()
        minute = minute + 1
        return string.format("2026-11-05T10:%02d:00Z", minute)
    end
end
-- }}}

io.write("\n=== a run, start to goodbye ===\n")
-- {{{
local run = goodbye.start("blitter", { root = ROOT, seed = 1234, clock = clock_from(0) })
check("starting makes the RAM tiers, for the log",
    shell("readlink '" .. ROOT .. "/tmp'") == BASE .. "/exec/guide-feature")
run:log("watching arrivals by listing")
check("count starts a counter at one", run:count("arrivals-taken") == 1)
run:count("arrivals-taken")
run:count("words-written", 7)
run:count("words-blanked", 0)
check("no receipt while running", slurp(RECEIPT) == nil)
local written = run:finish()
check("finish says where the receipt went", written == RECEIPT)

local expected = table.concat({
    "program: blitter",
    "ended: 2026-11-05T10:03:00Z",
    "seed: 1234",
    "arrivals-taken: 2",
    "words-blanked: 0",
    "words-written: 7",
}, "\n") .. "\n"
check("the receipt is the head, then the counters sorted", slurp(RECEIPT) == expected,
    slurp(RECEIPT))
check("nothing half-written is left beside it", slurp(RECEIPT .. ".partial") == nil)

local back = goodbye.read(RECEIPT)
check("it reads back into a table", back.program == "blitter" and back.seed == 1234
    and back.ended == "2026-11-05T10:03:00Z" and back.counters["words-written"] == 7
    and back.counters["words-blanked"] == 0)

local log = slurp(LOG) or ""
check("the log has the start, what was said, and the end, each timed",
    log == "2026-11-05T10:01:00Z started with seed 1234\n"
        .. "2026-11-05T10:02:00Z watching arrivals by listing\n"
        .. "2026-11-05T10:04:00Z ended; goodbye written to output/goodbye-blitter\n", log)
refused("goodbye is said once", "already said goodbye", function() run:finish() end)
-- }}}

io.write("\n=== the next run ===\n")
-- {{{
local second = goodbye.start("blitter", { root = ROOT, clock = clock_from(20) })
check("the last receipt is moved aside as the next run starts",
    slurp(RECEIPT) == nil and slurp(RECEIPT .. ".previous") == expected)
second:count("arrivals-taken", 3)
second:count("words-written", 7)
second:finish()
local difference = shell("diff '" .. RECEIPT .. ".previous' '" .. RECEIPT .. "'")
check("two receipts compare with diff, line by line",
    string.find(difference, "< arrivals-taken: 2\n", 1, true) ~= nil
    and string.find(difference, "> arrivals-taken: 3", 1, true) ~= nil
    and string.find(difference, "words-written", 1, true) == nil, difference)
check("a run with no seed has no seed line", goodbye.read(RECEIPT).seed == nil
    and not string.find(slurp(RECEIPT), "seed", 1, true))
check("the log keeps both runs", select(2, string.gsub(slurp(LOG), " started", "")) == 2)
-- }}}

io.write("\n=== a crash ===\n")
-- {{{
local crash = shell("cd '" .. ROOT .. "' && EXEC_TIER_ROOT='" .. BASE .. "/exec' "
    .. "ARTIFACT_TIER_ROOT='" .. BASE .. "/shm' luajit -e \""
    .. "local g = dofile('" .. ROOT .. "/src/002-goodbye.lua'); "
    .. "local r = g.start('blitter', { root = '" .. ROOT .. "' }); "
    .. "r:count('arrivals-taken'); error('the blitter fell over')\" 2>&1; echo exit=$?")
check("a program that crashes ends badly", string.find(crash, "exit=1", 1, true) ~= nil, crash)
check("and leaves no receipt: the missing goodbye is the crash report",
    slurp(RECEIPT) == nil)
check("the last good receipt is still there to compare",
    goodbye.read(RECEIPT .. ".previous").counters["arrivals-taken"] == 3)
local log_after = slurp(LOG)
check("its log shows a start with no end after it",
    string.match(log_after, "started\n$") ~= nil, log_after)
-- }}}

io.write("\n=== what a receipt refuses ===\n")
-- {{{
local third = goodbye.start("blitter", { root = ROOT })
refused("a counter named like a head line", "cannot be a counter's name",
    function() third:count("ended") end)
refused("a counter with a space", "cannot be a counter's name",
    function() third:count("words written") end)
refused("a counter going down", "only grows", function() third:count("x", -1) end)
refused("a counter growing by a fraction", "only grows", function() third:count("x", 0.5) end)
refused("a seed that is not whole", "seed must be a whole number",
    function() goodbye.start("blitter", { root = ROOT, seed = 1.5 }) end)
refused("a program name that is not a name", "is not a program's name",
    function() goodbye.start("../blitter", { root = ROOT }) end)
refused("format refuses a negative counter", "zero or more", function()
    goodbye.format({ program = "x", ended = "now", counters = { y = -2 } })
end)
refused("a damaged receipt is noticed", "not a `name: value` line", function()
    goodbye.parse("program: blitter\nhalf a line\n", "output/goodbye-blitter")
end)
check("no receipt reads as nil", goodbye.read(ROOT .. "/output/goodbye-nobody") == nil)
third:finish()
check("separate programs keep separate receipts",
    goodbye.start("canvas-server", { root = ROOT }):finish()
        == ROOT .. "/output/goodbye-canvas-server"
    and goodbye.read(RECEIPT).program == "blitter")
-- }}}

shell("rm -rf '" .. BASE .. "'")
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
