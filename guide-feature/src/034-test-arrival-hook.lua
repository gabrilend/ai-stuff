#!/usr/bin/env luajit
-- 034-test-arrival-hook.lua
--
-- Tests kuvalu's arrival hook (033, scripts/arrival-hook) as rmail would
-- call it: through the guide mailbox's own hooks/guide-hook, made by
-- scripts/make-mailboxes (031), in a throwaway project. Both calls, receive
-- and update, write the body byte for byte into the arrivals folder under a
-- name the blitter takes, by a dot name and a rename; print nothing; and
-- exit at once. An update whose body comes on standard input (rmail #215)
-- is taken from there. Anything that is not a voice's canvas is left alone,
-- and a call the hook does not know is refused with a non-zero exit. After
-- a reboot (the RAM tiers gone) the hook makes them again. Then the real
-- blitter takes what the hook wrote and makes new versions from it.
--
-- For a general: a voice's canvas that reaches kuvalu's mailbox reaches the
-- blitter, unchanged, and nothing else does.
--
-- usage:
--   luajit 034-test-arrival-hook.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")
local series = dofile(DIR .. "/src/018-phase-1-series.lua")
local blitter = dofile(DIR .. "/src/016-blitter.lua")
local mailboxes = dofile(DIR .. "/src/031-mailboxes.lua")

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
local function q(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end
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
-- }}}

