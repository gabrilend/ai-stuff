#!/usr/bin/env luajit
-- 036-test-to-voices.lua
--
-- Tests the canvas mailed to the voices (035, and its place in the
-- blitter's list): in a throwaway project with a guide mailbox made by
-- scripts/make-mailboxes and a throwaway git checkout as the project, the
-- phase 1 series is played into the real blitter. After every version the
-- guide mailbox's outbox/the-canvas is one living message, addressed to the
-- three voices, whose body is that version in the to-voices form, read back
-- by the one canvas reader; the project's commit is read at every version;
-- the cuts each voice made in its latest turn that landed are listed, and
-- go when its next turn lands. Then the settings that turn it off or would
-- send versions nowhere, and the blitter run as a program, both ways.
--
-- For a general: every voice is always sent the newest canvas, the same
-- one, with what its last edit destroyed, through one file rmail carries.
--
-- usage:
--   luajit 036-test-to-voices.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")
pcall(ffi.cdef, "int poll(void *fds, unsigned long nfds, int timeout);")
local series = dofile(DIR .. "/src/018-phase-1-series.lua")
local blitter = dofile(DIR .. "/src/016-blitter.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
local mailboxes = dofile(DIR .. "/src/031-mailboxes.lua")
local to_voices = dofile(DIR .. "/src/035-to-voices.lua")
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
-- }}}

