-- test_matchmaking_client_net.lua - the matchmaking client library over real sockets, on loopback (issue 801c)
--
-- In plain terms: runs itself in a network of its own (`unshare -rn`, see
-- netns.lua), starts the matchmaking daemon there, and has a host and a
-- player, each a client library polled as a game would poll it, go
-- through a lobby. Then the server is killed: the clients hear it, their
-- lobbies close, and once a server is back on the same port they
-- reconnect by themselves and can open a lobby again.
--
-- Run with: luajit src/tests/test_matchmaking_client_net.lua [DIR]
-- (DIR defaults to the project this file is in.)

-- The project: the argument, or the folder this test sits in (run-tests.sh
-- runs each test by its full path, from the project), or the owner's.
local DIR = arg[1] or arg[0]:match("^(.+)/src/tests/[^/]+%.lua$") or (arg[0]:match("^src/tests/") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/tests/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

require("netns").enter(arg[0], { DIR })

local socket = require("socket")
local client = require("matchmaking.client")
local protocol = require("matchmaking.protocol")

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

-- {{{ a daemon
local function daemon(bind)
    local pipe = io.popen("exec sh -c " .. quote("echo $$; exec luajit " .. quote(DIR .. "/src/cli/matchmaking-serve.lua") .. " "
        .. quote(DIR) .. " --bind " .. bind .. " --seconds 60 --quiet 2>&1"), "r")
    local pid = tonumber(pipe:read("*l"))
    local line = pipe:read("*l") or ""
    local ip, port = line:match("^listening (%S+) (%d+)$")
    if not ip then pipe:close() return nil, line end
    return pid, ip, tonumber(port), pipe
end

local function kill(pid, pipe)
    os.execute("kill " .. pid)
    pipe:read("*a")
    pipe:close()
end
-- }}}

-- Polls every connection given until `done()` or `seconds` pass.
local function until_(conns, done, seconds)
    local t = socket.gettime()
    while not done() and socket.gettime() - t < (seconds or 3) do
        for _, c in ipairs(conns) do c:poll(0.005) end
    end
    return done()
end
-- }}}

local pid, ip, port, pipe = daemon("127.0.0.1:0")
test("the daemon listens", pid ~= nil, ip)
if not pid then os.exit(1) end

