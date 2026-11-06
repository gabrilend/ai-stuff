-- test_matchmaking_server.lua - the matchmaking server's rules, without a network (issue 801b)
--
-- In plain terms: plays hosts and joining players against the server's
-- core, bytes in and bytes out, on a clock the test moves by hand. Checks
-- that lobbies open, fill, chat, start and close as the issue says; that
-- what a player may not do is ignored and what is not a message closes
-- the connection; that the timeouts, the rate limit and the counts hold;
-- and that a closed lobby leaves nothing behind.
--
-- Run with: luajit src/tests/test_matchmaking_server.lua [DIR]
-- (DIR defaults to the project this file is in.)

-- The project: the argument, or the folder this test sits in (run-tests.sh
-- runs each test by its full path, from the project), or the owner's.
local DIR = arg[1] or arg[0]:match("^(.+)/src/tests/[^/]+%.lua$") or (arg[0]:match("^src/tests/") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

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

local function refused(f, want)
    local ok, err = pcall(f)
    return not ok and tostring(err):find(want, 1, true) ~= nil, tostring(err)
end

-- {{{ a server on a hand-moved clock
local now = 1000
local lines = {}
local function fresh(config)
    config = config or {}
    config.clock = function() return now end
    config.log = function(line) lines[#lines + 1] = line end
    lines = {}
    return server.new(config)
end
local function logged(want)
    for _, l in ipairs(lines) do if l:find(want, 1, true) then return true end end
    return false
end
-- }}}

-- {{{ talking to it
local function send(srv, id, name, message)
    return srv:receive(id, protocol.encode(name, message))
end

-- Every message waiting for connection `id`, as { name, message } pairs.
local function inbox(srv, id)
    local buf, out = srv:output(id), {}
    while #buf > 0 do
        local name, m, rest = protocol.read_frame(buf)
        out[#out + 1] = { name = name, m = m }
        buf = rest
    end
    return out
end

local function only(srv, id, name)
    local got = inbox(srv, id)
    if #got ~= 1 or got[1].name ~= name then
        local names = {}
        for i, g in ipairs(got) do names[i] = g.name end
        return nil, "got " .. #got .. ": " .. table.concat(names, ",")
    end
    return got[1].m
end

local game = { map_name = "Castle Defense v1.3", map_hash = "sha256:abc", asset_packs = { { id = "medieval", hash = "h1" } },
    max_players = 4, game_mode = "co-op", region = "us-west", host_port = 6112 }
local function with(t, extra)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end

-- A host connection with an open lobby: id, game id, player id.
local function host(srv, extra, ip)
    local id = srv:accept(ip or "10.0.0.1", 50000)
    send(srv, id, "REGISTER_GAME", with(game, extra))
    local ack = only(srv, id, "JOIN_ACK")
    return id, ack and ack.game_id, ack and ack.player_id
end

local function join(srv, gid, name, ip)
    local id = srv:accept(ip or "10.0.0.2", 50001)
    send(srv, id, "JOIN_GAME", { game_id = gid, player_name = name })
    local got = inbox(srv, id)
    return id, got[1] and got[1].m.player_id, got[1]
end
-- }}}
-- }}}

-- {{{ settings
print("settings")
test("an unknown setting is refused", refused(function() server.new({ max_lobies = 3 }) end, "max_lobies is not a setting"))
test("a setting of the wrong kind is refused", refused(function() server.new({ max_lobbies = "3" }) end, "max_lobbies should be a number"))
test("it listens on loopback unless told", server.DEFAULTS.bind == "127.0.0.1:8080")
test("a lobby times out after an hour by default", server.DEFAULTS.lobby_timeout_seconds == 3600)
-- }}}

-- {{{ the codec (question Q-1)
print("the codec")
do
    local used = { encode = 0, read_frame = 0 }
    local codec = {
        encode = function(n, m) used.encode = used.encode + 1 return protocol.encode(n, m) end,
        read_frame = function(b) used.read_frame = used.read_frame + 1 return protocol.read_frame(b) end,
    }
    local srv = server.new({ codec = codec, clock = function() return now end })
    local c = srv:accept("10.0.0.1", 1)
    srv:receive(c, protocol.encode("PING", { nonce = 5 }))
    local _, m = protocol.decode(srv:output(c))
    test("messages go through the codec it is given", used.read_frame >= 1 and used.encode == 1 and m.nonce == 5)
    test("protocol.lua is the codec by default", server.new({ clock = function() return now end }).codec == protocol)
end
-- }}}

