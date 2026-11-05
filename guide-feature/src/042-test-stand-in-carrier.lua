#!/usr/bin/env luajit
-- 042-test-stand-in-carrier.lua
--
-- Tests the stand-in carrier (041) against rmail's file-and-hook contract,
-- with three mailboxes made by scripts/make-mailboxes and each mailbox's
-- hook wrapper swapped for one that records how it was called: outbox files
-- (`to:` lines, body, dot names skipped); the first delivery a new inbox
-- file and on_receive in the background (sender, subject, file); every
-- change after an edit through on_update, waited for (sender, file, body,
-- the body on standard input too, the argument empty over 64 KiB), whose
-- output replaces the body and whose failure refuses the edit until it is
-- tried again; only the newest body carried; a second sender's message of
-- the same subject named <subject>-from-<sender>; the sender known by the
-- token both contacts hold; each contact's timer (due at the start, the
-- floor and the jitter, due at once after it delivered); and what is never
-- carried: a contact elsewhere, unknown, or not knowing the sender.
--
-- For a general: the rehearsal's mail moves exactly as rmail would move
-- it, so what passes there passes on the real machines' mail.
--
-- usage:
--   luajit 042-test-stand-in-carrier.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int poll(void *fds, unsigned long nfds, int timeout);")
local mailboxes = dofile(DIR .. "/src/031-mailboxes.lua")
local carrier = dofile(DIR .. "/src/041-stand-in-carrier.lua")

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
local function wait_for(path, piece)
    for _ = 1, 100 do
        if has(slurp(path), piece) then return true end
        sleep(0.02)
    end
    return false
end
-- }}}

