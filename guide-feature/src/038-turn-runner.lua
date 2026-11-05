-- 038-turn-runner.lua - one voice's turns, one at a time, always from the
-- newest canvas.
--
-- In plain terms: step 4 of docs/datapath-round-trip.md. The turn hook (037)
-- leaves the newest canvas from kuvalu in tmp/shared-memory/turn/<voice>/
-- waiting and starts this in the background. It takes the voice's lock, then
-- repeats: take the waiting canvas, run one turn on it, send the result back
-- to kuvalu as the voice's living message outbox/canvas, until nothing is
-- waiting. Then it lets go of the lock and exits. A canvas that arrives
-- during a turn waits; of two that arrive during one turn only the newer is
-- there to take. (issue 304)
--
-- The lock is the directory turn/<voice>/lock, holding a file `pid` with the
-- runner's process number and the time the system started that process. It
-- is made under another name with its pid file already in it, then renamed
-- into place, which either succeeds or fails in one step, so two runners can
-- never both hold it and no runner ever sees a lock without its number. A
-- lock whose process is not running (or is a different process that was
-- given the same number) was left by a runner that died; it is moved aside,
-- removed, and a log line says so.
--
-- "Run one turn" is a program named by the `turn` setting in
-- input/turn-runner, run as
--   <turn> --dir ROOT --voice NAME --turn N --canvas FILE --out FILE
-- reading the to-voices canvas in FILE and writing the voice's from-voice
-- canvas to --out. In phase 3 that is scripts/stand-in-turn (039); the real
-- turn (405) replaces it by changing the setting, not this file. What the turn
-- writes is read back and checked (voice, turn, base, size) before anything
-- is sent; a turn that changed nothing sends nothing.
--
--   luajit src/038-turn-runner.lua --dir ROOT --mailbox ~/guide-mail-fg-sora-1
--   local runner = dofile(DIR .. "/src/038-turn-runner.lua")
--   runner.run(root, mailbox_folder)          -- what the program does
--   runner.take_lock(folder, note), runner.release(folder), runner.holder(folder)
--
-- The voice is the mailbox's own name (its config's `name`), so several
-- voices can share one project, each with its own folder under turn/. Each
-- voice's turn number is kept on disk in output/turn-counter-<voice> and
-- grows by one for every canvas sent. One line per event goes to
-- turn/<voice>/events (`<unix time with ms> <event> <version> [turn]`), for
-- the rehearsal's timings (305); the receipt output/goodbye-turn-runner-
-- <voice> counts turns-run, canvases-sent, unchanged-turns, turns-failed and
-- canvases-refused. LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int getpid(void);")
pcall(ffi.cdef, "int kill(int pid, int sig);")
pcall(ffi.cdef, "typedef struct { long tv_sec; long tv_nsec; } guide_timespec;")
pcall(ffi.cdef, "int clock_gettime(int clock, guide_timespec *tp);")