-- {{{ connecting
print("connecting")
local none, err = client.connect({ host = "127.0.0.1", port = port + 1 == 65536 and 1 or port + 1, timeout = 1000 })
test("a port nobody listens on is refused", none == nil and err ~= nil, err)
local t0 = socket.gettime()
none, err = client.connect({ host = "10.1.2.3", port = 8080, timeout = 300 })
test("a server out of reach is reported, within the timeout", none == nil and err ~= nil and socket.gettime() - t0 < 1, err)
local stalled = assert(socket.bind("127.0.0.1", 0, 1))   -- a server that never accepts: its queue is full
local _, stalled_port = stalled:getsockname()
local queued = {}
for i = 1, 4 do queued[i] = socket.tcp() queued[i]:settimeout(0) queued[i]:connect("127.0.0.1", stalled_port) end
socket.sleep(0.1)
t0 = socket.gettime()
none, err = client.connect({ host = "127.0.0.1", port = tonumber(stalled_port), timeout = 300 })
local took = socket.gettime() - t0
test("a server that never answers is given up on after the timeout", none == nil and err == "no answer in 300 ms"
    and took >= 0.29 and took < 1, tostring(err) .. " after " .. took)
for i = 1, 4 do queued[i]:close() end
stalled:close()
local host_log = {}
local host = assert(client.connect({ host = ip, port = port, name = "Host", reconnect_min = 0.2,
    log = function(l) host_log[#host_log + 1] = l end }))
local player = assert(client.connect({ host = ip, port = port, name = "Ann", reconnect_min = 0.2 }))
test("two games connect", host.state == "connected" and player.state == "connected")
-- }}}

-- {{{ a lobby over the network
print("a lobby over the network")
local lobby = host:create_lobby({ map_name = "Castle Defense", map_hash = "sha256:abc", max_players = 4,
    game_mode = "co-op", region = "us-west", host_port = 6200 })
test("the host opens a lobby, waiting for the answer", lobby and lobby.state == "waiting" and lobby.game_id == 1)
local games = player:list_games({ region = "us-west" })
test("the player lists it", games and #games == 1 and games[1].id == lobby.game_id)
local joined, chat, started = {}, {}, {}
lobby:on("player_join", function(p) joined[#joined + 1] = p.name end)
lobby:on("chat", function(p, text) chat[#chat + 1] = p.name .. ": " .. text end)
local plobby
player:join_game(games[1], function(l) plobby = l end)
test("joining by callback, the host hears player_join", until_({ host, player }, function() return plobby and joined[1] end)
    and joined[1] == "Ann")
plobby:on("game_start", function(c) started[#started + 1] = c end)
plobby:send_chat("hello")
test("chat arrives", until_({ host, player }, function() return chat[1] end) and chat[1] == "Ann: hello")
lobby:start_game()
test("game_start gives the player the host's address", until_({ host, player }, function() return started[1] end)
    and started[1].ip == "127.0.0.1" and started[1].port == 6200)
local pongs = 0
player:on("pong", function() pongs = pongs + 1 end)
player:ping()
test("a ping is answered and measured", until_({ player }, function() return pongs == 1 end) and player.latency_ms >= 0)
-- }}}

-- {{{ the server goes and comes back
print("the server goes and comes back")
local drops, closes, back = {}, {}, {}
host:on("disconnect", function(w) drops[#drops + 1] = "host: " .. w end)
player:on("disconnect", function(w) drops[#drops + 1] = "player: " .. w end)
lobby:on("closed", function(w) closes[#closes + 1] = w end)
plobby:on("closed", function(w) closes[#closes + 1] = w end)
host:on("reconnect", function() back[#back + 1] = "host" end)
player:on("reconnect", function() back[#back + 1] = "player" end)
kill(pid, pipe)
test("both hear the server go", until_({ host, player }, function() return #drops == 2 end), table.concat(drops, "; "))
test("and both lobbies close, disconnected", #closes == 2 and closes[1] == "disconnected" and closes[2] == "disconnected"
    and host.lobby == nil and player.lobby == nil)
local tries_from = #host_log
until_({ host, player }, function() return false end, 0.5)
local tries = 0
for i = tries_from + 1, #host_log do if host_log[i]:find("could not connect", 1, true) then tries = tries + 1 end end
test("while the server is away they keep trying, not connected", host.state ~= "connected" and #back == 0)
test("waiting longer between tries", tries >= 1 and tries <= 3, tries .. " tries in half a second")
local pid2, _, port2, pipe2 = daemon("127.0.0.1:" .. port)
test("a server comes back on the same port", pid2 ~= nil and port2 == port)
test("both reconnect by themselves", until_({ host, player }, function() return #back == 2 end, 10), #back)
local again = host:create_lobby({ map_name = "Castle Defense", map_hash = "sha256:abc", max_players = 4,
    game_mode = "co-op", region = "us-west" })
test("and can open a lobby again", again and again.state == "waiting")
again:leave()
local packs = {}
for i = 1, 900 do packs[i] = { id = "pack-" .. i, hash = string.rep("h", 1000) } end
local big
host:create_lobby({ map_name = "Many Packs", map_hash = "sha256:abc", max_players = 4, game_mode = "co-op",
    region = "eu", asset_packs = packs }, function(l) big = l end)
local listed
until_({ host, player }, function() return big end, 5)
player:list_games({ region = "eu" }, function(g) listed = g end)
test("a lobby of 900 asset packs is sent whole: the server lists every pack", until_({ host, player }, function() return listed end, 5)
    and #listed == 1 and #listed[1].asset_packs == 900 and listed[1].asset_packs[900].id == "pack-900")
big:leave()
-- }}}

-- {{{ more than the socket takes at once
print("more than the socket takes at once")
do
    local raw = assert(socket.bind("127.0.0.1", 0))      -- a server that reads only when the test says
    local _, raw_port = raw:getsockname()
    local flood = assert(client.connect({ host = "127.0.0.1", port = tonumber(raw_port), reconnect = false }))
    local peer = raw:accept()
    peer:settimeout(0)
    local n = 500000
    for _ = 1, n do flood:ping() end
    flood:poll(0)
    test("what the socket doesn't take is held back", flood.pending ~= nil and #flood.pending > 0)
    local parts, t = {}, socket.gettime()
    local total, want = 0, nil
    while socket.gettime() - t < 10 do
        flood:poll(0)
        local data, _, partial = peer:receive(1048576)
        local b = data or partial
        if b and #b > 0 then parts[#parts + 1] = b total = total + #b end
        if not flood.pending and #flood.out == 0 and not (b and #b > 0) then break end
    end
    local bytes = table.concat(parts)
    local pos, count, in_order = 1, 0, true
    while pos <= #bytes do
        local len = protocol.frame_length(bytes:sub(pos, pos + 7))
        if not len or pos + len - 1 > #bytes then break end
        local name, m = protocol.decode(bytes:sub(pos, pos + len - 1))
        count = count + 1
        if name ~= "PING" or m.nonce ~= count then in_order = false end
        pos = pos + len
    end
    test("and all of it arrives, in order, once the server reads", count == n and in_order and pos == #bytes + 1, count)
    flood:disconnect()
    peer:close()
    raw:close()
end
-- }}}

-- {{{ disconnecting for good
print("disconnecting for good")
player:disconnect()
local last = host:create_lobby({ map_name = "Last", map_hash = "h", max_players = 2, game_mode = "x", region = "eu" })
host:disconnect()
test("disconnect closes the lobby and the connection", host.state == "closed" and last and last.state == "closed" and host.sock == nil)
until_({ host, player }, function() return false end, 0.5)
test("and never reconnects", host.state == "closed" and player.state == "closed" and #back == 2)
if pid2 then kill(pid2, pipe2) end
-- }}}

print(string.format("\nTests: %d passed, %d failed", pass_count, test_count - pass_count))
print(string.format("matchmaking client over the network: %d of %d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
