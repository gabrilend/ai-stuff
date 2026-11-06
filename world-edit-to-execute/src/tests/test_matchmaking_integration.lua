-- test_matchmaking_integration.lua - the matchmaking pieces together, end to end (issue 801h)
--
-- In plain terms: runs itself in a network of its own (`unshare -rn`, see
-- netns.lua), starts the server the way an operator would
-- (`world-edit-matchmaking.lua serve --config FILE`, with its NAT
-- reflector, asset mirror and a one-second countdown), and plays the
-- issue's six scenarios against it with client libraries polled as a
-- game polls them: a lobby from opening to game start; NAT traversal (the
-- lobby over real TCP, the UDP over simulated home routers, natsim.lua);
-- the asset mirror's advertisement; fifty lobbies at once; a host that
-- vanishes; and what is refused. It times the lobby's messages against
-- the issue's baselines, checks the operator's tool sees it all, and
-- ends with every connection gone and a clean stop.
--
-- Run with: luajit src/tests/test_matchmaking_integration.lua [DIR]
-- (DIR defaults to the project this file is in.)

-- The project: the argument, or the folder this test sits in (run-tests.sh
-- runs each test by its full path, from the project), or the owner's.
local DIR = arg[1] or arg[0]:match("^(.+)/src/tests/[^/]+%.lua$") or (arg[0]:match("^src/tests/") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/tests/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

require("netns").enter(arg[0], { DIR })

local socket = require("socket")
local client = require("matchmaking.client")
local nat = require("matchmaking.nat")
local natsim = require("natsim")
local packs = require("matchmaking.packs")
local daemon = require("matchmaking.daemon")

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

local function refused(fn, want)
    local ok, err = pcall(fn)
    return not ok and tostring(err):find(want, 1, true) ~= nil, tostring(err)
end

local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

local p = io.popen("mktemp -d -t wete-int.XXXXXX")
local ROOT = p:read("*l")
p:close()
if not (ROOT and ROOT:match("/wete%-int%.%w+$")) then print("  [FAIL] no folder of its own to work in") os.exit(1) end

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
local CONF = ROOT .. "/conf/server.conf.lua"
local STATE = ROOT .. "/conf/matchmaking.state"
local LOG = ROOT .. "/conf/matchmaking.log"

-- Runs the tool; returns its exit code and what it printed.
local function run(args)
    local pipe = io.popen("luajit " .. quote(CLI) .. " " .. args .. " 2>&1; echo \"exit $?\"", "r")
    local out = pipe:read("*a")
    pipe:close()
    local code = tonumber(out:match("exit (%d+)%s*$"))
    return code, out:gsub("exit %d+%s*$", "")
end

local PORT

-- Polls every connection given until `done()` or `seconds` pass.
local conns = {}
-- (`only`: just these connections.)
local function until_(done, seconds, only)
    local t = socket.gettime()
    local list = only or conns
    while not done() and socket.gettime() - t < (seconds or 3) do
        for _, c in ipairs(list) do if c.state ~= "closed" then c:poll(#list == 1 and 0.001 or 0) end end
        if #list > 1 then socket.sleep(0.0005) end
    end
    return done()
end

local function connect(name)
    local c, err = client.connect({ host = "127.0.0.1", port = PORT, name = name, reconnect = false })
    if c then conns[#conns + 1] = c end
    return c, err
end

-- Drops connections that are done with, so `until_` stops polling them.
local function forget(c)
    for i, x in ipairs(conns) do if x == c then table.remove(conns, i) return end end
end

local function median(list)
    local s = {}
    for i, v in ipairs(list) do s[i] = v end
    table.sort(s)
    return s[math.floor((#s + 1) / 2)]
end

local function ms(seconds) return string.format("%.1f ms", seconds * 1000) end
-- }}}

-- {{{ the server, as an operator starts it
print("the server, as an operator starts it")
os.execute("mkdir -p " .. quote(ROOT .. "/conf/packs"))
write(ROOT .. "/conf/packs/test-pack-v1.pack", "units and doodads, version 1")
write(ROOT .. "/extra.pack", "extra models")
local H1 = packs.hash_file(ROOT .. "/conf/packs/test-pack-v1.pack")
local H2 = packs.hash_file(ROOT .. "/extra.pack")
write(CONF, [[
return {
    bind = "127.0.0.1:0",
    max_players_per_lobby = 12,
    countdown_seconds = 1,
    nat = { enabled = true, port = 0 },
    asset_mirror = { enabled = true, contact = "mirror@example.org", packs_dir = "packs" },
    log_file = "matchmaking.log",
    state_file = "matchmaking.state", state_interval = 0.1,
}
]])
local code, o = run("validate-config " .. quote(CONF) .. " --no-color")
test("the configuration is valid", code == 0, o)

local pipe = io.popen("exec sh -c " .. quote("echo $$; exec luajit " .. quote(CLI) .. " serve --config " .. quote(CONF) .. " -q 2>&1"), "r")
local PID = tonumber(pipe:read("*l"))
local line = pipe:read("*l") or ""
local nline = pipe:read("*l") or ""
local ip
local PORT_
ip, PORT_ = line:match("^listening (%S+) (%d+)$")
PORT = tonumber(PORT_)
local NIP, NPORT = nline:match("^nat (%S+) (%d+) %d+$")
NPORT = tonumber(NPORT)
test("it listens, with its NAT reflector", ip == "127.0.0.1" and PORT and NPORT, line .. " / " .. nline)
if not (PORT and NPORT) then
    if PID then os.execute("kill " .. PID) end
    pipe:read("*a") pipe:close()
    os.exit(1)
end
-- The state as the server writes it next (every 0.1 s).
local function state_now()
    socket.sleep(0.3)
    return daemon.read_state(STATE)
end
-- }}}

-- {{{ 1: a lobby from opening to game start
print("1: a lobby from opening to game start")
local create_t, join_t, chat_t = {}, {}, {}
local host = assert(connect("Player123"))
local guest = assert(connect("FriendlyGuy"))
local t0 = socket.gettime()
local lobby = host:create_lobby({ map_name = "Castle Defense v1.3", map_hash = "sha256:abc", max_players = 4,
    game_mode = "melee", region = "lo" })
create_t[1] = socket.gettime() - t0
test("the host opens a lobby", lobby and lobby.state == "waiting" and lobby.is_host)
local games = guest:list_games({ map_name = "castle" })
test("a player finds it by part of its map's name", games and #games == 1 and games[1].map_name == "Castle Defense v1.3"
    and games[1].players == 1)
t0 = socket.gettime()
local glob = guest:join_game(games[1])
join_t[1] = socket.gettime() - t0
test("and joins it", glob and glob.state == "waiting" and glob.game_id == lobby.game_id)
test("both see two players", until_(function() return #lobby:get_players() == 2 end) and #glob:get_players() == 2)
test("the host is the first player, for both", glob.host_id == lobby.player_id and lobby.host_id == lobby.player_id)

local heard = {}
lobby:on("chat", function(player, text) heard[#heard + 1] = player.name .. ": " .. text end)
glob:on("chat", function(player, text) heard[#heard + 1] = "to guest, " .. player.name .. ": " .. text end)
t0 = socket.gettime()
glob:send_chat("Hello!")
until_(function() return heard[1] ~= nil end)
chat_t[1] = socket.gettime() - t0
test("a chat line reaches the host", heard[1] == "FriendlyGuy: Hello!", heard[1])
lobby:send_chat("Welcome")
test("and the host's reaches the player", until_(function() return heard[#heard] == "to guest, Player123: Welcome" end), heard[#heard])

local ready
lobby:on("player_ready", function(player, r) ready = player.name .. " " .. tostring(r) end)
glob:set_ready(true)
test("a player's ready mark reaches the host", until_(function() return ready == "FriendlyGuy true" end), ready)

local st = state_now()
code, o = run("lobbies --state " .. quote(STATE) .. " --no-color")
test("the operator sees the lobby", code == 0 and o:find("Castle Defense v1.3", 1, true) and o:find("Player123", 1, true)
    and o:find("2/4", 1, true) and o:find("WAITING", 1, true), o)
code, o = run("lobby " .. lobby.game_id .. " --state " .. quote(STATE) .. " --no-color")
test("and its players, ready or not", code == 0 and o:find("Player123 (host) [not ready]", 1, true)
    and o:find("FriendlyGuy [ready]", 1, true), o)

local countdowns, started = {}, {}
for name, l in pairs({ host = lobby, guest = glob }) do
    l:on("countdown", function(s) countdowns[#countdowns + 1] = name .. " " .. s end)
    l:on("game_start", function(h) started[name] = h end)
end
t0 = socket.gettime()
lobby:start_game()
test("both are told the game starts in a second", until_(function() return #countdowns == 2 end)
    and countdowns[1]:find(" 1$") and countdowns[2]:find(" 1$"), table.concat(countdowns, ", "))
test("a player who tries to join now is told the game is starting", (function()
    local late = assert(connect("Late"))
    local l, err = late:join_game(lobby.game_id)
    late:disconnect() forget(late)
    return (l == nil or l.state == "closed") and tostring(err):find("the game is starting", 1, true) ~= nil
end)())
test("then both are told it started, where the host is", until_(function() return started.host and started.guest end, 3)
    and started.guest.ip == "127.0.0.1" and started.guest.port == 6112)
local took = socket.gettime() - t0
test("after the countdown, not before", took >= 0.9 and took < 2.5, took)
test("the lobby is under way for both", lobby.state == "in_progress" and glob.state == "in_progress")
test("and no longer listed as open", #guest:list_games({}) == 0)
host:disconnect() guest:disconnect() forget(host) forget(guest)
-- }}}

-- {{{ 2: NAT traversal
print("2: NAT traversal")
local kind = nat.detect_type({ stun_server = NIP .. ":" .. NPORT, local_ip = "127.0.0.1" })
test("the server's reflector finds this machine open", kind == "open", kind)

-- The lobbies go over real TCP to the real server; the UDP goes through
-- simulated routers, on a simulated clock.
local now = 0
local function clock() return now end
local net = natsim.network({ clock = clock })
local s1 = net:machine("1.0.0.1")
local refl = nat.reflector({ main = s1:udp(3478), alt_port = s1:udp(3479), alt_ip = net:machine("1.0.0.2"):udp(3478) })
local function behind(kind_, n)
    return net:nat("8.3.0." .. n, kind_):machine("192.168.1." .. n):udp(6112)
end
local function detect(ep)
    local d = nat.detector(ep, { server_ip = "1.0.0.1", server_port = 3478, clock = clock })
    for _ = 1, 1000 do
        refl:poll() d:step()
        if d.result then break end
        now = now + 0.01
    end
    return d
end
-- One lobby of two, the host behind `hkind` and the player behind `pkind`;
-- the game started, then their sessions run. Returns what they report.
local function nat_game(hkind, pkind, n)
    local hep, pep = behind(hkind, n), behind(pkind, n + 1)
    local hd, pd = detect(hep), detect(pep)
    local hc, pc = assert(connect("NatHost" .. n)), assert(connect("NatPlayer" .. n))
    local hl = hc:create_lobby({ map_name = "NAT Test " .. n, map_hash = "h", max_players = 2, game_mode = "x", region = "lo" })
    local pl = pc:join_game(hl.game_id)
    local go = 0
    hl:on("game_start", function() go = go + 1 end)
    pl:on("game_start", function() go = go + 1 end)
    hl:start_game()
    until_(function() return go == 2 end, 3)
    local hs = nat.session(hl, { endpoint = hep, mapped_ip = hd.mapped_ip, mapped_port = hd.mapped_port, clock = clock })
    local ps = nat.session(pl, { endpoint = pep, mapped_ip = pd.mapped_ip, mapped_port = pd.mapped_port, clock = clock })
    local ev = {}
    for name, s in pairs({ host = hs, player = ps }) do
        for _, e in ipairs({ "established", "failed", "data" }) do
            s:on(e, function(_, x) ev[name .. " " .. e] = type(x) == "string" and x or true end)
        end
    end
    local t = now
    ps:start()
    -- the endpoints cross the real server; the punches run on the simulated clock
    until_(function() return hs:punch_for(pl.player_id) ~= nil and ps:punch_for(hl.player_id) ~= nil end, 3)
    while now - t < 8 do
        hs:step() ps:step()
        if (ev["host established"] and ev["player established"]) or (ev["host failed"] and ev["player failed"]) then break end
        now = now + 0.02
    end
    local result = { started = go == 2, hd = hd, pd = pd, ev = ev, seconds = now - t }
    if ev["host established"] and ev["player established"] then
        ps:punch_for(hl.player_id):send("ping")
        hs:step()
        hs:punch_for(pl.player_id):send("pong")
        ps:step()
    end
    hs:close() ps:close()
    hc:disconnect() pc:disconnect() forget(hc) forget(pc)
    return result
end

local a = nat_game("restricted_cone", "port_restricted", 10)
test("the detector names both routers", a.hd.result == "restricted_cone" and a.pd.result == "port_restricted",
    tostring(a.hd.result) .. " " .. tostring(a.pd.result))
test("the game starts, then the endpoints cross the server", a.started)
test("restricted cone host and port-restricted player punch through", a.ev["host established"] and a.ev["player established"])
test("within the issue's three seconds", a.seconds < 3, a.seconds)
test("and their datagrams cross both ways", a.ev["host data"] == "ping" and a.ev["player data"] == "pong",
    tostring(a.ev["host data"]) .. " " .. tostring(a.ev["player data"]))
local b = nat_game("port_restricted", "symmetric", 20)
test("port-restricted host and symmetric player: both are told it failed (no relay)",
    b.ev["host failed"] and b.ev["player failed"] and not b.ev["host established"])
test("after the five seconds a punch gets", b.seconds >= 5 and b.seconds < 6, b.seconds)
-- }}}

-- {{{ 3: the asset mirror
print("3: the asset mirror")
local mh = assert(connect("PackHost"))
local packs_needed = { { id = "test-pack-v1", hash = H1 }, { id = "extra-pack", hash = H2 } }
local ml = mh:create_lobby({ map_name = "Pack Test", map_hash = "h", asset_packs = packs_needed, max_players = 4,
    game_mode = "x", region = "lo" })
until_(function() return ml.mirror ~= nil end, 1)
local host_told = ml.mirror
test("the host is told which of its packs the mirror has", host_told and host_told.contact == "mirror@example.org"
    and #host_told.packs == 1 and host_told.packs[1].id == "test-pack-v1")
local mj = assert(connect("PackPlayer"))
local mjl = mj:join_game(mj:list_games({ map_name = "pack" })[1])
until_(function() return mjl.mirror ~= nil end, 2)
test("a joining player is told the mirror's contact", mjl.mirror and mjl.mirror.contact == "mirror@example.org")
local plan = mjl:missing_packs({}) or {}
test("with nothing, the mirror's pack comes from the mirror, the other from the host",
    #plan == 2 and plan[1].id == "test-pack-v1" and plan[1].from == "mirror"
    and plan[1].size == #"units and doodads, version 1" and plan[2].id == "extra-pack" and plan[2].from == "host")
plan = mjl:missing_packs({ ["test-pack-v1"] = H1 }) or {}
test("a pack already held is not fetched", #plan == 1 and plan[1].id == "extra-pack")
plan = mjl:missing_packs({ ["test-pack-v1"] = "sha256:other" }) or {}
test("another version of it is", #plan == 2)

code, o = run("assets add " .. quote(ROOT .. "/extra.pack") .. " extra-pack --config " .. quote(CONF) .. " --no-color")
test("the operator adds the other pack", code == 0 and o:find("Added: extra-pack", 1, true)
    and o:find("process " .. PID .. ") reads the folder again", 1, true), o)
test("the running server takes it", until_(function()
    local s = daemon.read_state(STATE)
    return s and s.mirror and #s.mirror.packs == 2
end, 3))
local mk = assert(connect("PackPlayer2"))
local mkl = mk:join_game(mk:list_games({ map_name = "pack" })[1])
until_(function() return mkl.mirror ~= nil end, 2)
plan = mkl:missing_packs({}) or {}
test("the next player is told both come from the mirror", #plan == 2 and plan[1].from == "mirror" and plan[2].from == "mirror")
code, o = run("assets list --config " .. quote(CONF) .. " --no-color")
test("assets list shows both", code == 0 and o:find("extra-pack", 1, true) and o:find("test-pack-v1", 1, true), o)
mh:disconnect() mj:disconnect() mk:disconnect() forget(mh) forget(mj) forget(mk)
-- }}}

-- {{{ 4: fifty lobbies at once
print("4: fifty lobbies at once")
local hosts, lobbies = {}, {}
t0 = socket.gettime()
for i = 1, 50 do
    hosts[i] = assert(connect("Host" .. i))
    local t = socket.gettime()
    lobbies[i] = hosts[i]:create_lobby({ map_name = "Lobby " .. i, map_hash = "h", max_players = 2, game_mode = "x", region = "lo" })
    create_t[#create_t + 1] = socket.gettime() - t
end
local watcher = assert(connect("Watcher"))
local all = watcher:list_games({})
test("fifty lobbies are open", all and #all == 50, all and #all)
local seen = {}
for _, g in ipairs(all or {}) do seen[g.map_name] = true end
test("each its own", seen["Lobby 1"] and seen["Lobby 50"])
local joiners = {}
for i = 1, 50 do
    joiners[i] = assert(connect("Joiner" .. i))
    local t = socket.gettime()
    joiners[i]:join_game(lobbies[i].game_id)
    join_t[#join_t + 1] = socket.gettime() - t
end
test("a player joins each, and each host sees two", until_(function()
    for i = 1, 50 do if #lobbies[i]:get_players() ~= 2 then return false end end
    return true
end, 5))
test("full lobbies are no longer listed", #watcher:list_games({ free_slots = 1 }) == 0)
st = state_now()
test("the server counts 101 connections and 100 players in lobbies", st and st.stats.players_online == 101
    and st.stats.players_in_lobbies == 100, st and (st.stats.players_online .. " " .. st.stats.players_in_lobbies))
local all_took = socket.gettime() - t0
test("all of it within ten seconds", all_took < 10, all_took)
for i = 1, 50 do
    local t = socket.gettime()
    local got
    lobbies[i]:on("chat", function() got = true end)
    joiners[i].lobby:send_chat("gg")
    until_(function() return got end, 1, { joiners[i], hosts[i] })
    chat_t[#chat_t + 1] = socket.gettime() - t
end
for i = 1, 50 do hosts[i]:disconnect() joiners[i]:disconnect() forget(hosts[i]) forget(joiners[i]) end
watcher:disconnect() forget(watcher)
-- }}}

-- {{{ 5: a host that vanishes
print("5: a host that vanishes")
local vh = assert(connect("Vanisher"))
local vp = assert(connect("Stayer"))
local vl = vh:create_lobby({ map_name = "Disconnect Test", map_hash = "h", max_players = 4, game_mode = "x", region = "lo" })
local vpl = vp:join_game(vl.game_id)
local closed_why
vpl:on("closed", function(why) closed_why = why end)
until_(function() return #vl:get_players() == 2 end)
vh.sock:close()                          -- no LEAVE, no goodbye: the socket just goes
forget(vh)
test("the player is told the lobby closed", until_(function() return closed_why ~= nil end, 3) and closed_why == "the lobby closed",
    closed_why)
test("and it is gone from the list", #vp:list_games({}) == 0)
local ql = vp:create_lobby({ map_name = "Second Try", map_hash = "h", max_players = 4, game_mode = "x", region = "lo" })
local qp = assert(connect("Quitter"))
local qpl = qp:join_game(ql.game_id)
local left
ql:on("player_leave", function(pl_, how) left = pl_.name .. " " .. how end)
until_(function() return #ql:get_players() == 2 end)
qp.sock:close()
forget(qp)
test("a player who vanishes is seen to leave", until_(function() return left ~= nil end, 3) and left == "Quitter left", left)
test("and the lobby stays open", ql.state == "waiting" and #ql:get_players() == 1)
vp:disconnect() forget(vp)
-- }}}

-- {{{ 6: what is refused
print("6: what is refused")
local eh = assert(connect("ErrHost"))
local ep_ = assert(connect("ErrPlayer"))
local none, err = ep_:join_game(999999)
test("joining a lobby that isn't there", (none == nil or none.state == "closed"), err)
test("says so", tostring(err):find("no such game", 1, true) or (none and none.close_reason == "no such game"), err)
local el = eh:create_lobby({ map_name = "Permission Test", map_hash = "h", max_players = 2, game_mode = "x", region = "lo" })
local epl = ep_:join_game(el.game_id)
test("a player can't start the game", refused(function() epl:start_game() end, "only the host starts the game"))
test("nor kick", refused(function() epl:kick(el.player_id) end, "only the host kicks"))
test("nor open a second lobby on the same connection", refused(function()
    ep_:create_lobby({ map_name = "x", map_hash = "h", max_players = 2, game_mode = "x", region = "lo" })
end, "already in lobby"))
epl.is_host = true                      -- past the library's own check: the server still refuses
epl:start_game()
epl.is_host = false
until_(function() return false end, 0.3)
test("a player's START_GAME that gets through is ignored by the server", el.state == "waiting" and epl.state == "waiting"
    and (read(LOG) or ""):find("START_GAME of a lobby it does not host", 1, true))
local third = assert(connect("Third"))
local tl, terr = third:join_game(el.game_id)
test("a full lobby refuses a third player", (tl == nil or tl.state == "closed") and tostring(terr):find("full", 1, true), terr)
local kicked_why
epl:on("closed", function(why) kicked_why = why end)
el:kick(epl.player_id)
test("a kicked player is told so", until_(function() return kicked_why ~= nil end) and kicked_why == "kicked by the host", kicked_why)
test("and the lobby has room again", until_(function() return #el:get_players() == 1 end))
eh:disconnect() ep_:disconnect() third:disconnect() forget(eh) forget(ep_) forget(third)
-- }}}

-- {{{ the baselines
print("the baselines (medians over the runs above)")
local mc, mj_, mch = median(create_t), median(join_t), median(chat_t)
print("    lobby created " .. ms(mc) .. " (" .. #create_t .. "), joined " .. ms(mj_) .. " (" .. #join_t .. "), chat "
    .. ms(mch) .. " (" .. #chat_t .. "), punch " .. string.format("%.2f s simulated", a.seconds))
test("a lobby opens in under 50 ms", mc < 0.05, ms(mc))
test("a join in under 100 ms", mj_ < 0.1, ms(mj_))
test("a chat line arrives in under 20 ms", mch < 0.02, ms(mch))
-- }}}

-- {{{ cleaning up
print("cleaning up")
st = state_now()
test("every connection is gone, every lobby closed", st and st.stats.players_online == 0 and st.stats.lobbies_active == 0,
    st and (st.stats.players_online .. " " .. st.stats.lobbies_active))
test("nothing was dropped for misbehaving", st and st.stats.dropped == 0, st and st.stats.dropped)
code, o = run("status --config " .. quote(CONF) .. " --no-color")
test("status: running, no lobbies", code == 0 and o:find("Lobbies: 0 active", 1, true), o)
local last = assert(connect("Last"))
local ll = last:create_lobby({ map_name = "Stop Test", map_hash = "h", max_players = 2, game_mode = "x", region = "lo" })
local last_why
ll:on("closed", function(why) last_why = why end)
os.execute("kill " .. PID)
test("SIGTERM: the last lobby is told it closed", until_(function() return last_why ~= nil end, 3) and last_why == "the lobby closed",
    last_why)
pipe:read("*a")
pipe:close()
last:disconnect()
local final = daemon.read_state(STATE)
test("and the server says it stopped", final and final.running == false and final.stopped_by == "SIGTERM")
-- }}}

if ROOT:match("/wete%-int%.%w+$") then os.execute("rm -rf -- " .. quote(ROOT)) end

print(string.format("\nTests: %d passed, %d failed", pass_count, test_count - pass_count))
print(string.format("matchmaking integration: %d of %d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
