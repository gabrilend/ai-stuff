#!/usr/bin/env luajit
-- 040-test-turn.lua
--
-- Tests a voice's side of the relay (issue 304): the turn hook (037), the
-- turn runner and its lock (038) and the stand-in turn (039), in a
-- throwaway project with a voice mailbox and a guide mailbox made by
-- scripts/make-mailboxes. The hook is called exactly as rmail calls it,
-- through the mailbox's own config line, and waited on as rmail waits on
-- on_update: it must print nothing and return at once while a turn runs.
-- Then the cases the issue names: two canvases arriving during one turn
-- (only the newest is used), a hook call while the runner is busy (no second
-- runner), a dead runner's lock (cleared, with a log line); and a failing
-- turn, a turn that changes nothing, a turn program named by the setting,
-- and the voice's canvas carried into kuvalu's blitter as a new version.
--
-- For a general: whatever arrives while a voice is thinking, it next thinks
-- about the newest canvas, never two things at once, and never stalls on a
-- crashed predecessor.
--
-- usage:
--   luajit 040-test-turn.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")
pcall(ffi.cdef, "int poll(void *fds, unsigned long nfds, int timeout);")
pcall(ffi.cdef, "int getpid(void);")
local series = dofile(DIR .. "/src/018-phase-1-series.lua")
local blitter = dofile(DIR .. "/src/016-blitter.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
local mailboxes = dofile(DIR .. "/src/031-mailboxes.lua")
local runner = dofile(DIR .. "/src/038-turn-runner.lua")
local stand_in = dofile(DIR .. "/src/039-stand-in-turn.lua")
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

-- {{{ small helpers
local function shell(command)
    local pipe = io.popen(command .. " 2>&1; echo \"exit:$?\"")
    local text = pipe:read("*a")
    pipe:close()
    local body, status = string.match(text, "^(.-)\n?exit:(%d+)\n$")
    return body, tonumber(status)
end
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
local function write(path, text)
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
end
local function has(text, piece) return text ~= nil and string.find(text, piece, 1, true) ~= nil end
local function q(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end
local function sleep(seconds) ffi.C.poll(nil, 0, math.floor(seconds * 1000)) end
local function count(text, piece)
    local n, at = 0, 1
    while text do
        local found = string.find(text, piece, at, true)
        if not found then break end
        n, at = n + 1, found + 1
    end
    return n
end
-- waits up to `seconds` for test() to be true
local function wait_until(test, seconds)
    local deadline = runner.now() + (seconds or 10)
    while runner.now() < deadline do
        if test() then return true end
        sleep(0.05)
    end
    return test()
end
-- }}}

-- {{{ a throwaway project with a voice mailbox and a guide mailbox
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

local VOICE = "fg-sora-1"
local MAIL = BASE .. "/" .. VOICE
write(BASE .. "/set", table.concat({
    'guide.folder = "' .. BASE .. '/guide-mail"', "guide.port = 1223", 'guide.ip = "127.0.0.1"',
    'guide.hook = "none"', 'guide.contacts = "' .. VOICE .. '"',
    VOICE .. '.folder = "' .. MAIL .. '"', VOICE .. ".port = 10101",
    VOICE .. '.ip = "127.0.0.1"', VOICE .. '.hook = "turn"',
    VOICE .. '.project = "' .. ROOT .. '"', VOICE .. '.contacts = "guide"',
}, "\n") .. "\n")
mailboxes.build(mailboxes.read_set(BASE .. "/set"), { root = ROOT })
local config = mailboxes.read_config(MAIL .. "/config")

local function runner_settings(turn)
    write(ROOT .. "/input/turn-runner", 'guide = "guide"\nturn = "' .. turn .. '"\n')
end
local function stand_in_settings(seconds)
    write(ROOT .. "/input/stand-in-turn",
        'words = "lantern harbor kitten orchard"\nseconds = ' .. seconds .. "\n")
end
runner_settings("scripts/stand-in-turn")
stand_in_settings(0)

local FOLDER = BASE .. "/shm/guide-feature/turn/" .. VOICE   -- where the tiers put it
local OUT_CANVAS = MAIL .. "/outbox/canvas"
local COUNTER = ROOT .. "/output/turn-counter-" .. VOICE
local RUNNER_LOG = ROOT .. "/tmp/shared-memory/turn-runner-" .. VOICE .. ".log"
local HOOK_LOG = ROOT .. "/tmp/shared-memory/turn-hook.log"

-- the command rmail runs for a hook, built from the mailbox's config line
local function rmail_calls(hook, ...)
    local line = config[hook]
    local path = MAIL .. "/" .. string.gsub(string.match(line, "^(%S+)"), "^%./", "")
    local command = path .. string.sub(line, #string.match(line, "^(%S+)") + 1)
    for _, value in ipairs({ ... }) do command = command .. " " .. q(value) end
    return command
end
-- kuvalu's canvas for a version: the to-voices form, rows given or blank
local function to_voices(version, rows)
    local record = canvas.blank(40, 6, "to-voices")
    record.headers = { canvas = version, size = { width = 40, height = 6 }, mode = "newest",
        project = { name = "guide-feature", commit = "abc1234" },
        endpoint = { name = "voice-small", address = "http://192.168.1.100:20166" },
        written = "2026-11-05T10:00:00Z" }
    if rows then record.rows = rows end
    return canvas.write(record, "to-voices")
end
-- delivers a version as rmail does: a new inbox file and on_receive the
-- first time, an edit through on_update after that. Returns the hook's
-- output, exit status and seconds.
local delivered = false
local function deliver(body)
    local inbox = MAIL .. "/inbox/the-canvas"
    local started = runner.now()
    local out, status
    if not delivered then
        write(inbox, body)
        out, status = shell(rmail_calls("on_receive", "guide", "the-canvas", inbox))
        delivered = true
    else
        out, status = shell(rmail_calls("on_update", "guide", inbox, body))
        write(inbox, body)
    end
    return out, status, runner.now() - started
end
-- the voice's canvas in its outbox: to: line and the record
local function sent()
    local text = slurp(OUT_CANVAS)
    if not text then return nil end
    local to, body = string.match(text, "^(.-)\n\n(.*)$")
    local ok, record = pcall(canvas.read, body or "", "from-voice", "outbox/canvas")
    return to, ok and record or nil, body
end
local function idle() return slurp(FOLDER .. "/lock/pid") == nil end
local function events()
    local list = {}
    for line in string.gmatch(slurp(FOLDER .. "/events") or "", "[^\n]+") do
        local at, what, rest = string.match(line, "^([%d%.]+) (%S+) (.*)$")
        list[#list + 1] = { at = tonumber(at), what = what, rest = rest }
    end
    return list
end
local function said(list)
    local out = {}
    for _, event in ipairs(list) do out[#out + 1] = event.what .. " " .. event.rest end
    return table.concat(out, ", ")
end
local function reset_events() os.remove(FOLDER .. "/events") end
-- the runner's receipt once it says what `test` looks for (it is written
-- just after the lock is let go)
local function receipt_when(test)
    local found
    wait_until(function()
        found = goodbye.read(ROOT .. "/output/goodbye-turn-runner-" .. VOICE)
        return found and test(found.counters)
    end, 5)
    return found
end
-- }}}

io.write("\n=== one canvas, as rmail delivers it ===\n")
-- {{{
check("the voice mailbox's hooks run the turn hook", has(slurp(MAIL .. "/hooks/guide-hook"),
    "/scripts/turn-hook"), slurp(MAIL .. "/hooks/guide-hook"))
stand_in_settings(1)
local out, status, seconds = deliver(to_voices(1))
check("on_receive: exit 0 and nothing printed", status == 0 and out == "", out)
check("it returns at once, while the one-second turn runs (rmail is not held up)",
    seconds < 0.8, seconds)
check("the runner holds the voice's lock while the turn runs", wait_until(function()
    return slurp(FOLDER .. "/lock/pid") ~= nil end, 2))
check("the turn ends and the lock is let go", wait_until(idle, 10))
local to, record = sent()
check("the voice's canvas is in outbox/canvas, addressed to the guide", to == "to: guide", to)
check("it reads as the voice's canvas: voice, turn 1, base 1, the size it was sent",
    record and record.headers.voice == VOICE and record.headers.turn == 1
    and record.headers.base == 1 and record.width == 40 and record.height == 6,
    record and (record.headers.voice .. " " .. record.headers.turn .. " " .. record.headers.base))
check("with the stand-in's first word at row 1, column 1", record
    and string.sub(record.rows[1], 1, 7) == "lantern", record and record.rows[1])
check("the turn number is kept on disk", slurp(COUNTER) == "1\n", slurp(COUNTER))
check("no dot files are left in the outbox (written aside, then renamed)",
    shell("ls -A " .. q(MAIL .. "/outbox")) == "canvas", (shell("ls -A " .. q(MAIL .. "/outbox"))))
check("the waiting canvas was taken and nothing is left behind in turn/",
    shell("ls -A " .. q(FOLDER)) == "events", (shell("ls -A " .. q(FOLDER))))
check("each step is an event with its time: received, taken, sent",
    said(events()) == "received 1, taken 1, sent 1 1", said(events()))
check("the hook's log line", has(slurp(HOOK_LOG), VOICE .. " receive: version 1 waiting; runner started"),
    slurp(HOOK_LOG))
local receipt = receipt_when(function(c) return c["turns-run"] == 1 and c["canvases-sent"] == 1 end)
check("the runner's receipt: one turn run, one canvas sent", receipt ~= nil)
check("the RAM tiers hold it, as the turn folder is in tmp/shared-memory",
    slurp(BASE .. "/shm/guide-feature/turn/" .. VOICE .. "/events") ~= nil)
-- }}}

io.write("\n=== two canvases during one turn; a hook call while the runner is busy ===\n")
-- {{{
reset_events()
stand_in_settings(1.5)
deliver(to_voices(2))
wait_until(function() return slurp(FOLDER .. "/lock/pid") ~= nil end, 2)
sleep(0.2)
local out3, status3, seconds3 = deliver(to_voices(3))
local out4, status4, seconds4 = deliver(to_voices(4))
check("while a turn runs, each update returns at once, printing nothing",
    out3 == "" and out4 == "" and status3 == 0 and status4 == 0 and seconds3 < 0.8
    and seconds4 < 0.8, tostring(seconds3) .. " " .. tostring(seconds4))
check("the hook saw the runner busy and started no second one",
    count(slurp(HOOK_LOG), "is busy and will take it") == 2, slurp(HOOK_LOG))
check("the newer canvas replaced the one waiting, and the hook said so",
    has(slurp(HOOK_LOG), "version 4 waiting (replaced version 3, never taken)"))
check("all three are done", wait_until(function()
    return idle() and slurp(FOLDER .. "/waiting") == nil end, 15))
check("version 3 was never taken: turns on 2 and then 4, the newest",
    said(events()) == "received 2, taken 2, received 3, received 4, replaced 3, sent 2 2, "
    .. "taken 4, sent 4 3", said(events()))
to, record = sent()
check("the outbox holds the turn on version 4, turn 3", record and record.headers.base == 4
    and record.headers.turn == 3)
local log = slurp(RUNNER_LOG) or ""
check("one runner ran both turns (one start in its log since the first)",
    count(log, "started") == 2, log)
-- }}}

io.write("\n=== a dead runner's lock ===\n")
-- {{{
reset_events()
stand_in_settings(0)
local dead = tonumber((shell("sh -c 'echo $$'")))
shell("mkdir -p " .. q(FOLDER .. "/lock"))
write(FOLDER .. "/lock/pid", dead .. " 12345\n")
check("its process is not running", not runner.alive(dead))
deliver(to_voices(5))
check("the hook did not take it for a running runner", has(slurp(HOOK_LOG),
    "version 5 waiting; runner started"))
check("the runner cleared it and ran the turn", wait_until(function()
    return idle() and said(events()) == "received 5, taken 5, sent 5 4" end, 10), said(events()))
check("with a log line naming the process", has(slurp(RUNNER_LOG), "cleared a lock left by process "
    .. dead .. ", which is not running"), slurp(RUNNER_LOG))

-- a number now given to a running process, but not the one that wrote it
reset_events()
local me = ffi.C.getpid()
check("a running process with another start time is not the lock's writer",
    runner.alive(me, runner.start_time(me)) and not runner.alive(me, "1"))
shell("mkdir -p " .. q(FOLDER .. "/lock"))
write(FOLDER .. "/lock/pid", me .. " 1\n")
deliver(to_voices(6))
check("such a lock is cleared too", wait_until(function()
    return idle() and said(events()) == "received 6, taken 6, sent 6 5" end, 10), said(events()))
check("logged as left by a process not running", has(slurp(RUNNER_LOG),
    "cleared a lock left by process " .. me .. ","))

-- a live runner's lock: the hook leaves the canvas waiting for it
reset_events()
shell("mkdir -p " .. q(FOLDER .. "/lock"))
write(FOLDER .. "/lock/pid", me .. " " .. runner.start_time(me) .. "\n")
deliver(to_voices(7))
sleep(0.3)
check("a running process's lock is respected: the canvas waits, no runner starts",
    slurp(FOLDER .. "/waiting") ~= nil and said(events()) == "received 7",
    said(events()))
check("a runner started by hand finds the lock held and leaves", (function()
    local ok, turns, why = pcall(runner.run, ROOT, MAIL)
    return ok and turns == nil and has(why, "process " .. me)
end)())
shell("rm -rf " .. q(FOLDER .. "/lock"))
deliver(to_voices(8))
check("once it is gone, the next call starts a runner, which takes only the newest",
    wait_until(function()
        return idle() and said(events()) == "received 7, busy -, received 8, replaced 7, taken 8, sent 8 6"
    end, 10), said(events()))
-- }}}

io.write("\n=== the lock itself ===\n")
-- {{{
local LOCKS = BASE .. "/locks"
shell("mkdir -p " .. q(LOCKS))
check("taken once", runner.take_lock(LOCKS) == true)
local again, holder = runner.take_lock(LOCKS)
check("not twice, even by the same process: the holder is named", again == false and holder == me)
check("it holds the number and start time", slurp(LOCKS .. "/lock/pid") == me .. " "
    .. runner.start_time(me) .. "\n")
runner.release(LOCKS)
check("let go, it is gone, with nothing left beside it", shell("ls -A " .. q(LOCKS)) == "",
    (shell("ls -A " .. q(LOCKS))))
shell("mkdir -p " .. q(LOCKS .. "/lock"))
write(LOCKS .. "/lock/pid", "999999999 1\n")
runner.release(LOCKS)
check("another process's lock is not let go by release", slurp(LOCKS .. "/lock/pid") == "999999999 1\n")
shell("rm -rf " .. q(LOCKS .. "/lock") .. " && mkdir -p " .. q(LOCKS .. "/lock"))
write(LOCKS .. "/lock/something-else", "")
local noted
check("a lock directory with no number in it is cleared", runner.take_lock(LOCKS,
    function(line) noted = line end) == true and has(noted, "no process number"), noted)
runner.release(LOCKS)
-- }}}

io.write("\n=== turns that fail, change nothing, or are another program ===\n")
-- {{{
reset_events()
-- exit 4: 3 is a turn that gave way to a newer canvas (405)
write(BASE .. "/failing-turn", "#!/bin/sh\necho 'the model is away' >&2\nexit 4\n")
shell("chmod +x " .. q(BASE .. "/failing-turn"))
runner_settings(BASE .. "/failing-turn")
local before = slurp(OUT_CANVAS)
deliver(to_voices(9))
check("a failing turn: the lock is let go", wait_until(function()
    return idle() and #events() >= 3 end, 10), said(events()))
check("nothing is sent and the turn number is not used", slurp(OUT_CANVAS) == before
    and slurp(COUNTER) == "6\n", slurp(COUNTER))
check("it is an event, and the log gives the reason", said(events()) == "received 9, taken 9, failed 9 7"
    and has(slurp(RUNNER_LOG), "exited 4: the model is away"), said(events()))
check("counted as a failed turn", receipt_when(function(c) return c["turns-failed"] == 1 end) ~= nil)

reset_events()
write(BASE .. "/wrong-base", "#!/bin/sh\nwhile [ $# -gt 0 ]; do case \"$1\" in --out) out=$2;; "
    .. "--turn) turn=$2;; esac; shift 2; done\nprintf 'voice: fg-sora-1\\nturn: %s\\nbase: 99\\n"
    .. "size: 40x6\\nwritten: 2026-11-05T10:00:00Z\\n\\nhello\\n\\n\\n\\n\\n\\nmarks:\\n' \"$turn\" > \"$out\"\n")
shell("chmod +x " .. q(BASE .. "/wrong-base"))
runner_settings(BASE .. "/wrong-base")
deliver(to_voices(10))
wait_until(function() return idle() and #events() >= 3 end, 10)
check("a turn whose canvas names another base is not sent",
    said(events()) == "received 10, taken 10, failed 10 7" and slurp(OUT_CANVAS) == before
    and has(slurp(RUNNER_LOG), "base 99"), said(events()))

reset_events()
write(BASE .. "/other-turn", "#!/bin/sh\necho \"$@\" > " .. q(BASE .. "/other-args")
    .. "\nexec luajit " .. q(ROOT .. "/src/039-stand-in-turn.lua") .. " \"$@\"\n")
shell("chmod +x " .. q(BASE .. "/other-turn"))
runner_settings(BASE .. "/other-turn")
deliver(to_voices(11))
wait_until(function() return idle() and #events() >= 3 end, 10)
check("the turn is whatever program the setting names (how 405 comes in)",
    said(events()) == "received 11, taken 11, sent 11 7", said(events()))
check("run as <turn> --dir ROOT --voice NAME --turn N --canvas FILE --out FILE",
    slurp(BASE .. "/other-args") == "--dir " .. ROOT .. " --voice " .. VOICE .. " --turn 7 --canvas "
    .. ROOT .. "/tmp/shared-memory/turn/" .. VOICE .. "/taken --out " .. ROOT
    .. "/tmp/shared-memory/turn/" .. VOICE .. "/turn-out\n", slurp(BASE .. "/other-args"))

reset_events()
runner_settings("scripts/stand-in-turn")
local base12 = canvas.read(to_voices(12), "to-voices")
write(ROOT .. "/input/stand-in-turn", 'words = "lantern"\nseconds = 0\n')
local done = stand_in.edit(base12, VOICE, 8, { "lantern" })
before = slurp(OUT_CANVAS)
deliver(to_voices(12, done.rows))
wait_until(function() return idle() and #events() >= 3 end, 10)
check("a turn that changes nothing sends nothing, and keeps its number",
    said(events()) == "received 12, taken 12, unchanged 12" and slurp(OUT_CANVAS) == before
    and slurp(COUNTER) == "7\n", said(events()))
check("counted as an unchanged turn", receipt_when(function(c) return c["unchanged-turns"] == 1 end) ~= nil)
stand_in_settings(0)

reset_events()
deliver("not a canvas\n")
wait_until(function() return idle() and #events() >= 3 end, 10)
check("a waiting text that is not a canvas is refused, counted and not sent",
    said(events()) == "received -, taken -, refused -" and slurp(OUT_CANVAS) == before,
    said(events()))
-- }}}

local blank = canvas.read(to_voices(20), "to-voices")
local thirds = {}
for number = 1, 3 do
    thirds[number] = stand_in.edit(blank, "fg-sora-" .. number, 2, { "a", "longer-than-a-third" }).rows[2]
end
check("the stand-in writes in the voice's own third, cut to fit it (40 columns: 1, 14, 27)",
    thirds[1] == "longer-than-a" .. string.rep(" ", 27)
    and thirds[2] == string.rep(" ", 13) .. "longer-than-a" .. string.rep(" ", 14)
    and thirds[3] == string.rep(" ", 26) .. "longer-than-a" .. " ", thirds[3])

local again = stand_in.edit({ width = 40, height = 6, headers = { canvas = 3 },
    rows = done.rows }, VOICE, 8, { "lantern", "harbor" })
check("when the turn's word is there already, the stand-in writes the next one that is not",
    string.sub(again.rows[2], 1, 6) == "harbor", again.rows[2])

io.write("\n=== what the hook leaves alone or refuses ===\n")
-- {{{
reset_events()
write(MAIL .. "/inbox/hello", "hi\n")
out, status = shell(rmail_calls("on_receive", "guide", "hello", MAIL .. "/inbox/hello"))
check("another subject: left alone, exit 0", status == 0 and out == ""
    and slurp(FOLDER .. "/waiting") == nil and has(slurp(HOOK_LOG), "subject is 'hello'"))
out, status = shell(rmail_calls("on_update", "someone", MAIL .. "/inbox/the-canvas", to_voices(13)))
check("the canvas from anyone but the guide: left alone", status == 0
    and slurp(FOLDER .. "/waiting") == nil and has(slurp(HOOK_LOG), "comes from 'someone'"))
out, status = shell(rmail_calls("on_receive", "guide", "the-canvas"))
check("not a call it takes: exit 1", status == 1 and has(slurp(HOOK_LOG), "not a call this hook takes"))
out, status = shell(rmail_calls("on_receive", "guide", "the-canvas", BASE .. "/nowhere/the-canvas"))
check("an inbox file that cannot be read: exit 1", status == 1)
write(BASE .. "/the-canvas", to_voices(13))
out, status = shell(rmail_calls("on_receive", "guide", "the-canvas", BASE .. "/the-canvas"))
check("a file in no mailbox's inbox: exit 1 (no voice to run for)", status == 1
    and has(slurp(HOOK_LOG), "is not in a mailbox's inbox"))
out, status = shell("printf '%s' " .. q(to_voices(14)) .. " | "
    .. rmail_calls("on_update", "guide", MAIL .. "/inbox/the-canvas", ""))
check("an update whose body is only on standard input (rmail #215) is read from there",
    status == 0 and wait_until(function() return idle() and said(events()) == "received 14, taken 14, sent 14 8" end, 10),
    said(events()))
out, status = shell("cd " .. q(MAIL) .. " && " .. rmail_calls("on_update", "guide", "inbox/the-canvas",
    to_voices(15)))
check("an inbox path relative to where rmail runs is found", status == 0 and wait_until(function()
    return idle() and has(said(events()), "sent 15 9") end, 10), said(events()))
write(MAIL .. "/inbox/the-canvas-from-guide", "")
out, status = shell(rmail_calls("on_update", "guide", MAIL .. "/inbox/the-canvas-from-guide",
    to_voices(16)))
check("an edit of inbox/the-canvas-from-guide (rmail's name when another's the-canvas was there) is taken",
    status == 0 and wait_until(function()
        return idle() and has(said(events()), "sent 16 10") end, 10), said(events()))
write(ROOT .. "/input/turn-runner", "guide = guide\n")
out, status = shell(rmail_calls("on_update", "guide", MAIL .. "/inbox/the-canvas", to_voices(17)))
check("settings that do not read: exit 1, so rmail sends it again", status == 1
    and has(slurp(HOOK_LOG), "input/turn-runner"), slurp(HOOK_LOG))
runner_settings("scripts/stand-in-turn")
-- }}}

io.write("\n=== into kuvalu's blitter ===\n")
-- {{{
local b = blitter.new({ root = ROOT, commit = "abc1234", wait = function() end,
    publishers = { blitter.log_publisher } })
local version1 = b.current
reset_events()
deliver(to_voices(1, version1.rows))
wait_until(function() return idle() and #events() >= 3 end, 10)
to, record, body = sent()
local arrivals = ROOT .. "/tmp/shared-memory/arrivals"
shell("mkdir -p " .. q(arrivals))
write(arrivals .. "/" .. VOICE .. "-" .. os.time() .. "-0a1b2c3d", body or "")
b:step()
check("the voice's canvas, as sent, is blitted into a new version", b.version == 2, b.version)
check("with the stand-in's word in it", has(b.current.rows[(record.headers.turn - 1) % 6 + 1],
    ({ "lantern", "harbor", "kitten", "orchard" })[(record.headers.turn - 1) % 4 + 1]),
    b.current.rows[1])
b:finish()
-- }}}

shell("rm -rf '" .. BASE .. "'")
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