-- {{{ registering
print("registering")
do
    local srv = fresh()
    local h = srv:accept("10.0.0.1", 50000)
    test("a connection is numbered", h == 1)
    send(srv, h, "REGISTER_GAME", with(game, { host_name = "Ritz" }))
    local ack = only(srv, h, "JOIN_ACK")
    test("registering is answered with a JOIN_ACK for the new game", ack and ack.game_id == 1 and ack.player_id == 1)
    test("the host is the lobby's first player, by the name it gave", ack and #ack.players == 1 and ack.players[1].name == "Ritz"
        and ack.players[1].ready == false)
    local l = srv:lobby_list()[1]
    test("the lobby waits, holding the map and the host's address", l and l.state == "waiting" and l.map_name == game.map_name
        and l.host_ip == "10.0.0.1" and l.host_port == 6112 and l.max_players == 4)
    test("its opening is logged", logged("lobby 1 opened by connection 1 (10.0.0.1:50000): Castle Defense v1.3, 4 players, co-op, us-west"))
    send(srv, h, "REGISTER_GAME", game)
    local rej = only(srv, h, "JOIN_REJECT")
    test("a second register from the same connection is refused", rej and rej.game_id == 0 and rej.reason == "already in lobby 1")
    test("a host with no name is called host", (function()
        local _, gid = host(srv)
        for _, x in ipairs(srv:lobby_list()) do if x.game_id == gid then return x.players[1].name == "host" end end
    end)())
    for _, bad in ipairs({ { 0, "a lobby holds 1 to 12 players" }, { 13, "a lobby holds 1 to 12 players" } }) do
        local id = srv:accept("10.0.0.9", 1)
        send(srv, id, "REGISTER_GAME", with(game, { max_players = bad[1] }))
        local r = only(srv, id, "JOIN_REJECT")
        test("a lobby of " .. bad[1] .. " players is refused", r and r.reason == bad[2])
    end
    local id = srv:accept("10.0.0.9", 1)
    send(srv, id, "REGISTER_GAME", with(game, { host_name = string.rep("n", 65) }))
    local r = only(srv, id, "JOIN_REJECT")
    test("a host name over 64 bytes is refused", r and r.reason == "a name is 1 to 64 bytes")
    send(srv, id, "REGISTER_GAME", with(game, { host_name = "" }))
    r = only(srv, id, "JOIN_REJECT")
    test("an empty host name is refused", r and r.reason == "a name is 1 to 64 bytes")

    local small = fresh({ max_lobbies = 2 })
    host(small) host(small)
    local third = small:accept("10.0.0.3", 1)
    send(small, third, "REGISTER_GAME", game)
    r = only(small, third, "JOIN_REJECT")
    test("past max_lobbies a register is refused", r and r.game_id == 0 and r.reason == "the server holds its most lobbies")
end
-- }}}

