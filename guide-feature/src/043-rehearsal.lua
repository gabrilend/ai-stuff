-- 043-rehearsal.lua - the whole round on kuvalu: the guide mailbox, three
-- stand-in voices, the hooks, the turn runners and the blitter, together.
--
-- In plain terms: before any mini-computer is set up, this plays the whole
-- relay on one machine (docs/datapath-round-trip.md, steps 1 to 7). It makes
-- four mailboxes in RAM with the mailbox setup (301): the guide, with the
-- arrival hook (302), and fg-sora-1, -2 and -3, each with the guide as its
-- contact and the turn hook (304) running the stand-in turn. Then it runs
-- the blitter with the canvas mailed to the voices (303), carries the mail
-- between them, and measures every voice turn:
--
--   published   the version written to the guide's outbox
--   received    the voice's turn hook left it waiting
--   taken       the turn runner took it
--   finished    the turn ended and the voice's canvas was in its outbox
--   delivered   the carrier put it in the guide's inbox (stand-in carrier)
--   arrived     it was in the blitter's arrivals folder
--   blitted     the blitter took it (a new version, or unchanged)
--   back        the voice received the version its turn made
--
-- It stays the test bench for every later change: the real turn (405) and
-- distill mode (601) are first run here.
--
-- Everything is made in a workspace in RAM, tmp/shared-memory/rehearsal/: a
-- copy of the project (src/, libs/ and scripts/ linked, its own input/ and
-- RAM tiers), so nothing already running on the project is touched, and the
-- four mailboxes beside it. The mail is carried by the stand-in carrier
-- (041), on this machine only, or, on the owner's machine, by real rmail
-- daemons (`carrier = "rmail"`). It is all removed at the end; what stays
-- is the log and the timings:
--   tmp/shared-memory/rehearsal.log        what happened, line by line
--   tmp/shared-memory/rehearsal-timings    one line per voice turn
--   tmp/shared-memory/rehearsal-events     every event, time ordered
--   output/goodbye-rehearsal               the counts
--
--   scripts/rehearse [ROOT] [--minutes M] [--keep]
--   local rehearsal = dofile(DIR .. "/src/043-rehearsal.lua")
--   local result = rehearsal.run({ root = ROOT, on_version = function(record, voice) end })
--
-- Settings in input/rehearsal; the voices' turn in input/turn-runner (the
-- real turn, 405, with input/turn, input/turn-instructions and the voices'
-- endpoints from the endpoints file; or the stand-in, with
-- input/stand-in-turn), the canvas in input/blitter and the project's
-- checkout in input/to-voices, all copied into the workspace.
-- (issue 305) LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")
pcall(ffi.cdef, "int poll(void *fds, unsigned long nfds, int timeout);")
pcall(ffi.cdef, "int kill(int pid, int sig);")

