-- test_matchmaking_cli.lua - the matchmaking server's command-line tool (issue 801g)
--
-- In plain terms: checks configuration files (good ones, and each kind
-- of mistake, with what to do instead), the state file a running server
-- writes, and the signals it stops on. Then, in a network of its own
-- (`unshare -rn`), runs world-edit-matchmaking.lua for real: serve from a
-- configuration file, and status, lobbies, lobby, logs, assets and
-- validate-config against it while clients use it, until SIGTERM and
-- SIGINT stop it cleanly.
--
-- Its files go in a folder `mktemp -d` makes (under $TMPDIR when set),
-- removed at the end.
--
-- Run with: luajit src/tests/test_matchmaking_cli.lua [DIR]
-- (DIR defaults to the project this file is in.)

-- The project: the argument, or the folder this test sits in (run-tests.sh
-- runs each test by its full path, from the project), or the owner's.
local DIR = arg[1] or arg[0]:match("^(.+)/src/tests/[^/]+%.lua$") or (arg[0]:match("^src/tests/") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/tests/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

require("netns").enter(arg[0], { DIR })

local socket = require("socket")
local config = require("matchmaking.config")
local daemon = require("matchmaking.daemon")
local client = require("matchmaking.client")

-- {{{ Test utilities
local test_count, pass_count = 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. tostring(msg) or ""))
    end
end

local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

local p = io.popen("mktemp -d -t wete-cli.XXXXXX")
local ROOT = p:read("*l")
p:close()
if not (ROOT and ROOT:match("/wete%-cli%.%w+$")) then print("  [FAIL] no folder of its own to work in") os.exit(1) end

local function write(path, data)
    local f = assert(io.open(path, "wb"))
    f:write(data)
    f:close()
end
local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local d = f:read("*a")
    f:close()
    return d
end

local CLI = DIR .. "/src/cli/world-edit-matchmaking.lua"
-- Runs the tool; returns its exit code and everything it printed.
local function run(args)
    local h = io.popen("luajit " .. quote(CLI) .. " " .. args .. " 2>&1; echo \"exit $?\"", "r")
    local o = h:read("*a")
    h:close()
    local code = tonumber(o:match("exit (%d+)%s*$"))
    return code, o:gsub("exit %d+%s*$", "")
end

local function problems_text(problems)
    local t = {}
    for _, q in ipairs(problems or {}) do t[#t + 1] = q.level .. ": " .. q.text end
    return table.concat(t, " | ")
end
-- }}}

