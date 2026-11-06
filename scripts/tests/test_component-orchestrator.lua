#!/usr/bin/env luajit
-- test_component-orchestrator.lua
-- Checks libs/component-orchestrator.lua and its shell wrapper (issue 013)
-- with real processes: `sleep` stands in for a daemon, netcat for something
-- that listens on a port. Everything runs in a temp folder, on 127.0.0.1.
--
-- Run: `luajit test_component-orchestrator.lua [SCRIPTS_DIR]`. Exits 1 on
-- any failure. Takes about 10 seconds.

-- {{{ DIR + library
local DIR = arg[1] or "/home/ritz/programming/ai-stuff/scripts"
package.path = DIR .. "/libs/?.lua;" .. package.path
local orch = require("component-orchestrator")
-- }}}

local failures = 0

-- {{{ local function check
local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print("FAIL " .. label .. ": got " .. tostring(got) .. ", want " .. tostring(want))
    else
        print("ok   " .. label)
    end
end
-- }}}

-- {{{ helpers
local function sh(line)
    local h = io.popen(line, "r")
    local out = h:read("*a")
    h:close()
    return (out:gsub("%s+$", ""))
end

local function alive(pid)
    -- a zombie counts as gone
    local state = sh("awk '{print $3}' /proc/" .. tostring(pid) .. "/stat 2>/dev/null")
    return state ~= "" and state ~= "Z"
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local WORK = sh("mktemp -d /tmp/test-component-orchestrator-XXXXXX")
assert(WORK:match("^/tmp/test%-component%-orchestrator%-"), "no temp folder")
local STATE = WORK .. "/state"

-- a free-looking port: tests run one at a time, so a random high one will do
math.randomseed(os.time() + tonumber(sh("echo $$")))
local PORT = 20000 + math.random(0, 20000)

-- netcat that keeps listening: OpenBSD's spelling, else the traditional one
local LISTEN
if sh("nc -h 2>&1 | grep -c OpenBSD") ~= "0" then
    LISTEN = "nc -lk 127.0.0.1 " .. PORT
else
    LISTEN = "nc -l -k -p " .. PORT
end
-- }}}

orch.init({ project_dir = WORK, state_dir = STATE, quiet = true })

-- {{{ dependency order
orch.register("server", { command = LISTEN, port = PORT })
orch.register("client", { command = "sleep 300", depends_on = { "server" } })
orch.register("helper", { command = "sleep 300", depends_on = { "client", "server" } })
check("dependencies come first", table.concat(orch.dependency_order(), " "), "server client helper")

orch.register("loop-a", { command = "true", depends_on = { "loop-b" } })
orch.register("loop-b", { command = "true", depends_on = { "loop-a" } })
local ok, err = pcall(orch.dependency_order, { "loop-a" })
check("a cycle is refused", ok, false)
check("the cycle is named", tostring(err):match("cycle: loop%-a %-> loop%-b %-> loop%-a") ~= nil, true)
orch.register("orphan", { command = "true", depends_on = { "nobody" } })
local started, why = orch.start("orphan")
check("an unknown dependency stops the start", started, false)
check("and is named", tostring(why):match("unknown component nobody") ~= nil, true)
-- }}}