local settings = dofile(DIR .. "/src/001-settings.lua")
local goodbye = dofile(DIR .. "/src/002-goodbye.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
local blitter = dofile(DIR .. "/src/016-blitter.lua")
local mailboxes = dofile(DIR .. "/src/031-mailboxes.lua")
local to_voices = dofile(DIR .. "/src/035-to-voices.lua")
local runner = dofile(DIR .. "/src/038-turn-runner.lua")
local carrier_module = dofile(DIR .. "/src/041-stand-in-carrier.lua")

local M = {}
M.VOICES = { "fg-sora-1", "fg-sora-2", "fg-sora-3" }
M.STAGES = { "published", "received", "taken", "finished", "delivered", "arrived",
             "blitted", "back" }

-- {{{ M.SETTINGS
M.SETTINGS = {
    ["minutes"]    = { type = "decimal", required = true },   -- how long it runs
    ["carrier"]    = { type = "choice", of = { "stand-in", "rmail" }, required = true },
    ["first-port"] = { type = "whole", required = true },     -- the guide's; voices the next three
    ["pace"]       = { type = "decimal", required = true },   -- stand-in: a contact's timer, seconds
    ["jitter"]     = { type = "decimal", required = true },   -- stand-in: give or take, seconds
    ["rmail"]      = { type = "text", required = true },      -- rmail: the command run with a config
}
-- }}}

-- {{{ small helpers
local quote = runner.quote
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
local function sleep(seconds) ffi.C.poll(nil, 0, math.floor(seconds * 1000)) end
local function shell(command)
    local pipe = io.popen(command .. " 2>&1; echo \"exit:$?\"")
    local text = pipe:read("*a")
    pipe:close()
    local body, status = string.match(text, "^(.-)\n?exit:(%d+)\n$")
    return body or text, tonumber(status)
end
local function fail(text) error("rehearsal: " .. text, 0) end
-- a settings value written back as its file holds it
local function text_value(value) return '"' .. string.gsub(value, '[\\"]', "\\%0") .. '"' end
-- }}}

-- {{{ function M.workspace()
-- Makes the workspace: the project copy with its input, and the four
-- mailboxes made by the mailbox setup. Returns its paths.
function M.workspace(root, values, ws)
    local w = { base = ws, root = ws .. "/project/guide-feature", mail = ws .. "/mail" }
    shell("rm -rf " .. quote(ws))
    shell("mkdir -p " .. quote(w.root .. "/input") .. " " .. quote(w.root .. "/output") .. " "
        .. quote(ws .. "/exec") .. " " .. quote(ws .. "/shm") .. " " .. quote(w.mail))
    for _, link in ipairs({ "src", "libs", "scripts" }) do
        shell("ln -s " .. quote(root .. "/" .. link) .. " " .. quote(w.root .. "/" .. link))
    end
    for _, name in ipairs({ "blitter", "turn-runner", "stand-in-turn" }) do
        local text = slurp(root .. "/input/" .. name)
        if not text then fail("input/" .. name .. " is missing") end
        write(w.root .. "/input/" .. name, text)
    end
    -- the real turn's settings and words (405), when the project has them
    for _, name in ipairs({ "turn", "turn-instructions" }) do
        local text = slurp(root .. "/input/" .. name)
        if text then write(w.root .. "/input/" .. name, text) end
    end
    -- the endpoints file, which names each voice's endpoint in every version
    -- the guide sends (402)
    local endpoints = slurp(root .. "/endpoints")
    if not endpoints then fail("there is no endpoints file in the project root") end
    write(w.root .. "/endpoints", endpoints)
    -- the canvas to the voices: the project's endpoint and checkout, the
    -- workspace's guide mailbox, always sent
    local mailed = settings.read("to-voices", to_voices.SETTINGS, { root = root })
    w.guide = w.mail .. "/guide"
    write(w.root .. "/input/to-voices", table.concat({
        "send = " .. text_value("on"), "mailbox = " .. text_value(w.guide),
        "tell-the-voice = " .. text_value(mailed["tell-the-voice"]),
        "project-checkout = " .. text_value(mailed["project-checkout"]) }, "\n") .. "\n")
    local guide = settings.read("turn-runner", runner.SETTINGS, { root = w.root }).guide
    -- the four mailboxes, on this machine, by the mailbox setup (301)
    local port = values["first-port"]
    local lines = {
        guide .. ".folder = " .. text_value(w.guide), guide .. ".port = " .. port,
        guide .. ".ip = " .. text_value("127.0.0.1"), guide .. ".hook = " .. text_value("arrival"),
        guide .. ".project = " .. text_value(w.root),
        guide .. ".contacts = " .. text_value(table.concat(M.VOICES, " ")),
    }
    w.boxes = { w.guide }
    for number, voice in ipairs(M.VOICES) do
        local folder = w.mail .. "/" .. voice
        w.boxes[#w.boxes + 1] = folder
        for _, line in ipairs({
            ".folder = " .. text_value(folder), ".port = " .. (port + number),
            ".ip = " .. text_value("127.0.0.1"), ".hook = " .. text_value("turn"),
            ".project = " .. text_value(w.root), ".contacts = " .. text_value(guide) }) do
            lines[#lines + 1] = voice .. line
        end
    end
    write(ws .. "/set", table.concat(lines, "\n") .. "\n")
    local out, status = shell(quote(w.root .. "/scripts/make-mailboxes") .. " " .. quote(w.root)
        .. " --set " .. quote(ws .. "/set"))
    if status ~= 0 then fail("the mailboxes could not be made: " .. out) end
    w.made = out
    return w
end
-- }}}

-- {{{ local function voice_events()
-- New lines of each voice's events file since the last call.
local function voice_events(w, seen)
    local found = {}
    for _, voice in ipairs(M.VOICES) do
        local text = slurp(w.root .. "/tmp/shared-memory/turn/" .. voice .. "/events") or ""
        local from = seen[voice] or 0
        if #text > from then
            local chunk = string.sub(text, from + 1)
            local last = 0
            for line, stop in string.gmatch(chunk, "([^\n]*)\n()") do
                local at, what, version, turn = string.match(line, "^([%d%.]+) (%S+) (%S+) ?(%d*)$")
                if at then
                    found[#found + 1] = { at = tonumber(at), voice = voice, what = what,
                        version = tonumber(version), turn = tonumber(turn), order = #found }
                end
                last = stop - 1
            end
            seen[voice] = from + last
        end
    end
    -- in time, and in the order written where two share a millisecond
    table.sort(found, function(a, b)
        if a.at ~= b.at then return a.at < b.at end
        return a.order < b.order
    end)
    return found
end
-- }}}

-- {{{ function M.run()
-- The rehearsal. opts: root, minutes (over the setting), keep (leave the
-- workspace), on_version (called with each version, the voice that made it,
-- the blitter and that turn's timing row, for a demo to draw). Returns a summary: turns (the timing
-- rows), events, versions, counts, and the workspace's paths.
function M.run(opts)
    opts = opts or {}
    local root = opts.root or DIR
    local values = settings.read("rehearsal", M.SETTINGS, { root = root })
    local minutes = opts.minutes or values.minutes
    local tiers = dofile(root .. "/libs/ensure-ram-tiers.lua")
    tiers.ensure(root, root)
    local run = goodbye.start("rehearsal", { root = root })
    local log_path = root .. "/tmp/shared-memory/"
    -- the workspace has its own RAM tiers, for everything started from here on
    -- (by its real path: the tiers check where their links point)
    local base = shell("mkdir -p " .. quote(root .. "/tmp/shared-memory/rehearsal") .. " && cd "
        .. quote(root .. "/tmp/shared-memory/rehearsal") .. " && pwd -P")
    ffi.C.setenv("EXEC_TIER_ROOT", base .. "/exec", 1)
    ffi.C.setenv("ARTIFACT_TIER_ROOT", base .. "/shm", 1)
    local w = M.workspace(root, values, base)
    tiers.ensure(w.root, w.root)
    run:log("workspace " .. w.base .. "; mailboxes made: " .. string.gsub(w.made, "\n", "; "))

    local start = runner.now()
    local function since(at) return at and string.format("%.3f", at - start) or "-" end
    local events, turns, versions = {}, {}, {}
    local function event(at, voice, what, version, turn, detail)
        events[#events + 1] = { at = at, voice = voice, what = what, version = version,
            turn = turn, detail = detail }
    end
    -- one timing row per voice turn, keyed voice/turn
    local function row(voice, turn)
        local key = voice .. "/" .. turn
        if not turns[key] then
            turns[key] = { voice = voice, turn = turn }
            turns[#turns + 1] = turns[key]
        end
        return turns[key]
    end
    local published, received_at = {}, {}

    -- the blitter, with the canvas mailed to the voices and a publisher
    -- that times every version
    local mail_publisher = assert(to_voices.publisher({ root = w.root, voices = M.VOICES }))
    local function timing_publisher(b, record, report, voice)
        local version, at = record.headers.canvas, runner.now()
        published[version] = at
        versions[#versions + 1] = { version = version, voice = voice, at = at,
            turn = voice and b.last_turn[voice] }
        event(at, voice or "kuvalu", "published", version, voice and b.last_turn[voice])
        local r
        if voice then
            r = row(voice, b.last_turn[voice])
            r.blitted, r.version = at, version
        end
        if opts.on_version then opts.on_version(record, voice, b, r) end
    end
    local b = blitter.new({ root = w.root, wait = function() end,
        commit = to_voices.commit_of(settings.read("to-voices", to_voices.SETTINGS,
            { root = w.root })["project-checkout"]),
        publishers = { blitter.log_publisher, mail_publisher, timing_publisher } })

    -- the carrier: the stand-in here, or real rmail daemons
    local carrier, daemons = nil, {}
    if values.carrier == "stand-in" then
        carrier = carrier_module.new({ folders = w.boxes, pace = values.pace,
            jitter = values.jitter, scratch = w.base,
            event = function(e)
                local turn = tonumber(string.match(e.body or "", "\nturn: (%d+)\n"))
                local version = tonumber(string.match(e.body or "", "^canvas: (%d+)\n"))
                    or tonumber(string.match(e.body or "", "\nbase: (%d+)\n"))
                local voice = e.from == "guide" and e.to or e.from
                event(e.at, voice, "carried-" .. e.kind, version, turn,
                    e.from .. " -> " .. e.to .. " " .. e.subject)
                if e.from ~= "guide" and turn and (e.kind == "new" or e.kind == "edit") then
                    row(voice, turn).delivered = e.at
                end
                if e.kind ~= "new" and e.kind ~= "edit" then
                    run:log(string.format("carrier: %s -> %s %s: %s", e.from, e.to, e.subject, e.kind))
                end
            end })
        run:log(string.format("the stand-in carrier: a contact is due every %s s, give or take %s s",
            values.pace, values.jitter))
    else
        for _, folder in ipairs(w.boxes) do
            local pid = tonumber((shell("setsid " .. values.rmail .. " " .. quote(folder .. "/config")
                .. " >>" .. quote(folder .. "/daemon.log") .. " 2>&1 </dev/null & echo $!")))
            daemons[#daemons + 1] = pid
            local list = io.open(w.base .. "/daemons", "a")
            if list then list:write(tostring(pid), "\n") list:close() end
            run:log("started rmail for " .. folder .. " as process " .. tostring(pid))
        end
    end

    -- the loop: carry, take arrivals, read the voices' events
    local seen, arrived = {}, {}
    local deadline = start + minutes * 60
    local ok, problem = pcall(function()
        while runner.now() < deadline do
            if carrier then carrier:round() end
            local names = blitter.pending(b.arrivals)
            for _, name in ipairs(names) do
                local at = runner.now()
                local text = slurp(b.arrivals .. "/" .. name) or ""
                local voice = string.match(text, "^voice: (%S+)\n")
                local turn = tonumber(string.match(text, "\nturn: (%d+)\n"))
                local r = voice and turn and row(voice, turn)
                if r then
                    -- the voice's own events may be read after its arrival
                    r.base = r.base or tonumber(string.match(text, "\nbase: (%d+)\n"))
                    r.published = r.published or (r.base and published[r.base])
                end
                local outcome = b:take(name)
                if r then
                    r.arrived, r.outcome = at, outcome
                    if outcome ~= "blitted" then r.blitted = runner.now() end
                    event(at, voice, "arrived", tonumber(string.match(text, "\nbase: (%d+)\n")),
                        turn, outcome)
                end
            end
            for _, e in ipairs(voice_events(w, seen)) do
                event(e.at, e.voice, e.what, e.version, e.turn)
                if e.what == "received" and e.version then
                    received_at[e.voice .. "/" .. e.version] = e.at
                    -- the version some turn of this voice made has come back
                    for _, r in ipairs(turns) do
                        if r.voice == e.voice and r.version == e.version and not r.back then
                            r.back = e.at
                        end
                    end
                elseif e.what == "taken" and e.version then
                    seen[e.voice .. "/taken"] = e
                elseif (e.what == "sent" or e.what == "unchanged" or e.what == "failed")
                    and e.version then
                    local taken = seen[e.voice .. "/taken"]
                    local r = e.turn and row(e.voice, e.turn)
                        or { voice = e.voice, outcome = e.what }
                    if not e.turn then
                        turns[#turns + 1] = r
                        r.outcome = e.what
                    end
                    r.base, r.finished = e.version, e.at
                    r.taken = taken and taken.at
                    r.received = received_at[e.voice .. "/" .. e.version]
                    r.published = published[e.version]
                end
            end
            sleep(0.05)
        end
    end)

    -- teardown: the daemons, the runners, the blitter, the workspace
    for _, pid in ipairs(daemons) do if pid then ffi.C.kill(-pid, 15) ffi.C.kill(pid, 15) end end
    for _, voice in ipairs(M.VOICES) do
        -- the runner and its turn: its own session and process group (setsid)
        local pid = runner.holder(w.root .. "/tmp/shared-memory/turn/" .. voice)
        if pid then ffi.C.kill(-pid, 15) ffi.C.kill(pid, 15) end
    end
    local counters = {}
    for name, value in pairs(b.run.counters) do counters[name] = value end
    b:finish()
    if not ok then run:log("stopped: " .. tostring(problem)) end

    -- the timings, one line per voice turn, times from the start in seconds
    table.sort(turns, function(a, c)
        if a.voice ~= c.voice then return a.voice < c.voice end
        return (a.finished or a.blitted or 0) < (c.finished or c.blitted or 0)
    end)
    local lines = { "# voice turn base version outcome " .. table.concat(M.STAGES, " ")
        .. "   (seconds from the start; - not reached)" }
    -- a canvas sent but never carried: replaced in the voice's outbox by its
    -- next turn's before the voice's timer came round (only the newest of a
    -- living message travels), or still on its way when the rehearsal ended
    local carried_after = {}
    for _, r in ipairs(turns) do
        if r.delivered and r.turn then
            carried_after[r.voice] = math.max(carried_after[r.voice] or 0, r.turn)
        end
    end
    for _, r in ipairs(turns) do
        if not r.outcome and not r.version and r.finished and r.turn then
            r.outcome = (carried_after[r.voice] or 0) > r.turn and "superseded" or "in-flight"
        end
    end
    for _, r in ipairs(turns) do
        lines[#lines + 1] = string.format("%s %s %s %s %s %s %s %s %s %s %s %s %s", r.voice,
            tostring(r.turn or "-"), tostring(r.base or "-"), tostring(r.version or "-"),
            r.outcome or (r.version and "blitted") or "-", since(r.published), since(r.received),
            since(r.taken), since(r.finished), since(r.delivered), since(r.arrived),
            since(r.blitted), since(r.back))
    end
    write(log_path .. "rehearsal-timings", table.concat(lines, "\n") .. "\n")
    for index, e in ipairs(events) do e.order = index end
    table.sort(events, function(a, c)
        if a.at ~= c.at then return a.at < c.at end
        return a.order < c.order
    end)
    local out = {}
    for _, e in ipairs(events) do
        out[#out + 1] = string.format("%s %s %s %s %s%s", since(e.at), e.voice, e.what,
            tostring(e.version or "-"), tostring(e.turn or "-"), e.detail and (" " .. e.detail) or "")
    end
    write(log_path .. "rehearsal-events", table.concat(out, "\n") .. "\n")

    -- the counts
    local per = {}
    for _, voice in ipairs(M.VOICES) do per[voice] = { received = 0, replaced = 0, turns = 0,
        sent = 0, waited = 0 } end
    local busy = {}
    for _, e in ipairs(events) do
        local p = per[e.voice]
        if p then
            if e.what == "received" then
                p.received = p.received + 1
                if busy[e.voice] then p.waited = p.waited + 1 end
            elseif e.what == "replaced" then p.replaced = p.replaced + 1
            elseif e.what == "taken" then busy[e.voice] = true
            elseif e.what == "sent" or e.what == "unchanged" or e.what == "failed"
                or e.what == "refused" then
                busy[e.voice] = false
                p.turns = p.turns + 1
                if e.what == "sent" then p.sent = p.sent + 1 end
            end
        end
    end
    for _, voice in ipairs(M.VOICES) do
        local p = per[voice]
        run:count(voice .. ".canvases-received", p.received)
        run:count(voice .. ".canvases-waited", p.waited)
        run:count(voice .. ".canvases-replaced", p.replaced)
        run:count(voice .. ".turns-run", p.turns)
        run:count(voice .. ".canvases-sent", p.sent)
        run:log(string.format("%s: %d canvases received (%d while a turn ran, %d of those "
            .. "replaced before use), %d turns, %d canvases sent", voice, p.received, p.waited,
            p.replaced, p.turns, p.sent))
    end
    run:count("versions", #versions)
    run:count("voice-turns-blitted", (function()
        local n = 0
        for _, r in ipairs(turns) do if r.outcome == "blitted" or r.version then n = n + 1 end end
        return n
    end)())
    run:log("timings in tmp/shared-memory/rehearsal-timings, events in rehearsal-events")
    if not opts.keep then shell("rm -rf " .. quote(w.base)) end
    run:finish()
    if not ok then error(problem, 0) end
    return { turns = turns, events = events, versions = versions, per = per, start = start,
             blitter = counters, workspace = w }
end
-- }}}

-- {{{ run as a program
if arg and arg[0] and string.match(arg[0], "043%-rehearsal%.lua$") then
    local opts = { root = DIR }
    local index = 1
    while index <= #arg do
        if arg[index] == "--dir" then opts.root = arg[index + 1]; index = index + 2
        elseif arg[index] == "--minutes" then opts.minutes = tonumber(arg[index + 1]); index = index + 2
        elseif arg[index] == "--keep" then opts.keep = true; index = index + 1
        else
            io.stderr:write("usage: rehearse [ROOT] [--minutes M] [--keep]\n")
            os.exit(2)
        end
    end
    local ok, result = pcall(M.run, opts)
    if not ok then
        io.stderr:write(tostring(result), "\n")
        os.exit(1)
    end
    for _, voice in ipairs(M.VOICES) do
        local p = result.per[voice]
        io.write(string.format("%s: %d received, %d waited, %d replaced, %d turns, %d sent\n",
            voice, p.received, p.waited, p.replaced, p.turns, p.sent))
    end
    io.write(#result.versions, " versions; timings in ", opts.root,
        "/tmp/shared-memory/rehearsal-timings\n")
    os.exit(0)
end
-- }}}

return M
