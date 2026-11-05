#!/usr/bin/env luajit
-- 044-test-rehearsal.lua
--
-- Tests the rehearsal (043, scripts/rehearse) by running it, short and
-- fast, in a throwaway project: twenty seconds, the stand-in carrier's
-- timers at one second give or take half, a turn of half a second. The
-- four mailboxes are made by the mailbox setup; versions go round from the
-- blitter to the three voices and their turns come back as new versions.
-- Every voice turn's timings are in order (published, received, taken,
-- finished, delivered, arrived, blitted, back); the counts agree with the
-- events; nothing is left running and the workspace is gone. Then --keep,
-- and the real-rmail carrier with a stand-in daemon command: four daemons
-- started, each given its mailbox's config, and stopped at the end.
--
-- For a general: the whole relay runs on one machine, as it will on four,
-- and every leg of every turn is timed.
--
-- usage:
--   luajit 044-test-rehearsal.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local series = dofile(DIR .. "/src/018-phase-1-series.lua")
local goodbye = dofile(DIR .. "/src/002-goodbye.lua")
local rehearsal = dofile(DIR .. "/src/043-rehearsal.lua")

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
-- }}}

-- {{{ a throwaway project and its checkout
local BASE = shell("mktemp -d")
local ROOT = BASE .. "/project/guide-feature"
shell("mkdir -p '" .. ROOT .. "/input' '" .. ROOT .. "/output' '" .. BASE .. "/exec' '"
    .. BASE .. "/shm'")
for _, link in ipairs({ "src", "libs", "scripts" }) do
    shell("ln -s '" .. DIR .. "/" .. link .. "' '" .. ROOT .. "/" .. link .. "'")
end
local ENV = "EXEC_TIER_ROOT=" .. q(BASE .. "/exec") .. " ARTIFACT_TIER_ROOT=" .. q(BASE .. "/shm") .. " "
local CHECKOUT = BASE .. "/the-project"
shell("mkdir -p '" .. CHECKOUT .. "' && git -C '" .. CHECKOUT .. "' init -q && git -C '" .. CHECKOUT
    .. "' -c user.name=test -c user.email=test@localhost commit -q --allow-empty -m one")
write(ROOT .. "/input/blitter", series.SETTINGS)
write(ROOT .. "/endpoints", slurp(DIR .. "/endpoints"))
write(ROOT .. "/input/turn-runner", slurp(DIR .. "/input/turn-runner"))
write(ROOT .. "/input/stand-in-turn", 'words = "lantern harbor kitten orchard"\nseconds = 0.5\n')
write(ROOT .. "/input/to-voices", 'send = "off"\nmailbox = "~/guide-mail"\ntell-the-voice = "on"\n'
    .. 'project-checkout = "' .. CHECKOUT .. '"\n')
local function rehearsal_settings(over)
    local values = { minutes = "0.33", carrier = '"stand-in"', ["first-port"] = "41223",
        pace = "1", jitter = "0.5", rmail = '"luajit /nowhere/rmail.lua"' }
    for key, value in pairs(over or {}) do values[key] = value end
    local out = {}
    for _, key in ipairs({ "minutes", "carrier", "first-port", "pace", "jitter", "rmail" }) do
        out[#out + 1] = key .. " = " .. values[key]
    end
    write(ROOT .. "/input/rehearsal", table.concat(out, "\n") .. "\n")
end
rehearsal_settings()
local SHM = BASE .. "/shm/guide-feature"
local WS = SHM .. "/rehearsal"
-- }}}

io.write("\n=== twenty seconds of the whole round ===\n")
-- {{{
local out, status = shell(ENV .. q(ROOT .. "/scripts/rehearse") .. " " .. q(ROOT))
check("it runs and ends cleanly", status == 0, out)
check("it says what each voice did", has(out, "fg-sora-1: ") and has(out, "fg-sora-3: ")
    and has(out, "versions; timings in"), out)
local log = slurp(SHM .. "/rehearsal.log") or ""
check("the four mailboxes were made by the mailbox setup", has(log, "mailboxes made:")
    and has(log, "guide") and has(log, "fg-sora-3"), log)

-- the timings: one row per voice turn
local rows, header = {}, nil
for line in string.gmatch(slurp(SHM .. "/rehearsal-timings") or "", "[^\n]+") do
    if string.sub(line, 1, 1) == "#" then header = line
    else
        local f = {}
        for field in string.gmatch(line, "%S+") do f[#f + 1] = field end
        rows[#rows + 1] = { voice = f[1], turn = tonumber(f[2]), base = tonumber(f[3]),
            version = tonumber(f[4]), outcome = f[5], times = { select(6, unpack(f)) } }
    end
end
check("the timings name their columns", has(header, "published received taken finished "
    .. "delivered arrived blitted back"), header)
local blitted = {}
for _, r in ipairs(rows) do
    if r.outcome == "blitted" then blitted[r.voice] = (blitted[r.voice] or 0) + 1 end
end
check("every voice's turns came back as new versions, more than once each",
    (blitted["fg-sora-1"] or 0) >= 2 and (blitted["fg-sora-2"] or 0) >= 2
    and (blitted["fg-sora-3"] or 0) >= 2, slurp(SHM .. "/rehearsal-timings"))
local in_order, full, problem = true, 0, nil
for _, r in ipairs(rows) do
    local last = -1
    for index, value in ipairs(r.times) do
        local t = tonumber(value)
        if t then
            if t + 0.002 < last then
                in_order, problem = false, r.voice .. " turn " .. tostring(r.turn) .. " stage " .. index
            end
            last = t
        end
    end
    if r.outcome == "blitted" and #r.times == 8 then
        local all = true
        for _, value in ipairs(r.times) do if value == "-" then all = false end end
        if all then full = full + 1 end
    end
end
check("in every row the stages come in order", in_order, problem)
local named = true
for _, r in ipairs(rows) do
    if not ({ blitted = true, unchanged = true, superseded = true, ["in-flight"] = true })[r.outcome] then
        named = false
    end
end
check("every row says how the turn ended: blitted, unchanged, superseded or in flight", named)
local turn_time = true
for _, r in ipairs(rows) do
    local taken, finished = tonumber(r.times[3]), tonumber(r.times[4])
    if taken and finished and finished - taken < 0.45 then turn_time = false end
end
check("each row's turn took the stand-in's half second, from taken to finished", turn_time)
check("whole rows, every stage timed from the version published to it coming back", full >= 3, full)
local paced = true
for _, r in ipairs(rows) do
    local finished, delivered = tonumber(r.times[4]), tonumber(r.times[5])
    if finished and delivered and delivered - finished > 1.5 + 0.5 then paced = false end
end
check("a voice's canvas waits no longer than its contact's timer (1 s give or take 0.5)", paced)
local made = {}
for _, r in ipairs(rows) do if r.version then made[r.version] = r end end
local based = true
for _, r in ipairs(rows) do
    if r.base and r.base > 1 and not made[r.base] then based = false end
end
check("every turn was on version 1 or one the voices made", based)

local events = slurp(SHM .. "/rehearsal-events") or ""
check("the events, in time: carried, received, taken, sent, arrived, published",
    has(events, " carried-new ") and has(events, " carried-edit ") and has(events, " received ")
    and has(events, " taken ") and has(events, " sent ") and has(events, " arrived ")
    and has(events, " published "))
check("the second voice's canvas is carried into the guide's inbox under rmail's name",
    has(events, "fg-sora-2 -> guide canvas"))

local receipt = goodbye.read(ROOT .. "/output/goodbye-rehearsal")
local c = receipt and receipt.counters or {}
local agree = true
for _, voice in ipairs(rehearsal.VOICES) do
    local p = function(name) return c[voice .. "." .. name] or 0 end
    if not (p("canvases-replaced") <= p("canvases-waited") and p("canvases-waited")
        <= p("canvases-received") and p("canvases-sent") <= p("turns-run")
        and p("turns-run") <= p("canvases-received") and p("canvases-sent") >= 2) then
        agree = false
    end
end
check("the receipt's counts agree (replaced <= waited <= received, sent <= turns)", agree)
-- canvases that waited, counted again here from the events
local waited, busy = {}, {}
for line in string.gmatch(events, "[^\n]+") do
    local voice, what = string.match(line, "^%S+ (%S+) (%S+)")
    if what == "taken" then busy[voice] = true
    elseif what == "sent" or what == "unchanged" or what == "failed" or what == "refused" then
        busy[voice] = false
    elseif what == "received" and busy[voice] then waited[voice] = (waited[voice] or 0) + 1 end
end
local same = true
for _, voice in ipairs(rehearsal.VOICES) do
    if (waited[voice] or 0) ~= (c[voice .. ".canvases-waited"] or 0) then same = false end
end
check("canvases that waited: the receipt's count is the events' (received while a turn ran)", same)
check("versions counted", (c.versions or 0) >= 7 and c["voice-turns-blitted"] >= 6, c.versions)
check("the workspace is gone", slurp(WS .. "/set") == nil)
local ps = shell("ps -eo args")
local left = {}
for line in string.gmatch(ps, "[^\n]+") do if has(line, WS) then left[#left + 1] = line end end
check("no turn runner or hook of it left running", #left == 0, table.concat(left, "\n"))
-- }}}

io.write("\n=== --keep, and real rmail daemons ===\n")
-- {{{
rehearsal_settings({ minutes = "0.05" })
out, status = shell(ENV .. q(ROOT .. "/scripts/rehearse") .. " " .. q(ROOT) .. " --keep")
check("--keep leaves the workspace to read", status == 0 and slurp(WS .. "/set") ~= nil
    and slurp(WS .. "/mail/fg-sora-2/config") ~= nil, out)
shell("rm -rf " .. q(WS))

local FAKE = BASE .. "/fake-rmail"
write(FAKE, "#!/bin/sh\necho \"$1 $$\" >> " .. q(BASE .. "/daemons-started") .. "\nexec sleep 60\n")
shell("chmod +x " .. q(FAKE))
rehearsal_settings({ minutes = "0.05", carrier = '"rmail"', rmail = '"' .. FAKE .. '"' })
out, status = shell(ENV .. q(ROOT .. "/scripts/rehearse") .. " " .. q(ROOT))
local started = slurp(BASE .. "/daemons-started") or ""
check("carrier rmail: one daemon per mailbox, each given its config", status == 0
    and has(started, WS .. "/mail/guide/config") and has(started, WS .. "/mail/fg-sora-3/config")
    and select(2, string.gsub(started, "\n", "")) == 4, started .. out)
local alive = 0
for pid in string.gmatch(started, " (%d+)\n") do
    local stat = slurp("/proc/" .. pid .. "/stat")      -- a zombie has ended
    if stat and not string.match(stat, "^%d+ %b() Z") then alive = alive + 1 end
end
check("and all stopped at the end", alive == 0 and started ~= "", alive)
-- }}}

shell("rm -rf '" .. BASE .. "'")
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