-- {{{ three mailboxes, their hooks recording their calls
local BASE = shell("mktemp -d")
local ROOT = BASE .. "/project/guide-feature"
shell("mkdir -p '" .. ROOT .. "'")
local NAMES = { "guide", "fg-sora-1", "fg-sora-2" }
local FOLDER = {}
local lines = {}
for index, name in ipairs(NAMES) do
    FOLDER[name] = BASE .. "/" .. name
    lines[#lines + 1] = name .. '.folder = "' .. FOLDER[name] .. '"'
    lines[#lines + 1] = name .. ".port = " .. (41222 + index)
    lines[#lines + 1] = name .. '.ip = "127.0.0.1"'
    lines[#lines + 1] = name .. '.hook = "' .. (name == "guide" and "arrival" or "turn") .. '"'
    lines[#lines + 1] = name .. '.project = "' .. ROOT .. '"'
    lines[#lines + 1] = name .. '.contacts = "' .. (name == "guide" and "fg-sora-1 fg-sora-2"
        or "guide") .. '"'
end
write(BASE .. "/set", table.concat(lines, "\n") .. "\n")
mailboxes.build(mailboxes.read_set(BASE .. "/set"), { root = ROOT })
for _, name in ipairs(NAMES) do
    local f = FOLDER[name]
    write(f .. "/hooks/guide-hook", "#!/bin/sh\n"
        .. "{ printf 'call'; for a in \"$@\"; do printf '|%s' \"$a\"; done; printf '\\n'; } >> "
        .. q(f .. "/calls") .. "\n"
        .. "[ \"$1\" = receive ] && [ -f " .. q(f .. "/slow") .. " ] && sleep 1\n"
        .. "if [ \"$1\" = update ]; then\n"
        .. "  cat > " .. q(f .. "/stdin") .. "\n"
        .. "  [ -f " .. q(f .. "/refuse") .. " ] && exit 1\n"
        .. "  [ -f " .. q(f .. "/replace") .. " ] && cat " .. q(f .. "/replace") .. "\n"
        .. "fi\nexit 0\n")
end

local clock = 100
local events = {}
local c = carrier.new({ folders = { FOLDER.guide, FOLDER["fg-sora-1"], FOLDER["fg-sora-2"] },
    pace = 10, now = function() return clock end, scratch = BASE,
    event = function(e) events[#events + 1] = e end })
local function kinds()
    local out = {}
    for _, e in ipairs(events) do out[#out + 1] = e.from .. ">" .. e.to .. ":" .. e.kind end
    events = {}
    return table.concat(out, " ")
end
local function calls(name)
    local text = slurp(FOLDER[name] .. "/calls") or ""
    os.remove(FOLDER[name] .. "/calls")
    return text
end
-- }}}

io.write("\n=== an outbox file ===\n")
-- {{{
local to, body = carrier.parse("to: fg-sora-1\nto: fg-sora-2\n\nthe body\n\nwith a gap\n")
check("its to: lines and its body", to and to[1] == "fg-sora-1" and to[2] == "fg-sora-2"
    and body == "the body\n\nwith a gap\n")
check("anything else above the blank line is not an outbox file",
    carrier.parse("to: a\nsubject: b\n\nbody") == nil and carrier.parse("no blank line") == nil)
check("rmail's file name for a subject", carrier.file_name("..a b/c d") == "c-d"
    and carrier.file_name("") == "untitled")
-- }}}

io.write("\n=== the first delivery, and edits ===\n")
-- {{{
local GUIDE_OUT = FOLDER.guide .. "/outbox/the-canvas"
write(FOLDER.guide .. "/outbox/.the-canvas.part", "to: fg-sora-1\n\nhalf")
write(GUIDE_OUT, "to: fg-sora-1\nto: fg-sora-2\n\nversion 1\n")
write(FOLDER["fg-sora-1"] .. "/slow", "")
local started = io.popen("date +%s.%N"):read("*l")
local delivered = c:round()
local took = tonumber(io.popen("date +%s.%N"):read("*l")) - tonumber(started)
os.remove(FOLDER["fg-sora-1"] .. "/slow")
check("on_receive runs in the background: a slow hook does not hold the round up", took < 0.8, took)
check("every contact is due at the start: both voices get it", delivered == 2
    and kinds() == "guide>fg-sora-1:new guide>fg-sora-2:new")
local INBOX1 = FOLDER["fg-sora-1"] .. "/inbox/the-canvas"
check("a new inbox file named after the subject, holding the body",
    slurp(INBOX1) == "version 1\n" and slurp(FOLDER["fg-sora-2"] .. "/inbox/the-canvas") == "version 1\n")
check("a dot file in the outbox is never sent", not has(shell("ls -A " .. q(FOLDER["fg-sora-1"]
    .. "/inbox")), ".the-canvas"))
check("on_receive: the mode word, sender, subject and inbox file",
    wait_for(FOLDER["fg-sora-1"] .. "/calls", "\n")
    and calls("fg-sora-1") == "call|receive|guide|the-canvas|" .. INBOX1 .. "\n")
calls("fg-sora-2")
clock = 105
check("nothing new: nothing carried", c:round() == 0 and kinds() == "")
write(GUIDE_OUT, "to: fg-sora-1\nto: fg-sora-2\n\nversion 2\n")
check("a change waits for its contact's timer (due 10 s after the last exchange)",
    c:round() == 0 and slurp(INBOX1) == "version 1\n")
write(GUIDE_OUT, "to: fg-sora-1\nto: fg-sora-2\n\nversion 3\n")
clock = 110
check("then only the newest body is carried, as an edit", c:round() == 2
    and kinds() == "guide>fg-sora-1:edit guide>fg-sora-2:edit" and slurp(INBOX1) == "version 3\n")
local got = calls("fg-sora-1")
check("on_update, waited for: the mode word, sender, inbox file and new body",
    got == "call|update|guide|" .. INBOX1 .. "|version 3\n\n", got)
check("the body on standard input too (rmail #215)", slurp(FOLDER["fg-sora-1"] .. "/stdin") == "version 3\n")
calls("fg-sora-2")

write(FOLDER["fg-sora-1"] .. "/replace", "what the hook printed\n")
write(GUIDE_OUT, "to: fg-sora-1\n\nversion 4\n")
clock = 120
c:round()
check("what on_update prints replaces the body", slurp(INBOX1) == "what the hook printed\n")
os.remove(FOLDER["fg-sora-1"] .. "/replace")
kinds()

write(FOLDER["fg-sora-1"] .. "/refuse", "")
write(GUIDE_OUT, "to: fg-sora-1\n\nversion 5\n")
clock = 130
check("an on_update that fails refuses the edit (rmail #215)", c:round() == 0
    and kinds() == "guide>fg-sora-1:refused" and slurp(INBOX1) == "what the hook printed\n")
os.remove(FOLDER["fg-sora-1"] .. "/refuse")
clock = 140
check("and it is carried when next due", c:round() == 1 and slurp(INBOX1) == "version 5\n")
kinds()
calls("fg-sora-1")

local big = string.rep("x", carrier.BIG + 1) .. "\n"
write(GUIDE_OUT, "to: fg-sora-1\n\n" .. big)
clock = 150
c:round()
check("over 64 KiB the argument is empty and the body only on standard input",
    calls("fg-sora-1") == "call|update|guide|" .. INBOX1 .. "|\n"
    and slurp(FOLDER["fg-sora-1"] .. "/stdin") == big and slurp(INBOX1) == big)
kinds()
-- }}}

io.write("\n=== the voices' canvases in the guide's inbox ===\n")
-- {{{
write(FOLDER["fg-sora-1"] .. "/outbox/canvas", "to: guide\n\nfrom one\n")
write(FOLDER["fg-sora-2"] .. "/outbox/canvas", "to: guide\n\nfrom two\n")
clock = 151
check("not due yet (their timers for the guide were set at the start)", c:round() == 0)
clock = 160
check("then both are carried", c:round() >= 2 and has(kinds(), "fg-sora-2>guide:new"))
check("the first is inbox/canvas, the second sender's canvas-from-fg-sora-2, as rmail names them",
    slurp(FOLDER.guide .. "/inbox/canvas") == "from one\n"
    and slurp(FOLDER.guide .. "/inbox/canvas-from-fg-sora-2") == "from two\n")
local guide_calls = (wait_for(FOLDER.guide .. "/calls", "fg-sora-2") and calls("guide")) or ""
check("the guide knows each sender by the token their contacts share",
    has(guide_calls, "|receive|fg-sora-1|canvas|") and has(guide_calls, "|receive|fg-sora-2|canvas|"),
    guide_calls)
write(GUIDE_OUT, "to: fg-sora-1\n\nversion 6\n")
clock = 161
check("a contact that has just delivered is due at once: the guide answers fg-sora-1 now",
    c:round() == 1 and kinds() == "guide>fg-sora-1:edit" and slurp(INBOX1) == "version 6\n")
-- }}}

io.write("\n=== timers with jitter ===\n")
-- {{{
local jittery = carrier.new({ folders = { FOLDER.guide, FOLDER["fg-sora-1"] }, pace = 10,
    jitter = 5, random = function() return 1 end, now = function() return clock end,
    scratch = BASE })
clock = 200
jittery:round()
check("next due after the floor plus the jitter drawn (random 1: +5 s)",
    jittery.timers[FOLDER["fg-sora-1"]].guide == 215, jittery.timers[FOLDER["fg-sora-1"]].guide)
-- }}}

io.write("\n=== what is never carried ===\n")
-- {{{
clock = 300
write(FOLDER.guide .. "/outbox/hello", "to: nobody\n\nhi\n")
c:round()
check("a contact the mailbox does not have: reported, not carried", has(kinds(), "guide>nobody:unknown-contact"))
clock = 310
c:round()
check("reported once, not every round", kinds() == "")
os.remove(FOLDER.guide .. "/outbox/hello")

local contacts = slurp(FOLDER.guide .. "/contacts")
write(FOLDER.guide .. "/contacts", (string.gsub(contacts, 'fg%-sora%-2%.ip = "127%.0%.0%.1"',
    'fg-sora-2.ip = "192.168.1.12"')))
write(GUIDE_OUT, "to: fg-sora-2\n\nversion 7\n")
clock = 320
c:round()
check("a contact on another machine: not carried (loopback only)", kinds() == "guide>fg-sora-2:not-here")
write(FOLDER.guide .. "/contacts", contacts)

local theirs = slurp(FOLDER["fg-sora-2"] .. "/contacts")
write(FOLDER["fg-sora-2"] .. "/contacts", (string.gsub(theirs, 'token = "[^"]*"', 'token = "other"')))
clock = 330
c:round()
local said = kinds()
check("a receiver that holds no contact with the sender's token: not carried",
    has(said, "guide>fg-sora-2:unknown-sender"), said .. " | " .. slurp(FOLDER["fg-sora-2"] .. "/contacts"))
write(FOLDER["fg-sora-2"] .. "/contacts", theirs)

os.remove(FOLDER["fg-sora-2"] .. "/inbox/the-canvas")
clock = 340
c:round()
check("an inbox file the receiver deleted is not made again (rmail's 404)",
    kinds() == "guide>fg-sora-2:deleted" and slurp(FOLDER["fg-sora-2"] .. "/inbox/the-canvas") == nil)
-- }}}

shell("rm -rf '" .. BASE .. "'")
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
