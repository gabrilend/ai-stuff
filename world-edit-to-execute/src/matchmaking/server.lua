--[[
server.lua - the matchmaking server's core (issue 801b)

What this is: the server hosts and joining players talk to before a game
starts (issue 801). It keeps the open lobbies in memory, answers the
messages of protocol.lua, passes chat, ready marks and NAT endpoints
between the members of a lobby, and closes lobbies whose host has gone
or that have been quiet too long. Game traffic never comes here: once a
game starts its players connect straight to the host.

Two layers:
  The core knows connections only by number and bytes: accept(ip, port)
  gives a connection, receive(id, bytes) hands it what arrived,
  output(id) takes what is to be sent, close(id) ends it, sweep() runs
  the timeouts. No sockets, so every rule is tested without a network.
  The socket layer (start, tick, stop) puts LuaSocket underneath: one
  listening socket, every connection non-blocking, one select() a tick.
  LuaSocket is only loaded by start(), so the core needs nothing installed.

Who may do what (decisions of 2026-11-05, in the issue):
  - A connection is in at most one lobby, as its host or as a player.
  - Registering opens a lobby and makes its sender the lobby's first
    player; the answer is a JOIN_ACK carrying the new game id, since the
    protocol has no register answer. A refused register is a JOIN_REJECT
    with game id 0.
  - Joining answers the joiner with JOIN_ACK and tells the others with
    LOBBY_UPDATE "join". Leaving tells the others with "leave".
  - A player marks itself ready by sending LOBBY_UPDATE "ready" or
    "unready"; the server takes the player from the connection, never
    from the message, and tells every member, the sender among them.
  - Chat goes to every member, the sender among them, its player id
    stamped by the server.
  - START_GAME from the host sends GAME_START to every member with the
    host's address as the server sees it and the port it registered;
    with countdown_seconds above 0 (801e), it first sends LOBBY_UPDATE
    "countdown" with the seconds, and GAME_START follows when they are
    up. A player leaving, kicked or unready, or the host sending
    LOBBY_UPDATE "cancel", stops the countdown: LOBBY_UPDATE "cancel",
    and the lobby waits again. Nobody joins during a countdown.
  - LEAVE_GAME from the host naming a player kicks that player (801e):
    every member, the kicked one among them, gets LOBBY_UPDATE "kick".
  - NAT_PUNCH from a player goes to the host, and from the host to the
    player it names; the player id is rewritten to the sender's, and an
    empty ip is filled with the sender's address as the server sees it.
  - With a mirror (801f), whoever opens or joins a lobby whose packs the
    mirror holds (same id, same hash) is sent ASSET_PACKS_AVAILABLE: those
    packs and the mirror's rmail contact, which hands them out.
  - When a lobby closes (its host unregistered, left or went, or it was
    quiet past lobby_timeout_seconds), every member left is sent
    UNREGISTER_GAME with its game id.
  - A message the sender may not send (not its lobby, not the host,
    a server's message) is ignored and logged; bytes that are not a
    message, too many messages, or output not being read close the
    connection (801a decision 6).
]]

local protocol = require("matchmaking.protocol")
local packs = require("matchmaking.packs")

local server = {}
server.__index = server

server.DEFAULTS = {
    bind = "127.0.0.1:8080",          -- loopback unless told otherwise
    max_lobbies = 1000,
    max_players_per_lobby = 12,
    max_connections = 1000,           -- select() handles at most 1024 sockets
    lobby_timeout_seconds = 3600,     -- a lobby with no lobby message this long is closed
    idle_timeout_seconds = 120,       -- a connection that sends nothing this long is closed
    rate_per_second = 50,             -- messages a connection may send each second...
    rate_burst = 100,                 -- ...and at most this many at once
    max_output_bytes = 4194304,       -- unsent bytes a connection may pile up
    max_name = 64,                    -- bytes in a player's name
    countdown_seconds = 0,            -- seconds from START_GAME to GAME_START (801e); 0 starts at once
}

-- {{{ server.new
-- A server with `config` over the defaults; `config.clock` (seconds,
-- default LuaSocket's gettime or os.time), `config.log` (a function
-- taking one line; default none) and `config.codec` may be given.
--
-- The codec turns messages into bytes and back: `encode(name, message)`
-- and `read_frame(buffer) -> name, message, rest` (and optionally
-- MAX_LIST), protocol.lua by default. Question Q-1 (CRITICAL-PATH.md)
-- asks whether matchmaking should speak 803's message layer instead;
-- answering it yes means a codec with these two calls over that layer,
-- with the same message names and fields, and nothing here changes.
function server.new(config)
    config = config or {}
    local self = setmetatable({}, server)
    self.config = {}
    for k, v in pairs(server.DEFAULTS) do self.config[k] = v end
    for k, v in pairs(config) do
        if k ~= "clock" and k ~= "log" and k ~= "codec" and k ~= "mirror" then
            if server.DEFAULTS[k] == nil then error("matchmaking server: " .. tostring(k) .. " is not a setting", 0) end
            if type(v) ~= type(server.DEFAULTS[k]) then
                error("matchmaking server: " .. k .. " should be a " .. type(server.DEFAULTS[k]), 0)
            end
            self.config[k] = v
        end
    end
    self.clock = config.clock
    if not self.clock then
        local ok, socket = pcall(require, "socket")
        self.clock = ok and socket.gettime or os.time
    end
    self.log = config.log or function() end
    self.codec = config.codec or protocol
    if config.mirror ~= nil and not (type(config.mirror) == "table" and type(config.mirror.contact) == "string"
        and config.mirror.contact ~= "" and type(config.mirror.packs) == "table" and config.mirror.packs.get) then
        error("matchmaking server: mirror should be { contact = an rmail contact, packs = a registry of packs.lua }", 0)
    end
    self.mirror = config.mirror
    self.conns, self.lobbies, self.sockets = {}, {}, {}
    self.next_conn, self.next_game, self.next_player = 1, 1, 1
    self.started_at = self.clock()
    self.count = { messages_in = 0, messages_out = 0, bytes_in = 0, bytes_out = 0, connections = 0,
        lobbies_created = 0, lobbies_closed = 0, dropped = 0, ignored = 0, refused_connections = 0 }
    self.rate_sec, self.rate_count, self.last_rate = math.floor(self.started_at), 0, 0
    return self
end
-- }}}

-- {{{ sending
local function send(self, conn, name, message)
    local bytes = self.codec.encode(name, message)
    conn.out[#conn.out + 1] = bytes
    conn.out_bytes = conn.out_bytes + #bytes
    self.count.messages_out = self.count.messages_out + 1
    if conn.out_bytes > self.config.max_output_bytes then conn.overflow = true end
end

local function players_of(self, lobby)
    local list = {}
    for i, id in ipairs(lobby.members) do
        local p = self.conns[id].player
        list[i] = { player_id = p.player_id, name = p.name, ready = p.ready }
    end
    return list
end

local function broadcast(self, lobby, name, message, except)
    for _, id in ipairs(lobby.members) do
        if id ~= except then send(self, self.conns[id], name, message) end
    end
end
-- }}}

-- {{{ lobbies
local function close_lobby(self, lobby, why)
    for _, id in ipairs(lobby.members) do
        local c = self.conns[id]
        if c.open then send(self, c, "UNREGISTER_GAME", { game_id = lobby.game_id }) end
        c.lobby, c.player = nil, nil
    end
    lobby.members = {}
    lobby.state = "closed"
    self.lobbies[lobby.game_id] = nil
    self.count.lobbies_closed = self.count.lobbies_closed + 1
    self.log("lobby " .. lobby.game_id .. " closed: " .. why)
end

-- A countdown stops: the lobby waits again and every member hears why.
local function cancel_countdown(self, lobby, player_id, why)
    if lobby.state ~= "countdown" then return end
    lobby.state, lobby.start_at = "waiting", nil
    broadcast(self, lobby, "LOBBY_UPDATE", { game_id = lobby.game_id, event = "cancel",
        player_id = player_id, players = players_of(self, lobby) })
    self.log("lobby " .. lobby.game_id .. ": countdown stopped, " .. why)
end

-- `conn` leaves its lobby: the lobby closes if it was the host. With
-- `kicked`, the event is "kick" and the kicked player hears it too.
local function leave(self, conn, why, kicked)
    local lobby = conn.lobby
    if not lobby then return end
    if lobby.host == conn.id then return close_lobby(self, lobby, "its host " .. why) end
    local player_id = conn.player.player_id
    for i, id in ipairs(lobby.members) do
        if id == conn.id then table.remove(lobby.members, i) break end
    end
    conn.lobby, conn.player = nil, nil
    lobby.last_active = self.clock()
    local update = { game_id = lobby.game_id, event = kicked and "kick" or "leave",
        player_id = player_id, players = players_of(self, lobby) }
    broadcast(self, lobby, "LOBBY_UPDATE", update)
    if kicked and conn.open then send(self, conn, "LOBBY_UPDATE", update) end
    self.log("lobby " .. lobby.game_id .. ": player " .. player_id .. " " .. why)
    cancel_countdown(self, lobby, player_id, "player " .. player_id .. " " .. why)
end

-- The lobby's packs the mirror holds, told to one member (801f).
local function advertise(self, conn, lobby)
    if not self.mirror then return end
    local list = packs.available(self.mirror.packs, lobby.asset_packs)
    if #list == 0 then return end
    send(self, conn, "ASSET_PACKS_AVAILABLE", { game_id = lobby.game_id, contact = self.mirror.contact, packs = list })
end

local function good_name(self, name)
    return #name >= 1 and #name <= self.config.max_name
end

local function lobby_count(self)
    local n = 0
    for _ in pairs(self.lobbies) do n = n + 1 end
    return n
end
-- }}}

-- {{{ handlers
-- Each takes (self, conn, message) and returns a reason when the message
-- is ignored.
local handlers = {}

function handlers.REGISTER_GAME(self, conn, m)
    local function reject(reason)
        send(self, conn, "JOIN_REJECT", { game_id = 0, reason = reason })
        return "register refused: " .. reason
    end
    if conn.lobby then return reject("already in lobby " .. conn.lobby.game_id) end
    if lobby_count(self) >= self.config.max_lobbies then return reject("the server holds its most lobbies") end
    if m.max_players < 1 or m.max_players > self.config.max_players_per_lobby then
        return reject("a lobby holds 1 to " .. self.config.max_players_per_lobby .. " players")
    end
    local name = m.host_name or "host"
    if not good_name(self, name) then return reject("a name is 1 to " .. self.config.max_name .. " bytes") end
    local lobby = {
        game_id = self.next_game, map_name = m.map_name, map_hash = m.map_hash,
        asset_packs = m.asset_packs, max_players = m.max_players, game_mode = m.game_mode,
        region = m.region, host_port = m.host_port, host = conn.id, members = { conn.id },
        state = "waiting", created = self.clock(), last_active = self.clock(),
    }
    self.next_game = self.next_game + 1
    self.lobbies[lobby.game_id] = lobby
    self.count.lobbies_created = self.count.lobbies_created + 1
    conn.lobby = lobby
    conn.player = { player_id = self.next_player, name = name, ready = false }
    self.next_player = self.next_player + 1
    send(self, conn, "JOIN_ACK", { game_id = lobby.game_id, player_id = conn.player.player_id,
        players = players_of(self, lobby) })
    advertise(self, conn, lobby)
    self.log(string.format("lobby %d opened by connection %d (%s:%d): %s, %d players, %s, %s",
        lobby.game_id, conn.id, conn.ip, conn.port, m.map_name, m.max_players, m.game_mode, m.region))
end

-- The lobby `conn` is in, if it is `game_id`; and whether it hosts it.
local function own_lobby(conn, game_id)
    local lobby = conn.lobby
    if not lobby or lobby.game_id ~= game_id then return nil end
    return lobby, lobby.host == conn.id
end

function handlers.UNREGISTER_GAME(self, conn, m)
    local lobby, host = own_lobby(conn, m.game_id)
    if not host then return "UNREGISTER_GAME of a lobby it does not host" end
    close_lobby(self, lobby, "unregistered by its host")
end

function handlers.UPDATE_GAME(self, conn, m)
    local lobby, host = own_lobby(conn, m.game_id)
    if not host then return "UPDATE_GAME of a lobby it does not host" end
    if lobby.state ~= "waiting" then return "UPDATE_GAME after the game started" end
    if m.max_players < #lobby.members or m.max_players > self.config.max_players_per_lobby then
        return "UPDATE_GAME to " .. m.max_players .. " players"
    end
    lobby.max_players = m.max_players
    lobby.last_active = self.clock()
    self.log("lobby " .. lobby.game_id .. " now holds " .. m.max_players .. " players")
end

function handlers.LIST_GAMES(self, conn, m)
    local ids = {}
    for id, lobby in pairs(self.lobbies) do
        local free = lobby.max_players - #lobby.members
        if lobby.state == "waiting"
            and (not m.map_name or lobby.map_name:lower():find(m.map_name:lower(), 1, true))
            and (not m.game_mode or lobby.game_mode == m.game_mode)
            and (not m.region or lobby.region == m.region)
            and (not m.free_slots or free >= m.free_slots) then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    local games = {}
    for i = 1, math.min(#ids, self.codec.MAX_LIST or protocol.MAX_LIST) do
        local l = self.lobbies[ids[i]]
        games[i] = { game_id = l.game_id, map_name = l.map_name, map_hash = l.map_hash,
            asset_packs = l.asset_packs, game_mode = l.game_mode, region = l.region,
            players = #l.members, max_players = l.max_players }
    end
    send(self, conn, "GAME_LIST", { games = games })
end

function handlers.JOIN_GAME(self, conn, m)
    local function reject(reason)
        send(self, conn, "JOIN_REJECT", { game_id = m.game_id, reason = reason })
        return "join refused: " .. reason
    end
    if conn.lobby then return reject("already in lobby " .. conn.lobby.game_id) end
    local lobby = self.lobbies[m.game_id]
    if not lobby then return reject("no such game") end
    if lobby.state == "countdown" then return reject("the game is starting") end
    if lobby.state ~= "waiting" then return reject("the game has started") end
    if #lobby.members >= lobby.max_players then return reject("the lobby is full") end
    if not good_name(self, m.player_name) then return reject("a name is 1 to " .. self.config.max_name .. " bytes") end
    conn.lobby = lobby
    conn.player = { player_id = self.next_player, name = m.player_name, ready = false }
    self.next_player = self.next_player + 1
    lobby.members[#lobby.members + 1] = conn.id
    lobby.last_active = self.clock()
    local players = players_of(self, lobby)
    send(self, conn, "JOIN_ACK", { game_id = lobby.game_id, player_id = conn.player.player_id, players = players })
    advertise(self, conn, lobby)
    broadcast(self, lobby, "LOBBY_UPDATE", { game_id = lobby.game_id, event = "join",
        player_id = conn.player.player_id, players = players }, conn.id)
    self.log("lobby " .. lobby.game_id .. ": player " .. conn.player.player_id .. " joined from connection " .. conn.id)
end

function handlers.LEAVE_GAME(self, conn, m)
    local lobby, host = own_lobby(conn, m.game_id)
    if not lobby then return "LEAVE_GAME of a lobby it is not in" end
    if not m.player_id then return leave(self, conn, "left") end
    if not host then return "a kick from a player" end
    if lobby.state ~= "waiting" and lobby.state ~= "countdown" then return "a kick after the game started" end
    for _, id in ipairs(lobby.members) do
        local c = self.conns[id]
        if id ~= conn.id and c.player.player_id == m.player_id then
            return leave(self, c, "was kicked by the host", true)
        end
    end
    return "a kick of player " .. m.player_id .. ", not in lobby " .. lobby.game_id
end

function handlers.LOBBY_UPDATE(self, conn, m)
    local lobby, host = own_lobby(conn, m.game_id)
    if not lobby then return "LOBBY_UPDATE of a lobby it is not in" end
    if m.event == "cancel" then
        if not host then return "a cancel from a player" end
        if lobby.state ~= "countdown" then return "a cancel with no countdown" end
        lobby.last_active = self.clock()
        return cancel_countdown(self, lobby, conn.player.player_id, "cancelled by the host")
    end
    if m.event ~= "ready" and m.event ~= "unready" then return "LOBBY_UPDATE " .. m.event .. " from a player" end
    if lobby.state ~= "waiting" and lobby.state ~= "countdown" then return "LOBBY_UPDATE after the game started" end
    conn.player.ready = m.event == "ready"
    lobby.last_active = self.clock()
    broadcast(self, lobby, "LOBBY_UPDATE", { game_id = lobby.game_id, event = m.event,
        player_id = conn.player.player_id, players = players_of(self, lobby) })
    if m.event == "unready" then
        cancel_countdown(self, lobby, conn.player.player_id, "player " .. conn.player.player_id .. " is not ready")
    end
end

local function start_now(self, lobby)
    local host = self.conns[lobby.host]
    lobby.state = "starting"
    broadcast(self, lobby, "GAME_START", { game_id = lobby.game_id, host_ip = host.ip, host_port = lobby.host_port })
    lobby.state, lobby.start_at = "in_progress", nil
    self.log("lobby " .. lobby.game_id .. " started with " .. #lobby.members .. " players")
end

function handlers.START_GAME(self, conn, m)
    local lobby, host = own_lobby(conn, m.game_id)
    if not host then return "START_GAME of a lobby it does not host" end
    if lobby.state ~= "waiting" then return "START_GAME twice" end
    lobby.last_active = self.clock()
    local seconds = self.config.countdown_seconds
    if seconds <= 0 then return start_now(self, lobby) end
    lobby.state, lobby.start_at = "countdown", self.clock() + seconds
    broadcast(self, lobby, "LOBBY_UPDATE", { game_id = lobby.game_id, event = "countdown",
        player_id = conn.player.player_id, players = players_of(self, lobby), seconds = math.ceil(seconds) })
    self.log("lobby " .. lobby.game_id .. " starts in " .. seconds .. " seconds")
end

function handlers.NAT_PUNCH(self, conn, m)
    local lobby, host = own_lobby(conn, m.game_id)
    if not lobby then return "NAT_PUNCH of a lobby it is not in" end
    local to
    if host then
        for _, id in ipairs(lobby.members) do
            if id ~= conn.id and self.conns[id].player.player_id == m.player_id then to = self.conns[id] end
        end
        if not to then return "NAT_PUNCH to player " .. m.player_id .. ", not in lobby " .. lobby.game_id end
    else
        to = self.conns[lobby.host]
    end
    lobby.last_active = self.clock()
    send(self, to, "NAT_PUNCH", { game_id = lobby.game_id, player_id = conn.player.player_id,
        ip = m.ip ~= "" and m.ip or conn.ip, port = m.port })
end

function handlers.CHAT_MSG(self, conn, m)
    local lobby = own_lobby(conn, m.game_id)
    if not lobby then return "CHAT_MSG to a lobby it is not in" end
    if m.text == "" then return "an empty CHAT_MSG" end
    lobby.last_active = self.clock()
    broadcast(self, lobby, "CHAT_MSG", { game_id = lobby.game_id, player_id = conn.player.player_id, text = m.text })
end

function handlers.PING(self, conn, m)
    send(self, conn, "PONG", { nonce = m.nonce })
end
-- }}}

-- {{{ the core: connections as numbers and bytes

-- {{{ server:accept
-- A new connection from `ip`:`port`: its number, or nil when the server
-- holds max_connections already.
function server:accept(ip, port)
    local n = 0
    for _ in pairs(self.conns) do n = n + 1 end
    if n >= self.config.max_connections then
        self.count.refused_connections = self.count.refused_connections + 1
        self.log("connection from " .. ip .. ":" .. port .. " refused: the server is full")
        return nil
    end
    local id = self.next_conn
    self.next_conn = id + 1
    local now = self.clock()
    self.conns[id] = { id = id, ip = ip, port = port, inbuf = "", out = {}, out_bytes = 0, open = true,
        last_heard = now, tokens = self.config.rate_burst, token_time = now }
    self.count.connections = self.count.connections + 1
    self.log("connection " .. id .. " from " .. ip .. ":" .. port)
    return id
end
-- }}}

-- {{{ server:close
-- Ends connection `id`, taking it out of its lobby. Its output is dropped.
function server:close(id, why)
    local conn = self.conns[id]
    if not conn then return end
    conn.open = false
    leave(self, conn, why or "disconnected")
    self.conns[id] = nil
    self.log("connection " .. id .. " closed: " .. (why or "disconnected"))
end

local function drop(self, conn, why)
    self.count.dropped = self.count.dropped + 1
    self:close(conn.id, "dropped, " .. why)
end
-- }}}

-- {{{ server:receive
-- Bytes that arrived on connection `id`; every whole message among them
-- is handled. Returns false when the connection was closed for them.
function server:receive(id, bytes)
    local conn = self.conns[id]
    if not conn then return false end
    local now = self.clock()
    conn.last_heard = now
    conn.inbuf = conn.inbuf .. bytes
    self.count.bytes_in = self.count.bytes_in + #bytes
    while true do
        local ok, name, message, rest = pcall(self.codec.read_frame, conn.inbuf)
        if not ok then drop(self, conn, name) return false end
        if not name then break end
        conn.inbuf = rest
        -- the rate: a bucket refilled rate_per_second, holding rate_burst
        conn.tokens = math.min(self.config.rate_burst, conn.tokens + (now - conn.token_time) * self.config.rate_per_second)
        conn.token_time = now
        if conn.tokens < 1 then drop(self, conn, "more than " .. self.config.rate_per_second .. " messages a second") return false end
        conn.tokens = conn.tokens - 1
        self.count.messages_in = self.count.messages_in + 1
        local sec = math.floor(now)
        if sec ~= self.rate_sec then
            self.last_rate = (sec == self.rate_sec + 1) and self.rate_count or 0
            self.rate_sec, self.rate_count = sec, 0
        end
        self.rate_count = self.rate_count + 1
        local handler = handlers[name]
        local why = handler and handler(self, conn, message) or (not handler and name .. " is the server's to send")
        if why then
            self.count.ignored = self.count.ignored + 1
            self.log("connection " .. id .. ": ignored, " .. why)
        end
        if conn.overflow then break end
    end
    -- the sender's or a member's output may have overflowed through a broadcast
    local over = {}
    for cid, c in pairs(self.conns) do if c.overflow then over[#over + 1] = cid end end
    table.sort(over)
    for _, cid in ipairs(over) do drop(self, self.conns[cid], "its output is not being read") end
    return self.conns[id] ~= nil
end
-- }}}

-- {{{ server:output
-- The bytes waiting to go out on connection `id`, taken (empty if none).
function server:output(id)
    local conn = self.conns[id]
    if not conn or #conn.out == 0 then return "" end
    local bytes = table.concat(conn.out)
    conn.out, conn.out_bytes = {}, 0
    self.count.bytes_out = self.count.bytes_out + #bytes
    return bytes
end
-- }}}

-- {{{ server:sweep
-- The timeouts: connections silent past idle_timeout_seconds are closed,
-- lobbies with no lobby message past lobby_timeout_seconds are closed.
function server:sweep()
    local now = self.clock()
    local ids = {}
    for id in pairs(self.conns) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local c = self.conns[id]
        if c and now - c.last_heard >= self.config.idle_timeout_seconds then
            self:close(id, "silent for " .. self.config.idle_timeout_seconds .. " seconds")
        end
    end
    local gids = {}
    for gid in pairs(self.lobbies) do gids[#gids + 1] = gid end
    table.sort(gids)
    for _, gid in ipairs(gids) do
        local l = self.lobbies[gid]
        if l and l.state == "countdown" and now >= l.start_at then
            start_now(self, l)
        elseif l and now - l.last_active >= self.config.lobby_timeout_seconds then
            close_lobby(self, l, "quiet for " .. self.config.lobby_timeout_seconds .. " seconds")
        end
    end
end
-- }}}

-- {{{ server:stats
function server:stats()
    local now = self.clock()
    local sec = math.floor(now)
    local rate = self.last_rate
    if sec ~= self.rate_sec then rate = (sec == self.rate_sec + 1) and self.rate_count or 0 end
    local s = { lobbies_active = 0, players_online = 0, players_in_lobbies = 0,
        messages_per_second = rate, uptime_seconds = now - self.started_at }
    for _, l in pairs(self.lobbies) do
        s.lobbies_active = s.lobbies_active + 1
        s.players_in_lobbies = s.players_in_lobbies + #l.members
    end
    for _ in pairs(self.conns) do s.players_online = s.players_online + 1 end
    for k, v in pairs(self.count) do s[k] = v end
    return s
end
-- }}}

-- {{{ server:lobby_list
-- A copy of every lobby, by game id: its map, state, host and players.
function server:lobby_list()
    local list = {}
    for gid, l in pairs(self.lobbies) do
        local host = self.conns[l.host]
        list[#list + 1] = { game_id = gid, map_name = l.map_name, map_hash = l.map_hash, game_mode = l.game_mode,
            region = l.region, state = l.state, max_players = l.max_players, host_ip = host.ip,
            host_port = l.host_port, players = players_of(self, l) }
    end
    table.sort(list, function(a, b) return a.game_id < b.game_id end)
    return list
end
-- }}}
-- }}}

-- {{{ the socket layer (LuaSocket)

local function split_bind(bind)
    local host, port = bind:match("^(.*):(%d+)$")
    if not host then error("matchmaking server: bind should be host:port, is " .. tostring(bind), 0) end
    return host, tonumber(port)
end

-- {{{ server:start
-- Listens on config.bind ("host:port"; port 0 takes a free one). Raises
-- if it can't.
function server:start()
    local socket = require("socket")
    local host, port = split_bind(self.config.bind)
    local listener, err = socket.bind(host, port, 64)
    if not listener then error("matchmaking server: can't listen on " .. self.config.bind .. ": " .. tostring(err), 0) end
    listener:settimeout(0)
    self.socket_lib, self.listener = socket, listener
    self.started_at = self.clock()
    local ip, p = listener:getsockname()
    self.log("listening on " .. ip .. ":" .. p)
end
-- }}}

-- {{{ server:address
-- The address listened on: ip, port.
function server:address()
    if not self.listener then return nil end
    local ip, port = self.listener:getsockname()
    return ip, tonumber(port)
end
-- }}}

local function close_socket(self, id)
    local s = self.sockets[id]
    if s then s:close() self.sockets[id] = nil end
end

-- {{{ server:tick
-- One round: waits up to `wait` seconds (default 0) for something to
-- happen, accepts, reads, handles, writes and sweeps.
function server:tick(wait)
    local socket = self.socket_lib
    if not socket then error("matchmaking server: tick before start", 0) end
    local readers, writers, of = { self.listener }, {}, {}
    for id, s in pairs(self.sockets) do
        readers[#readers + 1] = s
        of[s] = id
        local c = self.conns[id]
        if c and (#c.out > 0 or c.pending) then writers[#writers + 1] = s end
    end
    local readable, writable = socket.select(readers, writers, wait or 0)
    for _, s in ipairs(readable or {}) do
        if s == self.listener then
            while true do
                local client = self.listener:accept()
                if not client then break end
                client:settimeout(0)
                client:setoption("tcp-nodelay", true)
                local ip, port = client:getpeername()
                local id = self:accept(ip, tonumber(port))
                if id then self.sockets[id] = client else client:close() end
            end
        else
            local id = of[s]
            local data, err, partial = s:receive(65536)
            local bytes = data or partial
            if bytes and #bytes > 0 then self:receive(id, bytes) end
            if err == "closed" then self:close(id, "disconnected") end
        end
    end
    self:sweep()
    -- write what is waiting, keeping what the socket didn't take
    for id, s in pairs(self.sockets) do
        local c = self.conns[id]
        if not c then
            close_socket(self, id)
        else
            local bytes = (c.pending or "") .. self:output(id)
            c.pending = nil
            if #bytes > 0 then
                local last, err, partial_last = s:send(bytes)
                last = last or partial_last or 0
                if last < #bytes then
                    if err == "closed" then
                        self:close(id, "disconnected")
                        close_socket(self, id)
                    else
                        c.pending = bytes:sub(last + 1)
                        if #c.pending > self.config.max_output_bytes then
                            drop(self, c, "its output is not being read")
                            close_socket(self, id)
                        end
                    end
                end
            end
        end
    end
end
-- }}}

-- {{{ server:stop
-- Closes every lobby, telling its members (one try at sending, without
-- waiting), then every connection and the listener.
function server:stop()
    local gids = {}
    for gid in pairs(self.lobbies) do gids[#gids + 1] = gid end
    table.sort(gids)
    for _, gid in ipairs(gids) do close_lobby(self, self.lobbies[gid], "the server stopped") end
    for id, s in pairs(self.sockets) do
        local c = self.conns[id]
        local bytes = c and ((c.pending or "") .. self:output(id)) or ""
        if #bytes > 0 then s:send(bytes) end
    end
    local ids = {}
    for id in pairs(self.conns) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do self:close(id, "the server stopped") end
    for id in pairs(self.sockets) do close_socket(self, id) end
    if self.listener then self.listener:close() self.listener = nil end
    self.socket_lib = nil
    self.log("stopped")
end
-- }}}
-- }}}

return server
