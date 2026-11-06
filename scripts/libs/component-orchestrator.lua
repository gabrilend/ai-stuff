#!/usr/bin/env luajit
-- component-orchestrator.lua
--
-- Starts, stops and watches the long-running parts of a project (a daemon, a
-- client, a model server), in the order their dependencies need, and
-- remembers what it started so a later run can still stop it. Abstracted
-- from handheld-office/scripts/orchestrator.lua (issue 013), which did this
-- for three hard-coded Rust binaries.
--
-- As a library:
--   local orch = require("component-orchestrator")
--   orch.init({ project_dir = "/path/to/project" })
--   orch.register("daemon", { command = "target/release/daemon", port = 8080 })
--   orch.register("client", { command = "target/release/client",
--                             depends_on = { "daemon" } })
--   orch.start_all()        -- daemon first, then client
--   orch.status_all()       -- a table per component
--   orch.health_check("daemon")
--   orch.stop_all()         -- client first, then daemon
--
-- From the shell (what libs/component-orchestrator.sh calls):
--   luajit component-orchestrator.lua [project-dir] <command> [name]
--   commands: start NAME, stop NAME, health NAME, start-all, stop-all, status
--   Components come from <state-dir>/components.tsv (see load_components).
--
-- WHERE THINGS GO
--
-- Everything lives in one state folder, <project>/tmp/orchestrator/ unless
-- init is given another:
--   state.tsv         what is running: name, pid, process start time, when
--   orchestrator.log  one timestamped line per start, stop and failure
--   <name>.out        the component's own output (stdout and stderr)
--   components.tsv    registrations made from the shell wrapper
-- Plain tab-separated lines rather than JSON, so the bash wrapper and a person
-- with grep can read them, and no JSON library has to be found.
--
-- HOW A PROCESS IS TRACKED
--
-- A component runs as `setsid sh -c 'exec <command>'`, so its pid is also its
-- process group: stopping it signals the group, and helpers it spawned stop
-- with it. The old orchestrator stopped things with `pkill -f daemon`, which
-- kills any process whose command line says "daemon". This one signals only
-- the pid it started, and checks first that the pid still belongs to that
-- process: Linux reuses pids, so the process start time from /proc is saved
-- beside the pid and must still match.
--
-- LuaJIT compatible. os.execute's result is read both ways (a number from a
-- stock LuaJIT, true/nil plus a code with Lua 5.2 compatibility).

local MODULE_ARG = ...      -- the module name when required, else the first argument
local orch = {}

-- {{{ state
local config = nil          -- set by init
local components = {}       -- name -> registration
local order = {}            -- names in registration order
local records = {}          -- name -> { pid, ticks, started_at }
local hooks = {}            -- event -> { fn, ... }
-- }}}

-- {{{ local function shell_quote
local function shell_quote(word)
    return "'" .. tostring(word):gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function succeeded
-- Whether os.execute's result means exit status 0, under either LuaJIT build.
local function succeeded(a, b, c)
    if a == true or a == 0 then return true end
    if a == nil and b == "exit" then return c == 0 end
    return false
end
-- }}}

-- {{{ local function quietly
-- Runs a shell command line with its output thrown away; true on exit 0.
local function quietly(line)
    return succeeded(os.execute(line .. " >/dev/null 2>&1"))
end
-- }}}

-- {{{ local function read_command
-- Runs a shell command line and returns its standard output.
local function read_command(line)
    local handle = io.popen(line, "r")
    if not handle then return "" end
    local out = handle:read("*a") or ""
    handle:close()
    return out
end
-- }}}

-- {{{ local function sleep
local function sleep(seconds)
    os.execute(string.format("sleep %.2f", seconds))
end
-- }}}

-- {{{ local function now
local function now()
    return os.date("%Y-%m-%d %H:%M:%S")
end
-- }}}

-- {{{ local function log
-- One timestamped line to the log file, and to stdout unless config.quiet.
local function log(message)
    local line = string.format("[%s] %s", now(), message)
    if not config.quiet then print(line) end
    local f = io.open(config.log_file, "a")
    if f then
        f:write(line, "\n")
        f:close()
    end
end
-- }}}

-- {{{ local function emit
-- Calls the functions registered with orch.on for this event. A hook that
-- raises an error is logged, not allowed to stop the orchestrator.
local function emit(event, name, info)
    for _, fn in ipairs(hooks[event] or {}) do
        local ok, err = pcall(fn, name, info)
        if not ok then log("hook for " .. event .. " failed: " .. tostring(err)) end
    end
end
-- }}}

