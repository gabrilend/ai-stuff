--[[
nat.lua - finds the kind of NAT a machine is behind and punches UDP holes through it (issue 801d)

In plain terms: two players behind home routers can't reach each other
until each router has seen a packet go out to the other. This module
does three things for that, all over UDP:

- a **reflector**, run beside the matchmaking server, that tells a
  machine which address and port its packets come from as seen from the
  outside, and can answer from a second port or a second address;
- a **detector** that asks the reflector a few questions and works out
  the kind of NAT (open, full cone, restricted cone, port-restricted
  cone, symmetric, or blocked);
- a **punch**: both sides send probes to each other's outside address
  at once, until one answers; then the hole is open and the punch keeps
  it open with a keepalive.

A **session** ties punches to a lobby of the client library (client.lua):
the endpoints travel through the matchmaking server's NAT_PUNCH message.

Every piece works on an *endpoint*: anything with `send(data, ip, port)`,
`receive()` (returns data, ip, port, or nil when nothing waits) and
`local_address()` (ip, port). `nat.udp` makes one from a LuaSocket UDP
socket; src/tests/natsim.lua makes simulated ones behind simulated NATs.
Time comes from a `clock` (seconds) the caller may pass.

The packets are this module's own ("WN", a kind, a 32-bit token, then a
little body; see the info page), kept apart from the matchmaking
server's MessagePack messages: they ride UDP, not the TCP stream. If
question Q-1 settles on 803's message layer, only `nat.encode` and
`nat.decode` change.

IPv4 only. No relay: a punch that fails is reported, and the game says
so (see the info page for the compatibility table and the open questions
left to the owner).
]]

local bit = require("bit")

local nat = {}

nat.DEFAULTS = {
    probe_interval = 0.1,     -- seconds between probes while punching
    punch_timeout = 5,        -- seconds before a punch gives up
    keepalive = 15,           -- seconds between keepalives once open
    lost_after = 3,           -- keepalives' worth of silence before "lost"
    detect_retry = 0.2,       -- seconds between repeats of a question to the reflector
    detect_wait = 1,          -- seconds before a question counts as unanswered
}

