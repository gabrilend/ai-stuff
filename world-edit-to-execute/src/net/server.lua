--[[
server.lua - the one true game, and the rules for talking to its players (issue 803)

What this is: the server's side of play. It owns the simulation, advances
it 62.5 ticks a second, takes players' orders, and sends each player what
they can see. It also keeps track of who it has heard from lately and
pauses everyone when a player goes silent for too long, running the
waiting dialog's countdown, sliders and drop vote.

It is plain logic with no threads, sockets or clock of its own: whoever
runs it calls `receive` with each arriving message and `step` with the
time, and gives it a function to send bytes with. So the same server runs
inside the client, in a test with a made-up clock, or later behind a real
network.

The simulation plugs in through three functions, so this file knows
nothing about units:
  sim.order(player, order, tick) -> accepted (bool), refusal (a messages.refusal number)
  sim.tick(tick) -> events (a list of {kind, tick, unit, other})
  sim.visible(player) -> unit records (as in the unit_states message)

The rules, as decided with the owner (2026-09-25):
  - nothing is rewound: a silent player pauses the game, and play resumes
    from the tick it paused on;
  - each player's tolerance (seconds of silence before the game pauses) is
    their own slider, 0.25 to 10 s, starting at 2 s; the lowest is in force;
  - after a 30-second countdown, the players still connected vote; a drop
    needs three quarters of them, rounded down, and at least one vote.
]]

local messages = require("net.messages")

local server = {}
server.__index = server

-- {{{ The numbers (changes to these go in docs/balance-updates.md)
server.TICK_MS = 16                 -- 62.5 ticks a second
server.TOLERANCE_START_MS = 2000
server.TOLERANCE_LEAST_MS = 250
server.TOLERANCE_MOST_MS = 10000
server.COUNTDOWN_MS = 30000         -- from a player's silence pausing the game to their drop vote opening
server.WAITING_EVERY_MS = 100       -- how often the waiting dialog's news is sent while paused
-- }}}

-- {{{ function server.votes_needed(connected)
-- Three quarters of the players still connected, rounded down, and never
-- fewer than one: with one player left, three quarters rounds down to zero,
-- which would drop the silent player with nobody asking.
function server.votes_needed(connected)
    return math.max(1, math.floor(connected * 3 / 4))
end
-- }}}

-- {{{ function server.new(sim, players, send, now_ms)
-- `players`: how many (ids 0 .. players-1). `send(player, bytes)` delivers
-- a message to one player. Everyone counts as heard at the start.
function server.new(sim, players, send, now_ms)
    local s = setmetatable({
        sim = sim, send_bytes = send,
        tick = 0, next_tick_ms = now_ms + server.TICK_MS,
        paused = false, paused_since_ms = 0, last_waiting_ms = -math.huge,
        players = {},     -- by id: { heard_ms, tolerance_ms, dropped, silent_since_ms }
        votes = {},       -- by silent player: { [voter] = true }
        refused = {},     -- messages refused from players: { player, why }
    }, server)
    for p = 0, players - 1 do
        s.players[p] = { heard_ms = now_ms, tolerance_ms = server.TOLERANCE_START_MS, dropped = false }
    end
    return s
end
-- }}}

-- {{{ local function each_player(s)
-- Iterates the players still in the game, in id order.
local function each_player(s)
    local p = -1
    return function()
        repeat p = p + 1 until s.players[p] == nil or not s.players[p].dropped
        if s.players[p] then return p, s.players[p] end
    end
end
-- }}}

-- {{{ function server:send(player, name, message)
function server:send(player, name, message)
    self.send_bytes(player, messages.encode(name, message))
end
-- }}}

-- {{{ function server:broadcast(name, message)
function server:broadcast(name, message)
    local bytes = messages.encode(name, message)
    for p in each_player(self) do self.send_bytes(p, bytes) end
end
-- }}}

-- {{{ function server:tolerance_in_force()
-- The lowest slider among the players still in the game.
function server:tolerance_in_force()
    local least = math.huge
    for _, pl in each_player(self) do least = math.min(least, pl.tolerance_ms) end
    return least
end
-- }}}

