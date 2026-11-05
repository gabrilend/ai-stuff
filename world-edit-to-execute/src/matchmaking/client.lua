--[[
client.lua - the matchmaking client library (issue 801c)

What this is: what a game uses to reach the matchmaking server
(server.lua): list the hosted games, open a lobby as its host, join one,
chat, mark ready, start, and learn where the host is when the game
begins. Event-driven and non-blocking, so a game's frame never waits on
the network: the game calls conn:poll() once a frame, and what arrived
fires the handlers it set with :on().

Two layers, as in server.lua:
  The core knows the server only as bytes: conn:feed(bytes) hands it what
  arrived, conn:output() takes what is to be sent, conn:lost(why) says the
  connection went. client.new() makes one, so every rule is tested with
  the server's core and no network.
  The socket layer: client.connect() opens a LuaSocket connection (the
  one call that waits, up to `timeout`), and conn:poll(wait) reads,
  writes, keeps the connection alive and reconnects after it drops.

Waiting or not: list_games, create_lobby and join_game take an optional
callback. Given one, they return at once and call it when the answer
comes. Without one they wait for the answer (polling, up to `timeout`)
and return it, as in the issue's examples.

Decisions of 2026-11-05 (the issue has them all):
  - A connection is in at most one lobby, as the server has it; asking
    for a second raises here, before anything is sent.
  - A dropped connection closes its lobby ("closed" with "disconnected"):
    the server has already dropped it. After a reconnect the game opens
    or joins again; game ids change.
  - Reconnecting waits 1 second, then twice as long each failure, up to
    30; never after conn:disconnect().
  - A ping every 30 seconds keeps the connection (the server closes one
    silent for 120) and measures conn.latency_ms.
]]

local protocol = require("matchmaking.protocol")

local client = {}
local unpack = unpack or table.unpack

client.DEFAULTS = {
    host = "127.0.0.1",
    port = 8080,
    timeout = 5000,             -- ms: to connect, and to wait for an answer
    name = "player",            -- the name joined and hosted under, unless given
    ping_interval = 30,         -- seconds between pings
    reconnect = true,
    reconnect_min = 1,          -- seconds before the first try...
    reconnect_max = 30,         -- ...doubling each failure up to this
}

-- {{{ events
local function on(self, event, fn)
    self.handlers[event] = self.handlers[event] or {}
    table.insert(self.handlers[event], fn)
    return fn
end

local function off(self, event, fn)
    for i, f in ipairs(self.handlers[event] or {}) do
        if f == fn then table.remove(self.handlers[event], i) return true end
    end
    return false
end

local function emit(self, event, ...)
    local list = self.handlers[event]
    if not list then return end
    for _, fn in ipairs({ unpack(list) }) do fn(...) end
end
-- }}}

local Conn, Lobby = {}, {}
Conn.__index, Lobby.__index = Conn, Lobby
Conn.on, Conn.off, Lobby.on, Lobby.off = on, off, on, off

-- {{{ client.new
-- A connection's core, with no socket: `options` over client.DEFAULTS,
-- plus `clock` (seconds), `log` (a function taking a line) and `pump`
-- (a function(wait) that moves bytes, used when a call waits).
function client.new(options)
    options = options or {}
    local self = setmetatable({ handlers = {} }, Conn)
    self.options = {}
    for k, v in pairs(client.DEFAULTS) do self.options[k] = v end
    for k, v in pairs(options) do
        if k ~= "clock" and k ~= "log" and k ~= "pump" then
            if client.DEFAULTS[k] == nil then error("matchmaking client: " .. tostring(k) .. " is not an option", 0) end
            if type(v) ~= type(client.DEFAULTS[k]) then
                error("matchmaking client: " .. k .. " should be a " .. type(client.DEFAULTS[k]), 0)
            end
            self.options[k] = v
        end
    end
    self.clock = options.clock
    if not self.clock then
        local ok, socket = pcall(require, "socket")
        self.clock = ok and socket.gettime or os.time
    end
    self.log = options.log or function() end
    self.pump = options.pump
    self.state = "connected"
    self.inbuf, self.out = "", {}
    self.lists = {}                       -- callbacks waiting for GAME_LIST, in order
    self.nonce, self.pings = 0, {}
    self.last_ping = self.clock()
    self.backoff = self.options.reconnect_min
    return self
end
-- }}}