-- {{{ local function process_ticks
-- The process's start time, in clock ticks since boot (field 22 of
-- /proc/<pid>/stat), and its state letter. nil when there is no such process
-- or no /proc. The command name in field 2 may hold spaces and parentheses,
-- so the fields are counted from the last ")".
local function process_ticks(pid)
    local f = io.open("/proc/" .. tostring(pid) .. "/stat", "r")
    if not f then return nil end
    local text = f:read("*a") or ""
    f:close()
    local rest = text:match(".*%)%s+(.*)$")
    if not rest then return nil end
    local fields = {}
    for word in rest:gmatch("%S+") do fields[#fields + 1] = word end
    -- rest starts at field 3 (state), so field 22 is fields[20]
    return fields[20], fields[1]
end
-- }}}

-- {{{ local function pid_alive
-- Whether pid is a live process (not a zombie) and, when ticks is given,
-- still the same process that was started.
local function pid_alive(pid, ticks)
    if not pid then return false end
    local current, state = process_ticks(pid)
    if current then
        if state == "Z" or state == "X" then return false end
        return ticks == nil or ticks == "" or current == ticks
    end
    -- no /proc at all: fall back on kill -0, which cannot tell a reused pid
    if process_ticks("self") then return false end
    return quietly("kill -0 " .. tonumber(pid))
end
-- }}}

-- {{{ local function save_state
-- Rewrites state.tsv from records: one line per running component.
local function save_state()
    local tmp = config.state_file .. ".new"
    local f = io.open(tmp, "w")
    if not f then return false end
    for _, name in ipairs(order) do
        local r = records[name]
        if r then
            f:write(name, "\t", r.pid, "\t", r.ticks or "", "\t", r.started_at or "", "\n")
        end
    end
    -- records for names not registered this run are kept too, so a run that
    -- registers only some components does not forget the others
    for name, r in pairs(records) do
        if not components[name] then
            f:write(name, "\t", r.pid, "\t", r.ticks or "", "\t", r.started_at or "", "\n")
        end
    end
    f:close()
    return os.rename(tmp, config.state_file)
end
-- }}}

-- {{{ local function load_state
local function load_state()
    records = {}
    local f = io.open(config.state_file, "r")
    if not f then return end
    for line in f:lines() do
        local name, pid, ticks, started = line:match("^([^\t]+)\t(%d+)\t([^\t]*)\t?(.*)$")
        if name then
            records[name] = { pid = tonumber(pid), ticks = ticks, started_at = started }
        end
    end
    f:close()
end
-- }}}

-- {{{ orch.init
-- options:
--   project_dir  the project's folder (required); commands run from here
--   state_dir    where state, log and output files go
--                (default <project_dir>/tmp/orchestrator)
--   quiet        true: log to the file only, not to stdout
-- Reads state.tsv, so components started by an earlier run are known.
function orch.init(options)
    options = options or {}
    assert(options.project_dir, "component-orchestrator: init needs project_dir")
    local state_dir = options.state_dir or (options.project_dir .. "/tmp/orchestrator")
    config = {
        project_dir = options.project_dir,
        state_dir = state_dir,
        state_file = state_dir .. "/state.tsv",
        log_file = state_dir .. "/orchestrator.log",
        components_file = state_dir .. "/components.tsv",
        quiet = options.quiet or false,
    }
    components, order, hooks = {}, {}, {}
    if not quietly("mkdir -p " .. shell_quote(state_dir)) then
        return nil, "cannot create " .. state_dir
    end
    load_state()
    return true
end
-- }}}