-- {{{ listing
print("listing")
do
    local srv = fresh()
    local _, g1 = host(srv, { map_name = "Castle Defense", region = "eu", game_mode = "co-op", max_players = 2 })
    local _, g2 = host(srv, { map_name = "DotA Allstars", region = "us-west", game_mode = "melee", max_players = 10 })
    local h3, g3 = host(srv, { map_name = "castle wars", region = "us-west", game_mode = "co-op" })
    local c = srv:accept("10.0.0.5", 1)
    local function list(filter)
        send(srv, c, "LIST_GAMES", filter)
        local m = only(srv, c, "GAME_LIST")
        local ids = {}
        for i, g in ipairs(m and m.games or {}) do ids[i] = g.game_id end
        return table.concat(ids, ","), m
    end
    local all, m = list({})
    test("every waiting game, by id", all == g1 .. "," .. g2 .. "," .. g3)
    local g = m.games[1]
    test("a game is listed with its map, packs and counts", g.map_name == "Castle Defense" and g.map_hash == "sha256:abc"
        and g.asset_packs[1].id == "medieval" and g.players == 1 and g.max_players == 2 and g.region == "eu")
    test("by map name, any case, any part", list({ map_name = "CASTLE" }) == g1 .. "," .. g3)
    test("by game mode", list({ game_mode = "melee" }) == tostring(g2))
    test("by region", list({ region = "us-west" }) == g2 .. "," .. g3)
    test("by region and mode", list({ region = "us-west", game_mode = "co-op" }) == tostring(g3))
    join(srv, g1, "p")
    test("by free slots: a full game is left out", list({ free_slots = 1 }) == g2 .. "," .. g3)
    test("by free slots: at least that many", list({ free_slots = 9 }) == tostring(g2))
    test("the latency filter is the client's, ignored here", list({ max_latency_ms = 1 }) == all)
    send(srv, h3, "START_GAME", { game_id = g3 })
    inbox(srv, h3)
    test("a started game is not listed", list({}) == g1 .. "," .. g2)
    test("nothing matching is an empty list", list({ map_name = "nope" }) == "")
end
-- }}}