-- {{{ packets
nat.KIND = { BIND = 1, BOUND = 2, PROBE = 3, ACK = 4, KEEPALIVE = 5 }
nat.FLAG = { ALT_PORT = 1, ALT_IP = 2 }
local KIND_NAME = {}
for k, v in pairs(nat.KIND) do KIND_NAME[v] = k end

local function u32(n)                  -- each byte % 256: wraps at 32 bits
    return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
end
local function u16(n) return string.char(math.floor(n / 256) % 256, n % 256) end
local function read_u32(s, i)
    local a, b, c, d = s:byte(i, i + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
end
local function read_u16(s, i)
    local a, b = s:byte(i, i + 1)
    return a * 256 + b
end
local function ip4(s)
    local a, b, c, d = (s or ""):match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
    if not (a and a < 256 and b < 256 and c < 256 and d < 256) then return string.char(0, 0, 0, 0) end
    return string.char(a, b, c, d)
end
local function read_ip4(s, i) return table.concat({ s:byte(i, i + 3) }, ".") end

-- A packet as bytes. `p.kind` is a name of nat.KIND; BIND carries
-- `flags`, BOUND `ip`, `port`, `alt_port` and `alt_ip` (the reflector's
-- other port and address, "0.0.0.0" when it has none), PROBE and ACK a
-- `seq`.
function nat.encode(p)
    local kind = nat.KIND[p.kind]
    if not kind then error("nat: no packet kind " .. tostring(p.kind), 0) end
    local body = ""
    if kind == nat.KIND.BIND then body = string.char((p.flags or 0) % 256)
    elseif kind == nat.KIND.BOUND then body = ip4(p.ip) .. u16(p.port or 0) .. u16(p.alt_port or 0) .. ip4(p.alt_ip)
    elseif kind == nat.KIND.PROBE or kind == nat.KIND.ACK then body = u32(p.seq or 0) end
    return "WN" .. string.char(kind) .. u32(p.token or 0) .. body
end

local BODY = { [1] = 1, [2] = 12, [3] = 4, [4] = 4, [5] = 0 }

-- The packet in `s`, or nil when it is not one of ours (a game's own
-- datagram, or one cut short).
function nat.decode(s)
    if type(s) ~= "string" or #s < 7 or s:sub(1, 2) ~= "WN" then return nil end
    local kind = s:byte(3)
    if not KIND_NAME[kind] or #s ~= 7 + BODY[kind] then return nil end
    local p = { kind = KIND_NAME[kind], token = read_u32(s, 4) }
    if kind == nat.KIND.BIND then p.flags = s:byte(8)
    elseif kind == nat.KIND.BOUND then
        p.ip, p.port, p.alt_port, p.alt_ip = read_ip4(s, 8), read_u16(s, 12), read_u16(s, 14), read_ip4(s, 16)
    elseif kind == nat.KIND.PROBE or kind == nat.KIND.ACK then p.seq = read_u32(s, 8) end
    return p
end
-- }}}

local function default_clock()
    local ok, socket = pcall(require, "socket")
    if ok then return socket.gettime end
    return os.time
end

local function merged(options)
    local o = {}
    for k, v in pairs(nat.DEFAULTS) do o[k] = v end
    for k, v in pairs(options or {}) do o[k] = v end
    o.clock = o.clock or default_clock()
    return o
end

-- {{{ the reflector
-- `endpoints.main` takes the questions; `endpoints.alt_port` (same
-- address, another port) and `endpoints.alt_ip` (another address) answer
-- the ones that ask for it. Without alt_ip, a question asking for it gets
-- no answer, which the detector reads as "no", so it never asks.
local Reflector = {}
Reflector.__index = Reflector

function nat.reflector(endpoints)
    if not (endpoints and endpoints.main and endpoints.alt_port) then
        error("nat: a reflector needs a main endpoint and one on another port", 0)
    end
    local self = setmetatable({ ep = endpoints, answered = 0 }, Reflector)
    local main_ip, main_port = endpoints.main:local_address()
    local _, alt_port = endpoints.alt_port:local_address()
    self.alt_port = alt_port
    self.alt_ip = endpoints.alt_ip and (endpoints.alt_ip:local_address()) or "0.0.0.0"
    self.ip, self.port = main_ip, main_port
    return self
end

-- One datagram that came to the endpoint `which` ("main", "alt_port" or
-- "alt_ip"): a BIND is answered, anything else dropped.
function Reflector:handle(which, data, ip, port)
    local p = nat.decode(data)
    if not p or p.kind ~= "BIND" then return false end
    local from = self.ep[which]
    if bit.band(p.flags, nat.FLAG.ALT_IP) ~= 0 then from = self.ep.alt_ip
    elseif bit.band(p.flags, nat.FLAG.ALT_PORT) ~= 0 then from = self.ep.alt_port end
    if not from then return false end
    from:send(nat.encode({ kind = "BOUND", token = p.token, ip = ip, port = port,
        alt_port = self.alt_port, alt_ip = self.alt_ip }), ip, port)
    self.answered = self.answered + 1
    return true
end

-- Answers everything waiting on every endpoint; returns how many datagrams it read.
function Reflector:poll()
    local n = 0
    for _, which in ipairs({ "main", "alt_port", "alt_ip" }) do
        local ep = self.ep[which]
        while ep do
            local data, ip, port = ep:receive()
            if not data then break end
            n = n + 1
            self:handle(which, data, ip, port)
        end
    end
    return n
end

function Reflector:close()
    for _, ep in pairs(self.ep) do if ep.close then ep:close() end end
end
-- }}}

-- {{{ the detector
-- Asks the reflector at `server_ip`:`server_port` in turn:
--   1. "where am I?"                      no answer: blocked; same as my own address: open
--   2. "answer from your other address"   (only when it has one) answered: full cone
--   3. "answer from your other port"      answered: restricted cone, else port-restricted
--   4. "where am I?" to its other port    another outside port: symmetric
-- (3 comes before 4: once a datagram has gone to the other port, a
-- port-restricted router lets its answers in and would pass for a
-- restricted one.)
-- Without a second address a full cone can't be told from a restricted
-- one, and is reported as "restricted_cone" (both punch the same way).
local Detector = {}
Detector.__index = Detector

function nat.detector(endpoint, options)
    local o = merged(options)
    if not (o.server_ip and o.server_port) then error("nat: the detector needs server_ip and server_port", 0) end
    local self = setmetatable({ ep = endpoint, o = o, stage = 0, result = nil, token_base = o.token or math.random(1, 2 ^ 30) }, Detector)
    return self
end

local function ask(self, stage, port, flags)
    self.stage, self.asked_port, self.flags = stage, port, flags
    self.token = (self.token_base + stage) % 4294967296
    self.started, self.sent_at = self.o.clock(), nil
end

local function finish(self, result)
    self.result, self.stage = result, -1
    return result
end

-- The answer to the question asked, or nil.
local function answered(self, p, ip, port)
    if not p or p.kind ~= "BOUND" or p.token ~= self.token then return false end
    if ip ~= self.o.server_ip and ip ~= self.server_alt_ip then return false end
    return true
end

local function next_stage(self, got, p)
    local stage = self.stage
    if stage == 1 then
        if not got then return finish(self, "blocked") end
        self.mapped_ip, self.mapped_port = p.ip, p.port
        self.server_alt_port = p.alt_port
        self.server_alt_ip = p.alt_ip ~= "0.0.0.0" and p.alt_ip or nil
        local lip, lport = self.ep:local_address()
        if p.ip == lip and p.port == lport then return finish(self, "open") end
        if self.server_alt_ip then return ask(self, 2, self.o.server_port, nat.FLAG.ALT_IP) end
        return ask(self, 3, self.o.server_port, nat.FLAG.ALT_PORT)
    elseif stage == 2 then
        if got then return finish(self, "full_cone") end
        return ask(self, 3, self.o.server_port, nat.FLAG.ALT_PORT)
    elseif stage == 3 then
        self.cone = got and "restricted_cone" or "port_restricted"
        return ask(self, 4, self.server_alt_port, 0)
    elseif stage == 4 then
        if not got then return finish(self, "blocked") end
        if p.ip ~= self.mapped_ip or p.port ~= self.mapped_port then return finish(self, "symmetric") end
        return finish(self, self.cone)
    end
end

-- Moves the detection on: reads what came, repeats the question when
-- due. Returns the kind of NAT once known, nil until then. Datagrams that
-- aren't answers are handed to `options.other` if given, else dropped.
function Detector:step()
    if self.result then return self.result end
    if self.stage == 0 then ask(self, 1, self.o.server_port, 0) end
    while true do
        local data, ip, port = self.ep:receive()
        if not data then break end
        local p = nat.decode(data)
        if answered(self, p, ip, port) then
            next_stage(self, true, p)
            if self.result then return self.result end
        elseif self.o.other then self.o.other(data, ip, port) end
    end
    local now = self.o.clock()
    if now - self.started >= self.o.detect_wait then
        next_stage(self, false)
        if self.result then return self.result end
        now = self.o.clock()
    end
    if not self.sent_at or now - self.sent_at >= self.o.detect_retry then
        self.sent_at = now
        self.ep:send(nat.encode({ kind = "BIND", token = self.token, flags = self.flags }), self.o.server_ip, self.asked_port)
    end
    return nil
end

-- Blocking: detects through `options.endpoint` (or a fresh UDP socket on
-- `options.local_ip`, default 0.0.0.0) against `options.stun_server`
-- ("ip:port", a reflector of this module, not a public STUN server).
-- Returns the kind, the outside ip and port.
function nat.detect_type(options)
    local o = merged(options)
    if o.stun_server then
        local ip, port = o.stun_server:match("^([%d%.]+):(%d+)$")
        if not ip then error("nat: stun_server is ip:port, not " .. o.stun_server, 0) end
        o.server_ip, o.server_port = ip, tonumber(port)
    end
    local ep, own = o.endpoint, false
    if not ep then ep, own = nat.udp(o.local_ip or "0.0.0.0", o.local_port or 0), true end
    local d = nat.detector(ep, o)
    local result = d:step()
    while not result do
        if ep.wait then ep:wait(0.02) end
        result = d:step()
    end
    if own then ep:close() end
    return result, d.mapped_ip, d.mapped_port
end
-- }}}

-- {{{ the punch
-- Probes `remote_ip`:`remote_port` every probe_interval; answers the
-- other side's probes. Open ("established") when an answer to one of its
-- own probes comes back, "failed" after punch_timeout without one. Once
-- open, sends a keepalive when it has sent nothing for `keepalive`
-- seconds, and is "lost" after lost_after keepalives' worth of silence
-- (it keeps sending keepalives then, and is open again when the remote
-- is heard).
-- Probes from another port of the peer's address (a symmetric NAT gave
-- it a new one) move the remote there. Only packets carrying `token`
-- count, so two punches can share an endpoint.
local Punch = {}
Punch.__index = Punch

function nat.create_punch(options)
    local o = merged(options)
    if not (o.endpoint and o.remote_ip and o.remote_port) then
        error("nat: a punch needs endpoint, remote_ip and remote_port", 0)
    end
    local now = o.clock()
    return setmetatable({ o = o, ep = o.endpoint, token = (o.token or 0) % 4294967296,
        remote_ip = o.remote_ip, remote_port = o.remote_port, state = "punching",
        started = now, seq = 0, sent_at = nil, heard_at = now, inbox = {}, probes = 0 }, Punch)
end

local function send_to_remote(self, packet)
    self.sent_at = self.o.clock()
    self.ep:send(packet, self.remote_ip, self.remote_port)
end

function Punch:send_probe()
    self.seq = self.seq + 1
    self.probes = self.probes + 1
    send_to_remote(self, nat.encode({ kind = "PROBE", token = self.token, seq = self.seq }))
end

-- One datagram from `ip`:`port`: true when it was this punch's (and is
-- used up), false when it is someone else's or the game's.
function Punch:handle(data, ip, port)
    local p = nat.decode(data)
    if not p then
        if (self.state == "established" or self.state == "lost") and ip == self.remote_ip and port == self.remote_port then
            self.heard_at = self.o.clock()
            self.state = "established"
        end
        return false
    end
    if p.token ~= self.token or ip ~= self.remote_ip then return false end
    if self.state == "failed" then return true end
    if p.kind == "PROBE" then
        if port ~= self.remote_port then self.remote_port = port end
        self.heard_at = self.o.clock()
        self.ep:send(nat.encode({ kind = "ACK", token = self.token, seq = p.seq }), ip, port)
        return true
    end
    if port ~= self.remote_port then return true end
    self.heard_at = self.o.clock()
    if p.kind == "ACK" and self.state == "punching" then
        self.state = "established"
        self.established_at = self.heard_at
    elseif self.state == "lost" then
        self.state = "established"
    end
    return true
end

-- Sends what is due and moves the state on; returns the state.
function Punch:step()
    local now = self.o.clock()
    if self.state == "punching" then
        if now - self.started >= self.o.punch_timeout then
            self.state = "failed"
        elseif not self.sent_at or now - self.sent_at >= self.o.probe_interval then
            self:send_probe()
        end
    elseif self.state == "established" or self.state == "lost" then
        if self.state == "established" and now - self.heard_at >= self.o.keepalive * self.o.lost_after then
            self.state = "lost"
        end
        if now - self.sent_at >= self.o.keepalive then
            send_to_remote(self, nat.encode({ kind = "KEEPALIVE", token = self.token }))
        end
    end
    return self.state
end

-- For a punch that has its endpoint to itself: reads everything waiting,
-- keeps the game's datagrams from the remote for `receive`, then steps.
function Punch:poll()
    while true do
        local data, ip, port = self.ep:receive()
        if not data then break end
        if not self:handle(data, ip, port) and not nat.decode(data) and ip == self.remote_ip and port == self.remote_port then
            self.inbox[#self.inbox + 1] = data
        end
    end
    return self:step()
end

function Punch:established() return self.state == "established" end
function Punch:failed() return self.state == "failed" end
function Punch:get_socket() return self.ep end
function Punch:remote() return self.remote_ip, self.remote_port end

-- The game's own datagrams, once open (also while lost: they may get through).
function Punch:send(data)
    if self.state ~= "established" and self.state ~= "lost" then
        error("nat: the punch is " .. self.state .. ", not established", 0)
    end
    send_to_remote(self, data)
end

function Punch:receive()
    return table.remove(self.inbox, 1)
end
-- }}}

