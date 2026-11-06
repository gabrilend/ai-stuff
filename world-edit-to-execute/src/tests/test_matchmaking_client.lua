-- test_matchmaking_client.lua - the matchmaking client library against the server's core (issue 801c)
--
-- In plain terms: a host and players, each a client library, talk to the
-- matchmaking server's core through bytes passed by hand, on a clock the
-- test moves. Checks that a game listed, a lobby opened and joined, chat,
-- ready marks, the start and the endpoints for NAT reach the game as the
-- events the issue names; that refusals come back as reasons; that the
-- keepalive pings and measures; and that a connection gone wrong closes
-- the lobby and says why.
--
-- Run with: luajit src/tests/test_matchmaking_client.lua [DIR]
-- (DIR defaults to the project this file is in.)

-- The project: the argument, or the folder this test sits in (run-tests.sh
-- runs each test by its full path, from the project), or the owner's.
local DIR = arg[1] or arg[0]:match("^(.+)/src/tests/[^/]+%.lua$") or (arg[0]:match("^src/tests/") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local protocol = require("matchmaking.protocol")
local server = require("matchmaking.server")
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

local function refused(f, want)
    local ok, err = pcall(f)
    return not ok and tostring(err):find(want, 1, true) ~= nil, tostring(err)
end

-- {{{ clients wired to a server's core by hand
local now = 1000
local function clock() return now end
local srv, wires, lines

-- Moves every byte both ways until nothing moves; a connection the
-- server closed is lost to its client.
local function pump()
    local moved = true
    while moved do
        moved = false
        for _, w in ipairs(wires) do
            if w.c.state == "connected" then
                if not srv.conns[w.id] then w.c:lost("the server closed the connection") moved = true
                else
                    local up = w.c:output()
                    if #up > 0 then srv:receive(w.id, up) moved = true end
                    local down = srv:output(w.id)
                    if #down > 0 then w.c:feed(down) moved = true end
                end
            end
        end
    end
end

local function fresh(config)
    lines = {}
    config = config or {}
    config.clock = clock
    config.log = function(l) lines[#lines + 1] = "server: " .. l end
    srv = server.new(config)
    wires = {}
end

local function wire(name, ip)
    local c = client.new({ name = name, clock = clock, pump = pump, log = function(l) lines[#lines + 1] = name .. ": " .. l end })
    local id = srv:accept(ip or ("10.0.0." .. (#wires + 1)), 40000 + #wires)
    wires[#wires + 1] = { c = c, id = id }
    return c, id
end

local function logged(want)
    for _, l in ipairs(lines) do if l:find(want, 1, true) then return true end end
    return false
end

local function recorder(lobby, events)
    local got = {}
    for _, e in ipairs(events) do
        lobby:on(e, function(...) got[#got + 1] = { e, ... } end)
    end
    return got
end
-- }}}

local game = { map_name = "Castle Defense v1.3", map_hash = "sha256:abc", asset_packs = { { id = "medieval", hash = "h" } },
    max_players = 3, game_mode = "co-op", region = "us-west" }
-- }}}

-- {{{ options
print("options")
test("an unknown option is refused", refused(function() client.new({ hots = "x" }) end, "hots is not an option"))
test("an option of the wrong kind is refused", refused(function() client.new({ port = "80" }) end, "port should be a number"))
test("waiting needs a pump or a socket", refused(function() client.new():list_games() end, "nothing to wait with"))
test("polling needs a socket", refused(function() client.new():poll() end, "poll without a socket"))
-- }}}

-- {{{ the codec (question Q-1)
print("the codec")
do
    local used = 0
    local codec = { encode = function(n, m) used = used + 1 return protocol.encode(n, m) end, read_frame = protocol.read_frame }
    local c = client.new({ codec = codec, clock = clock })
    c:ping()
    test("messages go through the codec it is given", used == 1 and protocol.decode(c:output()) == "PING")
    test("protocol.lua is the codec by default", client.new({ clock = clock }).codec == protocol)
end
-- }}}

-- {{{ hosting and listing
print("hosting and listing")
fresh()
local hc = wire("Host")
local lobby = hc:create_lobby(game)
test("create_lobby waits and gives the lobby", lobby and lobby.state == "waiting" and lobby.game_id == 1 and lobby.is_host)
test("the host is its first player, by the connection's name", lobby and #lobby.players == 1 and lobby.players[1].name == "Host"
    and lobby.player_id == lobby.players[1].player_id)
test("it registered port 6112 when none was given", srv:lobby_list()[1].host_port == 6112)
test("a second lobby on one connection is refused here", refused(function() hc:create_lobby(game) end, "already in lobby 1"))
local other = wire("Other")
local refusal_lobby, reason = other:create_lobby({ map_name = "m", map_hash = "h", max_players = 99, game_mode = "x", region = "eu",
    host_name = "Named" })
test("a refused lobby gives nil and the server's reason", refusal_lobby == nil and reason == "a lobby holds 1 to 12 players", reason)
test("after a refusal the connection holds no lobby", other.lobby == nil)
local named = other:create_lobby({ map_name = "Echo Isles", map_hash = "h2", max_players = 2, game_mode = "melee",
    region = "eu", host_name = "Named", host_port = 7000 })
test("a host's lobby is closed with UNREGISTER_GAME, not as a player leaving", (function()
    local probe = wire("Probe")
    local pl = probe:create_lobby(game)
    pl:leave()
    pump()
    return logged("closed: unregistered by its host")
end)())
test("a host may name itself and its port", named and named.players[1].name == "Named" and srv:lobby_list()[2].host_port == 7000)

local pc = wire("Ann", "10.0.0.3")
local games = pc:list_games({ region = "us-west" })
test("list_games waits and gives the games", games and #games == 1 and games[1].map_name == game.map_name)
test("each game carries id as well as game_id", games and games[1].id == 1 and games[1].game_id == 1)
local all = pc:list_games()
test("no filter is every game", all and #all == 2)
local called
test("with a callback list_games returns at once", pc:list_games({ game_mode = "melee" }, function(g) called = g end) == nil and called == nil)
pump()
test("and calls it with the answer", called and #called == 1 and called[1].map_name == "Echo Isles")
local order = {}
pc:list_games({ region = "eu" }, function(g) order[#order + 1] = "eu" .. #g end)
pc:list_games({ region = "us-west" }, function(g) order[#order + 1] = "us" .. #g end)
pump()
test("answers go to their callbacks in order", order[1] == "eu1" and order[2] == "us1")
-- }}}

-- {{{ joining and the lobby's events
print("joining and the lobby's events")
local hev = recorder(lobby, { "player_join", "player_leave", "player_ready", "chat", "game_start", "nat_punch", "closed" })
local plobby = pc:join_game(games[1])
test("join_game takes a listed game and waits", plobby and plobby.state == "waiting" and not plobby.is_host
    and plobby.game_id == 1 and #plobby.players == 2)
test("the host hears player_join with the player", hev[1] and hev[1][1] == "player_join" and hev[1][2].name == "Ann"
    and hev[1][2].player_id == plobby.player_id)
test("the host's lobby knows its players", #lobby:get_players() == 2)
local pev = recorder(plobby, { "player_join", "player_leave", "player_ready", "chat", "game_start", "nat_punch", "closed" })
local bc = wire("Bo")
local blobby = bc:join_game(1, "Bobby")
test("join_game takes an id and a name", blobby and blobby.players[3].name == "Bobby")
test("the players already there hear of the join", pev[1] and pev[1][1] == "player_join" and pev[1][2].name == "Bobby")
local cc = wire("Cy")
local full, why = cc:join_game(1)
test("a refused join gives nil and why", full == nil and why == "the lobby is full")
local nolobby, why2 = cc:join_game(42)
test("an unknown game is refused", nolobby == nil and why2 == "no such game")
test("a second join on one connection is refused here", refused(function() pc:join_game(2) end, "already in lobby 1"))

plobby:set_ready(true)
pump()
local last = hev[#hev]
test("set_ready reaches the host as player_ready", last[1] == "player_ready" and last[2].name == "Ann" and last[3] == true)
test("and the player itself", pev[#pev][1] == "player_ready" and pev[#pev][3] == true)
plobby:set_ready(false)
pump()
test("unready is player_ready false", hev[#hev][1] == "player_ready" and hev[#hev][3] == false)

blobby:send_chat("gl hf")
pump()
test("chat reaches the others with who said it", hev[#hev][1] == "chat" and hev[#hev][2].name == "Bobby" and hev[#hev][3] == "gl hf"
    and pev[#pev][1] == "chat" and pev[#pev][3] == "gl hf")

plobby:punch(nil, 7100)
pump()
test("a player's endpoint reaches the host as nat_punch", hev[#hev][1] == "nat_punch" and hev[#hev][2].player_id == plobby.player_id
    and hev[#hev][2].ip == "10.0.0.3" and hev[#hev][2].port == 7100)
lobby:punch("", 6112, plobby.player_id)
pump()
test("the host's endpoint reaches the player it names", pev[#pev][1] == "nat_punch" and pev[#pev][2].player_id == lobby.player_id
    and pev[#pev][2].ip == "10.0.0.1")

local before = #hev
local stray = 0
local stray_fn = lobby:on("chat", function() stray = stray + 1 end)
hc:feed(protocol.encode("CHAT_MSG", { game_id = 2, player_id = 1, text = "elsewhere" }))
hc:feed(protocol.encode("LOBBY_UPDATE", { game_id = 2, event = "join", player_id = 9, players = {} }))
hc:feed(protocol.encode("UNREGISTER_GAME", { game_id = 2 }))
test("messages of another lobby are ignored", #hev == before and stray == 0 and lobby.state == "waiting"
    and logged("chat of another lobby") and logged("an UNREGISTER_GAME of another lobby"))
test("off takes a handler away", lobby:off("chat", stray_fn) and not lobby:off("chat", stray_fn))
blobby:send_chat("once more")
pump()
test("and it hears no more", stray == 0 and hev[#hev][3] == "once more")
test("only the host starts", refused(function() plobby:start_game() end, "only the host starts the game"))
test("only the host changes the lobby", refused(function() plobby:set_max_players(4) end, "only the host changes the lobby"))
blobby:leave()
pump()
test("a player leaving closes its lobby here, saying it left", blobby.state == "closed" and bc.lobby == nil)
test("the host hears player_leave with who it was", hev[#hev][1] == "player_leave" and hev[#hev][2].name == "Bobby")
test("a closed lobby refuses chat", refused(function() blobby:send_chat("x") end, "chat in a lobby that is closed"))
lobby:set_max_players(2)
pump()
test("the host may change the most players", srv:lobby_list()[1].max_players == 2)

lobby:start_game()
pump()
test("starting fires game_start for the host and the players, with the host's address",
    hev[#hev][1] == "game_start" and hev[#hev][2].ip == "10.0.0.1" and hev[#hev][2].port == 6112
    and pev[#pev][1] == "game_start" and plobby:get_host_connection().port == 6112 and plobby.state == "in_progress")
lobby:leave()
pump()
test("the host leaving closes its lobby here", lobby.state == "closed" and hc.lobby == nil)
test("and the players hear closed", pev[#pev][1] == "closed" and pev[#pev][2] == "the lobby closed" and pc.lobby == nil)
local again = pc:join_game(2)
test("a player whose lobby closed may join another", again and again.game_id == 2)
-- }}}

-- {{{ answers by callback
print("answers by callback")
fresh()
local h2 = wire("H")
local got_lobby
local l2 = h2:create_lobby(game, function(l, err) got_lobby = l or err end)
test("with a callback create_lobby returns the lobby, opening", l2 and l2.state == "opening" and got_lobby == nil)
test("an opening lobby refuses chat", refused(function() l2:send_chat("x") end, "in a lobby that is opening"))
pump()
test("the callback gets the lobby once open", got_lobby == l2 and l2.state == "waiting")
local p2 = wire("P")
local got_reason
p2:join_game(9, function(l, err) got_reason = err end)
pump()
test("a join's callback gets nil and why", got_reason == "no such game")
-- }}}

-- {{{ keepalive
print("keepalive")
fresh()
local k = wire("K")
k:tick()
test("no ping before the interval", k:output() == "")
local pongs = {}
k:on("pong", function(ms) pongs[#pongs + 1] = ms end)
now = now + 30
k:tick()
local ping = k:output()
local name, m = protocol.decode(ping)
test("a ping after 30 seconds", name == "PING" and m.nonce == 1)
srv:receive(wires[1].id, ping)
now = now + 0.042
k:feed(srv:output(wires[1].id))
test("its pong measures the latency", math.abs((k.latency_ms or 0) - 42) < 1e-6 and #pongs == 1, k.latency_ms)
k:tick()
test("and the next waits another interval", k:output() == "")
k:feed(protocol.encode("PONG", { nonce = 77 }))
test("a pong not asked for is ignored", #pongs == 1 and logged("a PONG not asked for"))
k:feed(protocol.encode("GAME_LIST", { games = {} }))
test("a list not asked for is ignored", logged("a GAME_LIST not asked for"))
k:feed(protocol.encode("LIST_GAMES", {}))
test("a client's message from the server is ignored", logged("LIST_GAMES is not the server's to send") and k.state == "connected")
-- }}}

-- {{{ losing the connection
print("losing the connection")
fresh()
local h3 = wire("H")
local l3 = h3:create_lobby(game)
local pl = wire("P")
local pl3 = pl:join_game(l3.game_id)
local closed, drops = {}, {}
pl3:on("closed", function(w) closed[#closed + 1] = w end)
pl:on("disconnect", function(w) drops[#drops + 1] = w end)
local listed = "not yet"
pl:list_games({}, function(g, err) listed = err end)
pl:feed("this is not a message")
test("bytes that are not a message drop the connection", pl.state == "disconnected" and drops[1]
    and drops[1]:find("the server sent what is not a message", 1, true), drops[1])
test("its lobby closes, disconnected", closed[1] == "disconnected" and pl.lobby == nil and pl3.state == "closed")
test("an answer still waited for fails with why", listed and listed:find("not a message", 1, true))
test("sending while disconnected is refused", refused(function() pl:list_games({}, function() end) end, "not connected (disconnected)"))
test("a reconnect is planned a second on", pl.next_try == now + 1)

local hl = {}
l3:on("closed", function(w) hl[#hl + 1] = w end)
srv:close(wires[1].id)
pump()
test("the server closing the host's connection closes its lobby", h3.state == "disconnected" and hl[1] == "disconnected")
local d = wire("D")
d:disconnect()
test("disconnect ends the connection for good", d.state == "closed")
test("and sends nothing more", refused(function() d:list_games({}, function() end) end, "not connected (closed)"))

local mute = client.new({ clock = clock, timeout = 500, pump = function() now = now + 0.1 end })
local waited_from = now
local none, err = mute:list_games()
test("no answer within the timeout gives nil and why", none == nil and err == "no answer in 500 ms")
test("after waiting the timeout, no longer", now - waited_from >= 0.5 and now - waited_from < 0.65, now - waited_from)
local nl, nerr = mute:create_lobby(game)
test("an unanswered lobby gives nil and why", nl == nil and nerr == "no answer in 500 ms" and mute.lobby == nil)
-- }}}

print(string.format("\nTests: %d passed, %d failed", pass_count, test_count - pass_count))
print(string.format("matchmaking client: %d of %d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