local settings = dofile(DIR .. "/src/001-settings.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
local mailboxes = dofile(DIR .. "/src/031-mailboxes.lua")

local M = {}
M.SUBJECT = "canvas"       -- the voice's living message to kuvalu

-- {{{ M.SETTINGS
-- input/turn-runner. The hook reads it too (for `guide`).
M.SETTINGS = {
    ["guide"] = { type = "text", required = true },   -- the contact canvases come from and go to
    ["turn"]  = { type = "text", required = true },   -- the program that runs one turn
}
-- }}}

-- {{{ small helpers
local function quote(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end
M.quote = quote

local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end

local function write(path, text)
    local handle = io.open(path, "wb")
    if not handle then return false end
    handle:write(text)
    handle:close()
    return true
end

local function exists(path)
    local handle = io.open(path, "rb")
    if handle then handle:close() return true end
    return false
end

-- A command's output and exit status (io.popen's close does not give it
-- under LuaJIT).
local function shell(command)
    local pipe = io.popen(command .. " 2>&1; echo \"exit:$?\"")
    local text = pipe:read("*a")
    pipe:close()
    local body, status = string.match(text, "^(.-)\n?exit:(%d+)\n$")
    return body or text, tonumber(status)
end

-- The time now, in seconds with milliseconds.
function M.now()
    local spec = ffi.new("guide_timespec")
    if ffi.C.clock_gettime(0, spec) == 0 then
        return tonumber(spec.tv_sec) + math.floor(tonumber(spec.tv_nsec) / 1e6) / 1000
    end
    return os.time()
end

function M.pid() return ffi.C.getpid() end

-- When the system started a process (field 22 of /proc/<pid>/stat, in clock
-- ticks since boot), or nil where there is no /proc. Two processes given the
-- same number one after the other have different start times.
function M.start_time(pid)
    local text = slurp("/proc/" .. pid .. "/stat")
    if not text then return nil end
    local after = string.match(text, "^.*%) (.*)$")   -- the name may hold spaces
    if not after then return nil end
    local fields = {}
    for field in string.gmatch(after, "%S+") do fields[#fields + 1] = field end
    return fields[20]                                 -- field 22 is the 20th after the name
end

-- Whether the process that wrote a lock is still running.
function M.alive(pid, start)
    if not pid then return false end
    if ffi.C.kill(pid, 0) ~= 0 and ffi.errno() ~= 1 then   -- 1: EPERM, running as someone else
        return false
    end
    local now = M.start_time(pid)
    if start and now and start ~= now then return false end
    return true
end
-- }}}

-- {{{ paths
function M.folder(root, voice) return root .. "/tmp/shared-memory/turn/" .. voice end
function M.counter_path(root, voice) return root .. "/output/turn-counter-" .. voice end

-- One line in turn/<voice>/events.
function M.event(folder, what, version, turn)
    local handle = io.open(folder .. "/events", "a")
    if not handle then return end
    handle:write(string.format("%.3f %s %s%s\n", M.now(), what, tostring(version or "-"),
        turn and (" " .. turn) or ""))
    handle:close()
end
-- }}}

-- {{{ the lock
-- Who holds a folder's lock: pid, start time, and whether it is running.
-- nil when there is no lock.
function M.holder(folder)
    local text = slurp(folder .. "/lock/pid")
    if not text then
        -- a lock directory with no readable number is not a lock anyone holds
        local listing = io.open(folder .. "/lock", "rb")
        if listing then listing:close() return false, nil, false end
        return nil
    end
    local pid, start = string.match(text, "^(%d+) ?(%S*)")
    pid = tonumber(pid)
    if start == "" then start = nil end
    return pid, start, M.alive(pid, start)
end

-- Takes the lock. Returns true, or false and the running holder's pid.
-- `note` is given a line when a dead runner's lock is cleared.
function M.take_lock(folder, note)
    local mine = M.pid()
    for _ = 1, 3 do
        local ready = folder .. "/.lock-" .. mine
        os.execute("rm -rf " .. quote(ready) .. " && mkdir -p " .. quote(ready))
        write(ready .. "/pid", mine .. " " .. (M.start_time(mine) or "") .. "\n")
        if os.rename(ready, folder .. "/lock") then return true end
        os.execute("rm -rf " .. quote(ready))
        local pid, start, running = M.holder(folder)
        if running then return false, pid end
        if pid ~= nil then
            -- a dead runner's lock: move it aside in one step, then make sure
            -- it was the one looked at before removing it
            local aside = folder .. "/.stale-" .. mine
            os.execute("rm -rf " .. quote(aside))
            if os.rename(folder .. "/lock", aside) then
                local moved = slurp(aside .. "/pid") or ""
                if (tonumber(string.match(moved, "^(%d+)")) or false) == pid then
                    os.execute("rm -rf " .. quote(aside))
                    if note then
                        note(pid and ("cleared a lock left by process " .. pid
                            .. ", which is not running")
                            or "cleared a lock with no process number in it")
                    end
                else
                    os.rename(aside, folder .. "/lock")   -- someone else's, newly taken
                end
            end
        end
    end
    local pid = M.holder(folder)
    return false, pid
end

-- Lets go of the lock, if it is this process's: moved aside in one step,
-- then removed, so the name `lock` is never an empty directory another
-- runner could rename onto. Someone else's lock is put back.
function M.release(folder)
    local mine = M.pid()
    local aside = folder .. "/.released-" .. mine
    if os.rename(folder .. "/lock", aside) then
        if tonumber(string.match(slurp(aside .. "/pid") or "", "^(%d+)")) == mine then
            os.execute("rm -rf " .. quote(aside))
        else
            os.rename(aside, folder .. "/lock")
        end
    end
end
-- }}}

-- {{{ function M.context()
-- What a run needs, from the mailbox and input/turn-runner. Errors name what
-- is wrong.
function M.context(root, mailbox)
    local values = settings.read("turn-runner", M.SETTINGS, { root = root })
    if not string.match(values.guide, "^[%w_%-]+$") then
        error("input/turn-runner: guide must be a contact's name, not " .. values.guide, 0)
    end
    local config = mailboxes.read_config(mailbox .. "/config")
    local voice = config and config.name
    if not voice or not string.match(voice, "^[%w_%-]+$") then
        error("turn-runner: " .. mailbox .. "/config has no name a voice can have", 0)
    end
    local turn = values.turn
    if string.sub(turn, 1, 1) ~= "/" then turn = root .. "/" .. turn end
    return { root = root, mailbox = mailbox, voice = voice, guide = values.guide,
             turn = turn, folder = M.folder(root, voice) }
end
-- }}}

-- {{{ function M.turn_once()
-- One turn on the canvas in `taken`. Returns what happened: "sent",
-- "unchanged", "failed" or "refused", and a line for the log.
function M.turn_once(ctx, run, taken)
    local text = slurp(taken) or ""
    local ok, record = pcall(canvas.read, text, "to-voices", "turn/waiting")
    if not ok then
        run:count("canvases-refused")
        return "refused", nil, nil, "the waiting canvas does not read: " .. tostring(record)
    end
    local base = record.headers.canvas
    local counter = M.counter_path(ctx.root, ctx.voice)
    local last = tonumber(string.match(slurp(counter) or "", "^(%d+)")) or 0
    local turn = last + 1
    local out = ctx.folder .. "/turn-out"
    os.remove(out)
    local started = M.now()
    local output, status = shell(quote(ctx.turn) .. " --dir " .. quote(ctx.root)
        .. " --voice " .. quote(ctx.voice) .. " --turn " .. turn .. " --canvas "
        .. quote(taken) .. " --out " .. quote(out))
    local took = M.now() - started
    run:count("turns-run")
    local function failed(why)
        run:count("turns-failed")
        return "failed", base, turn, string.format("turn %d on version %d failed after %.2fs: %s",
            turn, base, took, why)
    end
    if status ~= 0 then
        return failed("the turn program exited " .. tostring(status)
            .. (output ~= "" and (": " .. string.sub(output, -300)) or ""))
    end
    local written = slurp(out)
    if not written then return failed("the turn wrote nothing to " .. out) end
    local read_ok, voice = pcall(canvas.read, written, "from-voice", "the turn's canvas")
    if not read_ok then return failed(tostring(voice)) end
    local h = voice.headers
    if h.voice ~= ctx.voice or h.turn ~= turn or h.base ~= base
        or voice.width ~= record.width or voice.height ~= record.height then
        return failed(string.format("its headers say voice %s turn %d base %d size %dx%d; "
            .. "expected %s %d %d %dx%d", h.voice, h.turn, h.base, voice.width, voice.height,
            ctx.voice, turn, base, record.width, record.height))
    end
    local same = true
    for row = 1, record.height do
        if voice.rows[row] ~= record.rows[row] then same = false break end
    end
    if same then
        run:count("unchanged-turns")
        return "unchanged", base, nil, string.format("turn on version %d changed nothing "
            .. "(%.2fs); nothing sent", base, took)
    end
    -- the living message to kuvalu: written aside, then renamed into place
    local outbox = ctx.mailbox .. "/outbox"
    os.execute("mkdir -p " .. quote(outbox))
    local part = outbox .. "/." .. M.SUBJECT .. ".part"
    if not write(part, "to: " .. ctx.guide .. "\n\n" .. canvas.write(voice, "from-voice"))
        or not os.rename(part, outbox .. "/" .. M.SUBJECT) then
        os.remove(part)
        return failed("cannot write " .. outbox .. "/" .. M.SUBJECT)
    end
    local counter_part = counter .. ".part"
    write(counter_part, turn .. "\n")
    os.rename(counter_part, counter)
    run:count("canvases-sent")
    return "sent", base, turn, string.format("turn %d on version %d sent (%.2fs)", turn,
        base, took)
end
-- }}}

-- {{{ function M.run()
-- The program: take the lock, run turns while canvases wait, let go.
-- Returns the number of turns run, or nil and why when another runner holds
-- the lock. opts.goodbye: the goodbye module (tests pass a clock through it).
function M.run(root, mailbox, opts)
    opts = opts or {}
    local ctx = M.context(root, mailbox)
    local tiers = dofile(root .. "/libs/ensure-ram-tiers.lua")
    tiers.ensure(root, root)
    os.execute("mkdir -p " .. quote(ctx.folder) .. " " .. quote(root .. "/output"))
    local notes = {}
    local held, pid = M.take_lock(ctx.folder, function(line) notes[#notes + 1] = line end)
    if not held then
        M.event(ctx.folder, "busy", nil)
        return nil, "another runner (process " .. tostring(pid) .. ") holds the lock"
    end
    local goodbye = opts.goodbye or dofile(root .. "/src/002-goodbye.lua")
    local run = goodbye.start("turn-runner-" .. ctx.voice, { root = root, clock = opts.clock })
    for _, line in ipairs(notes) do run:log(line) end
    local waiting = ctx.folder .. "/waiting"
    local taken = ctx.folder .. "/taken"
    local turns = 0
    local ok, problem = pcall(function()
        while true do
            while os.rename(waiting, taken) do
                M.event(ctx.folder, "taken", string.match(slurp(taken) or "", "^canvas: (%d+)"))
                local what, base, turn, line = M.turn_once(ctx, run, taken)
                M.event(ctx.folder, what, base, turn)
                run:log(line)
                os.remove(taken)
                os.remove(ctx.folder .. "/turn-out")
                turns = turns + 1
            end
            M.release(ctx.folder)
            -- a canvas that came after the last look and before the release
            -- found the lock held, so its hook started no runner: look once more
            if not exists(waiting) then break end
            if not M.take_lock(ctx.folder, function(line) run:log(line) end) then break end
        end
    end)
    if not ok then
        M.release(ctx.folder)
        run:log("stopped: " .. tostring(problem))
        error(problem, 0)
    end
    run:finish()
    return turns
end
-- }}}

-- {{{ run as a program
if arg and arg[0] and string.match(arg[0], "038%-turn%-runner%.lua$") then
    local root, mailbox = DIR, nil
    local index = 1
    while index <= #arg do
        if arg[index] == "--dir" then root = arg[index + 1]
        elseif arg[index] == "--mailbox" then mailbox = arg[index + 1]
        else
            io.stderr:write("usage: turn-runner [--dir ROOT] --mailbox FOLDER\n")
            os.exit(2)
        end
        index = index + 2
    end
    if not mailbox then
        io.stderr:write("usage: turn-runner [--dir ROOT] --mailbox FOLDER\n")
        os.exit(2)
    end
    local ok, turns, why = pcall(M.run, root, mailbox)
    if not ok then
        io.stderr:write(tostring(turns), "\n")
        local log = io.open(root .. "/tmp/shared-memory/turn-hook.log", "a")
        if log then
            log:write(os.date("!%Y-%m-%dT%H:%M:%SZ"), " turn-runner: ", tostring(turns), "\n")
            log:close()
        end
        os.exit(1)
    end
    if not turns then io.stderr:write(why, "\n") end
    os.exit(0)
end
-- }}}

return M