-- {{{ sending and losing
local function send(self, name, message)
    if self.state ~= "connected" then error("matchmaking client: not connected (" .. self.state .. ")", 0) end
    self.out[#self.out + 1] = protocol.encode(name, message)
end

local function close_lobby(self, why)
    local lobby = self.lobby
    if not lobby then return end
    self.lobby = nil
    local was = lobby.state
    lobby.state = "closed"
    if was == "opening" then
        lobby.reason = why
        if lobby.callback then lobby.callback(nil, why) end
    else
        emit(lobby, "closed", why)
    end
end

-- {{{ Conn:lost
-- The connection went (`why`): every waiting answer fails, the lobby
-- closes, "disconnect" fires, and a reconnect is planned.
function Conn:lost(why)
    if self.state == "disconnected" or self.state == "closed" then return end
    self.state = "disconnected"
    self.inbuf, self.out, self.pending = "", {}, nil
    if self.sock then self.sock:close() self.sock = nil end
    local lists = self.lists
    self.lists = {}
    for _, cb in ipairs(lists) do cb(nil, why) end
    close_lobby(self, "disconnected")
    self.log("disconnected: " .. why)
    self.next_try = self.clock() + self.backoff
    emit(self, "disconnect", why)
end
-- }}}
-- }}}

-- {{{ what the server sends
local function player_in(list, id)
    for _, p in ipairs(list or {}) do if p.player_id == id then return p end end
end

local receive = {}

function receive.GAME_LIST(self, m)
    local cb = table.remove(self.lists, 1)
    if not cb then return "a GAME_LIST not asked for" end
    for _, g in ipairs(m.games) do g.id = g.game_id end
    cb(m.games)
end

function receive.JOIN_ACK(self, m)
    local lobby = self.lobby
    if not lobby or lobby.state ~= "opening" then return "a JOIN_ACK not asked for" end
    lobby.game_id, lobby.player_id, lobby.players = m.game_id, m.player_id, m.players
    lobby.state = "waiting"
    self.log("in lobby " .. m.game_id .. " as player " .. m.player_id)
    if lobby.callback then lobby.callback(lobby) end
end

function receive.JOIN_REJECT(self, m)
    local lobby = self.lobby
    if not lobby or lobby.state ~= "opening" then return "a JOIN_REJECT not asked for" end
    self.log("refused: " .. m.reason)
    close_lobby(self, m.reason)
end

-- The lobby a message is about, if it is ours.
local function ours(self, m)
    local lobby = self.lobby
    if lobby and lobby.state ~= "opening" and lobby.game_id == m.game_id then return lobby end
end

function receive.LOBBY_UPDATE(self, m)
    local lobby = ours(self, m)
    if not lobby then return "a LOBBY_UPDATE of another lobby" end
    local before = lobby.players
    lobby.players = m.players
    if m.event == "join" then
        emit(lobby, "player_join", player_in(m.players, m.player_id))
    elseif m.event == "leave" then
        emit(lobby, "player_leave", player_in(before, m.player_id) or { player_id = m.player_id })
    elseif m.event == "ready" or m.event == "unready" then
        emit(lobby, "player_ready", player_in(m.players, m.player_id), m.event == "ready")
    end
end

function receive.CHAT_MSG(self, m)
    local lobby = ours(self, m)
    if not lobby then return "chat of another lobby" end
    emit(lobby, "chat", player_in(lobby.players, m.player_id) or { player_id = m.player_id }, m.text)
end

function receive.GAME_START(self, m)
    local lobby = ours(self, m)
    if not lobby then return "a GAME_START of another lobby" end
    lobby.state = "in_progress"
    lobby.host_connection = { ip = m.host_ip, port = m.host_port }
    emit(lobby, "game_start", lobby.host_connection)
end

function receive.NAT_PUNCH(self, m)
    local lobby = ours(self, m)
    if not lobby then return "a NAT_PUNCH of another lobby" end
    emit(lobby, "nat_punch", { player_id = m.player_id, ip = m.ip, port = m.port })
end

function receive.UNREGISTER_GAME(self, m)
    if not ours(self, m) then return "an UNREGISTER_GAME of another lobby" end
    close_lobby(self, "the lobby closed")
end

function receive.PONG(self, m)
    local sent = self.pings[m.nonce]
    if not sent then return "a PONG not asked for" end
    self.pings[m.nonce] = nil
    self.latency_ms = (self.clock() - sent) * 1000
    emit(self, "pong", self.latency_ms)
end
-- }}}

-- {{{ the core: bytes in and out

-- {{{ Conn:feed
-- Bytes from the server; every whole message is handled. Bytes that are
-- not a message drop the connection.
function Conn:feed(bytes)
    if self.state ~= "connected" then return end
    self.inbuf = self.inbuf .. bytes
    while self.state == "connected" do
        local ok, name, m, rest = pcall(protocol.read_frame, self.inbuf)
        if not ok then return self:lost("the server sent what is not a message: " .. name) end
        if not name then break end
        self.inbuf = rest
        local handler = receive[name]
        local why = handler and handler(self, m) or (not handler and name .. " is not the server's to send")
        if why then self.log("ignored: " .. why) end
    end
end
-- }}}

-- {{{ Conn:output
function Conn:output()
    if #self.out == 0 then return "" end
    local bytes = table.concat(self.out)
    self.out = {}
    return bytes
end
-- }}}

-- {{{ Conn:tick
-- The keepalive: a ping every ping_interval seconds while connected.
function Conn:tick()
    if self.state ~= "connected" then return end
    local now = self.clock()
    if now - self.last_ping >= self.options.ping_interval then self:ping() end
end

function Conn:ping()
    self.nonce = (self.nonce + 1) % 4294967296
    self.pings[self.nonce] = self.clock()
    self.last_ping = self.clock()
    send(self, "PING", { nonce = self.nonce })
end
-- }}}

-- {{{ Conn:wait
-- Polls until `done()` is true or `timeout` ms pass; returns done()'s answer.
function Conn:wait(done)
    if not self.pump then error("matchmaking client: nothing to wait with (no pump, no socket)", 0) end
    local limit = self.clock() + self.options.timeout / 1000
    while true do
        local r = done()
        if r then return r end
        if self.clock() >= limit then return nil end
        self.pump(0.01)
    end
end
-- }}}
-- }}}

-- {{{ asking the server

-- {{{ Conn:list_games
-- The waiting games, filtered by any of map_name, game_mode, region,
-- free_slots, max_latency_ms (passed on; nothing measures a game's
-- latency yet). Each game carries `id` as well as `game_id`.
function Conn:list_games(filter, callback)
    send(self, "LIST_GAMES", filter or {})
    if callback then self.lists[#self.lists + 1] = callback return end
    local got, err, done = nil, nil, false
    self.lists[#self.lists + 1] = function(games, why) got, err, done = games, why, true end
    if not self:wait(function() return done end) then return nil, "no answer in " .. self.options.timeout .. " ms" end
    return got, err
end
-- }}}

local function one_lobby(self)
    if self.lobby then error("matchmaking client: already in lobby " .. tostring(self.lobby.game_id or "(opening)"), 0) end
end

local function open_lobby(self, lobby, callback)
    self.lobby = lobby
    lobby.callback = callback
    if callback then return lobby end
    if not self:wait(function() return lobby.state ~= "opening" end) then
        close_lobby(self, "no answer in " .. self.options.timeout .. " ms")
    end
    if lobby.state == "closed" then return nil, lobby.reason end
    return lobby
end

-- {{{ Conn:create_lobby
-- Opens a lobby as its host. `game`: map_name, map_hash, asset_packs,
-- max_players, game_mode, region, host_port (default 6112), host_name
-- (default the connection's name).
function Conn:create_lobby(game, callback)
    local m = {}
    for k, v in pairs(game) do m[k] = v end
    m.host_port = m.host_port or 6112
    m.host_name = m.host_name or self.options.name
    m.asset_packs = m.asset_packs or {}
    one_lobby(self)
    send(self, "REGISTER_GAME", m)
    local lobby = setmetatable({ handlers = {}, conn = self, is_host = true, state = "opening", players = {} }, Lobby)
    return open_lobby(self, lobby, callback)
end
-- }}}

-- {{{ Conn:join_game
-- Joins a game: its id, or a game from list_games. `name` defaults to
-- the connection's.
function Conn:join_game(game, name, callback)
    if type(name) == "function" then name, callback = nil, name end
    local id = type(game) == "table" and (game.game_id or game.id) or game
    one_lobby(self)
    send(self, "JOIN_GAME", { game_id = id, player_name = name or self.options.name })
    local lobby = setmetatable({ handlers = {}, conn = self, is_host = false, state = "opening", players = {} }, Lobby)
    return open_lobby(self, lobby, callback)
end
-- }}}

-- {{{ Conn:disconnect
-- Ends the connection for good: the lobby closes, no reconnect.
function Conn:disconnect()
    if self.state == "closed" then return end
    if self.state == "connected" and self.sock then
        local bytes = (self.pending or "") .. self:output()
        if #bytes > 0 then self.sock:send(bytes) end
    end
    self:lost("disconnected by the game")
    self.state = "closed"
end
-- }}}
-- }}}

-- {{{ the lobby
local function live(lobby, what)
    if lobby.state ~= "waiting" and lobby.state ~= "in_progress" then
        error("matchmaking client: " .. what .. " in a lobby that is " .. lobby.state, 0)
    end
end

function Lobby:send_chat(text)
    live(self, "chat")
    send(self.conn, "CHAT_MSG", { game_id = self.game_id, player_id = self.player_id, text = text })
end

function Lobby:set_ready(ready)
    live(self, "ready")
    send(self.conn, "LOBBY_UPDATE", { game_id = self.game_id, event = ready and "ready" or "unready",
        player_id = self.player_id, players = {} })
end

function Lobby:start_game()
    if not self.is_host then error("matchmaking client: only the host starts the game", 0) end
    live(self, "start")
    send(self.conn, "START_GAME", { game_id = self.game_id })
end

function Lobby:set_max_players(n)
    if not self.is_host then error("matchmaking client: only the host changes the lobby", 0) end
    live(self, "a change")
    send(self.conn, "UPDATE_GAME", { game_id = self.game_id, players = #self.players, max_players = n })
end

-- An endpoint for NAT traversal (801d): a player's goes to the host, the
-- host's to the player named. An empty ip asks the server to fill in the
-- address it sees.
function Lobby:punch(ip, port, player_id)
    live(self, "a NAT endpoint")
    send(self.conn, "NAT_PUNCH", { game_id = self.game_id, player_id = player_id or 0, ip = ip or "", port = port })
end

function Lobby:leave()
    if self.state == "closed" then return end
    live(self, "leaving")
    send(self.conn, self.is_host and "UNREGISTER_GAME" or "LEAVE_GAME", { game_id = self.game_id })
    if self.conn.lobby == self then close_lobby(self.conn, "left") end
end

function Lobby:get_players() return self.players end
function Lobby:get_host_connection() return self.host_connection end
-- }}}

-- {{{ the socket layer (LuaSocket)

-- Starts a connection without waiting: nil while it is being made (the
-- socket says when, even one made at once), or false and why.
local function begin_connect(self)
    local socket = require("socket")
    self.socket_lib = socket
    local s = socket.tcp()
    s:settimeout(0)
    local ok, err = s:connect(self.options.host, self.options.port)
    self.sock, self.connect_started = s, self.clock()
    self.state = "connecting"
    if ok or err == "already connected" or err == "timeout" or err == "Operation already in progress" then return nil end
    return false, err
end

local function connected(self)
    self.sock:setoption("tcp-nodelay", true)
    self.state = "connected"
    self.inbuf, self.out, self.pending = "", {}, nil
    self.last_ping = self.clock()
    self.backoff = self.options.reconnect_min
    self.log("connected to " .. self.options.host .. ":" .. self.options.port)
end

local function failed(self, why)
    if self.sock then self.sock:close() self.sock = nil end
    self.state = "disconnected"
    self.next_try = self.clock() + self.backoff
    self.backoff = math.min(self.backoff * 2, self.options.reconnect_max)
    self.log("could not connect: " .. why)
    return why
end

-- Moves a connection that is being made along: true once made, false
-- and why when it failed, nil while it is still being made.
local function check_connect(self)
    local _, writable = self.socket_lib.select(nil, { self.sock }, 0)
    if writable and writable[1] then
        if self.sock:getpeername() then connected(self) return true end
        return false, failed(self, "refused")
    end
    if self.clock() - self.connect_started >= self.options.timeout / 1000 then
        return false, failed(self, "no answer in " .. self.options.timeout .. " ms")
    end
end

-- {{{ client.connect
-- Connects to `options.host`:`options.port`, waiting up to `timeout` ms:
-- the connection, or nil and why.
function client.connect(options)
    local self = client.new(options)
    self.pump = function(wait) self:poll(wait) end
    local ok, err = begin_connect(self)
    if ok == false then failed(self, err) return nil, err end
    while true do
        local done, why = check_connect(self)
        if done then return self end
        if done == false then return nil, why end
        self.socket_lib.sleep(0.005)
    end
end
-- }}}

-- {{{ Conn:poll
-- Once a frame: waits up to `wait` seconds (default 0) for the server,
-- then reads, handles, writes, pings, and reconnects when it is time.
function Conn:poll(wait)
    local socket = self.socket_lib
    if not socket then error("matchmaking client: poll without a socket (use client.connect)", 0) end
    if self.state == "disconnected" and self.options.reconnect and self.clock() >= (self.next_try or 0) then
        local ok, err = begin_connect(self)
        if ok == false then failed(self, err) end
    end
    if self.state == "connecting" then
        local done = check_connect(self)
        if done then emit(self, "reconnect") end
        if not done and wait and wait > 0 then socket.sleep(wait) end
        return
    end
    if self.state ~= "connected" then
        if wait and wait > 0 then socket.sleep(wait) end
        return
    end
    local readable = socket.select({ self.sock }, nil, wait or 0)
    if readable and readable[1] then
        local data, err, partial = self.sock:receive(65536)
        local bytes = data or partial
        if bytes and #bytes > 0 then self:feed(bytes) end
        if err == "closed" then return self:lost("the server closed the connection") end
    end
    if self.state ~= "connected" then return end
    self:tick()
    local bytes = (self.pending or "") .. self:output()
    self.pending = nil
    if #bytes > 0 then
        local last, err, partial_last = self.sock:send(bytes)
        last = last or partial_last or 0
        if last < #bytes then
            if err == "closed" then return self:lost("the server closed the connection") end
            self.pending = bytes:sub(last + 1)
        end
    end
end
-- }}}
-- }}}

return client
