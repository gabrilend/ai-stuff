-- test_matchmaking_daemon.lua - the matchmaking server over real sockets, on loopback (issue 801b)
--
-- In plain terms: runs itself in a network of its own (`unshare -rn`, see
-- netns.lua), starts the matchmaking server as a daemon there, and plays
-- a host and joining players against it through real connections: a
-- lobby opened, joined, chatted in, started, and closed when its host
-- goes; fifty connections at once; a client sending rubbish; the daemon
-- stopping by itself. Then the socket layer inside this process, to see
-- that stopping the server tells every lobby's members.
--
-- Run with: luajit src/tests/test_matchmaking_daemon.lua [DIR]
-- (DIR defaults to the project this file is in.)

-- The project: the argument, or the folder this test sits in (run-tests.sh
-- runs each test by its full path, from the project), or the owner's.
local DIR = arg[1] or arg[0]:match("^(.+)/src/tests/[^/]+%.lua$") or (arg[0]:match("^src/tests/") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/tests/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

require("netns").enter(arg[0], { DIR })

local socket = require("socket")
local protocol = require("matchmaking.protocol")
local server = require("matchmaking.server")

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

-- Running, not merely waiting to be reaped (Linux's /proc).
local function alive(pid)
    local f = io.open("/proc/" .. pid .. "/stat", "r")
    if not f then return false end
    local stat = f:read("*a")
    f:close()
    return stat:match("^%d+ %b() (%a)") ~= "Z"
end

-- {{{ a daemon
-- Starts the daemon with `options`; returns its pid, address and pipe
-- (standard output and error together), or nil and what it said.
local function daemon(options)
    local cmd = "exec sh -c " .. quote("echo $$; exec luajit " .. quote(DIR .. "/src/cli/matchmaking-serve.lua") .. " "
        .. quote(DIR) .. " " .. options .. " 2>&1")
    local pipe = io.popen(cmd, "r")
    local pid = tonumber(pipe:read("*l"))
    local said = {}
    while true do
        local line = pipe:read("*l")
        if not line then pipe:close() return nil, table.concat(said, "\n") end
        said[#said + 1] = line
        local ip, port = line:match("^listening (%S+) (%d+)$")
        if ip then return pid, ip, tonumber(port), pipe end
    end
end
-- }}}

-- {{{ a client
local function client(ip, port)
    local c = assert(socket.connect(ip, port))
    c:settimeout(3)
    return c
end

local function put(c, name, message) return c:send(protocol.encode(name, message)) end

-- The next message off `c`: name and fields, or nil and why.
local function get(c)
    local head, err = c:receive(8)
    if not head then return nil, err end
    local total = protocol.frame_length(head)
    local body = ""
    if total > 8 then
        body, err = c:receive(total - 8)
        if not body then return nil, err end
    end
    return protocol.decode(head .. body)
end
-- }}}
-- }}}

local game = { map_name = "Castle Defense v1.3", map_hash = "sha256:abc", asset_packs = {}, max_players = 4,
    game_mode = "co-op", region = "us-west", host_port = 6112, host_name = "Host" }