-- {{{ the session
-- Punches for a lobby of client.lua, sharing one endpoint. `options`:
-- `endpoint`, and the outside address the detector found as `mapped_ip`
-- and `mapped_port` (without them the matchmaking server fills in the
-- address it sees and the port is the endpoint's own, which is right for
-- an open machine or a NAT that keeps ports). Events through `on`:
-- "established" (player_id, punch), "failed" (player_id, punch), "lost"
-- (player_id, punch), "data" (player_id, data) for the game's datagrams.
--
-- A player calls `start()` to send its endpoint to the host; the host
-- answers each one it gets with its own and both punch at once. The token
-- both sides use is made from the game id and the player's id.
local Session = {}
Session.__index = Session

function nat.token(game_id, player_id)
    return (game_id * 4096 + player_id) % 4294967296
end

function nat.session(lobby, options)
    local o = merged(options)
    if not o.endpoint then error("nat: a session needs an endpoint", 0) end
    local self = setmetatable({ lobby = lobby, o = o, ep = o.endpoint, punches = {}, handlers = {} }, Session)
    self.listener = lobby:on("nat_punch", function(e) self:on_endpoint(e) end)
    return self
end

function Session:on(event, fn)
    self.handlers[event] = self.handlers[event] or {}
    table.insert(self.handlers[event], fn)
    return fn
end

local function emit(self, event, ...)
    for _, fn in ipairs(self.handlers[event] or {}) do fn(...) end
end

local function own_endpoint(self)
    local _, lport = self.ep:local_address()
    return self.o.mapped_ip or "", self.o.mapped_port or lport
end

function Session:start()
    if self.lobby.is_host then error("nat: the host waits for its players' endpoints", 0) end
    self.lobby:punch(own_endpoint(self))
end

function Session:on_endpoint(e)
    local lobby = self.lobby
    local player = lobby.is_host and e.player_id or lobby.player_id
    local old = self.punches[e.player_id]
    if old and old.state ~= "failed" and old.remote_ip == e.ip and old.remote_port == e.port then return end
    local p = nat.create_punch({ endpoint = self.ep, remote_ip = e.ip, remote_port = e.port,
        token = nat.token(lobby.game_id, player), clock = self.o.clock, probe_interval = self.o.probe_interval,
        punch_timeout = self.o.punch_timeout, keepalive = self.o.keepalive, lost_after = self.o.lost_after })
    p.player_id, p.reported = e.player_id, "punching"
    self.punches[e.player_id] = p
    if lobby.is_host then lobby:punch(self.o.mapped_ip or "", select(2, own_endpoint(self)), e.player_id) end
    p:step()
end

-- Reads the endpoint, hands each datagram to its punch, steps them all
-- and reports what changed.
function Session:step()
    while true do
        local data, ip, port = self.ep:receive()
        if not data then break end
        local taken = false
        for id, p in pairs(self.punches) do
            if p:handle(data, ip, port) then taken = true break end
        end
        if not taken and not nat.decode(data) then
            for id, p in pairs(self.punches) do
                if p.state == "established" and ip == p.remote_ip and port == p.remote_port then
                    emit(self, "data", id, data)
                    break
                end
            end
        end
    end
    for id, p in pairs(self.punches) do
        local state = p:step()
        if state ~= p.reported then
            p.reported = state
            if state ~= "punching" then emit(self, state, id, p) end
        end
    end
end

function Session:punch_for(player_id) return self.punches[player_id] end

function Session:close()
    self.lobby:off("nat_punch", self.listener)
end
-- }}}

