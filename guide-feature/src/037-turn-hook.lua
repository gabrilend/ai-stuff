-- 037-turn-hook.lua - a voice's rmail hook: the newest canvas from kuvalu,
-- left waiting, and the turn runner started if it is idle.
--
-- In plain terms: step 3 of docs/datapath-round-trip.md. rmail runs this
-- when kuvalu's canvas reaches the voice's mailbox, the first time
-- (on_receive) and every time after (on_update, an edit of the same living
-- message). It writes the canvas body to tmp/shared-memory/turn/<voice>/
-- waiting, under a dot name and then renamed, replacing any canvas already
-- waiting there, since only the newest matters. Then it starts the turn
-- runner (038) in the background, unless the voice's lock shows a runner is
-- already running; that runner looks for a waiting canvas when its turn
-- ends. The hook prints nothing, so rmail keeps the body as sent, and exits
-- at once: on_update holds rmail up while it runs, and a turn takes minutes.
-- (issue 304)
--
-- The mailbox's config tells the two calls apart with a word of its own
-- (031):
--   turn-hook receive <sender> <subject> <inbox file>     on_receive
--   turn-hook update  <sender> <inbox file> <new body>    on_update
-- Under rmail #215 on_update's body also comes on standard input, and the
-- argument is empty when the body is over 64 KiB; then it is read from
-- there. Only a message whose subject is `the-canvas` and whose sender is
-- the `guide` contact of input/turn-runner is taken; anything else is
-- logged and left alone. The voice is the mailbox's own name, read from the
-- config beside the inbox file.
--
-- The runner is started detached (its own session, its output to
-- /dev/null): rmail reads the hook's output to its end, and a child holding
-- that output open would hold rmail up for the whole turn.
--
-- Exit status: 0 when the canvas was left waiting or left alone on purpose;
-- 1 when it could not be, which under rmail #215 makes rmail refuse the edit
-- and send it again later. One log line per call, in
-- tmp/shared-memory/turn-hook.log. LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "char *getcwd(char *buf, size_t size);")
local settings = dofile(DIR .. "/src/001-settings.lua")
local mailboxes = dofile(DIR .. "/src/031-mailboxes.lua")
local runner = dofile(DIR .. "/src/038-turn-runner.lua")

local M = {}
M.SUBJECT = "the-canvas"
local quote = runner.quote

-- {{{ small helpers
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end

-- A path made whole against the directory rmail runs in.
local function absolute(path)
    if string.sub(path, 1, 1) == "/" then return path end
    local buffer = ffi.new("char[4096]")
    local cwd = ffi.C.getcwd(buffer, 4096) ~= nil and ffi.string(buffer) or "."
    return cwd .. "/" .. string.gsub(path, "^%./", "")
end

-- Starts the runner for a mailbox, detached, and returns at once.
function M.start_runner(root, mailbox)
    os.execute("setsid " .. quote(root .. "/scripts/turn-runner") .. " --mailbox "
        .. quote(mailbox) .. " </dev/null >/dev/null 2>&1 &")
end
-- }}}

-- {{{ function M.call()
-- One call. `args` are the arguments after --dir; `stdin` a function giving
-- standard input (read only when the body is not in the arguments).
-- opts.start: what starts the runner (tests). Returns the exit status and
-- the log line.
function M.call(root, args, stdin, opts)
    opts = opts or {}
    local kind, sender, subject, body, path = args[1], args[2], nil, nil, nil
    if kind == "receive" and #args == 4 then
        subject, path = args[3], args[4]
        body = slurp(path)
        if not body then
            return 1, string.format("%s receive: the inbox file %s cannot be read",
                tostring(sender), path)
        end
    elseif kind == "update" and #args == 4 then
        path = args[3]
        subject = string.match(path, "([^/]+)$")
        body = args[4]
        if body == "" then body = stdin() or "" end
    else
        return 1, "not a call this hook takes (receive or update, then rmail's three "
            .. "arguments): " .. table.concat(args, " | ")
    end
    if subject ~= M.SUBJECT then
        return 0, string.format("%s %s: left alone, its subject is '%s', not '%s'",
            tostring(sender), kind, tostring(subject), M.SUBJECT)
    end
    local read_ok, values = pcall(settings.read, "turn-runner", runner.SETTINGS, { root = root })
    if not read_ok then
        return 1, string.format("%s %s: %s", tostring(sender), kind, tostring(values))
    end
    if sender ~= values.guide then
        return 0, string.format("%s %s: left alone, the canvas comes from '%s', not from "
            .. "'%s'", tostring(sender), kind, tostring(sender), values.guide)
    end
    if body == "" then
        return 1, string.format("%s %s: the body is empty", sender, kind)
    end

    -- the voice: the name of the mailbox the inbox file is in
    local mailbox = string.match(absolute(path), "^(.*)/inbox/[^/]+$")
    local config = mailbox and mailboxes.read_config(mailbox .. "/config")
    local voice = config and config.name
    if not voice or not string.match(voice, "^[%w_%-]+$") then
        return 1, string.format("%s %s: %s is not in a mailbox's inbox with a name in its "
            .. "config", sender, kind, path)
    end

    -- a reboot empties the RAM tiers; make sure of them before writing
    local ok, problem = pcall(function()
        local tiers = dofile(root .. "/libs/ensure-ram-tiers.lua")
        tiers.ensure(root, root)
    end)
    if not ok then
        return 1, string.format("%s %s: the RAM tiers cannot be made: %s", voice, kind,
            tostring(problem))
    end
    local folder = runner.folder(root, voice)
    os.execute("mkdir -p " .. quote(folder))
    local version = string.match(body, "^canvas: (%d+)")
    local waiting = folder .. "/waiting"
    local replaced = slurp(waiting)
    local part = folder .. "/.waiting"
    local handle = io.open(part, "wb")
    if not handle then
        return 1, string.format("%s %s: cannot write in %s", voice, kind, folder)
    end
    handle:write(body)
    handle:close()
    if not os.rename(part, waiting) then
        os.remove(part)
        return 1, string.format("%s %s: cannot rename into %s", voice, kind, folder)
    end
    runner.event(folder, "received", version)
    local line = string.format("%s %s: version %s waiting", voice, kind, tostring(version))
    if replaced then
        local older = string.match(replaced, "^canvas: (%d+)")
        runner.event(folder, "replaced", older)
        line = line .. string.format(" (replaced version %s, never taken)", tostring(older))
    end

    local pid, _, running = runner.holder(folder)
    if running then
        return 0, line .. string.format("; the runner (process %d) is busy and will take it", pid)
    end
    ;(opts.start or M.start_runner)(root, mailbox)
    return 0, line .. "; runner started"
end
-- }}}

-- {{{ run as a program
if arg and arg[0] and string.match(arg[0], "037%-turn%-hook%.lua$") then
    local root, args = DIR, {}
    local index = 1
    while index <= #arg do
        if arg[index] == "--dir" and #args == 0 then
            root = arg[index + 1]
            index = index + 2
        else
            args[#args + 1] = arg[index]
            index = index + 1
        end
    end
    local status, line = M.call(root, args, function() return io.read("*a") end)
    -- the log is in RAM; a log that cannot be opened is not a reason to fail
    local log = io.open(root .. "/tmp/shared-memory/turn-hook.log", "a")
    if log then
        log:write(os.date("!%Y-%m-%dT%H:%M:%SZ"), " ", line, "\n")
        log:close()
    end
    os.exit(status)
end
-- }}}

return M
