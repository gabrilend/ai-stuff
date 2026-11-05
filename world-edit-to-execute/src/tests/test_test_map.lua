--[[
Tests for Test Map (Issue 913): the editor's settings, the W client's
goodbye receipt read and checked, other programs started, watched and
stopped, the local AzerothCore started, waited on, reused, started again
for a new build and stopped, and whole Test Map runs from F5: the receipt
shown, a crash reported, a malformed or too-new receipt refused, the
password kept off command lines and out of files, the server stopped
when the editor closes, and the camera turned from the view's WC3 units
into the W client's world by the converter's placement (W02's own
converter too, on Daow 4.4).

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
                   "--camera", "981.52,1959.82", "--realm", "127.0.0.1:" .. s.test_map.server.login_port,
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

-- {{{ The camera: the view's point in the W client's world
test_section("The camera: the view's point, in the W client's world")
do
    local coords = require("wowbuild.coords")
    -- the placement read from each kind of report the fake converter writes
    local map = TMP .. "/placed.w3x"
    write(map, "m")
    local function report_of(mode)
        local b = TMP .. "/placements/" .. mode
        os.execute("mkdir -p " .. proc.quote(b))
        shell(proc.quote(FIX .. "/fake-convert.sh") .. " " .. mode .. " " .. proc.quote(map) .. " " .. proc.quote(b) .. " 2>&1")
        local q, why = test_map.read_placement(b)
        return q, why, b
    end
    local p = report_of("ok")
    test("the converter's placement read from its conversion-report.lua", p and p.x0 == 1000 and p.y0 == 2000
        and math.abs(p.scale - 1 / 30.72) < 1e-15 and p.wc3_max[1] == 5000)
    local function refused(mode, words)
        local q, why = report_of(mode)
        test(mode .. ": no placement, said why", q == nil and (why or ""):find(words, 1, true) ~= nil, why)
    end
    refused("noreport", "wrote no conversion-report.lua")
    refused("noplace", "gives no placement")
    refused("badplace", "scale")
    refused("toonew", "format 2 is newer")
    local _, _, b = report_of("ok")
    write(b .. "/conversion-report.lua", "while true do end")
    local q, why = test_map.read_placement(b)
    test("a report that runs forever: refused as data", q == nil and (why or ""):find("runs too long", 1, true) ~= nil, why)
    write(b .. "/conversion-report.lua", "return { format = 1, placement = { client = os.exit } }")
    q, why = test_map.read_placement(b)
    test("a report reaching for functions: nothing reached", q == nil, why)

    -- the mapping: WC3 north is the client's +x, east its -y, 30.72 units a yard
    local x, y = coords.wc3_to_client(p, 0, 307.2)
    local xe, ye = coords.wc3_to_client(p, 307.2, 0)
    test("WC3 north 307.2 units: 10 yards up the W client's x", math.abs(x - 1010) < 1e-9 and math.abs(y - 2000) < 1e-9)
    test("WC3 east 307.2 units: 10 yards down its y (y points west)", math.abs(xe - 1000) < 1e-9 and math.abs(ye - 1990) < 1e-9)

    -- whole runs
    local s, base = fake_settings("camera")
    local T = new_run(s, { camera = function() return 99999, -99999 end })
    T:start(); T:wait(30)
    local args = lines(base .. "/log/fake-w-client.args")
    local want = string.format("%.2f,%.2f", 1000 + (-5000 + 32) / 30.72, 2000 - (5000 - 32) / 30.72)
    test("a view off the map: the camera put just inside its edge", T.last.outcome == "closed" and args[5] == "--camera"
        and args[6] == want, table.concat(args, " "))
    test("the turning logged, WC3 units and yards", (read(base .. "/log/test-map.log") or ""):find("moved onto the map's edge", 1, true) ~= nil)
    for _, mode in ipairs({ "noreport", "toonew" }) do
        s.test_map.convert[2] = mode
        local n = #said
        T:start(); T:wait(30)
        local a = read(base .. "/log/fake-w-client.args") or ""
        local told = false
        for k = n + 1, #said do if said[k]:find("no camera for the W client", 1, true) then told = true end end
        test(mode .. ": the W client opened without --camera, at the map's own start; said why", T.last.outcome == "closed"
            and not a:find("--camera", 1, true) and told, a)
    end
    s.test_map.convert[2] = "ok"
    T:close()

    -- W02's own converter (src/cli/wow-convert.lua) on a real map: the
    -- camera is the converter's placement of the view's point, and the W
    -- client's rule for which ADT it is in finds a file the converter wrote
    local real = DIR .. "/assets/Daow4.4.w3x"
    local mpq_ok, mpq_err = pcall(function() require("mpq").open(real):close() end)
    if not mpq_ok then
        print("  [SKIP] Test Map with W02's converter: " .. tostring(mpq_err):sub(1, 80))
    else
        local wowbuild = require("wowbuild")
        local s2, base2 = fake_settings("camera-w02")
        s2.test_map.convert = { "luajit", DIR .. "/src/cli/wow-convert.lua" }
        local T2 = new_run(s2, { save = function() return real end, camera = function() return 1000, -2000 end })
        T2:start(); T2:wait(60)
        local a = lines(base2 .. "/log/fake-w-client.args")
        local L = coords.layout(wowbuild.read_terrain(real))
        local wx, wy = L:to_wow(1000, -2000)
        test("W02's converter: the camera is its placement of the view's point", T2.last.outcome == "closed"
            and a[5] == "--camera" and a[6] == string.format("%.2f,%.2f", wx, wy), (T2.last.message or "") .. " / " .. table.concat(a, " "))
        local cx, cy = (a[6] or ""):match("^(-?[%d.]+),(-?[%d.]+)$")
        local tx, ty = coords.client_adt(tonumber(cx) or 0, tonumber(cy) or 0)
        local adt_file = string.format("%s/build/World/Maps/WC3_Daow4_4/WC3_Daow4_4_%d_%d.adt", base2, tx, ty)
        test("the ADT the W client opens there is one the converter wrote", read(adt_file) ~= nil, adt_file)
        -- (2026-11-05) W02c's map.lua: its rule is the report's placement
        local mf = test_map.read_map_file(base2 .. "/build")
        local cp, cnote = test_map.camera_placement(base2 .. "/build")
        local pc = test_map.read_placement(base2 .. "/build")
        test("W02's converter writes map.lua, and its wc3_to_wow is placement.client's rule exactly",
            mf and pc and mf.wc3_to_wow.scale == pc.scale and mf.wc3_to_wow.x0 == pc.x0 and mf.wc3_to_wow.y0 == pc.y0
            and cp and cnote == nil, cnote)
        -- (2026-11-05) F5 again on the unchanged map: W02's report is written
        -- anew (when, and how long it took), and the server is still reused
        local starts = count_lines(base2 .. "/starts")
        T2:start(); T2:wait(60)
        test("W02's converter, a second F5 on the unchanged map: the server is reused",
            T2.last.outcome == "closed" and count_lines(base2 .. "/starts") == starts,
            starts .. " then " .. count_lines(base2 .. "/starts"))
        T2:close()
    end
end
-- }}}

-- {{{ map.lua: the map the W client opens, and the camera's rule (2026-11-05)
test_section("map.lua: the map the W client opens, and the camera's rule")
do
    local map = TMP .. "/mapfile.w3x"
    write(map, "m")
    local function build_of(mode)
        local b = TMP .. "/mapfiles/" .. mode
        os.execute("mkdir -p " .. proc.quote(b))
        shell(proc.quote(FIX .. "/fake-convert.sh") .. " " .. mode .. " " .. proc.quote(map) .. " " .. proc.quote(b) .. " 2>&1")
        return b
    end
    local m, why, kind = test_map.read_map_file(build_of("ok"))
    test("map.lua read as data: its format and wc3_to_wow", m and m.format == 1 and m.wc3_to_wow.x0 == 1000
        and m.map.id == 900, why)
    m, why, kind = test_map.read_map_file(build_of("nomap"))
    test("no map.lua: missing, said", m == nil and kind == "missing" and why:find("wrote no map.lua", 1, true) ~= nil, why)
    m, why, kind = test_map.read_map_file(build_of("badmap"))
    test("map.lua of format 2: refused", m == nil and kind == "refused" and why:find("format is 2", 1, true) ~= nil, why)
    local b = build_of("ok")
    write(b .. "/map.lua", "return { format = 1, wc3_to_wow = { scale = 0, x0 = 1, y0 = 2 } }")
    m, why = test_map.read_map_file(b)
    test("map.lua with a scale of 0: refused", m == nil and why:find("wc3_to_wow", 1, true) ~= nil, why)
    write(b .. "/map.lua", "while true do end")
    m, why = test_map.read_map_file(b)
    test("map.lua that runs forever: refused as data", m == nil and why:find("runs too long", 1, true) ~= nil, why)

    local p, note = test_map.camera_placement(build_of("ok"))
    test("map.lua's rule and the report's placement agree: the placement, no note", p and p.x0 == 1000
        and p.wc3_max[1] == 5000 and note == nil, note)
    p, note = test_map.camera_placement(build_of("disagree"))
    test("they disagree: map.lua's rule (the W client's own) wins, with the report's bounds, and it is said",
        p and p.x0 == 1100 and p.y0 == 2000 and p.wc3_max[1] == 5000 and (note or ""):find("disagree", 1, true) ~= nil, note)
    p, note = test_map.camera_placement(build_of("noreport"))
    test("map.lua but no report: no camera (the bounds aren't known)", p == nil
        and (note or ""):find("bounds", 1, true) ~= nil, note)
    p, note = test_map.camera_placement(build_of("nomap"))
    test("a report but no map.lua: the report's placement, said", p and p.x0 == 1000
        and (note or ""):find("wrote no map.lua", 1, true) ~= nil, note)

    -- whole runs
    local s, base = fake_settings("mapfile1", { convert = "nomap" })
    local T = new_run(s)
    T:start(); T:wait(30)
    test("a build without map.lua: stopped before the server, naming map.lua and W02c", T.last.outcome == "failed"
        and T.last.message:find("map.lua", 1, true) ~= nil and T.last.message:find("W02c", 1, true) ~= nil
        and read(base .. "/starts") == nil and read(base .. "/log/fake-w-client.args") == nil, T.last.message)
    s.test_map.convert[2] = "badmap"
    T:start(); T:wait(30)
    test("a map.lua the W client wouldn't read: stopped the same way", T.last.outcome == "failed"
        and T.last.message:find("format is 2", 1, true) ~= nil and read(base .. "/starts") == nil, T.last.message)
    s.test_map.convert[2] = "disagree"
    local before = #said
    T:start(); T:wait(30)
    server_pids(T)
    local a = lines(base .. "/log/fake-w-client.args")
    local told = false
    for i = before + 1, #said do told = told or said[i]:find("disagree", 1, true) ~= nil end
    test("a disagreeing build: the camera by map.lua's rule (x0 1100), the disagreement said",
        T.last.outcome == "closed" and a[6] == "1081.52,1959.82" and told, table.concat(a, " "))
    T:close()
end
-- }}}

-- {{{ The W client's contract as it stands (its issue 1109, 2026-11-05)
test_section("The W client's contract, checked before a run")
do
    local function tm_with(t)
        local x = { password = PASSWORD, account = "tester" }
        for k, v in pairs(t or {}) do if v == false then x[k] = nil else x[k] = v end end  -- false: left out
        return x
    end
    local B, R = "/tmp/build", "/tmp/log/receipt.lua"
    local function check(name, t, host, port, words, build, rec)
        local ok, why = test_map.check_launch(tm_with(t), host or "127.0.0.1", port or 3724, build or B, rec or R)
        if words then
            test(name .. ": refused, saying why", ok == nil and (why or ""):find(words, 1, true) ~= nil, why)
        else
            test(name, ok == true, why)
        end
    end
    check("a launch the W client takes", {})
    check("no account: the W client takes none", { account = false })
    check("no password", { password = false }, nil, nil, "W_CLIENT_PASSWORD")
    check("an empty password", { password = "" }, nil, nil, "W_CLIENT_PASSWORD")
    check("a password of 255 bytes", { password = string.rep("p", 255) })
    check("a password of 256 bytes", { password = string.rep("p", 256) }, nil, nil, "255 bytes")
    check("an account of 63 characters", { account = string.rep("a", 63) })
    check("an account of 64 characters", { account = string.rep("a", 64) }, nil, nil, "1 to 63")
    check("an account with a space", { account = "my tester" }, nil, nil, "no spaces")
    check("an account with a control byte", { account = "te\tster" }, nil, nil, "no spaces")
    check("an account starting with --", { account = "--x" }, nil, nil, "starting with --")
    check("an IPv6 host", {}, "::1", nil, "no IPv6")
    check("an empty host", {}, "", nil, "test_map.server.host")
    check("a host with a space", {}, "local host", nil, "test_map.server.host")
    check("port 0", {}, nil, 0, "1 to 65535")
    check("port 65536", {}, nil, 65536, "1 to 65535")
    check("a port that isn't whole", {}, nil, 3724.5, "1 to 65535")
    check("a build folder of 599 bytes", {}, nil, nil, nil, "/" .. string.rep("b", 598))
    check("a build folder of 600 bytes", {}, nil, nil, "build folder", "/" .. string.rep("b", 599))
    check("a receipt path of 579 bytes", {}, nil, nil, nil, nil, "/" .. string.rep("r", 578))
    check("a receipt path of 580 bytes", {}, nil, nil, "receipt", nil, "/" .. string.rep("r", 579))

    -- a run the W client would refuse stops before anything is saved,
    -- converted or started
    local s, base = fake_settings("contract1")
    s.test_map.password = nil
    local saved = false
    local T = new_run(s, { save = function() saved = true return TMP .. "/edited.w3x" end })
    test("no password: F5 stops at once, naming W_CLIENT_PASSWORD", T:start() == nil and not T:busy()
        and T.last.outcome == "failed" and T.last.message:find("W_CLIENT_PASSWORD", 1, true) ~= nil, T.last and T.last.message)
    test("no password: nothing saved, converted or started", not saved and read(base .. "/build/map.cksum") == nil
        and read(base .. "/starts") == nil and T.keeper.running == nil)
    test("no password: the log says why", (read(base .. "/log/test-map.log") or ""):find("W_CLIENT_PASSWORD", 1, true) ~= nil)
    s.test_map.password, s.test_map.account = PASSWORD, "my tester"
    test("an account the W client refuses: stopped at once", T:start() == nil and T.last.outcome == "failed"
        and T.last.message:find("isn't one the W client takes", 1, true) ~= nil and read(base .. "/starts") == nil, T.last.message)
    T:close()

    -- what the W client itself writes when it refuses (the fake does as the
    -- real one does): an error receipt, read and shown as one
    local s2, base2 = fake_settings("contract2")
    local T2 = new_run(s2)
    T2:start(); T2:wait(30)
    local pids = server_pids(T2)
    test("the W client's receipt in its own layout read (comment line, one field a line)",
        T2.last.outcome == "closed" and (read(base2 .. "/log/receipt.lua") or ""):find("^%-%- the W client's goodbye receipt") ~= nil,
        T2.last.message)
    s2.test_map.w_client[2] = "error"
    T2:start(); T2:wait(30)
    test("an error receipt's why read back byte for byte (quotes, backslashes, a new line)",
        T2.last.outcome == "error" and T2.last.receipt.why == 'The map ground tiles are missing: "World\\Maps\\x"\n(two lines).',
        T2.last.receipt and T2.last.receipt.why)
    -- the editor's check passed over (as if an older editor launched it):
    -- the W client's own refusal still comes back as an error, not a crash
    s2.test_map.w_client[2] = "closed"
    local real_check = test_map.check_launch
    test_map.check_launch = function() return true end
    s2.test_map.password = nil
    T2:start(); T2:wait(30)
    test_map.check_launch = real_check
    s2.test_map.password = PASSWORD
    test("the W client's own refusal of a missing password: its error receipt shown",
        T2.last.outcome == "error" and T2.last.message:find("password from W_CLIENT_PASSWORD, and it is not set", 1, true) ~= nil,
        T2.last.message)

    -- the converter's server-stamp names only what the server reads, so a
    -- report that holds when it was written doesn't count: an unchanged map
    -- reuses the server (W02f step 1)
    s2.test_map.convert[2] = "stamped"
    T2:start(); T2:wait(30)
    local before = count_lines(base2 .. "/starts")
    local report1 = read(base2 .. "/build/conversion-report.lua")
    T2:start(); T2:wait(30)
    test("the converter's two reports differ (when written, how long)", report1 ~= nil
        and report1 ~= read(base2 .. "/build/conversion-report.lua"))
    test("a report written anew each time doesn't start the server again", T2.last.outcome == "closed"
        and count_lines(base2 .. "/starts") == before and proc.alive(pids[1]),
        before .. " then " .. count_lines(base2 .. "/starts"))

    -- (2026-11-05, W02f step 1) a build with no server stamp counts as new:
    -- the server is started again each time, and it is said
    s2.test_map.convert[2] = "nostamp"
    local n0, said0 = count_lines(base2 .. "/starts"), #said
    T2:start(); T2:wait(30)
    local n1 = count_lines(base2 .. "/starts")
    T2:start(); T2:wait(30)
    local n2 = count_lines(base2 .. "/starts")
    local told = false
    for i = said0 + 1, #said do told = told or said[i]:find("no server stamp", 1, true) ~= nil end
    test("no server stamp: the server started again on each F5, and said", T2.last.outcome == "closed"
        and n1 == n0 + 2 and n2 == n1 + 2 and told, n0 .. ", " .. n1 .. ", " .. n2)
    -- a stamp left from an earlier conversion never counts: the editor
    -- removes it before converting, so a converter that writes none can't
    -- reuse a server on another build's stamp
    s2.test_map.convert[2] = "ok"
    T2:start(); T2:wait(30)
    local stamp_before = read(base2 .. "/build/server-stamp")
    s2.test_map.convert[2] = "nostamp"
    local n3 = count_lines(base2 .. "/starts")
    T2:start(); T2:wait(30)
    test("an earlier build's stamp removed before converting: no reuse on it", stamp_before ~= nil
        and read(base2 .. "/build/server-stamp") == nil and count_lines(base2 .. "/starts") == n3 + 2)
    s2.test_map.convert[2] = "ok"
    T2:start(); T2:wait(30)
    pids = server_pids(T2)

    -- WETE: scripts/run finds this project by it
    local args = read(base2 .. "/log/fake-w-client.args") or ""
    local want = os.getenv("WETE")
    if want == nil or want == "" then want = DIR:sub(1, 1) == "/" and DIR or ((os.getenv("PWD") or ".") .. "/" .. DIR) end
    test("WETE given to the W client: this project, or the one already set", args:find("wete=" .. want .. "\n", 1, true) ~= nil, args)

    -- scripts/run named alone: given its client's folder as its first word
    local client = TMP .. "/w-client-alone"
    os.execute("mkdir -p " .. proc.quote(client .. "/scripts"))
    write(client .. "/scripts/run", "#!/bin/bash\n# as the W client's scripts/run: the folder first, then the options\n"
        .. "dir=\"$1\"; shift\nexec " .. proc.quote(FIX .. "/fake-w-client.sh") .. " \"$dir\" closed \"$@\"\n")
    os.execute("chmod +x " .. proc.quote(client .. "/scripts/run"))
    s2.test_map.w_client = { client .. "/scripts/run" }
    T2:start(); T2:wait(30)
    args = read(base2 .. "/log/fake-w-client.args") or ""
    test("scripts/run named alone gets its client's folder first", T2.last.outcome == "closed"
        and args:find("client-dir=" .. client .. "\n", 1, true) ~= nil, args)
    test("test_map.client_folder: only a scripts/run", test_map.client_folder("/a/b/scripts/run") == "/a/b"
        and test_map.client_folder("/a/b/w-client") == nil and test_map.client_folder("/a/scripts/run2") == nil)
    T2:close()
end

-- the W client's own receipt writer (its src/068-goodbye.c), compiled here
-- when its sources are found ($W_CLIENT_SRC, the W client's folder as
-- test_wow_registration takes it, else the owner's checkout): what it
-- writes is what receipt.read takes, byte for byte
do
    local src = (os.getenv("W_CLIENT_SRC") or "/mnt/kaun/custom-client") .. "/src"
    local have = read(src .. "/068-goodbye.c") and read(src .. "/013-errors.c")
    local cc = shell("command -v cc 2>/dev/null"):gsub("%s+$", "")
    if not have or cc == "" then
        print("  [SKIP] the W client's own receipt writer: " .. (have and "no C compiler" or ("no " .. src .. "/068-goodbye.c")))
    else
        local driver = TMP .. "/goodbye-driver.c"
        write(driver, [[
#include "068-goodbye.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
/* receipt map reason why frames: as the W client ends a run */
int main(int argc, char **argv)
{
    if (argc != 6) return 64;
    Goodbye *g = NULL;
    WWhy why = { W_OK, "" };
    if (goodbye_begin(argv[1], argv[2], &g, &why)) { fprintf(stderr, "%s\n", why.text); return 1; }
    for (int i = atoi(argv[5]); i > 0; --i) goodbye_frame(g);
    GoodbyeReason r = !strcmp(argv[3], "closed") ? GOODBYE_CLOSED : !strcmp(argv[3], "error") ? GOODBYE_ERROR : GOODBYE_LOST_CONNECTION;
    if (goodbye_end(g, r, argv[4], &why)) { fprintf(stderr, "%s\n", why.text); goodbye_free(g); return 1; }
    goodbye_free(g);
    return 0;
}
]])
        local bin = TMP .. "/goodbye-driver"
        local built = shell(cc .. " -std=c11 -D_POSIX_C_SOURCE=200809L -Wall -Wextra -Werror -I" .. proc.quote(src) .. " "
            .. proc.quote(driver) .. " " .. proc.quote(src .. "/068-goodbye.c") .. " " .. proc.quote(src .. "/013-errors.c")
            .. " -o " .. proc.quote(bin) .. " 2>&1 && echo built")
        test("the W client's receipt writer builds", built:find("built", 1, true) ~= nil, built)
        local function goodbye(map, reason, why, frames)
            local path = TMP .. "/real-receipt.lua"
            os.remove(path)
            shell(proc.quote(bin) .. " " .. proc.quote(path) .. " " .. proc.quote(map) .. " " .. reason .. " "
                .. proc.quote(why) .. " " .. frames .. " 2>&1")
            return path
        end
        local map = "/home/me/maps/daow \"4.4\" \\ build\nnext\1 caf\195\169"
        local r, why = receipt.read(goodbye(map, "closed", "", 9873), map)
        test("its closed receipt read, the map's path byte for byte (quotes, a backslash, a new line, a control byte, UTF-8)",
            r and r.reason == "closed" and r.frames == 9873 and r.map == map and r.why == nil, why)
        local sentence = "no ground at the start (12.5, -300) in map 900 from \"World\\Maps\\WC3_Daow4_4\"\n\tsecond line"
        r, why = receipt.read(goodbye(map, "error", sentence, 0), map)
        test("its error receipt read, the why byte for byte", r and r.reason == "error" and r.why == sentence, why)
        r, why = receipt.read(goodbye(map, "lost", "", 3), map)
        test("its lost-connection receipt read", r and r.reason == "lost-connection" and r.frames == 3, why)
        test("what it writes is what describe() shows", r and receipt.describe(r):find("lost its connection", 1, true) ~= nil)
    end
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
        "  w_client = { " .. lit(FIX .. "/fake-w-client.sh") .. ", 'hang' }, password = 'x',",
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
    test("the camera given is the view's, in the W client's world", lines(base .. "/log/fake-w-client.args")[6] == "1006.51,1996.74",
        read(base .. "/log/fake-w-client.args"))
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