-- {{{ configuration files
print("configuration files")
os.execute("mkdir " .. quote(ROOT .. "/conf") .. " " .. quote(ROOT .. "/conf/packs"))
write(ROOT .. "/conf/packs/medieval-v1.pack", "hello\n")
write(ROOT .. "/conf/good.conf.lua", [[
return {
    bind = "127.0.0.1:0",
    max_lobbies = 50, max_players_per_lobby = 8, lobby_timeout_seconds = 600, idle_timeout_seconds = 30,
    countdown_seconds = 0,
    nat = { enabled = true, port = 0 },
    asset_mirror = { enabled = true, contact = "mirror@example.org", packs_dir = "packs" },
    log_file = "server.log",
    state_file = "server.state", state_interval = 0.2,
}
]])
local s, problems = config.load(ROOT .. "/conf/good.conf.lua")
test("a good file is taken", s ~= nil and #problems == 0, problems_text(problems))
test("server settings pass through", s and s.server.bind == "127.0.0.1:0" and s.server.max_lobbies == 50 and s.server.countdown_seconds == 0
    and s.server.idle_timeout_seconds == 30)
test("paths are from the file's own folder", s and s.mirror.packs_dir == ROOT .. "/conf/packs" and s.log_file == ROOT .. "/conf/server.log"
    and s.state_file == ROOT .. "/conf/server.state")
test("nat and mirror come out for the daemon", s and s.nat.port == 0 and s.nat.alt_ip == nil and s.mirror.contact == "mirror@example.org")
local d = config.check({}, "/x")
test("an empty file: the defaults", d and d.state_file == "/x/matchmaking.state" and d.state_interval == 2 and d.nat == nil
    and d.mirror == nil and d.log_file == nil and next(d.server) == nil)
local function bad(t, want, base)
    local r, pr = config.check(t, base or ROOT)
    local text = problems_text(pr)
    return r == nil and text:find(want, 1, true) ~= nil, text
end
test("an unknown setting is an error", bad({ frobnicate = 1 }, "frobnicate is not a setting"))
test("the issue's relay setting says there is none", bad({ enable_relay = false }, "enable_relay is not a setting; there is no relay"))
test("its NAT switch says what to write", bad({ enable_nat_punch = true }, "write nat = { enabled = true, port = 3478 }"))
test("its dashboard and stats file say what to use", bad({ web_dashboard = {} }, "status --json") and bad({ stats_file = "x" }, "state file"))
test("a mirror port says packs go over rmail", bad({ asset_mirror = { port = 7878, contact = "m", packs_dir = "conf/packs" } }, "packs go over rmail, so the mirror has no port"))
test("a setting of the wrong kind", bad({ max_lobbies = "many" }, "max_lobbies should be a number, is a string"))
test("a count of 0 or a fraction", bad({ max_lobbies = 0 }, "max_lobbies should be a whole number above 0")
    and bad({ max_players_per_lobby = 2.5 }, "whole number"))
test("timeouts may be fractions, not 0", config.check({ idle_timeout_seconds = 0.5 }) ~= nil and bad({ lobby_timeout_seconds = 0 }, "seconds above 0"))
test("a countdown may be 0, not below", config.check({ countdown_seconds = 0 }) ~= nil and bad({ countdown_seconds = -1 }, "can't be below 0"))
test("a bind that isn't host:port", bad({ bind = "8080" }, "bind should be host:port") and bad({ bind = "h:70000" }, "bind should be host:port"))
test("a NAT port out of range, or not a number", bad({ nat = { port = 65535 } }, "nat.port should be") and bad({ nat = {} }, "nat.port should be"))
test("a NAT switched off needs no port", config.check({ nat = { enabled = false } }).nat == nil)
test("a NAT second address that isn't one", bad({ nat = { port = 1, alt_ip = "here" } }, "nat.alt_ip should be"))
test("an unknown NAT setting", bad({ nat = { port = 1, relay = true } }, "nat.relay is not a setting"))
test("a mirror without a contact or folder", bad({ asset_mirror = { packs_dir = "conf/packs" } }, "asset_mirror.contact should be")
    and bad({ asset_mirror = { contact = "m" } }, "asset_mirror.packs_dir should be"))
test("a mirror folder that isn't there", bad({ asset_mirror = { contact = "m", packs_dir = "nowhere" } }, "no folder " .. ROOT .. "/nowhere"))
test("a mirror switched off needs neither", config.check({ asset_mirror = { enabled = false } }).mirror == nil)
test("a nat or mirror that isn't a table", bad({ nat = true }, "nat should be a table") and bad({ asset_mirror = "yes" }, "asset_mirror should be a table"))
test("an enabled that isn't true or false", bad({ nat = { enabled = "yes", port = 1 } }, "nat.enabled should be true or false")
    and bad({ asset_mirror = { enabled = 1, contact = "m", packs_dir = "conf/packs" } }, "asset_mirror.enabled should be"))
test("files must be paths", bad({ log_file = "" }, "log_file should be a path") and bad({ state_interval = 0 }, "state_interval should be"))
local _, many = config.check({ a = 1, b = 2, max_lobbies = "x" })
test("every problem is listed, not only the first", #many == 3, problems_text(many))
test("absolute paths stay as they are", config.check({ log_file = "/var/log/mm.log" }, "/etc").log_file == "/var/log/mm.log")
local w, wp = config.check({ max_connections = 5000 })
test("over 1000 connections is a warning, not an error", w ~= nil and wp[1].level == "warning" and wp[1].text:find("1024", 1, true))
write(ROOT .. "/conf/evil.conf.lua", "os.execute('touch " .. ROOT .. "/conf/ran') return {}")
local e, ep = config.load(ROOT .. "/conf/evil.conf.lua")
test("a file can't run anything: no globals", e == nil and problems_text(ep):find("failed to run", 1, true) and not read(ROOT .. "/conf/ran"))
write(ROOT .. "/conf/num.conf.lua", "return 5")
test("a file must return a table", select(2, config.load(ROOT .. "/conf/num.conf.lua"))[1].text:find("should return a table", 1, true))
write(ROOT .. "/conf/broken.conf.lua", "return {")
test("a file that isn't Lua says where", problems_text(select(2, config.load(ROOT .. "/conf/broken.conf.lua"))):find("broken.conf.lua", 1, true))
test("no file says so", problems_text(select(2, config.load(ROOT .. "/conf/none.lua"))):find("no file", 1, true))
-- }}}

-- {{{ the state file and signals
print("the state file and signals")
local sample = { pid = 12, running = true, name = "a \"quoted\"\nline", list = { 1, 2.5, "x" }, nested = { ["odd key"] = true, n = -3 } }
test("state is written whole and read back the same", daemon.write_state(ROOT .. "/s.state", sample)
    and not read(ROOT .. "/s.state.part"))
local back = daemon.read_state(ROOT .. "/s.state")
test("every kind of value", back and back.pid == 12 and back.name == sample.name and back.list[2] == 2.5 and back.list[3] == "x"
    and back.nested["odd key"] == true and back.nested.n == -3)
test("a file that isn't a state is refused", daemon.read_state(ROOT .. "/conf/num.conf.lua") == nil and daemon.read_state(ROOT .. "/nothing") == nil)
local fw = io.open(ROOT .. "/sly.state", "w")
fw:write("return { pid = os.time() }\n") fw:close()
test("a state file can't run anything: no globals", daemon.read_state(ROOT .. "/sly.state") == nil)
test("not-a-number is written as 0", daemon.serialize(0 / 0) == "0" and daemon.serialize(math.huge) == "0")
local sig = daemon.signals({ "TERM", "HUP" })
test("signals can be taken", sig ~= nil)
test("nothing yet", sig.take() == nil)
os.execute("kill -HUP " .. daemon.pid())
os.execute("kill -TERM " .. daemon.pid())
test("a blocked signal waits to be taken, by name", sig.take() == "HUP" and sig.take() == "TERM" and sig.take() == nil)
sig.close()
-- }}}

-- {{{ the tool, running
print("the tool, running")
local conf = ROOT .. "/conf/good.conf.lua"
local code, o = run("validate-config " .. quote(conf) .. " --no-color")
test("validate-config: valid, and what it sets", code == 0 and o:find("Configuration valid", 1, true) and o:find("Bind: 127.0.0.1:0", 1, true)
    and o:find("Asset mirror: on, as mirror@example.org", 1, true) and o:find("NAT reflector: UDP 0 and 1", 1, true), o)
write(ROOT .. "/conf/bad.conf.lua", "return { enable_relay = true, max_lobbies = 0 }")
code, o = run("validate-config " .. quote(ROOT .. "/conf/bad.conf.lua"))
test("validate-config: every error, and exit 1", code == 1 and o:find("there is no relay", 1, true) and o:find("max_lobbies", 1, true)
    and o:find("not valid", 1, true), o)
code, o = run("validate-config " .. quote(conf) .. " --json")
test("validate-config --json", code == 0 and o:find('"valid":true', 1, true) and o:find('"contact":"mirror@example.org"', 1, true), o)
code, o = run("serve --config " .. quote(ROOT .. "/conf/bad.conf.lua"))
test("serve refuses a bad file", code == 1 and o:find("has errors", 1, true), o)

for _, c in ipairs({ "serve", "status", "lobbies", "lobby", "logs", "assets", "validate-config" }) do
    local cc, co = run(c .. " --help")
    test(c .. " --help", cc == 0 and #co > 60 and co:find(c, 1, true), co)
end
code, o = run("--help")
test("--help lists the commands", code == 0 and o:find("validate-config FILE", 1, true))
code, o = run("frob")
test("an unknown command: exit 2", code == 2 and o:find("frob is not a command", 1, true))
code, o = run("status --frob")
test("an unknown option: exit 2", code == 2 and o:find("--frob is not an option of status", 1, true))
code, o = run("serve --bind nope")
test("serve --bind checked: exit 2", code == 2 and o:find("bind should be host:port", 1, true), o)
code, o = run("serve --nat-alt-ip 127.0.0.2")
test("--nat-alt-ip needs --nat-port", code == 2 and o:find("needs --nat-port", 1, true), o)
code, o = run("serve --packs-dir " .. quote(ROOT))
test("--packs-dir needs --mirror-contact", code == 2 and o:find("go together", 1, true), o)
code, o = run("serve --bind 127.0.0.1:0 --mirror-contact m --packs-dir " .. quote(ROOT .. "/nowhere") .. " --state-file "
    .. quote(ROOT .. "/nowhere.state") .. " --seconds 1 -q")
test("serve with a packs folder that isn't there: exit 1", code == 1 and o:find("no folder " .. ROOT .. "/nowhere", 1, true), o)
code, o = run("status --state " .. quote(ROOT .. "/none.state"))
test("status with no state file: exit 1, says where it looked", code == 1 and o:find("no state file at", 1, true))

-- serve, from the file
local pipe = io.popen("exec sh -c " .. quote("echo $$; exec luajit " .. quote(CLI) .. " serve --config " .. quote(conf) .. " -q 2>&1"), "r")
local pid = tonumber(pipe:read("*l"))
local line = pipe:read("*l") or ""
local ip, port = line:match("^listening (%S+) (%d+)$")
local nline = pipe:read("*l") or ""
test("serve listens where the file says, and prints where", ip == "127.0.0.1" and tonumber(port) > 0, line)
test("with the NAT reflector the file asks for", nline:match("^nat 127%.0%.0%.1 %d+ %d+$") ~= nil, nline)
port = tonumber(port)
local STATE = ROOT .. "/conf/server.state"
local function wait_until(f, seconds)
    local t = socket.gettime()
    while socket.gettime() - t < (seconds or 3) do
        local r = f()
        if r then return r end
        socket.sleep(0.05)
    end
    return f()
end
test("it writes its state file", wait_until(function() return read(STATE) end) ~= nil)
code, o = run("status --config " .. quote(conf) .. " --no-color")
test("status: running, its numbers", code == 0 and o:find("running as process " .. pid, 1, true) and o:find("Lobbies: 0 active", 1, true)
    and o:find("Uptime:", 1, true) and o:find("Asset mirror: 1 packs", 1, true) and o:find("NAT reflector:", 1, true), o)

local host = assert(client.connect({ host = ip, port = port, name = "Host" }))
local ann = assert(client.connect({ host = ip, port = port, name = "Ann" }))
local lobby = host:create_lobby({ map_name = "Castle Defense v1.3", map_hash = "sha256:abc", max_players = 4, game_mode = "co-op",
    region = "us-west", asset_packs = { { id = "medieval-v1", hash = "h" } } })
local alobby = ann:join_game(lobby.game_id, "Ann")
alobby:set_ready(true)
local closed = {}
lobby:on("closed", function(w) closed[#closed + 1] = w end)
local function poll_for(seconds)
    local t = socket.gettime()
    while socket.gettime() - t < seconds do host:poll(0.01) ann:poll(0.01) end
end
poll_for(0.5)
code, o = run("status --state " .. quote(STATE) .. " --no-color")
test("status sees the lobby and its players", code == 0 and o:find("Lobbies: 1 active", 1, true) and o:find("Players: 2 online, 2 in lobbies", 1, true), o)
code, o = run("lobbies --config " .. quote(conf) .. " --no-color")
test("lobbies: a table of them", code == 0 and o:find("ID", 1, true) and o:find("Castle Defense v1.3", 1, true) and o:find("Host", 1, true)
    and o:find("2/4", 1, true) and o:find("WAITING", 1, true), o)
code, o = run("lobby " .. lobby.game_id .. " --config " .. quote(conf) .. " --no-color")
test("lobby ID: map, host, players with ready marks", code == 0 and o:find("Map: Castle Defense v1.3 (sha256:abc)", 1, true)
    and o:find("- Host (host) [not ready]", 1, true) and o:find("- Ann [ready]", 1, true) and o:find("State: WAITING", 1, true)
    and o:find("Asset pack: medieval-v1", 1, true), o)
code, o = run("lobby " .. lobby.game_id .. " --config " .. quote(conf) .. " --json")
test("lobby --json", code == 0 and o:find('"game_id":' .. lobby.game_id, 1, true) and o:find('"name":"Ann"', 1, true), o)
code, o = run("status --config " .. quote(conf) .. " --json")
test("status --json, running now", code == 0 and o:find('"running_now":true', 1, true) and o:find('"lobbies_active":1', 1, true), o)
code, o = run("lobby 99 --config " .. quote(conf))
test("a lobby that isn't there: exit 1", code == 1 and o:find("no lobby 99", 1, true))
code, o = run("lobby --config " .. quote(conf))
test("lobby without an id: exit 2", code == 2)

code, o = run("logs --config " .. quote(conf) .. " -n 3")
local count = select(2, o:gsub("\n", ""))
test("logs -n 3: the last three lines", code == 0 and count == 3 and o:find("lobby " .. lobby.game_id, 1, true), o)
code, o = run("logs --config " .. quote(conf))
test("logs: from the start, stamped", code == 0 and o:find("mirroring 1 packs", 1, true) and o:match("%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ listening on"), o)
local follow = io.popen("luajit " .. quote(CLI) .. " logs --config " .. quote(conf) .. " -n 0 --follow --seconds 1.5 2>&1", "r")
socket.sleep(0.3)
local third = assert(client.connect({ host = ip, port = port, name = "Bo" }))
poll_for(0.2)
local followed = follow:read("*a")
follow:close()
test("logs --follow prints new lines as they come", followed:find("connection 3 from 127.0.0.1", 1, true) ~= nil, followed)
third:disconnect()
code, o = run("logs")
test("logs without a log named: exit 2", code == 2)

code, o = run("assets list --config " .. quote(conf) .. " --no-color")
test("assets list: the packs, with size and hash", code == 0 and o:find("medieval-v1", 1, true) and o:find("6 B", 1, true)
    and o:find("sha256:5891b5b522d5df08", 1, true), o)
write(ROOT .. "/fantasy-v2.zip", "fantasy\n")
code, o = run("assets add " .. quote(ROOT .. "/fantasy-v2.zip") .. " --config " .. quote(conf) .. " --no-color")
test("assets add: copied in, its id from the name", code == 0 and o:find("Added: fantasy-v2 (8 B", 1, true)
    and read(ROOT .. "/conf/packs/fantasy-v2.pack") == "fantasy\n", o)
test("and the running server is told to look again", o:find("process " .. pid .. ") reads the folder again", 1, true))
test("which it does", wait_until(function() local st = daemon.read_state(STATE) return st and #st.mirror.packs == 2 end))
code, o = run("assets add " .. quote(ROOT .. "/fantasy-v2.zip") .. " --config " .. quote(conf))
test("adding an id twice is refused", code == 1 and o:find("already a pack fantasy-v2", 1, true))
code, o = run("assets add " .. quote(ROOT .. "/fantasy-v2.zip") .. " my-own --packs-dir " .. quote(ROOT .. "/conf/packs") .. " -q")
test("an id can be given; without a server named, nothing is told", code == 0 and read(ROOT .. "/conf/packs/my-own.pack") and not o:find("reads the folder", 1, true))
code, o = run("assets remove my-own --packs-dir " .. quote(ROOT .. "/conf/packs") .. " --no-color")
test("assets remove: gone", code == 0 and o:find("Removed: my-own", 1, true) and not read(ROOT .. "/conf/packs/my-own.pack")
    and o:find("no running server named", 1, true), o)
code, o = run("assets remove fantasy-v2 --config " .. quote(conf))
test("removing through the configuration tells the server", code == 0
    and wait_until(function() local st = daemon.read_state(STATE) return st and #st.mirror.packs == 1 end))
code, o = run("assets remove nothing --config " .. quote(conf))
test("removing what isn't there: exit 1", code == 1 and o:find("no pack nothing", 1, true))
code, o = run("assets list --config " .. quote(conf) .. " --json")
test("assets list --json", code == 0 and o:find('"id":"medieval-v1"', 1, true) and o:find('"size":6', 1, true), o)
code, o = run("assets frob --config " .. quote(conf))
test("an unknown assets command: exit 2", code == 2)

-- SIGTERM: everyone is told, the state says so
os.execute("kill -TERM " .. pid)
local rest = pipe:read("*a")
local ok_close, _, status = pipe:close()
poll_for(0.3)
test("SIGTERM: it stops, exit 0", status == 0 or ok_close == true, tostring(status) .. " " .. rest)
test("the lobby's members were told before it went", closed[1] == "the lobby closed", closed[1])
local st = daemon.read_state(STATE)
test("its state file says it stopped, and why", st and st.running == false and st.stopped_by == "SIGTERM")
code, o = run("status --config " .. quote(conf) .. " --no-color")
test("status: not running, stopped by SIGTERM, exit 1", code == 1 and o:find("not running: stopped (SIGTERM)", 1, true), o)
code, o = run("lobbies --config " .. quote(conf) .. " --no-color")
test("lobbies after a stop: none, and a warning", code == 0 and o:find("no lobbies", 1, true) and o:find("not running", 1, true), o)
test("its log ends with why", (read(ROOT .. "/conf/server.log") or ""):find("stopping: SIGTERM", 1, true))

-- SIGINT, and inline flags
local STATE2 = ROOT .. "/second.state"
local pipe2 = io.popen("exec sh -c " .. quote("echo $$; exec luajit " .. quote(CLI) .. " serve --bind 127.0.0.1:0 --countdown 2 --state-interval 0.1 --state-file "
    .. quote(STATE2) .. " --log-file " .. quote(ROOT .. "/second.log") .. " -q 2>&1"), "r")
local pid2 = tonumber(pipe2:read("*l"))
local line2 = pipe2:read("*l") or ""
local port2 = tonumber(line2:match("^listening %S+ (%d+)$"))
test("serve with flags only", port2 ~= nil, line2)
if port2 then
    local h2 = assert(client.connect({ host = "127.0.0.1", port = port2, name = "H" }))
    local l2 = h2:create_lobby({ map_name = "Quick", map_hash = "h", max_players = 2, game_mode = "x", region = "r" })
    l2:start_game()
    local t = socket.gettime()
    while socket.gettime() - t < 0.6 do h2:poll(0.01) end
    code, o = run("lobby " .. l2.game_id .. " --state " .. quote(STATE2) .. " --no-color")
    test("--countdown: the lobby shows its countdown", o:find("State: COUNTDOWN, starting in", 1, true) ~= nil, o)
    h2:disconnect()
end
os.execute("kill -INT " .. pid2)
pipe2:read("*a")
pipe2:close()
local st2 = daemon.read_state(STATE2)
test("SIGINT stops it cleanly too", st2 and st2.running == false and st2.stopped_by == "SIGINT")
test("its log went to the file", (read(ROOT .. "/second.log") or ""):find("stopping: SIGINT", 1, true))

-- a state left by a server that died without a word
daemon.write_state(ROOT .. "/dead.state", { pid = 999999, running = true, updated = os.time() - 120, stats = {}, lobbies = {}, bind = { ip = "x", port = 1 } })
code, o = run("status --state " .. quote(ROOT .. "/dead.state") .. " --no-color")
test("a server gone without saying: not running, exit 1", code == 1 and o:find("process 999999 is gone without saying so", 1, true), o)
-- }}}

if ROOT:match("/wete%-cli%.%w+$") then os.execute("rm -rf -- " .. quote(ROOT)) end

print(string.format("\nTests: %d passed, %d failed", pass_count, test_count - pass_count))
print(string.format("matchmaking command line: %d of %d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