-- {{{ the daemon
print("the daemon")
local pid, ip, port, pipe = daemon("--bind 127.0.0.1:0 --seconds 60")
test("it listens on loopback, on a port it chose", pid and ip == "127.0.0.1" and port > 0, ip)
if not pid then
    -- {{{ more output than the socket takes at once
print("more output than the socket takes at once")
do
    local srv = server.new({ bind = "127.0.0.1:0", max_output_bytes = 67108864, rate_burst = 1000, rate_per_second = 1000 })
    srv:start()
    local sip, sport = srv:address()
    for i = 1, 200 do      -- lobbies held by connections with no socket, straight through the core
        local id = srv:accept("10.0.0." .. i % 250, i)
        srv:receive(id, protocol.encode("REGISTER_GAME", { map_name = string.rep("m", 1000) .. i, map_hash = "h",
            asset_packs = {}, max_players = 2, game_mode = "melee", region = "eu", host_port = 6112 }))
        srv:output(id)
    end
    local c = socket.connect(sip, sport)
    for _ = 1, 30 do c:send(protocol.encode("LIST_GAMES", {})) end
    local t = socket.gettime()
    while srv:stats().messages_in < 230 and socket.gettime() - t < 3 do srv:tick(0.01) end
    for _ = 1, 20 do srv:tick(0) end
    local sid = next(srv.sockets)
    test("the socket was given more than it takes at once", sid ~= nil and srv.conns[sid].pending ~= nil)
    c:settimeout(0)
    local buf, lists, good = "", 0, true
    t = socket.gettime()
    while lists < 30 and socket.gettime() - t < 5 do
        srv:tick(0.01)
        local data, err, partial = c:receive(1048576)
        buf = buf .. (data or partial or "")
        while true do
            local ok, n, m, rest = pcall(protocol.read_frame, buf)
            if not ok then good = false break end
            if not n then break end
            lists = lists + 1
            if n ~= "GAME_LIST" or #m.games ~= 200 then good = false end
            buf = rest
        end
        if not good then break end
    end
    test("every byte arrives, in order, once the client reads", good and lists == 30, lists)
    c:close()
    srv:stop()
end
-- }}}

print(string.format("\nmatchmaking daemon: %d of %d passed", pass_count, test_count + 1))
    os.exit(1)
end

local h = client(ip, port)
put(h, "REGISTER_GAME", game)
local name, ack = get(h)
test("a host registers over a real connection", name == "JOIN_ACK" and ack.game_id == 1 and ack.players[1].name == "Host")
local gid = ack.game_id

local a, b = client(ip, port), client(ip, port)
put(a, "LIST_GAMES", { region = "us-west" })
local _, list = get(a)
test("a second connection lists the game", list and #list.games == 1 and list.games[1].map_name == game.map_name)
put(a, "JOIN_GAME", { game_id = gid, player_name = "Ann" })
local an, aack = get(a)
local hn, hup = get(h)
test("a player joins, and the host hears of it", an == "JOIN_ACK" and hn == "LOBBY_UPDATE" and hup.event == "join"
    and hup.player_id == aack.player_id)
put(b, "JOIN_GAME", { game_id = gid, player_name = "Bo" })
get(b) get(h) get(a)
put(b, "CHAT_MSG", { game_id = gid, player_id = 0, text = "gl hf" })
local c1, c2, c3 = select(2, get(h)), select(2, get(a)), select(2, get(b))
test("chat reaches all three", c1 and c2 and c3 and c1.text == "gl hf" and c2.text == "gl hf" and c3.text == "gl hf")
put(h, "START_GAME", { game_id = gid })
local s1, s2 = select(2, get(a)), select(2, get(b))
local s0n = get(h)
test("the start tells the players where the host is", s0n == "GAME_START" and s1 and s1.host_ip == "127.0.0.1"
    and s1.host_port == 6112 and s2 and s2.host_port == 6112)
h:close()
local un, u = get(a)
local bn = get(b)
test("the host going closes the lobby, telling its players", un == "UNREGISTER_GAME" and u.game_id == gid and bn == "UNREGISTER_GAME")

local many, answered = {}, 0
for i = 1, 50 do many[i] = client(ip, port) end
for i = 1, 50 do put(many[i], "PING", { nonce = i }) end
for i = 1, 50 do
    local n, m = get(many[i])
    if n == "PONG" and m.nonce == i then answered = answered + 1 end
end
test("fifty connections at once are each answered", answered == 50, answered)
for i = 1, 50 do many[i]:close() end

local junk = client(ip, port)
junk:send("this is not a message")
local jn, jerr = get(junk)
test("a client sending rubbish is disconnected", jn == nil and jerr == "closed", jerr)
put(a, "PING", { nonce = 77 })
local pn, pm = get(a)
test("the others are kept", pn == "PONG" and pm.nonce == 77)
a:close() b:close()

os.execute("kill " .. pid)
local log = pipe:read("*a")
pipe:close()
test("it logged the lobby's life", log:find("lobby 1 opened by connection 1 (127.0.0.1:", 1, true)
    and log:find("lobby 1 started with 3 players", 1, true) and log:find("lobby 1 closed: its host disconnected", 1, true), log:sub(1, 300))
test("it logged the dropped client", log:find("dropped, matchmaking: the magic is", 1, true) ~= nil)
test("log lines carry the time in UTC", log:match("%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ connection %d+ from") ~= nil)

local qpid, qip, qport, qpipe = daemon("--bind 127.0.0.1:0 --seconds 1 --quiet")
local t0 = socket.gettime()
while qpid and alive(qpid) and socket.gettime() - t0 < 5 do socket.sleep(0.05) end
test("--seconds stops it by itself", qpid and not alive(qpid))
test("--quiet logs nothing", qpipe and qpipe:read("*a") == "")
if qpipe then qpipe:close() end
test("once stopped it no longer listens", qip and socket.connect(qip, qport) == nil)

local none, said = daemon("--bind 127.0.0.1:notaport")
test("a bad --bind is refused", none == nil and said:find("bind should be host:port", 1, true) ~= nil, said)
none, said = daemon("--bind 192.0.2.1:0 --quiet")
test("an address not on this machine is refused", none == nil and said:find("can't listen on 192.0.2.1:0", 1, true) ~= nil, said)
none, said = daemon("--frobnicate")
test("an unknown option is refused", none == nil and said:find("--frobnicate is not an option", 1, true) ~= nil, said)
-- }}}

-- {{{ the socket layer in this process
print("the socket layer in this process")
do
    local lines = {}
    local srv = server.new({ bind = "127.0.0.1:0", log = function(l) lines[#lines + 1] = l end })
    srv:start()
    local sip, sport = srv:address()
    test("start listens where it was told", sip == "127.0.0.1" and sport > 0)
    local function pump(c, want)
        c:settimeout(0)
        local buf, got = "", {}
        local t = socket.gettime()
        while #got < want and socket.gettime() - t < 3 do
            if srv.socket_lib then srv:tick(0.01) else socket.sleep(0.01) end
            local data, err, partial = c:receive(65536)
            buf = buf .. (data or partial or "")
            while true do
                local n, m, rest = protocol.read_frame(buf)
                if not n then break end
                got[#got + 1] = { name = n, m = m }
                buf = rest
            end
            if err == "closed" then break end
        end
        return got
    end
    local hc = socket.connect(sip, sport)
    hc:send(protocol.encode("REGISTER_GAME", game))
    local g = pump(hc, 1)
    test("ticks answer a register", g[1] and g[1].name == "JOIN_ACK")
    local pc = socket.connect(sip, sport)
    pc:send(protocol.encode("JOIN_GAME", { game_id = g[1].m.game_id, player_name = "P" }))
    pump(pc, 1)
    test("stats see two connections in one lobby", srv:stats().players_online == 2 and srv:stats().players_in_lobbies == 2)
    -- a big message cut by the network
    local big = protocol.encode("CHAT_MSG", { game_id = g[1].m.game_id, player_id = 0, text = string.rep("z", 1024) })
    pc:send(big:sub(1, 500))
    srv:tick(0.01)
    pc:send(big:sub(501))
    local chat = pump(pc, 1)
    test("a message arriving in two pieces is read whole", chat[1] and chat[1].name == "CHAT_MSG" and #chat[1].m.text == 1024)
    -- every waiting connection is taken in one tick
    local waiting = {}
    for i = 1, 5 do waiting[i] = socket.connect(sip, sport) end
    socket.sleep(0.05)
    srv:tick(0)
    test("one tick accepts every connection waiting", srv:stats().players_online == 7, srv:stats().players_online)
    for i = 1, 5 do waiting[i]:close() end
    srv:tick(0.05)
    srv:stop()
    local bye = pump(pc, 1)
    test("stopping tells the lobby's members", bye[1] and bye[1].name == "UNREGISTER_GAME")
    pc:settimeout(1)
    local _, err = pc:receive(1)
    test("and closes their connections", err == "closed", err)
    test("and stops listening", socket.connect(sip, sport) == nil and next(srv.conns) == nil and next(srv.sockets) == nil)
    test("tick before start is refused", not pcall(srv.tick, srv))
    hc:close() pc:close()
end
-- }}}

-- {{{ more output than the socket takes at once
print("more output than the socket takes at once")
do
    local srv = server.new({ bind = "127.0.0.1:0", max_output_bytes = 67108864, rate_burst = 1000, rate_per_second = 1000 })
    srv:start()
    local sip, sport = srv:address()
    for i = 1, 200 do      -- lobbies held by connections with no socket, straight through the core
        local id = srv:accept("10.0.0." .. i % 250, i)
        srv:receive(id, protocol.encode("REGISTER_GAME", { map_name = string.rep("m", 1000) .. i, map_hash = "h",
            asset_packs = {}, max_players = 2, game_mode = "melee", region = "eu", host_port = 6112 }))
        srv:output(id)
    end
    local c = socket.connect(sip, sport)
    for _ = 1, 30 do c:send(protocol.encode("LIST_GAMES", {})) end
    local t = socket.gettime()
    while srv:stats().messages_in < 230 and socket.gettime() - t < 3 do srv:tick(0.01) end
    for _ = 1, 20 do srv:tick(0) end
    local sid = next(srv.sockets)
    test("the socket was given more than it takes at once", sid ~= nil and srv.conns[sid].pending ~= nil)
    c:settimeout(0)
    local buf, lists, good = "", 0, true
    t = socket.gettime()
    while lists < 30 and socket.gettime() - t < 5 do
        srv:tick(0.01)
        local data, err, partial = c:receive(1048576)
        buf = buf .. (data or partial or "")
        while true do
            local ok, n, m, rest = pcall(protocol.read_frame, buf)
            if not ok then good = false break end
            if not n then break end
            lists = lists + 1
            if n ~= "GAME_LIST" or #m.games ~= 200 then good = false end
            buf = rest
        end
        if not good then break end
    end
    test("every byte arrives, in order, once the client reads", good and lists == 30, lists)
    c:close()
    srv:stop()
end
-- }}}

print(string.format("\nTests: %d passed, %d failed", pass_count, test_count - pass_count))
print(string.format("matchmaking daemon: %d of %d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