-- {{{ orch.register
-- spec fields:
--   command        the shell command that runs the component (required);
--                  relative paths are from the project folder. `binary` is
--                  accepted as another name for it.
--   cwd            folder to run it in (default: the project folder)
--   port           a TCP port it listens on, checked on 127.0.0.1
--   health_command a shell command that exits 0 when the component is well
--   health_url     a URL that answers 2xx when it is well (needs curl)
--   depends_on     names of components that must be running first
--   start_wait     seconds to wait for it to become healthy (default 5)
--   stop_wait      seconds to wait after TERM before KILL (default 5)
-- Registering a name again replaces it.
function orch.register(name, spec)
    assert(config, "component-orchestrator: call init first")
    assert(type(name) == "string" and name:match("^[%w%._%-]+$"),
        "component-orchestrator: a name is letters, digits, '.', '_' or '-'")
    local command = spec.command or spec.binary
    assert(command, "component-orchestrator: " .. name .. " needs a command")
    if not components[name] then order[#order + 1] = name end
    components[name] = {
        name = name,
        command = command,
        cwd = spec.cwd or config.project_dir,
        port = tonumber(spec.port),
        health_command = spec.health_command,
        health_url = spec.health_url,
        depends_on = spec.depends_on or {},
        start_wait = spec.start_wait or 5,
        stop_wait = spec.stop_wait or 5,
    }
end
-- }}}

-- {{{ orch.load_components
-- Registers components from a tab-separated file (default components.tsv in
-- the state folder), one per line: name, port ("-" for none), dependencies
-- (comma-separated, "-" for none), then the command, which may hold tabs.
-- Lines starting with # are skipped. Returns how many were registered.
function orch.load_components(path)
    path = path or config.components_file
    local f = io.open(path, "r")
    if not f then return 0 end
    local count = 0
    for line in f:lines() do
        if line ~= "" and not line:match("^#") then
            local name, port, deps, command = line:match("^([^\t]+)\t([^\t]*)\t([^\t]*)\t(.+)$")
            if name then
                local depends_on = {}
                if deps ~= "-" and deps ~= "" then
                    for d in deps:gmatch("[^,]+") do depends_on[#depends_on + 1] = d end
                end
                orch.register(name, {
                    command = command,
                    port = (port ~= "-" and port ~= "") and port or nil,
                    depends_on = depends_on,
                })
                count = count + 1
            end
        end
    end
    f:close()
    return count
end
-- }}}

-- {{{ orch.on
-- Calls fn(name, info) after each event: "start", "stop", "fail".
function orch.on(event, fn)
    hooks[event] = hooks[event] or {}
    table.insert(hooks[event], fn)
end
-- }}}

-- {{{ orch.port_open
-- Whether something accepts TCP connections on 127.0.0.1:port (or host).
-- Uses bash's /dev/tcp, so no netcat is needed.
function orch.port_open(port, host)
    host = host or "127.0.0.1"
    return quietly(string.format("timeout 2 bash -c %s",
        shell_quote("exec 3<>/dev/tcp/" .. host .. "/" .. tonumber(port))))
end
-- }}}

-- {{{ orch.dependency_order
-- The registered names, each after everything it depends on. Errors on an
-- unknown dependency or a cycle, naming them.
function orch.dependency_order(names)
    local result, mark = {}, {}
    local function visit(name, path)
        if mark[name] == "done" then return end
        if mark[name] == "visiting" then
            error("component-orchestrator: dependency cycle: " .. table.concat(path, " -> ") .. " -> " .. name, 0)
        end
        local c = components[name]
        if not c then
            error("component-orchestrator: unknown component " .. name
                .. (#path > 0 and (" (needed by " .. path[#path] .. ")") or ""), 0)
        end
        mark[name] = "visiting"
        path[#path + 1] = name
        for _, dep in ipairs(c.depends_on) do visit(dep, path) end
        path[#path] = nil
        mark[name] = "done"
        result[#result + 1] = name
    end
    for _, name in ipairs(names or order) do visit(name, {}) end
    return result
end
-- }}}

-- {{{ orch.is_running
function orch.is_running(name)
    local r = records[name]
    return r ~= nil and pid_alive(r.pid, r.ticks)
end
-- }}}

-- {{{ orch.health_check
-- True when the component is running and every check it has passes: its port
-- accepts connections, its health_command exits 0, its health_url answers.
-- Otherwise false and why.
function orch.health_check(name)
    local c = components[name]
    if not c then return false, "unknown component " .. name end
    if not orch.is_running(name) then return false, "not running" end
    if c.port and not orch.port_open(c.port) then
        return false, "nothing listening on port " .. c.port
    end
    if c.health_command and not quietly("cd " .. shell_quote(c.cwd) .. " && " .. c.health_command) then
        return false, "health command failed"
    end
    if c.health_url and not quietly("curl -fsS --max-time 2 -o /dev/null " .. shell_quote(c.health_url)) then
        return false, "health URL did not answer"
    end
    return true
end
-- }}}

-- {{{ local function output_tail
-- The last few lines of a component's output file, for a failure message.
local function output_tail(name, lines)
    local out = read_command("tail -n " .. (lines or 5) .. " "
        .. shell_quote(config.state_dir .. "/" .. name .. ".out") .. " 2>/dev/null")
    return (out:gsub("%s+$", ""))
end
-- }}}

-- {{{ local function start_one
local function start_one(name)
    local c = components[name]
    if orch.is_running(name) then
        return true, "already running (pid " .. records[name].pid .. ")"
    end
    log("starting " .. name .. ": " .. c.command)
    local out_file = config.state_dir .. "/" .. name .. ".out"
    local line = string.format("cd %s && { setsid sh -c %s >> %s 2>&1 < /dev/null & echo $!; }",
        shell_quote(c.cwd), shell_quote("exec " .. c.command), shell_quote(out_file))
    local pid = tonumber(read_command(line):match("(%d+)"))
    if not pid then
        log("FAILED to start " .. name .. ": no process")
        emit("fail", name, { reason = "no process" })
        return false, "could not start " .. name
    end
    local ticks = process_ticks(pid)
    records[name] = { pid = pid, ticks = ticks, started_at = now() }
    save_state()

    -- Wait for it to come up: until it is healthy when it has checks, or a
    -- moment when it has none, so a command that fails at once is caught.
    local has_checks = c.port or c.health_command or c.health_url
    local deadline = has_checks and c.start_wait or 0.3
    local waited, ok, why = 0, false, nil
    while true do
        if not pid_alive(pid, ticks) then
            ok, why = false, "exited at once"
            break
        end
        if has_checks then
            ok, why = orch.health_check(name)
            if ok then break end
        elseif waited >= deadline then
            ok = true
            break
        end
        if waited >= deadline then break end
        sleep(0.1)
        waited = waited + 0.1
    end

    if not ok then
        local tail = output_tail(name)
        log("FAILED to start " .. name .. ": " .. why .. (tail ~= "" and (" -- " .. tail:gsub("\n", " | ")) or ""))
        if pid_alive(pid, ticks) then
            -- it is up but not healthy: leave nothing half-started behind
            quietly("kill -KILL -" .. pid)
        end
        records[name] = nil
        save_state()
        emit("fail", name, { reason = why, output = tail })
        return false, name .. ": " .. why .. (tail ~= "" and ("\n" .. tail) or "")
    end
    log("started " .. name .. " (pid " .. pid .. ")")
    emit("start", name, { pid = pid })
    return true
end
-- }}}

-- {{{ orch.start
-- Starts a component, and first everything it depends on. Returns true (and
-- "already running ..." when it was), or false and why. A component already
-- running is left alone.
function orch.start(name)
    local ok, list = pcall(orch.dependency_order, { name })
    if not ok then return false, list end
    local note
    for _, n in ipairs(list) do
        local started, why = start_one(n)
        if not started then
            if n ~= name then why = "dependency " .. why end
            return false, why
        end
        if n == name then note = why end
    end
    return true, note
end
-- }}}

-- {{{ orch.start_all
-- Starts every registered component in dependency order; stops at the first
-- that fails, leaving the ones already started running.
function orch.start_all()
    local ok, list = pcall(orch.dependency_order)
    if not ok then return false, list end
    for _, n in ipairs(list) do
        local started, why = start_one(n)
        if not started then return false, why end
    end
    return true
end
-- }}}

-- {{{ orch.stop
-- Stops one component: TERM to its process group, then KILL if it is still
-- there after stop_wait seconds. Components that depend on it are not
-- stopped; use stop_all for that. Returns true, or false and why.
function orch.stop(name)
    local r = records[name]
    local c = components[name]
    if not r then return true, "not running" end
    if not pid_alive(r.pid, r.ticks) then
        -- it ended on its own (or the pid now belongs to something else)
        records[name] = nil
        save_state()
        return true, "had already exited"
    end
    log("stopping " .. name .. " (pid " .. r.pid .. ")")
    quietly("kill -TERM -" .. r.pid)
    local wait = (c and c.stop_wait) or 5
    local waited = 0
    while pid_alive(r.pid, r.ticks) and waited < wait do
        sleep(0.1)
        waited = waited + 0.1
    end
    if pid_alive(r.pid, r.ticks) then
        log(name .. " ignored TERM; sending KILL")
        quietly("kill -KILL -" .. r.pid)
        sleep(0.2)
        if pid_alive(r.pid, r.ticks) then
            log("FAILED to stop " .. name)
            emit("fail", name, { reason = "would not stop" })
            return false, name .. " would not stop"
        end
    end
    records[name] = nil
    save_state()
    log("stopped " .. name)
    emit("stop", name, { pid = r.pid })
    return true
end
-- }}}

-- {{{ orch.stop_all
-- Stops every running component, dependents before what they depend on.
-- Components in state.tsv but not registered this run are stopped last.
function orch.stop_all()
    local ok, list = pcall(orch.dependency_order)
    if not ok then return false, list end
    local all_ok, why = true, nil
    for i = #list, 1, -1 do
        local stopped, reason = orch.stop(list[i])
        if not stopped then all_ok, why = false, reason end
    end
    local others = {}
    for name in pairs(records) do
        if not components[name] then others[#others + 1] = name end
    end
    table.sort(others)
    for _, name in ipairs(others) do
        local stopped, reason = orch.stop(name)
        if not stopped then all_ok, why = false, reason end
    end
    return all_ok, why
end
-- }}}

-- {{{ orch.status
-- A table: name, state ("running", "stopped", or "exited" when it was
-- started but its process is gone), pid, started_at, port, port_open.
function orch.status(name)
    local c = components[name]
    local r = records[name]
    local s = { name = name, port = c and c.port or nil }
    if r and pid_alive(r.pid, r.ticks) then
        s.state, s.pid, s.started_at = "running", r.pid, r.started_at
    elseif r then
        s.state, s.pid, s.started_at = "exited", r.pid, r.started_at
    else
        s.state = "stopped"
    end
    if s.port then s.port_open = orch.port_open(s.port) end
    return s
end
-- }}}

-- {{{ orch.status_all
-- orch.status for every registered component, in dependency order (in
-- registration order when the dependencies are broken).
function orch.status_all()
    local ok, list = pcall(orch.dependency_order)
    if not ok then list = order end
    local result = {}
    for _, name in ipairs(list) do result[#result + 1] = orch.status(name) end
    return result
end
-- }}}

-- {{{ orch.format_status
-- status_all as aligned text lines, for a terminal.
function orch.format_status(list)
    list = list or orch.status_all()
    local lines = {}
    for _, s in ipairs(list) do
        local port = s.port and (tostring(s.port) .. (s.port_open and " open" or " closed")) or "-"
        lines[#lines + 1] = string.format("%-16s %-8s %-8s %-12s %s",
            s.name, s.state, s.pid and tostring(s.pid) or "-", port, s.started_at or "")
    end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ command line
-- luajit component-orchestrator.lua [project-dir] <command> [name]
local function main(args)
    local DIR = "/home/ritz/programming/ai-stuff"
    local commands = { start = true, stop = true, health = true,
        ["start-all"] = true, ["stop-all"] = true, status = true }
    local i = 1
    if args[1] and not commands[args[1]] then
        DIR = args[1]
        i = 2
    end
    local command, name = args[i], args[i + 1]
    local usage = "usage: component-orchestrator.lua [project-dir] "
        .. "start NAME | stop NAME | health NAME | start-all | stop-all | status"
    if not command then
        io.stderr:write(usage, "\n")
        return 2
    end
    local ok, err = orch.init({ project_dir = DIR, state_dir = os.getenv("ORCH_STATE_DIR") })
    if not ok then
        io.stderr:write(err, "\n")
        return 1
    end
    orch.load_components()

    local result, why
    if command == "start" and name then
        result, why = orch.start(name)
    elseif command == "stop" and name then
        result, why = orch.stop(name)
    elseif command == "health" and name then
        result, why = orch.health_check(name)
        print(result and (name .. ": healthy") or (name .. ": " .. why))
        return result and 0 or 1
    elseif command == "start-all" then
        result, why = orch.start_all()
    elseif command == "stop-all" then
        result, why = orch.stop_all()
    elseif command == "status" then
        print(orch.format_status())
        return 0
    else
        io.stderr:write(usage, "\n")
        return 2
    end
    if not result then
        io.stderr:write("component-orchestrator: ", tostring(why), "\n")
        return 1
    end
    return 0
end

-- Run as a script, not when required (require passes the module name).
if MODULE_ARG ~= "component-orchestrator" then
    os.exit(main(arg))
end
-- }}}

return orch