-- {{{ the LuaSocket endpoint
-- A UDP socket bound to `ip`:`port` (port 0: any), never blocking.
function nat.udp(ip, port)
    local socket = require("socket")
    local u = assert(socket.udp())
    local ok, err = u:setsockname(ip or "0.0.0.0", port or 0)
    if not ok then u:close() error("nat: can't bind UDP " .. tostring(ip) .. ":" .. tostring(port) .. ": " .. tostring(err), 0) end
    u:settimeout(0)
    local ep = { socket = u }
    function ep:send(data, to_ip, to_port) return u:sendto(data, to_ip, to_port) end
    function ep:receive()
        local data, from_ip, from_port = u:receivefrom()
        if not data then return nil end
        return data, from_ip, from_port
    end
    function ep:local_address()
        local lip, lport = u:getsockname()
        return lip, tonumber(lport)
    end
    function ep:wait(seconds) socket.select({ u }, nil, seconds) end
    function ep:close() u:close() end
    return ep
end

-- A reflector on real sockets: `ip`:`port`, the same address one port up
-- (or any free port when port is 0), and `alt_ip`:`port` when given.
function nat.reflector_udp(ip, port, alt_ip)
    local main = nat.udp(ip, port)
    local _, bound = main:local_address()
    local ok, alt = pcall(nat.udp, ip, port ~= 0 and bound + 1 or 0)
    if not ok then main:close() error(alt, 0) end
    local eps = { main = main, alt_port = alt }
    if alt_ip then
        local ok2, a = pcall(nat.udp, alt_ip, bound)
        if not ok2 then main:close() alt:close() error(a, 0) end
        eps.alt_ip = a
    end
    local r = nat.reflector(eps)
    function r:sockets()
        local list = {}
        for _, ep in pairs(self.ep) do list[#list + 1] = ep.socket end
        return list
    end
    return r
end
-- }}}

return nat