-- {{{ start in order, with events
orch.init({ project_dir = WORK, state_dir = STATE, quiet = true })
orch.register("server", { command = LISTEN, port = PORT })
orch.register("client", { command = "sleep 300", depends_on = { "server" } })
local events = {}
orch.on("start", function(name) events[#events + 1] = "start:" .. name end)
orch.on("stop", function(name) events[#events + 1] = "stop:" .. name end)

started, why = orch.start("client")
check("starting the client starts the server first", table.concat(events, " "), "start:server start:client")
check("start succeeds", started, true)
check("the server's port is open", orch.port_open(PORT), true)
check("the server is healthy", (orch.health_check("server")), true)
local s = orch.status("server")
check("status says running", s.state, "running")
check("status shows the port open", s.port_open, true)
local server_pid = s.pid
check("the recorded pid is the listener itself", sh("cat /proc/" .. server_pid .. "/comm"), "nc")
check("the pid is its own process group",
    sh("awk '{print $5}' /proc/" .. server_pid .. "/stat"), tostring(server_pid))
started, why = orch.start("server")
check("starting it again leaves it alone", why ~= nil and why:match("already running") ~= nil, true)
check("same pid", orch.status("server").pid, server_pid)
-- }}}

-- {{{ state survives into a new run
orch.init({ project_dir = WORK, state_dir = STATE, quiet = true })
orch.register("server", { command = LISTEN, port = PORT })
orch.register("client", { command = "sleep 300", depends_on = { "server" } })
check("a new run knows the server is running", orch.is_running("server"), true)
check("state.tsv names both", select(2, read_file(STATE .. "/state.tsv"):gsub("\n", "")), 2)
events = {}
orch.on("stop", function(name) events[#events + 1] = "stop:" .. name end)
check("stop_all succeeds", (orch.stop_all()), true)
check("dependents stop first", table.concat(events, " "), "stop:client stop:server")
check("the listener is gone", alive(server_pid), false)
check("the port is closed", orch.port_open(PORT), false)
check("state.tsv is empty", read_file(STATE .. "/state.tsv"), "")
-- }}}

-- {{{ a command that fails at once
orch.register("broken", { command = "sh -c 'echo boom >&2; exit 3'" })
started, why = orch.start("broken")
check("a command that exits at once fails to start", started, false)
check("the failure quotes its output", tostring(why):match("boom") ~= nil, true)
check("nothing is recorded for it", orch.status("broken").state, "stopped")
check("the log says so", (read_file(STATE .. "/orchestrator.log") or ""):match("FAILED to start broken") ~= nil, true)

orch.register("deaf", { command = "sleep 300", port = PORT, start_wait = 0.5 })
started, why = orch.start("deaf")
check("a component that never opens its port fails", started, false)
check("and says why", tostring(why):match("nothing listening on port") ~= nil, true)
check("and is not left running", orch.status("deaf").state, "stopped")
-- }}}

-- {{{ health command
orch.register("well", { command = "sleep 300", health_command = "test -e " .. WORK .. "/ok" })
os.execute("touch " .. WORK .. "/ok")
check("a passing health command lets it start", (orch.start("well")), true)
os.execute("rm -f " .. WORK .. "/ok")
local healthy, reason = orch.health_check("well")
check("a failing health command makes it unhealthy", healthy, false)
check("and says so", reason, "health command failed")
orch.stop("well")
-- }}}

-- {{{ the whole process group stops, and TERM is followed by KILL
orch.register("family", { command = "sh -c 'sleep 300 & echo $! > " .. WORK .. "/child.pid; wait'" })
check("a component with a child starts", (orch.start("family")), true)
os.execute("sleep 0.2")
local child = tonumber(read_file(WORK .. "/child.pid") or "")
check("its child is running", child ~= nil and alive(child), true)
orch.stop("family")
os.execute("sleep 0.2")
check("stopping it stops the child too", child ~= nil and alive(child), false)

orch.register("stubborn", { command = "sh -c 'trap \"\" TERM; while :; do sleep 0.1; done'", stop_wait = 0.5 })
check("a component that ignores TERM starts", (orch.start("stubborn")), true)
local stubborn_pid = orch.status("stubborn").pid
check("stop still succeeds", (orch.stop("stubborn")), true)
check("it was killed", alive(stubborn_pid), false)
check("the log says KILL was needed",
    (read_file(STATE .. "/orchestrator.log") or ""):match("stubborn ignored TERM; sending KILL") ~= nil, true)
-- }}}

-- {{{ a reused pid is not ours
-- A process this test started itself is written into state.tsv as if the
-- orchestrator had started it, but with a different start time: that is how
-- a pid reused by an unrelated process looks.
local stranger = tonumber(sh("sleep 300 > /dev/null 2>&1 & echo $!"))
local f = io.open(STATE .. "/state.tsv", "w")
f:write("stranger\t", stranger, "\t1\t2026-01-01 00:00:00\n")
f:close()
orch.init({ project_dir = WORK, state_dir = STATE, quiet = true })
orch.register("stranger", { command = "sleep 300" })
check("a pid with the wrong start time is not running", orch.status("stranger").state, "exited")
orch.stop_all()
check("and stop_all leaves that process alone", alive(stranger), true)
os.execute("kill " .. stranger)
-- }}}

-- {{{ the shell wrapper
local wrapper = string.format([[
set -e
source %s/libs/component-orchestrator.sh
export ORCH_STATE_DIR=%s/shell-state
orch_init %s
orch_register server %q %d
orch_register client "sleep 300" "" server
orch_register client "sleep 301" "" server
orch_start_all > /dev/null
orch_status_all
orch_health server
orch_stop_all > /dev/null
orch_status_all
]], DIR, WORK, WORK, LISTEN, PORT)
local wf = io.open(WORK .. "/wrapper.sh", "w")
wf:write(wrapper)
wf:close()
local out = sh("bash " .. WORK .. "/wrapper.sh 2>&1")
local lines = {}
for line in out:gmatch("[^\n]+") do lines[#lines + 1] = line end
check("wrapper: registering again replaces the line",
    sh("grep -c '^client' " .. WORK .. "/shell-state/components.tsv"), "1")
check("wrapper: the replacement is kept",
    sh("grep -c 'sleep 301' " .. WORK .. "/shell-state/components.tsv"), "1")
check("wrapper: status lists the server first, running",
    (lines[1] or ""):match("^server%s+running%s+%d+%s+" .. PORT .. " open") ~= nil, true)
check("wrapper: then the client, running", (lines[2] or ""):match("^client%s+running") ~= nil, true)
check("wrapper: health", lines[3], "server: healthy")
check("wrapper: after stop-all the server is stopped", (lines[4] or ""):match("^server%s+stopped") ~= nil, true)
check("wrapper: and the client", (lines[5] or ""):match("^client%s+stopped") ~= nil, true)
-- }}}

-- {{{ cleanup
orch.init({ project_dir = WORK, state_dir = STATE, quiet = true })
orch.stop_all()
os.execute("rm -rf " .. WORK)
-- }}}

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
