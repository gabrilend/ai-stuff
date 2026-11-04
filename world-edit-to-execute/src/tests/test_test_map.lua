--[[
Tests for Test Map (Issue 913): the editor's settings, the W client's
goodbye receipt read and checked, other programs started, watched and
stopped, the local AzerothCore started, waited on, reused, started again
for a new build and stopped, and whole Test Map runs from F5: the receipt
shown, a crash reported, a malformed or too-new receipt refused, the
password kept off command lines and out of files, and the server stopped
when the editor closes.

No AzerothCore or W client runs here: fake programs stand in for them
(src/tests/fixtures/test-map: a LuaJIT server that opens a port, a shell
W client that writes a receipt, crashes or hangs, a shell converter).
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
-- }}}

-- {{{ Test infrastructure
local test_count, pass_count = 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end
-- }}}

local proc = require("editor.proc")
local settings = require("editor.settings")
local receipt = require("editor.receipt")
local server_keeper = require("editor.server_keeper")
local test_map = require("editor.test_map")

local FIX = DIR .. "/src/tests/fixtures/test-map"
local TMP = os.tmpname()
os.remove(TMP)
os.execute("mkdir -p " .. proc.quote(TMP))
local PASSWORD = "fake-secret-for-tests-913"

local function write(path, text)
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()
end
local function read(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end
local function lines(path)
    local t = {}
    for l in (read(path) or ""):gmatch("[^\n]+") do t[#t + 1] = l end
    return t
end
local function count_lines(path) return #lines(path) end
local function shell(cmd)
    local p = io.popen(cmd)
    local s = p:read("*a")
    p:close()
    return s
end

-- free ports: a random base, checked closed
local handed = {}
local function free_port()
    for _ = 1, 50 do
        local port = 20000 + math.random(0, 30000)
        if not handed[port] and not proc.port_open("127.0.0.1", port, 50) then
            handed[port] = true
            return port
        end
    end
end
math.randomseed(os.time() + tonumber(tostring({}):match("0x(%x+)") or "0", 16) % 100000)

local everything = {}   -- every pid started here, stopped at the end whatever happens
local function track(pid) everything[#everything + 1] = pid; return pid end

-- {{{ Settings
test_section("Settings")
do
    local root = TMP .. "/root"
    os.execute("mkdir -p " .. proc.quote(root))
    local s = settings.load(root, { getenv = function() return nil end })
    test("no settings file: defaults, said so", not s.found and s.test_map.server.login_port == 3724
        and s.test_map.convert == nil and s.test_map.w_client == nil)
    test("folders under the project's tmp", s.test_map.build_dir == root .. "/tmp/test-map/build"
        and s.test_map.log_dir == root .. "/tmp/shared-memory/test-map")
    write(root .. "/editor-settings.lua", [[
return { test_map = {
    w_client = "/opt/w/w-client",
    convert = { "luajit", "src/cli/convert.lua" },
    account = "from-file", password = "file-password",
    server = { login_port = 4000, programs = { { name = "authserver", command = "/opt/ac/authserver", port = 4000 } } },
} }]])
    s = settings.load(root, { getenv = function() return nil end })
    test("the file is read", s.found and s.test_map.w_client[1] == "/opt/w/w-client"
        and s.test_map.convert[2] == "src/cli/convert.lua")
    test("what it doesn't give keeps its default", s.test_map.server.host == "127.0.0.1"
        and s.test_map.server.start_seconds == 180 and s.test_map.server.login_port == 4000)
    test("a command given as text becomes a list", s.test_map.server.programs[1].command[1] == "/opt/ac/authserver")
    local env = { W_CLIENT_ACCOUNT = "from-env", W_CLIENT_PASSWORD = "env-password" }
    s = settings.load(root, { getenv = function(k) return env[k] end })
    test("the environment goes before the file: account and password",
        s.test_map.account == "from-env" and s.test_map.password == "env-password")
    env.W_CLIENT_PASSWORD = ""
    s = settings.load(root, { getenv = function(k) return env[k] end })
    test("an empty password in the environment counts as unset", s.test_map.password == "file-password")
    env.W_CLIENT_PASSWORD = "env-password"
    env.WETE_EDITOR_SETTINGS = root .. "/other.lua"
    write(env.WETE_EDITOR_SETTINGS, "return { test_map = { account = 'other' } }")
    env.W_CLIENT_ACCOUNT = nil
    s = settings.load(root, { getenv = function(k) return env[k] end })
    test("WETE_EDITOR_SETTINGS names another file", s.test_map.account == "other")
    write(root .. "/bad.lua", "os.execute('touch " .. root .. "/ran') return {}")
    s = settings.load(root, { path = root .. "/bad.lua", getenv = function() return nil end })
    test("the file is data: nothing in it can run a program", not s.found and read(root .. "/ran") == nil)
end
-- }}}

-- {{{ The receipt
test_section("The goodbye receipt")
do
    local folder = "/tmp/wete/build"
    local good = 'return { format = 1, map = "/tmp/wete/build", started = "2026-11-04T20:31:07Z", '
        .. 'ended = "2026-11-04T20:32:10Z", seconds = 63.2, frames = 3790, reason = "closed" }'
    local p = TMP .. "/receipt.lua"
    local function try(text)
        write(p, text)
        return receipt.read(p, folder)
    end
    local r = try(good)
    test("a good receipt is read", r and r.frames == 3790 and r.reason == "closed")
    test("and shown", r and receipt.describe(r):find("closed after 63.2 s, 3790 frames", 1, true) ~= nil,
        r and receipt.describe(r))
    r = try(good:gsub('"closed"', '"lost-connection"'))
    test("lost-connection", r and receipt.describe(r):find("lost its connection", 1, true) ~= nil)
    r = try(good:gsub('reason = "closed"', 'reason = "error", why = "No ground."'))
    test("error, with why", r and receipt.describe(r):find("No ground.", 1, true) ~= nil)
    os.remove(p)
    local _, why, kind = receipt.read(p, folder)
    test("no receipt: missing (a crash, to Test Map)", kind == "missing", why)
    local function refused(name, text, expect)
        local got, w, k = try(text)
        test(name, got == nil and k == "refused" and (not expect or (w or ""):find(expect, 1, true) ~= nil), w)
    end
    refused("a missing field is refused", good:gsub(", frames = 3790", ""), "frames")
    refused("a format above 1 is refused", good:gsub("format = 1", "format = 2"), "newer than this editor reads")
    refused("format 0 is refused", good:gsub("format = 1", "format = 0"), "format")
    refused("a fractional frame count", good:gsub("3790", "37.5"), "frames")
    refused("negative seconds", good:gsub("63.2", "-1"), "seconds")
    refused("seconds that aren't a number", good:gsub("63.2", "0/0"), "seconds")
    refused("a time not in UTC form", good:gsub("20:31:07Z", "20:31:07+01:00"), "started")
    refused("ended before started", good:gsub("2026%-11%-04T20:32:10Z", "2026-11-04T20:30:00Z"), "before")
    refused("an unknown reason", good:gsub('"closed"', '"quit"'), "reason")
    refused("error without why", good:gsub('"closed"', '"error"'), "why")
    refused("why without error", good:gsub('reason = "closed"', 'reason = "closed", why = "x"'), "why")
    refused("a field the format doesn't have", good:gsub("format = 1,", "format = 1, extra = true,"), "extra")
    refused("another map's receipt", good:gsub("/tmp/wete/build", "/elsewhere"), "another map")
    refused("not a table", "return 42", "table")
    refused("not Lua", "return {", "isn't Lua")
    refused("it can't call anything (an empty environment)", "os.exit(1) return {}", "fails")
    refused("it can't run forever", "while true do end", "too long")
    refused("compiled code is refused", string.dump(function() return {} end), "compiled")
    refused("too big", "return { x = '" .. string.rep("a", 70000) .. "' }", "too big")
end
-- }}}

-- {{{ Other programs
test_section("Other programs, started and stopped")
do
    local status, log = TMP .. "/p.status", TMP .. "/p.log"
    local pid = track(proc.spawn({ "sh", "-c", "echo hello; echo \"secret=${W_CLIENT_PASSWORD}\"; exit 7" },
        { log = log, status = status, env = { W_CLIENT_PASSWORD = "visible-to-it" } }))
    test("started: a pid at once", type(pid) == "number")
    local t0 = proc.now()
    while proc.alive(pid) and proc.now() - t0 < 5 do proc.sleep(0.02) end
    proc.sleep(0.05)
    test("it ran and ended", not proc.alive(pid))
    test("its exit code is read", proc.exit_code(status) == 7, tostring(proc.exit_code(status)))
    test("its output is in its log, and its environment reached it",
        (read(log) or ""):find("hello\nsecret=visible-to-it", 1, true) ~= nil, read(log))
    test("the environment is put back here after", os.getenv("W_CLIENT_PASSWORD") == nil)
    -- a program with a child of its own: stopped together
    local pidf = TMP .. "/child.pid"
    local hang = track(proc.spawn({ "sh", "-c", "sleep 300 & echo $! > " .. pidf .. "; wait" }, {}))
    proc.sleep(0.3)
    local child = tonumber(read(pidf) or "")
    test("it runs", proc.alive(hang) and child and proc.alive(child))
    test("stopped", proc.stop(hang, 2) and not proc.alive(hang))
    proc.sleep(0.1)
    test("its own child stopped with it (its group)", child and not proc.alive(child))
    local nope = track(proc.spawn({ TMP .. "/no-such-program" }, { status = status }))
    proc.sleep(0.2)
    test("a program that isn't there: it ends, code 127", not proc.alive(nope) and proc.exit_code(status) == 127)
    local port = free_port()
    test("a closed port is closed", not proc.port_open("127.0.0.1", port, 100))
    local srv = track(proc.spawn({ "luajit", FIX .. "/fake-server.lua", tostring(port), TMP .. "/starts0", "-" }, {}))
    local t1 = proc.now()
    while not proc.port_open("127.0.0.1", port, 100) and proc.now() - t1 < 5 do proc.sleep(0.05) end
    test("an open port is open (the fake server)", proc.port_open("localhost", port, 100))
    proc.stop(srv, 2)
end
-- }}}

-- {{{ The server keeper
test_section("The local AzerothCore, kept")
local function fake_programs(starts, auth, world, mode, delay)
    return {
        { name = "authserver", port = auth,
          command = { "luajit", FIX .. "/fake-server.lua", tostring(auth), starts, "{build}", mode or "listen", tostring(delay or 0.3) } },
        { name = "worldserver", port = world,
          command = { "luajit", FIX .. "/fake-server.lua", tostring(world), starts, "{build}", "listen", tostring(delay or 0.3) } },
    }
end
local function wait_keeper(k, seconds)
    local t0 = proc.now()
    while proc.now() - t0 < (seconds or 10) do
        local st, why = k:step()
        if st ~= "waiting" then return st, why end
        proc.sleep(0.02)
    end
    return "timeout"
end
do
    local logs = TMP .. "/keeper"
    local starts = TMP .. "/starts1"
    local auth, world = free_port(), free_port()
    local k = server_keeper.new({ host = "127.0.0.1", login_port = auth, start_seconds = 10, stop_seconds = 2,
                                  programs = fake_programs(starts, auth, world) }, { log_dir = logs, poll_every = 0.05 })
    test("started", k:begin(TMP .. "/build-a", "one") == "started")
    for _, r in ipairs(k.running) do track(r.pid) end
    test("not ready before its ports open", k:step() == "waiting")
    local st = wait_keeper(k)
    test("ready once both ports accept", st == "ready" and proc.port_open("127.0.0.1", world, 100))
    local l = lines(starts)
    test("each started once, given the build ({build} and WETE_TEST_MAP_BUILD)", #l == 2
        and l[1] == auth .. " " .. TMP .. "/build-a " .. TMP .. "/build-a", #l .. ": " .. tostring(l[1]))
    test("their pids written down", count_lines(logs .. "/server.pids") == 2)
    test("the same build again: reused", k:begin(TMP .. "/build-a", "one") == "reused" and k:step() == "ready"
        and count_lines(starts) == 2)
    local old = k.running[1].pid
    test("a new build: started again", k:begin(TMP .. "/build-b", "two") == "restarted")
    for _, r in ipairs(k.running) do track(r.pid) end
    test("the old one stopped", not proc.alive(old))
    test("ready again", wait_keeper(k) == "ready" and count_lines(starts) == 4)
    local pids = { k.running[1].pid, k.running[2].pid }
    test("stopped: both", k:stop() == 2 and not proc.alive(pids[1]) and not proc.alive(pids[2]))
    test("the pids file gone, the ports closed", read(logs .. "/server.pids") == nil
        and not proc.port_open("127.0.0.1", auth, 100))

    -- a server that never opens its port: a time limit
    local k2 = server_keeper.new({ host = "127.0.0.1", login_port = auth, start_seconds = 1, stop_seconds = 1,
                                   programs = fake_programs(starts, auth, world, "never") }, { log_dir = logs, poll_every = 0.05 })
    k2:begin(TMP .. "/build-a", "one")
    for _, r in ipairs(k2.running) do track(r.pid) end
    local hung = k2.running[1].pid
    local st2, why2 = wait_keeper(k2, 5)
    test("a server that never accepts: given up on after its time", st2 == nil
        and (why2 or ""):find("within 1 s on authserver (" .. auth .. ")", 1, true) ~= nil, why2)
    test("and stopped", not proc.alive(hung))

    -- a server that dies while starting
    local k3 = server_keeper.new({ host = "127.0.0.1", login_port = auth, start_seconds = 5, stop_seconds = 1,
                                   programs = fake_programs(starts, auth, world, "die", 0.1) }, { log_dir = logs, poll_every = 0.05 })
    k3:begin(TMP .. "/build-a", "one")
    for _, r in ipairs(k3.running) do track(r.pid) end
    local st3, why3 = wait_keeper(k3, 5)
    test("a server that dies: reported with its code and log", st3 == nil and (why3 or ""):find("authserver exited (code 3)", 1, true) ~= nil
        and why3:find("authserver.log", 1, true) ~= nil, why3)
    test("and the other one stopped", not k3.running)

    -- nothing to start
    local k4 = server_keeper.new({ login_port = auth, programs = {} }, { log_dir = logs })
    local how, why4 = k4:begin(TMP .. "/b", "x")
    test("no programs in the settings: said so", how == nil and why4:find("test_map.server.programs", 1, true) ~= nil)

    -- a server someone else started
    local other = track(proc.spawn({ "luajit", FIX .. "/fake-server.lua", tostring(auth), TMP .. "/starts-other", "-", "listen", "0" }, {}))
    local t0 = proc.now()
    while not proc.port_open("127.0.0.1", auth, 50) and proc.now() - t0 < 5 do proc.sleep(0.05) end
    local k5 = server_keeper.new({ login_port = auth, programs = fake_programs(starts, auth, world) }, { log_dir = logs })
    test("a server the editor didn't start: used as it is", k5:begin(TMP .. "/b", "x") == "outside" and k5:step() == "ready")
    k5:stop()
    test("and never stopped by the editor", proc.alive(other))
    proc.stop(other, 2)
end
-- }}}

-- {{{ Whole runs
test_section("Test Map runs (fake converter, servers and W client)")
local function fake_settings(name, opts)
    opts = opts or {}
    local base = TMP .. "/" .. name
    local auth, world = free_port(), free_port()
    return {
        path = "(the tests)", found = true,
        test_map = {
            convert = { FIX .. "/fake-convert.sh", opts.convert or "ok" },
            convert_seconds = opts.convert_seconds or 20,
            build_dir = base .. "/build", log_dir = base .. "/log",
            w_client = { FIX .. "/fake-w-client.sh", opts.client or "closed" },
            account = "tester", password = PASSWORD,
            server = { host = "127.0.0.1", login_port = auth, start_seconds = 10, stop_seconds = 2,
                       programs = fake_programs(base .. "/starts", auth, world) },
        },
    }, base
end
local said = {}
local function new_run(s, extra)
    local map = TMP .. "/edited.w3x"
    write(map, "a map's bytes")
    local o = { root = DIR, settings = s, poll_every = 0.05, say = function(t) said[#said + 1] = t end,
                save = function() return map end, camera = function() return 1234.4, -567.6 end }
    for k, v in pairs(extra or {}) do o[k] = v end
    return test_map.new(nil, o)
end
local function server_pids(T)
    local t = {}
    for _, r in ipairs((T.keeper and T.keeper.running) or {}) do t[#t + 1] = track(r.pid) end
    return t
end
local function files_holding(dir, text)
    return shell("grep -rlF -- " .. proc.quote(text) .. " " .. proc.quote(dir) .. " 2>/dev/null")
end

do
    local s, base = fake_settings("run1")
    local T = new_run(s)
    test("F5 starts a run", T:start() == true and T:busy())
    test("the map converted, the server started, the client opened, the receipt read", T:wait(30))
    local pids = server_pids(T)
    test("closed: the receipt shown", T.last and T.last.outcome == "closed"
        and T.last.message:find("closed after 1.5 s, 90 frames", 1, true) ~= nil, T.last and T.last.message)
    test("the build is in the build folder", read(base .. "/build/map.cksum") ~= nil)
    local args = lines(base .. "/log/fake-w-client.args")
    local want = { "--test-map", base .. "/build", "--receipt", base .. "/log/receipt.lua",
                   "--camera", "1234,-568", "--realm", "127.0.0.1:" .. s.test_map.server.login_port,
                   "--account", "tester" }
    local same = #args >= #want
    for i, w in ipairs(want) do same = same and args[i] == w end
    test("the W client is given the contract's options, in order", same, table.concat(args, " "))
    test("the server was accepting logins when the client opened", (read(base .. "/log/fake-w-client.args") or ""):find("realm=open", 1, true) ~= nil)
    local sum = shell("printf '%s' " .. proc.quote(PASSWORD) .. " | cksum | cut -d' ' -f1"):gsub("%s+$", "")
    test("the password reached it, in its environment", (read(base .. "/log/fake-w-client.args") or ""):find("password-cksum=" .. sum, 1, true) ~= nil)
    test("the password is on no command line it was given", not (read(base .. "/log/fake-w-client.args") or ""):find(PASSWORD, 1, true))
    test("each step logged to the log folder", (read(base .. "/log/test-map.log") or ""):find("server ready after", 1, true) ~= nil
        and (read(base .. "/log/test-map.log") or ""):find("closed after", 1, true) ~= nil)
    test("the server still runs after the client closed", #pids == 2 and proc.alive(pids[1]) and proc.alive(pids[2]))

    -- a second F5: the same server
    T:start()
    test("a second F5 runs again", T:wait(30) and T.last.outcome == "closed")
    test("a second F5 reuses the running server", count_lines(base .. "/starts") == 2
        and T.keeper.running[1].pid == pids[1], tostring(count_lines(base .. "/starts")))

    -- the W client's other endings, on the same server
    local function run_with(mode)
        s.test_map.w_client[2] = mode
        T:start()
        T:wait(30)
        return T.last
    end
    local r = run_with("lost")
    test("lost-connection shown", r.outcome == "lost-connection" and r.message:find("lost its connection", 1, true) ~= nil)
    r = run_with("error")
    test("an error shown, with its why", r.outcome == "error" and r.message:find("ground tiles are missing", 1, true) ~= nil)
    r = run_with("crash")
    test("no receipt: reported as a crash, with its exit code and log", r.outcome == "crashed"
        and r.message:find("crashed (exit code 3, no receipt)", 1, true) ~= nil
        and r.message:find("w-client.log", 1, true) ~= nil, r.message)
    r = run_with("badopt")
    test("exit code 2 without a receipt: a crash, saying an option was refused", r.outcome == "crashed"
        and r.message:find("an option was refused", 1, true) ~= nil, r.message)
    r = run_with("malformed")
    test("a malformed receipt refused", r.outcome == "refused" and r.message:find("frames", 1, true) ~= nil, r.message)
    r = run_with("toonew")
    test("a too-new format refused", r.outcome == "refused" and r.message:find("format 2 is newer", 1, true) ~= nil, r.message)
    r = run_with("loop")
    test("a receipt that would run forever refused", r.outcome == "refused", r.message)
    r = run_with("othermap")
    test("another map's receipt refused", r.outcome == "refused" and r.message:find("another map", 1, true) ~= nil, r.message)
    -- an old receipt never counts: a crash after a good run is still a crash
    s.test_map.w_client[2] = "closed"; T:start(); T:wait(30)
    r = run_with("crash")
    test("a receipt left from the run before doesn't hide a crash", r.outcome == "crashed")
    test("the server was reused for all of them", count_lines(base .. "/starts") == 2)
    -- the setting names the client's scripts/run: it runs from the client's folder
    local client = TMP .. "/w-client-folder"
    os.execute("mkdir -p " .. proc.quote(client .. "/scripts"))
    write(client .. "/scripts/run", "#!/bin/sh\nexec " .. proc.quote(FIX .. "/fake-w-client.sh") .. " \"$@\"\n")
    os.execute("chmod +x " .. proc.quote(client .. "/scripts/run"))
    local saved_client = s.test_map.w_client
    s.test_map.w_client = { client .. "/scripts/run", "closed" }
    T:start(); T:wait(30)
    test("scripts/run as the W client: run from the client's folder, options passed through",
        T.last.outcome == "closed" and (read(base .. "/log/fake-w-client.args") or ""):find("pwd=" .. client .. "\n", 1, true) ~= nil,
        read(base .. "/log/fake-w-client.args"))
    s.test_map.w_client = saved_client

    -- F5 while it runs; then the editor closes with the client open
    r = nil
    s.test_map.w_client[2] = "hang"
    T:start()
    local t0 = proc.now()
    while T.stage ~= "playing" and proc.now() - t0 < 20 do T:step(); proc.sleep(0.02) end
    test("the W client open, waited on (it hangs)", T.stage == "playing")
    local cpid = track(T.job.pid)
    test("F5 again while it runs: told, nothing started", T:start() == nil and T.stage == "playing"
        and said[#said]:find("already running", 1, true) ~= nil)
    local cmdlines = shell("cat /proc/" .. cpid .. "/cmdline 2>/dev/null | tr '\\0' ' '; for c in $(pgrep -g " .. cpid
        .. "); do tr '\\0' ' ' < /proc/$c/cmdline; done")
    test("the password is on none of its command lines", cmdlines:find("--test-map", 1, true) ~= nil
        and not cmdlines:find(PASSWORD, 1, true), cmdlines)
    for _ = 1, 10 do T:step() end
    test("still waiting: a W client that runs on isn't a crash", T.stage == "playing")
    T:close()
    test("the editor closing stops the W client", not proc.alive(cpid))
    test("and the server it started", not proc.alive(pids[1]) and not proc.alive(pids[2])
        and not proc.port_open("127.0.0.1", s.test_map.server.login_port, 100))
    test("the password is in no file Test Map wrote", files_holding(base, PASSWORD) == "", files_holding(base, PASSWORD))
end

do
    local s = fake_settings("run2", { convert = "fail" })
    local T = new_run(s)
    T:start(); T:wait(20)
    test("a failed conversion stops the run, with the converter's log", T.last.outcome == "failed"
        and T.last.message:find("converter failed (code 2)", 1, true) ~= nil, T.last.message)
    test("no server started for it", T.keeper.running == nil)
    s.test_map.convert = nil
    T:start()
    test("no converter in the settings: said so, naming W02", not T:busy() and T.last.outcome == "failed"
        and T.last.message:find("W02", 1, true) ~= nil, T.last.message)
    s.test_map.convert = { FIX .. "/fake-convert.sh", "slow" }
    s.test_map.convert_seconds = 0.3
    T:start(); T:wait(20)
    test("a converter that takes too long is stopped", T.last.outcome == "failed"
        and T.last.message:find("longer than", 1, true) ~= nil, T.last.message)
    s.test_map.convert, s.test_map.convert_seconds = { FIX .. "/fake-convert.sh", "ok" }, 20
    s.test_map.w_client = nil
    T:start(); T:wait(30)
    server_pids(T)
    test("no W client in the settings: said so", T.last.outcome == "failed"
        and T.last.message:find("test_map.w_client", 1, true) ~= nil, T.last.message)
    T:close()
    local s3 = fake_settings("run3")
    s3.test_map.server.programs = {}
    local T3 = new_run(s3)
    T3:start(); T3:wait(20)
    test("no server programs and nothing listening: said so", T3.last.outcome == "failed"
        and T3.last.message:find("test_map.server.programs", 1, true) ~= nil, T3.last.message)
    T3:close()
end

do
    -- a new build after an edit: the server starts again with it
    local s, base = fake_settings("run4")
    local map = TMP .. "/edited4.w3x"
    write(map, "first")
    local T = new_run(s, { save = function() return map end })
    T:start(); T:wait(30)
    local first = server_pids(T)[1]
    write(map, "second, edited")
    T:start(); T:wait(30)
    server_pids(T)
    test("an edited map: a new build, the server started again with it", T.last.outcome == "closed"
        and count_lines(base .. "/starts") == 4 and not proc.alive(first), tostring(count_lines(base .. "/starts")))
    T:close()
end
-- }}}

-- {{{ The editor closing (its Lua state closed)
test_section("The editor closes")
do
    -- another LuaJIT, as the editor's window is: it starts a run, sees the
    -- W client open, then ends without calling close(); its state closing
    -- must stop the server and the client
    local s, base = fake_settings("run5", { client = "hang" })
    local script = TMP .. "/editor-closes.lua"
    local function lit(v) return string.format("%q", v) end
    write(script, table.concat({
        "package.path = " .. lit(package.path),
        "local test_map = require('editor.test_map')",
        "local s = { path = 'x', found = true, test_map = {",
        "  convert = { " .. lit(FIX .. "/fake-convert.sh") .. ", 'ok' }, convert_seconds = 20,",
        "  build_dir = " .. lit(base .. "/build") .. ", log_dir = " .. lit(base .. "/log") .. ",",
        "  w_client = { " .. lit(FIX .. "/fake-w-client.sh") .. ", 'hang' },",
        "  server = { host = '127.0.0.1', login_port = " .. s.test_map.server.login_port .. ", start_seconds = 10, stop_seconds = 2,",
        "    programs = { { name = 'authserver', port = " .. s.test_map.server.login_port .. ", command = { 'luajit', "
            .. lit(FIX .. "/fake-server.lua") .. ", '" .. s.test_map.server.login_port .. "', " .. lit(base .. "/starts") .. ", '{build}' } } } } } }",
        "local map = os.tmpname(); local f = io.open(map, 'w'); f:write('m'); f:close()",
        "T = test_map.new(nil, { settings = s, save = function() return map end, say = function() end, poll_every = 0.05 })",
        "T:start()",
        "local proc = require('editor.proc'); local t0 = proc.now()",
        "while T.stage ~= 'playing' and proc.now() - t0 < 20 do T:step(); proc.sleep(0.02) end",
        "print(T.stage, T.job and T.job.pid, T.keeper.running and T.keeper.running[1].pid)",
        "io.stdout:flush()",
    }, "\n"))
    local out = shell("luajit " .. proc.quote(script) .. " 2>&1")
    local stage, cpid, spid = out:match("(%S+)%s+(%d+)%s+(%d+)")
    cpid, spid = tonumber(cpid), tonumber(spid)
    if cpid then track(cpid) end
    if spid then track(spid) end
    test("the run reached the W client", stage == "playing", out)
    proc.sleep(0.2)
    test("the editor closed: its W client stopped", cpid and not proc.alive(cpid))
    test("the editor closed: the server it started stopped", spid and not proc.alive(spid)
        and not proc.port_open("127.0.0.1", s.test_map.server.login_port, 100))
end
-- }}}

-- {{{ F5 in the editor's interface
test_section("F5 and the Test Map button in the editor")
do
    local editor = require("editor")
    local editor_ui = require("editor.ui")
    local E = assert(editor.open(DIR .. "/assets/Daow4.4.w3x"))
    local s, base = fake_settings("ui")
    local out = TMP .. "/ui-saved.w3x"
    local ui = editor_ui.new(E, 1280, 720, { save_path = out, root = DIR,
        test_map_settings = s, camera = function() return 100, 200, 1650 end })
    local function frame(i) i = i or {}; i.keys = i.keys or {}; ui:update(i, 1 / 30) end
    local labels = {}
    for _, b in ipairs(ui.buttons) do labels[b.label] = b end
    test("the toolbar's Test button is Test Map", labels["Test"] ~= nil and labels["Test"].action == "test")
    frame({ keys = { "F5" } })
    test("F5 saves the map and starts Test Map", ui.test_map and ui.test_map:busy() and read(out) ~= nil)
    local t0 = proc.now()
    while ui.test_map:busy() and proc.now() - t0 < 60 do frame(); proc.sleep(0.02) end
    server_pids(ui.test_map)
    test("the window's frames carry it through: the receipt shown in the status line",
        E.messages[#E.messages].text:find("closed after", 1, true) ~= nil, E.messages[#E.messages].text)
    test("the saved map is what was converted", read(base .. "/build/map.cksum") == shell("cksum < " .. proc.quote(out)))
    test("the camera given is the view's", (read(base .. "/log/fake-w-client.args") or ""):find("100,200", 1, true) ~= nil)
    local b = labels["Test"]
    frame({ mx = b.x + 3, my = b.y + 3, lp = true, lr = true })
    t0 = proc.now()
    while ui.test_map:busy() and proc.now() - t0 < 60 do frame(); proc.sleep(0.02) end
    test("the Test Map button runs it again, on the same server", ui.test_map.last.run == 2
        and ui.test_map.last.outcome == "closed" and count_lines(base .. "/starts") == 2,
        tostring(count_lines(base .. "/starts")))
    local others = 0
    for _, b in ipairs(ui.buttons) do if b.action == "test" or b.action == "preview" then others = others + 1 end end
    test("one F5: no second way to play the map in the editor's own viewer", others == 1 and ui.preview == nil)
    local pids = server_pids(ui.test_map)
    ui:close()
    test("closing the editor stops the server", #pids == 2 and not proc.alive(pids[1]) and not proc.alive(pids[2]))
    os.remove(out)
end
-- }}}

-- {{{ Cleanup
for _, pid in ipairs(everything) do if proc.alive(pid) then proc.stop(pid, 1) end end
os.execute("rm -rf " .. proc.quote(TMP))
-- }}}

-- {{{ Summary
print(string.format("\n%s\nTests: %d passed, %d failed", string.rep("=", 50), pass_count, test_count - pass_count))
if pass_count == test_count then
    print("ALL TESTS PASSED")
    os.exit(0)
else
    os.exit(1)
end
-- }}}