-- {{{ joining and leaving
print("joining and leaving")
do
    local srv = fresh()
    local h, gid, hp = host(srv, { max_players = 3, host_name = "H" })
    local a, ap, got = join(srv, gid, "Ann")
    test("a join is answered with JOIN_ACK and who is there", got and got.name == "JOIN_ACK" and got.m.game_id == gid
        and #got.m.players == 2 and got.m.players[1].player_id == hp and got.m.players[2].name == "Ann")
    test("the joiner gets nothing else", #inbox(srv, a) == 0)
    local up = only(srv, h, "LOBBY_UPDATE")
    test("the host is told of the join", up and up.event == "join" and up.player_id == ap and #up.players == 2)
    local b, bp = join(srv, gid, "Bo")
    test("the others hear of a second join", (only(srv, h, "LOBBY_UPDATE") or {}).player_id == bp
        and (only(srv, a, "LOBBY_UPDATE") or {}).player_id == bp)
    local _, _, full = join(srv, gid, "Cy")
    test("a full lobby refuses", full and full.name == "JOIN_REJECT" and full.m.reason == "the lobby is full" and full.m.game_id == gid)
    local _, _, none = join(srv, 99, "Cy")
    test("an unknown game refuses", none and none.name == "JOIN_REJECT" and none.m.reason == "no such game")
    send(srv, a, "JOIN_GAME", { game_id = gid, player_name = "Ann" })
    test("a player already in a lobby is refused", (only(srv, a, "JOIN_REJECT") or {}).reason == "already in lobby " .. gid)
    send(srv, b, "LEAVE_GAME", { game_id = gid })
    local la, lh = only(srv, a, "LOBBY_UPDATE"), only(srv, h, "LOBBY_UPDATE")
    test("a leave is told to those left", la and la.event == "leave" and la.player_id == bp and #la.players == 2 and lh and lh.player_id == bp)
    test("the leaver hears nothing", #inbox(srv, b) == 0)
    test("the leaver may join again", (select(3, (function()
        send(srv, b, "JOIN_GAME", { game_id = gid, player_name = "Bo" })
        return nil, nil, only(srv, b, "JOIN_ACK") end)())) ~= nil)
    inbox(srv, a) inbox(srv, h)
    local _, g9 = host(srv)
    local _, _, noname = join(srv, g9, "")
    test("an empty player name is refused", noname and noname.m.reason == "a name is 1 to 64 bytes")
    send(srv, a, "LEAVE_GAME", { game_id = gid + 1 })
    test("leaving a lobby it is not in is ignored", #inbox(srv, h) == 0 and logged("LEAVE_GAME of a lobby it is not in"))

    send(srv, h, "LEAVE_GAME", { game_id = gid })
    test("the host leaving closes the lobby, telling every member", (only(srv, a, "UNREGISTER_GAME") or {}).game_id == gid
        and (only(srv, b, "UNREGISTER_GAME") or {}).game_id == gid)
    test("the closed lobby is gone", srv.lobbies[gid] == nil and logged("lobby " .. gid .. " closed: its host left"))
    local h2, g2 = host(srv)
    send(srv, a, "JOIN_GAME", { game_id = g2, player_name = "Ann" })
    test("its players are free to join another", only(srv, a, "JOIN_ACK") ~= nil)
end
-- }}}

-- {{{ ready, chat, NAT endpoints
print("ready, chat and NAT endpoints")
do
    local srv = fresh()
    local h, gid, hp = host(srv)
    local a, ap = join(srv, gid, "Ann", "10.0.0.2")
    local b, bp = join(srv, gid, "Bo", "10.0.0.3")
    inbox(srv, h) inbox(srv, a)
    send(srv, a, "LOBBY_UPDATE", { game_id = gid, event = "ready", player_id = bp, players = {} })
    local r = only(srv, b, "LOBBY_UPDATE")
    test("ready is told to every member", r and r.event == "ready" and only(srv, h, "LOBBY_UPDATE") ~= nil)
    test("the ready player is the sender, whatever the message says", r and r.player_id == ap)
    test("the sender hears it too, its mark set", (function()
        local m = only(srv, a, "LOBBY_UPDATE")
        return m and m.players[2].player_id == ap and m.players[2].ready == true and m.players[3].ready == false
    end)())
    send(srv, a, "LOBBY_UPDATE", { game_id = gid, event = "unready", player_id = ap, players = {} })
    test("unready unmarks", (only(srv, h, "LOBBY_UPDATE") or { players = {} }).players[2].ready == false)
    inbox(srv, a) inbox(srv, b)
    send(srv, a, "LOBBY_UPDATE", { game_id = gid, event = "join", player_id = ap, players = {} })
    test("a player may not send join or leave events", #inbox(srv, h) == 0 and logged("LOBBY_UPDATE join from a player"))

    send(srv, b, "CHAT_MSG", { game_id = gid, player_id = hp, text = "hello" })
    local c1, c2, c3 = only(srv, h, "CHAT_MSG"), only(srv, a, "CHAT_MSG"), only(srv, b, "CHAT_MSG")
    test("chat reaches every member, the sender too", c1 and c2 and c3 and c1.text == "hello" and c3.text == "hello")
    test("chat carries the sender's player id, not the claimed one", c1 and c1.player_id == bp)
    send(srv, b, "CHAT_MSG", { game_id = gid, player_id = bp, text = "" })
    test("empty chat is ignored", #inbox(srv, h) == 0)
    send(srv, b, "CHAT_MSG", { game_id = gid + 7, player_id = bp, text = "x" })
    test("chat to another lobby is ignored", #inbox(srv, h) == 0 and logged("CHAT_MSG to a lobby it is not in"))
    local stranger = srv:accept("10.9.9.9", 1)
    send(srv, stranger, "CHAT_MSG", { game_id = gid, player_id = 0, text = "spam" })
    test("chat from outside the lobby is ignored", #inbox(srv, h) == 0 and #inbox(srv, stranger) == 0)

    send(srv, a, "NAT_PUNCH", { game_id = gid, player_id = 0, ip = "", port = 7000 })
    local p = only(srv, h, "NAT_PUNCH")
    test("a player's endpoint goes to the host, stamped with its id and seen address",
        p and p.player_id == ap and p.ip == "10.0.0.2" and p.port == 7000 and #inbox(srv, b) == 0)
    send(srv, a, "NAT_PUNCH", { game_id = gid, player_id = 0, ip = "203.0.113.5", port = 7001 })
    test("an ip the player gives is kept", (only(srv, h, "NAT_PUNCH") or {}).ip == "203.0.113.5")
    send(srv, h, "NAT_PUNCH", { game_id = gid, player_id = bp, ip = "", port = 6112 })
    p = only(srv, b, "NAT_PUNCH")
    test("the host's endpoint goes to the player it names, and no one else",
        p and p.player_id == hp and p.ip == "10.0.0.1" and p.port == 6112 and #inbox(srv, a) == 0)
    send(srv, h, "NAT_PUNCH", { game_id = gid, player_id = 999, ip = "", port = 1 })
    test("the host's endpoint to no such player is ignored", #inbox(srv, a) == 0 and #inbox(srv, b) == 0
        and logged("NAT_PUNCH to player 999"))
end
-- }}}

-- {{{ starting, updating, unregistering
print("starting, updating and unregistering")
do
    local srv = fresh()
    local h, gid = host(srv, { host_port = 6200 }, "192.168.1.4")
    local a = join(srv, gid, "Ann")
    inbox(srv, h)
    send(srv, a, "START_GAME", { game_id = gid })
    test("a player may not start the game", #inbox(srv, h) == 0 and #inbox(srv, a) == 0 and srv:lobby_list()[1].state == "waiting")
    send(srv, a, "UPDATE_GAME", { game_id = gid, players = 2, max_players = 8 })
    test("a player may not update the game", srv:lobby_list()[1].max_players == 4)
    send(srv, h, "UPDATE_GAME", { game_id = gid, players = 2, max_players = 1 })
    test("the host may not shrink the lobby below its players", srv:lobby_list()[1].max_players == 4)
    send(srv, h, "UPDATE_GAME", { game_id = gid, players = 2, max_players = 13 })
    test("nor past the most a lobby holds", srv:lobby_list()[1].max_players == 4)
    send(srv, h, "UPDATE_GAME", { game_id = gid, players = 2, max_players = 6 })
    test("the host may change the most players", srv:lobby_list()[1].max_players == 6)
    send(srv, h, "START_GAME", { game_id = gid })
    local s1, s2 = only(srv, h, "GAME_START"), only(srv, a, "GAME_START")
    test("starting tells every member where the host is", s1 and s2 and s2.game_id == gid and s2.host_ip == "192.168.1.4" and s2.host_port == 6200)
    test("the lobby is then in progress", srv:lobby_list()[1].state == "in_progress" and logged("lobby " .. gid .. " started with 2 players"))
    local _, _, late = join(srv, gid, "Late")
    test("a started game refuses joins", late and late.m.reason == "the game has started")
    send(srv, h, "START_GAME", { game_id = gid })
    test("starting twice is ignored", #inbox(srv, a) == 0 and logged("START_GAME twice"))
    send(srv, a, "LOBBY_UPDATE", { game_id = gid, event = "ready", player_id = 0, players = {} })
    test("ready marks after the start are ignored", #inbox(srv, h) == 0)
    send(srv, h, "UPDATE_GAME", { game_id = gid, players = 2, max_players = 5 })
    test("updates after the start are ignored", srv:lobby_list()[1].max_players == 6)
    send(srv, a, "UNREGISTER_GAME", { game_id = gid })
    test("a player may not unregister the game", #srv:lobby_list() == 1)
    send(srv, h, "UNREGISTER_GAME", { game_id = gid })
    test("the host unregistering tells every member, itself too", (only(srv, a, "UNREGISTER_GAME") or {}).game_id == gid
        and (only(srv, h, "UNREGISTER_GAME") or {}).game_id == gid and #srv:lobby_list() == 0)
end
-- }}}

-- {{{ keepalive and the server's own messages
print("keepalive")
do
    local srv = fresh()
    local c = srv:accept("10.0.0.1", 1)
    send(srv, c, "PING", { nonce = 4242 })
    test("a ping is answered with its nonce", (only(srv, c, "PONG") or {}).nonce == 4242)
    for _, name in ipairs({ "GAME_LIST", "JOIN_ACK", "JOIN_REJECT", "GAME_START", "PONG" }) do
        local examples = {
            GAME_LIST = { games = {} }, JOIN_ACK = { game_id = 1, player_id = 1, players = {} },
            JOIN_REJECT = { game_id = 1, reason = "x" }, GAME_START = { game_id = 1, host_ip = "x", host_port = 1 },
            PONG = { nonce = 1 },
        }
        send(srv, c, name, examples[name])
        test(name .. " from a client is ignored, the connection kept", #inbox(srv, c) == 0 and srv.conns[c] ~= nil
            and logged(name .. " is the server's to send"))
    end
    test("ignored messages are counted", srv:stats().ignored == 5)
end
-- }}}

-- {{{ bytes that are not messages
print("bytes that are not messages")
do
    local srv = fresh()
    local h, gid = host(srv)
    local a = join(srv, gid, "Ann")
    inbox(srv, h)
    local ping = protocol.encode("PING", { nonce = 9 })
    srv:receive(a, ping:sub(1, 5))
    test("half a message waits", #inbox(srv, a) == 0)
    srv:receive(a, ping:sub(6) .. ping:sub(1, 3))
    test("the rest completes it", (only(srv, a, "PONG") or {}).nonce == 9)
    srv:receive(a, ping:sub(4) .. ping)
    test("two at once are both answered", #inbox(srv, a) == 2)
    local kept = srv:receive(h, "XX\0\15\0\0\0\0")
    test("a wrong magic closes the connection", kept == false and srv.conns[h] == nil and logged("dropped, matchmaking: the magic is"))
    test("and the host's lobby with it, telling its players", (only(srv, a, "UNREGISTER_GAME") or {}).game_id == gid)
    test("drops are counted", srv:stats().dropped == 1)
    local c = srv:accept("10.0.0.7", 1)
    srv:receive(c, "WC\0\15\0\0\0\1\193")
    test("a payload that is not MessagePack closes the connection", srv.conns[c] == nil)
    c = srv:accept("10.0.0.7", 1)
    srv:receive(c, "WC\0\15\0\32\0\0")
    test("a header claiming too much closes it before the payload comes", srv.conns[c] == nil)
    test("bytes for a closed connection are refused", srv:receive(c, ping) == false and srv:output(c) == "")
end
-- }}}

-- {{{ the rate limit and the output limit
print("limits")
do
    local srv = fresh()
    local c = srv:accept("10.0.0.1", 1)
    local burst = string.rep(protocol.encode("PING", { nonce = 1 }), 100)
    srv:receive(c, burst)
    test("a burst of 100 is allowed", srv.conns[c] ~= nil and #inbox(srv, c) == 100)
    srv:receive(c, protocol.encode("PING", { nonce = 1 }))
    test("the 101st at once closes the connection", srv.conns[c] == nil and logged("more than 50 messages a second"))
    local d = srv:accept("10.0.0.1", 2)
    local fine = true
    for _ = 1, 300 do
        now = now + 0.02
        if not send(srv, d, "PING", { nonce = 2 }) then fine = false end
    end
    test("50 a second for six seconds is allowed", fine and #inbox(srv, d) == 300)

    local tiny = fresh({ max_output_bytes = 200 })
    local h, gid = host(tiny)
    local a = join(tiny, gid, "Ann")
    inbox(tiny, h)
    local heard = {}
    for i = 1, 6 do
        send(tiny, a, "CHAT_MSG", { game_id = gid, player_id = 0, text = "line " .. i .. string.rep(".", 20) })
        for _, g in ipairs(inbox(tiny, a)) do heard[#heard + 1] = g.name end
    end
    test("a member not reading its output is closed", tiny.conns[h] == nil and logged("its output is not being read"))
    test("the reader is not, and is told the lobby closed", tiny.conns[a] ~= nil and heard[1] == "CHAT_MSG" and heard[#heard] == "UNREGISTER_GAME", table.concat(heard, ","))

    local few = fresh({ max_connections = 2 })
    few:accept("1.1.1.1", 1)
    few:accept("1.1.1.1", 2)
    test("past max_connections a connection is refused", few:accept("1.1.1.1", 3) == nil and few:stats().refused_connections == 1)
end
-- }}}

-- {{{ the timeouts
print("timeouts")
do
    local srv = fresh({ idle_timeout_seconds = 120, lobby_timeout_seconds = 3600 })
    local h, gid = host(srv)
    local a = join(srv, gid, "Ann")
    local quiet = srv:accept("10.0.0.8", 1)
    inbox(srv, h)
    now = now + 119
    send(srv, h, "PING", { nonce = 1 }) send(srv, a, "PING", { nonce = 1 })
    srv:sweep()
    test("a connection is kept just short of the idle timeout", srv.conns[quiet] ~= nil)
    now = now + 1
    srv:sweep()
    test("a connection silent 120 seconds is closed", srv.conns[quiet] == nil and srv.conns[h] ~= nil and logged("silent for 120 seconds"))
    -- pings keep connections, not lobbies
    for _ = 1, 30 do
        now = now + 115
        send(srv, h, "PING", { nonce = 1 }) send(srv, a, "PING", { nonce = 1 })
        srv:sweep()
    end
    inbox(srv, h) inbox(srv, a)
    test("a lobby is kept while short of its timeout", #srv:lobby_list() == 1)
    send(srv, a, "CHAT_MSG", { game_id = gid, player_id = 0, text = "still here" })
    inbox(srv, h) inbox(srv, a)
    for _ = 1, 31 do
        now = now + 115
        send(srv, h, "PING", { nonce = 1 }) send(srv, a, "PING", { nonce = 1 })
        srv:sweep()
    end
    test("chat put its timeout back", #srv:lobby_list() == 1)
    now = now + 35
    srv:sweep()
    local got = inbox(srv, a)
    test("a lobby quiet an hour is closed, its members told", #srv:lobby_list() == 0 and got[#got].name == "UNREGISTER_GAME"
        and logged("closed: quiet for 3600 seconds"))
    test("its connections stay open", srv.conns[h] ~= nil and srv.conns[a] ~= nil)
end
-- }}}

-- {{{ statistics
print("statistics")
do
    now = 5000.5
    local srv = fresh()
    local h, gid = host(srv)
    local a = join(srv, gid, "Ann")
    srv:accept("10.0.0.9", 1)
    local s = srv:stats()
    test("lobbies, players and connections are counted", s.lobbies_active == 1 and s.players_in_lobbies == 2 and s.players_online == 3
        and s.connections == 3 and s.lobbies_created == 1)
    test("messages in and out are counted", s.messages_in == 2 and s.messages_out == 3, s.messages_in .. " " .. s.messages_out)
    test("the rate is the last whole second's: none yet", s.messages_per_second == 0)
    now = 5001.1
    for _ = 1, 7 do send(srv, a, "PING", { nonce = 1 }) end
    test("messages this second are not yet the rate; the second before's 2 are", srv:stats().messages_per_second == 2)
    now = 5002.0
    test("the last whole second's messages are the rate", srv:stats().messages_per_second == 7)
    now = 5003.2
    test("a second with none is a rate of 0", srv:stats().messages_per_second == 0)
    test("uptime counts from the start", math.abs(srv:stats().uptime_seconds - 2.7) < 1e-9)
    local before = srv:stats().bytes_out
    local bytes = srv:output(a)
    test("bytes handed out are counted", srv:stats().bytes_out == before + #bytes and #bytes > 0)
    srv:close(h)
    s = srv:stats()
    test("a closed lobby is counted", s.lobbies_active == 0 and s.lobbies_closed == 1 and s.players_in_lobbies == 0 and s.players_online == 2)
end
-- }}}

-- {{{ nothing left behind
print("nothing left behind")
do
    local srv = fresh()
    local watch = setmetatable({}, { __mode = "k" })
    local conns = {}
    for round = 1, 20 do
        local h, gid = host(srv)
        watch[srv.lobbies[gid]] = true
        local players = {}
        for p = 1, 3 do players[p] = join(srv, gid, "p" .. p) end
        send(srv, players[1], "CHAT_MSG", { game_id = gid, player_id = 0, text = "hi" })
        if round % 3 == 0 then send(srv, h, "START_GAME", { game_id = gid }) end
        if round % 2 == 0 then srv:close(h) else send(srv, h, "UNREGISTER_GAME", { game_id = gid }) end
        for _, p in ipairs(players) do inbox(srv, p) srv:close(p) end
        if srv.conns[h] then inbox(srv, h) srv:close(h) end
        conns[#conns + 1] = h
    end
    collectgarbage() collectgarbage()
    local left = 0
    for _ in pairs(watch) do left = left + 1 end
    test("twenty closed lobbies are collected", left == 0, left .. " left")
    test("no lobby or connection is held", next(srv.lobbies) == nil and next(srv.conns) == nil)
    test("every close is counted", srv:stats().lobbies_closed == 20 and srv:stats().lobbies_created == 20)
end
-- }}}

print(string.format("\nTests: %d passed, %d failed", pass_count, test_count - pass_count))
print(string.format("matchmaking server: %d of %d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