-- {{{ a throwaway project and its guide mailbox
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
write(BASE .. "/set", table.concat({
    'guide.folder = "' .. BASE .. '/guide-mail"', "guide.port = 1223", 'guide.ip = "127.0.0.1"',
    'guide.hook = "arrival"', 'guide.project = "' .. ROOT .. '"', 'guide.contacts = "fg-sora-1"',
    'fg-sora-1.folder = "' .. BASE .. '/voice-mail"', "fg-sora-1.port = 10101",
    'fg-sora-1.ip = "127.0.0.1"', 'fg-sora-1.hook = "none"', "" }, "\n"))
mailboxes.build(mailboxes.read_set(BASE .. "/set"), { root = ROOT })
local MAIL = BASE .. "/guide-mail"
local HOOK = MAIL .. "/hooks/guide-hook"
local ARRIVALS = ROOT .. "/tmp/shared-memory/arrivals"
local LOG = ROOT .. "/tmp/shared-memory/arrival-hook.log"

-- rmail's two calls, as its config lines make them (a hook path, unquoted,
-- then the word, then rmail's arguments quoted)
local config = mailboxes.read_config(MAIL .. "/config")
local function rmail_calls(hook, ...)
    local line = config[hook]
    local path = MAIL .. "/" .. string.gsub(string.match(line, "^(%S+)"), "^%./", "")
    local command = path .. string.sub(line, #string.match(line, "^(%S+)") + 1)
    for _, value in ipairs({ ... }) do command = command .. " " .. q(value) end
    return command
end
local function arrivals()
    local list = {}
    for name in string.gmatch(shell("ls -A '" .. ARRIVALS .. "' 2>/dev/null") or "", "[^\n]+") do
        list[#list + 1] = name
    end
    return list
end
local function clear() shell("rm -f '" .. ARRIVALS .. "'/* '" .. ARRIVALS .. "'/.[!.]*") end
local function timed(command)
    local wall = tonumber((shell("date +%s.%N")))
    local out, status = shell(command)
    return out, status, tonumber((shell("date +%s.%N"))) - wall
end
-- }}}

io.write("\n=== as rmail calls it ===\n")
-- {{{
local BODY = "voice: fg-sora-1\nturn: 1\nbase: 1\n\nthe cat sat — on the mat.\n\n"
write(MAIL .. "/inbox/canvas", BODY)
local before = os.time()
local out, status, seconds = timed(rmail_calls("on_receive", "fg-sora-1", "canvas", MAIL .. "/inbox/canvas"))
local list = arrivals()
check("on_receive: one arrival, and nothing printed", status == 0 and out == "" and #list == 1, out)
local sender, time, random = string.match(list[1] or "", "^([%w_%-]+)%-(%d+)%-(%x+)$")
check("named <sender>-<unix time>-<random>, as the blitter takes it",
    sender == "fg-sora-1" and tonumber(time) >= before and tonumber(time) <= os.time()
    and #random == 8, list[1])
check("the body, byte for byte", slurp(ARRIVALS .. "/" .. (list[1] or "")) == BODY)
check("it is quick, as on_update holds rmail up", seconds < 1, seconds)
clear()

local EDIT = BODY .. "an edit\n"
out, status = shell(rmail_calls("on_update", "fg-sora-1", MAIL .. "/inbox/canvas", EDIT))
list = arrivals()
check("on_update: the new body, byte for byte, and nothing printed",
    status == 0 and out == "" and #list == 1 and slurp(ARRIVALS .. "/" .. list[1]) == EDIT, out)
clear()

out, status = shell("printf '%s' " .. q(EDIT .. "from stdin\n") .. " | "
    .. rmail_calls("on_update", "fg-sora-1", MAIL .. "/inbox/canvas", ""))
list = arrivals()
check("an update whose body is only on standard input (rmail #215, over 64 KiB) is read from there",
    status == 0 and #list == 1 and slurp(ARRIVALS .. "/" .. list[1]) == EDIT .. "from stdin\n")
clear()

shell(rmail_calls("on_update", "fg-sora-1", MAIL .. "/inbox/canvas", "one"))
shell(rmail_calls("on_update", "fg-sora-1", MAIL .. "/inbox/canvas", "two"))
list = arrivals()
check("two edits are two arrivals, never one written over the other",
    #list == 2 and list[1] ~= list[2]
    and (slurp(ARRIVALS .. "/" .. list[1]) .. slurp(ARRIVALS .. "/" .. list[2])):len() == 6)
check("no dot file (one half written) is left behind", not has(shell("ls -A '" .. ARRIVALS .. "'"), "."))
clear()
-- }}}

io.write("\n=== what it leaves alone, and what it refuses ===\n")
-- {{{
write(MAIL .. "/inbox/hello", "just saying hi\n")
out, status = shell(rmail_calls("on_receive", "fg-sora-1", "hello", MAIL .. "/inbox/hello"))
check("a message whose subject is not canvas is left alone, and logged",
    status == 0 and out == "" and #arrivals() == 0
    and has(slurp(LOG), "fg-sora-1 receive: left alone, its subject is 'hello', not 'canvas'"))
out, status = shell(rmail_calls("on_update", "fg-sora-1", MAIL .. "/inbox/hello", "edited"))
check("an edit of such a message too (its subject is its inbox file's name)",
    status == 0 and #arrivals() == 0 and has(slurp(LOG), "update: left alone, its subject is 'hello'"))
out, status = shell(rmail_calls("on_update", "fg-sora-1", MAIL .. "/inbox/canvas-2", "edited"))
check("a second message that rmail named canvas-2 is not taken for the canvas", #arrivals() == 0)
out, status = shell(rmail_calls("on_update", "../x", MAIL .. "/inbox/canvas", BODY))
check("a sender that is not a name an arrival can carry is left alone",
    status == 0 and #arrivals() == 0 and has(slurp(LOG), "the sender '../x'"))
out, status = shell(HOOK .. " both fg-sora-1 canvas " .. q(MAIL .. "/inbox/canvas"))
check("a first word that is not receive or update is refused, not guessed",
    status == 1 and out == "" and #arrivals() == 0 and has(slurp(LOG), "not a call this hook takes"))
out, status = shell(HOOK .. " update fg-sora-1 " .. q(MAIL .. "/inbox/canvas"))
check("so is a call with the wrong number of arguments", status == 1 and #arrivals() == 0)
out, status = shell(HOOK .. " receive fg-sora-1 canvas " .. q(MAIL .. "/inbox/gone"))
check("an inbox file that is not there is a failure, so it is not lost silently",
    status == 1 and has(slurp(LOG), "cannot be read"))
out, status = shell(HOOK .. " update fg-sora-1 " .. q(MAIL .. "/inbox/canvas") .. " '' < /dev/null")
check("an empty body is a failure (under rmail #215, rmail sends it again)",
    status == 1 and #arrivals() == 0 and has(slurp(LOG), "the body is empty"))
-- }}}

io.write("\n=== after a reboot ===\n")
-- {{{
shell("rm -rf '" .. ROOT .. "/tmp' '" .. BASE .. "/exec' '" .. BASE .. "/shm'")
shell("mkdir -p '" .. BASE .. "/exec' '" .. BASE .. "/shm'")
out, status = shell(rmail_calls("on_update", "fg-sora-1", MAIL .. "/inbox/canvas", EDIT))
list = arrivals()
check("with the RAM tiers gone, it makes them again and writes the arrival",
    status == 0 and #list == 1 and slurp(ARRIVALS .. "/" .. list[1]) == EDIT, out)
check("in RAM, where the tiers put tmp/shared-memory, not in a plain folder on disk",
    list[1] ~= nil and slurp(BASE .. "/shm/guide-feature/arrivals/" .. list[1]) == EDIT)
clear()
-- }}}

io.write("\n=== into the blitter ===\n")
-- {{{
local b = blitter.new({ root = ROOT, commit = "abc1234", wait = function() end })
local function round(number, hook)
    local versions = {}
    for version = 1, b.version do versions[version] = b.history[version].rows end
    for _, one in ipairs(series.arrivals(number, versions, b.version)) do
        write(MAIL .. "/inbox/canvas", one.text)
        if hook == "on_receive" then
            shell(rmail_calls(hook, one.voice, "canvas", MAIL .. "/inbox/canvas"))
        else
            shell(rmail_calls(hook, one.voice, MAIL .. "/inbox/canvas", one.text))
        end
    end
    b:step()
end
round(1, "on_receive")
check("the blitter takes the first canvas the hook wrote: version 2", b.version == 2, b.version)
round(2, "on_update")
check("and the edits after it: versions 3 and 4", b.version == 4, b.version)
check("the arrivals folder is empty again: everything written was taken", #arrivals() == 0)
check("the blitter refused none", not has(slurp(ROOT .. "/tmp/shared-memory/blitter.log"), "refused"))
-- }}}

shell("rm -rf '" .. BASE .. "'")
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