-- {{{ a throwaway project, its checkout and its guide mailbox
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

local CHECKOUT = BASE .. "/the-project"
local GIT = "git -C '" .. CHECKOUT .. "' -c user.name=test -c user.email=test@localhost "
shell("mkdir -p '" .. CHECKOUT .. "' && git -C '" .. CHECKOUT .. "' init -q && " .. GIT
    .. "commit -q --allow-empty -m one")
local function head() return (shell("git -C '" .. CHECKOUT .. "' rev-parse --short=7 HEAD")) end

local MAIL = BASE .. "/guide-mail"
local lines = { 'guide.folder = "' .. MAIL .. '"', "guide.port = 1223", 'guide.ip = "127.0.0.1"',
    'guide.hook = "none"', 'guide.contacts = "fg-sora-1 fg-sora-2 fg-sora-3"' }
for number = 1, 3 do
    local name = "fg-sora-" .. number
    lines[#lines + 1] = name .. '.folder = "' .. BASE .. "/" .. name .. '"'
    lines[#lines + 1] = name .. ".port = " .. (10000 + number)
    lines[#lines + 1] = name .. '.ip = "127.0.0.1"'
    lines[#lines + 1] = name .. '.hook = "none"'
end
write(BASE .. "/set", table.concat(lines, "\n") .. "\n")
mailboxes.build(mailboxes.read_set(BASE .. "/set"), { root = ROOT })

local function settings_text(over)
    local values = { send = '"on"', mailbox = '"' .. MAIL .. '"', ["tell-the-voice"] = '"on"',
        endpoint = '"voice-small http://192.168.1.100:20166"',
        ["project-checkout"] = '"' .. CHECKOUT .. '"' }
    for key, value in pairs(over or {}) do values[key] = value end
    local out = {}
    for _, key in ipairs({ "send", "mailbox", "tell-the-voice", "endpoint", "project-checkout" }) do
        out[#out + 1] = key .. " = " .. values[key]
    end
    return table.concat(out, "\n") .. "\n"
end
write(ROOT .. "/input/to-voices", settings_text())
local OUTBOX = MAIL .. "/outbox"
local THE_CANVAS = OUTBOX .. "/the-canvas"

-- the outbox file: its to: lines, and its body read as a voice reads it
local function sent()
    local text = slurp(THE_CANVAS) or ""
    local to, body = string.match(text, "^(.-)\n\n(.*)$")
    local record = body and canvas.read(body, "to-voices", "the-canvas")
    return to, record, body
end
-- }}}

io.write("\n=== every version, mailed ===\n")
-- {{{
local VOICES = { "fg-sora-1", "fg-sora-2", "fg-sora-3" }
local publisher = to_voices.publisher({ root = ROOT, voices = VOICES })
local b = blitter.new({ root = ROOT, commit = "abc1234", wait = function() end,
    publishers = { blitter.log_publisher, publisher } })
local to, record, body = sent()
check("version 1 is in outbox/the-canvas as soon as the blitter starts",
    record and record.headers.canvas == 1, slurp(THE_CANVAS))
check("one to: line for each voice, in order", to == "to: fg-sora-1\nto: fg-sora-2\nto: fg-sora-3", to)
check("the to-voices headers: size, mode, the project and its checkout's commit, the endpoint",
    record.width == series.WIDTH and record.height == series.HEIGHT
    and record.headers.mode == "newest" and record.headers.project.name == "guide-feature"
    and record.headers.project.commit == head() and record.headers.endpoint.name == "voice-small"
    and record.headers.endpoint.address == "http://192.168.1.100:20166")
check("with tell-the-voice on, a cuts: section, empty while nothing was cut",
    record.cuts ~= nil and #record.cuts == 0 and has(body, "\nmarks:\ncuts:\n"))

local all_newest, only_one, rows_same, commits_follow = true, true, true, true
local cuts_after = {}
for number = 1, #series.ROUNDS do
    local versions = {}
    for version = 1, b.version do versions[version] = b.history[version].rows end
    for _, one in ipairs(series.arrivals(number, versions, b.version)) do
        write(ROOT .. "/tmp/shared-memory/arrivals/" .. one.name, one.text)
    end
    if number == 4 then shell(GIT .. "commit -q --allow-empty -m two") end
    b:step()
    to, record = sent()
    if not record or record.headers.canvas ~= b.version then all_newest = false end
    if shell("ls -A '" .. OUTBOX .. "'") ~= "the-canvas" then only_one = false end
    for row = 1, b.current.height do
        if record.rows[row] ~= b.current.rows[row] then rows_same = false end
    end
    if #record.marks ~= #b.current.marks then rows_same = false end
    if record.headers.project.commit ~= head() then commits_follow = false end
    local listed = {}
    for _, cut in ipairs(record.cuts or {}) do
        listed[#listed + 1] = string.format("%s %d %d %d %s", cut.voice, cut.version, cut.row,
            cut.column, cut.text)
    end
    cuts_after[number] = table.concat(listed, "; ")
end
check("after every round, the-canvas holds the newest version", all_newest)
check("and nothing else is in the outbox: no second message, no half-written file", only_one)
check("its rows and marks are the blitter's own", rows_same)
check("the commit is read at every version: a commit made mid-series shows at the next one",
    commits_follow and record.headers.project.commit == head())
check("a voice's cut words are listed from the version its turn landed",
    cuts_after[3] == "fg-sora-1 5 1 9 sat", cuts_after[3])
check("every voice's lines are in the one body, each from its own latest turn",
    cuts_after[4] == "fg-sora-1 5 1 9 sat; fg-sora-3 7 1 5 kitten", cuts_after[4])
check("a voice's lines go when its next turn lands, the others' stay",
    cuts_after[6] == "fg-sora-3 7 1 5 kitten", cuts_after[6])
b:finish()
local receipt = goodbye.read(ROOT .. "/output/goodbye-blitter")
check("the receipt counts the versions handed to rmail: every one",
    receipt.counters["versions-to-voices"] == 8
    and receipt.counters["versions-to-voices"] == receipt.counters["versions-in-history"],
    receipt.counters["versions-to-voices"])
-- }}}

io.write("\n=== the settings ===\n")
-- {{{
write(ROOT .. "/input/to-voices", settings_text({ ["tell-the-voice"] = '"off"' }))
shell("rm -f '" .. THE_CANVAS .. "'")
b = blitter.new({ root = ROOT, commit = "abc1234", wait = function() end,
    publishers = { to_voices.publisher({ root = ROOT, voices = VOICES }) } })
to, record, body = sent()
check("with tell-the-voice off, no cuts: section at all", record and record.cuts == nil
    and not has(body, "cuts:"))
b:finish()

write(ROOT .. "/input/to-voices", settings_text({ send = '"off"' }))
local none, why = to_voices.publisher({ root = ROOT, voices = VOICES })
check("with send off there is no publisher, and the reason says where it is set",
    none == nil and has(why, "send is off in input/to-voices"))

local function refused(over, voices, piece)
    write(ROOT .. "/input/to-voices", settings_text(over))
    local ok, problem = pcall(to_voices.publisher, { root = ROOT, voices = voices or VOICES })
    return not ok and has(tostring(problem), piece), problem
end
check("no mailbox at the folder: refused, naming the script that makes one",
    refused({ mailbox = '"' .. BASE .. '/nowhere"' }, nil, "make it with scripts/make-mailboxes"))
check("a voice the mailbox has no contact for: refused, naming it",
    refused(nil, { "fg-sora-1", "fg-sora-4" }, "no contact called fg-sora-4"))
check("an endpoint that is not a name and an address: refused",
    refused({ endpoint = '"voice-small"' }, nil, "must be a name and an address"))
check("a project checkout that is not a git checkout: refused",
    refused({ ["project-checkout"] = '"' .. BASE .. '"' }, nil, "is not a git checkout"))
check("a setting missing: refused, as every program's settings are",
    (function()
        write(ROOT .. "/input/to-voices", 'send = "on"\n')
        return not pcall(to_voices.publisher, { root = ROOT, voices = VOICES })
    end)())
-- }}}

io.write("\n=== the blitter as a program ===\n")
-- {{{
local function run_program()
    shell("rm -f '" .. THE_CANVAS .. "'")
    local pid = shell("cd '" .. ROOT .. "' && (scripts/run-blitter '" .. ROOT
        .. "' > /dev/null 2>&1 & echo $!)")
    for _ = 1, 100 do
        if has(slurp(ROOT .. "/tmp/shared-memory/blitter.log"), "now version") then break end
        ffi.C.poll(nil, 0, 50)
    end
    ffi.C.poll(nil, 0, 200)
    write(ROOT .. "/tmp/shared-memory/arrivals/stop", "")
    for _ = 1, 60 do
        if select(2, shell("kill -0 " .. pid)) ~= 0 then break end
        ffi.C.poll(nil, 0, 100)
    end
    return slurp(ROOT .. "/tmp/shared-memory/blitter.log")
end
write(ROOT .. "/input/to-voices", settings_text())
run_program()
to, record = sent()
check("run as a program with send on, it mails its first version", record ~= nil
    and to == "to: fg-sora-1\nto: fg-sora-2\nto: fg-sora-3")
write(ROOT .. "/input/to-voices", settings_text({ send = '"off"' }))
local log = run_program()
check("with send off it mails nothing, and its log says why",
    slurp(THE_CANVAS) == nil and has(log, "versions are not mailed to the voices"), log)
-- }}}

shell("rm -rf '" .. BASE .. "'")
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