-- {{{ function server:silent_players(now_ms)
-- The players not heard from for longer than the tolerance in force.
function server:silent_players(now_ms)
    local limit, silent = self:tolerance_in_force(), {}
    for p, pl in each_player(self) do
        if now_ms - pl.heard_ms > limit then silent[#silent + 1] = p end
    end
    return silent
end
-- }}}

-- {{{ function server:connected_count(now_ms)
-- Players in the game who aren't silent: the ones who may vote.
function server:connected_count(now_ms)
    local n = 0
    local limit = self:tolerance_in_force()
    for _, pl in each_player(self) do
        if now_ms - pl.heard_ms <= limit then n = n + 1 end
    end
    return n
end
-- }}}

-- {{{ The client messages the server takes, as a dispatch table
-- Each: function(self, player, message, now_ms). Anything else a client
-- sends is refused.
local takes = {}

-- {{{ takes.heard
-- Only the fact of hearing matters; every well-formed message counts.
function takes.heard() end
-- }}}

-- {{{ takes.order
-- Kept or refused by the simulation; takes effect on the next tick.
-- While paused, every order is refused: no tick will come to carry it.
function takes.order(self, player, order)
    local accepted, refusal
    if self.paused then
        accepted, refusal = false, messages.refusal.paused
    else
        accepted, refusal = self.sim.order(player, order, self.tick + 1)
    end
    self:send(player, "order_answer", {
        order_id = order.order_id, accepted = accepted and 1 or 0,
        effect_tick = self.tick + 1, refusal = accepted and messages.refusal.none or refusal,
    })
end
-- }}}

-- {{{ takes.tolerance
-- A slider moved. Outside the range, the message is refused (the slider
-- can't produce it), not moved to the nearest end.
function takes.tolerance(self, player, message)
    if message.ms < server.TOLERANCE_LEAST_MS or message.ms > server.TOLERANCE_MOST_MS then
        self.refused[#self.refused + 1] = { player = player, why = "tolerance " .. message.ms .. " ms is outside the slider" }
        return
    end
    self.players[player].tolerance_ms = message.ms
    local list = {}
    for p, pl in each_player(self) do list[#list + 1] = { player = p, ms = pl.tolerance_ms } end
    self:broadcast("tolerances", { in_force_ms = self:tolerance_in_force(), players = list })
end
-- }}}

-- {{{ takes.drop_vote
-- Counted only while paused, for a player whose countdown has run out,
-- from a voter who is connected. One vote per voter per silent player.
function takes.drop_vote(self, player, message, now_ms)
    local target = self.players[message.player]
    local why
    if player == message.player then why = "a player can't vote on themselves"
    elseif not self.paused then why = "no game is paused"
    elseif not target or target.dropped then why = "player " .. message.player .. " isn't in the game"
    elseif not target.silent_since_ms then why = "player " .. message.player .. " isn't silent"
    elseif now_ms - target.silent_since_ms < server.COUNTDOWN_MS then why = "the countdown for player " .. message.player .. " hasn't run out" end
    if why then
        self.refused[#self.refused + 1] = { player = player, why = why }
        return
    end
    self.votes[message.player] = self.votes[message.player] or {}
    self.votes[message.player][player] = true
    self:count_votes(now_ms)
end
-- }}}
-- }}}

-- {{{ function server:receive(player, bytes, now_ms)
-- One message from a player. A message that can't be decoded, or isn't one
-- a client sends, is refused and recorded; it doesn't count as hearing.
function server:receive(player, bytes, now_ms)
    local pl = self.players[player]
    if not pl or pl.dropped then return end
    local ok, name, message = pcall(messages.decode, bytes)
    if not ok then
        self.refused[#self.refused + 1] = { player = player, why = name }
        return
    end
    if not takes[name] then
        self.refused[#self.refused + 1] = { player = player, why = "a client doesn't send " .. name }
        return
    end
    pl.heard_ms = now_ms
    takes[name](self, player, message, now_ms)
end
-- }}}

-- {{{ function server:count_votes(now_ms)
-- Drops every silent player with enough votes, then tells everyone the
-- count. A drop can end the pause.
function server:count_votes(now_ms)
    local needed = server.votes_needed(self:connected_count(now_ms))
    for target, voters in pairs(self.votes) do
        local n = 0
        for voter in pairs(voters) do
            if not self.players[voter].dropped then n = n + 1 end
        end
        if n >= needed then
            self.players[target].dropped = true
            self.votes[target] = nil
        end
    end
    local list = {}
    for p, pl in each_player(self) do
        if pl.silent_since_ms then
            local n = 0
            for _ in pairs(self.votes[p] or {}) do n = n + 1 end
            list[#list + 1] = { player = p, votes = n }
        end
    end
    self:broadcast("votes", { needed = needed, silent = list })
end
-- }}}

-- {{{ function server:send_waiting(now_ms)
function server:send_waiting(now_ms)
    local list = {}
    for p, pl in each_player(self) do
        if pl.silent_since_ms then
            list[#list + 1] = {
                -- whole milliseconds: the clock has fractions, the message doesn't
                player = p, silent_ms = math.floor(now_ms - pl.heard_ms),
                countdown_ms = math.max(0, math.floor(server.COUNTDOWN_MS - (now_ms - pl.silent_since_ms))),
            }
        end
    end
    self:broadcast("waiting", { tick = self.tick, paused = self.paused and 1 or 0, silent = list })
    self.last_waiting_ms = now_ms
end
-- }}}

-- {{{ function server:step(now_ms)
-- Brings the game up to `now_ms`. Two paths each call:
--   someone is silent -> pause (or stay paused), send the waiting news
--   no one is        -> resume if paused, then run every tick now due
function server:step(now_ms)
    local silent = self:silent_players(now_ms)
    for _, pl in each_player(self) do
        local is_silent = now_ms - pl.heard_ms > self:tolerance_in_force()
        -- the countdown starts when a player's silence joins the pause
        if is_silent and not pl.silent_since_ms then pl.silent_since_ms = now_ms end
        if not is_silent then pl.silent_since_ms = nil end
    end
    if #silent > 0 then
        if not self.paused then
            self.paused, self.paused_since_ms = true, now_ms
            self:send_waiting(now_ms)
        elseif now_ms - self.last_waiting_ms >= server.WAITING_EVERY_MS then
            self:send_waiting(now_ms)
        end
        return
    end
    if self.paused then
        self.paused = false
        self.votes = {}
        self.next_tick_ms = now_ms + server.TICK_MS   -- the pause's time is not made up
        self:send_waiting(now_ms)
    end
    while now_ms >= self.next_tick_ms do
        self.tick = self.tick + 1
        self.next_tick_ms = self.next_tick_ms + server.TICK_MS
        local events = self.sim.tick(self.tick)
        for p in each_player(self) do
            self:send(p, "unit_states", { tick = self.tick, units = self.sim.visible(p) })
            if #events > 0 then self:send(p, "events", { tick = self.tick, events = events }) end
        end
    end
end
-- }}}

return server
