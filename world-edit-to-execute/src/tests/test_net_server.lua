-- test_net_server.lua - the server's rules: ticks, orders, pausing for a silent player, sliders, the drop vote (issue 803)
--
-- In plain terms: runs the server against a made-up game and a made-up
-- clock, playing the players by hand, and checks each rule decided with
-- the owner: nothing is rewound after a pause, the strictest slider is in
-- force, and a silent player is dropped only by enough votes after the
-- countdown.
--
-- Run with: luajit src/tests/test_net_server.lua [DIR]

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local messages = require("net.messages")
local server = require("net.server")

-- {{{ Test utilities
local test_count, pass_count = 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end
-- }}}

-- {{{ local function make_game(players)
-- A made-up game: one unit per player, which moves one step a tick. It
-- keeps orders it is given and refuses orders for the unit numbered 99.
-- Returns the server and every player's inbox (decoded messages, in order).
local function make_game(players)
    local sim = { orders = {} }
    local steps = 0
    function sim.order(player, order, tick)
        if order.units[1].id == 99 then return false, messages.refusal.unknown_unit end
        sim.orders[#sim.orders + 1] = { player = player, order = order, tick = tick }
        return true
    end
    function sim.tick(tick)
        steps = steps + 1
        if tick == 3 then return { { kind = messages.event_kind.death, tick = 3, unit = 7, other = 0 } } end
        return {}
    end
    function sim.visible(player)
        return { { id = player + 1, x = steps, y = 0, z = 0, vx = 62.5, vy = 0, vz = 0, facing = 0, anim = 1, anim_phase = 0, radius = 0.5, team = player } }
    end
    local inbox = {}
    for p = 0, players - 1 do inbox[p] = {} end
    local s = server.new(sim, players, function(p, bytes)
        local name, m = messages.decode(bytes)
        table.insert(inbox[p], { name = name, m = m })
    end, 0)
    return s, inbox, sim
end
-- }}}

-- {{{ local function last(inbox, name)
-- The newest message of that name in an inbox.
local function last(inbox, name)
    for i = #inbox, 1, -1 do if inbox[i].name == name then return inbox[i].m end end
end
-- }}}

-- {{{ local function count(inbox, name)
local function count(inbox, name)
    local n = 0
    for _, e in ipairs(inbox) do if e.name == name then n = n + 1 end end
    return n
end
-- }}}

-- {{{ local function beat(s, players, now)
-- The listed players send a heard beat at `now`.
local function beat(s, players, now)
    for _, p in ipairs(players) do s:receive(p, messages.encode("heard", { tick = s.tick }), now) end
end
-- }}}

print("\n=== Ticks ===")
do
    local s, inbox = make_game(2)
    for now = 0, 160, 16 do beat(s, { 0, 1 }, now); s:step(now) end
    test("62.5 ticks a second: 160 ms is 10 ticks", s.tick == 10, tostring(s.tick))
    test("every player gets a state every tick", count(inbox[0], "unit_states") == 10 and count(inbox[1], "unit_states") == 10)
    test("each state carries its tick", last(inbox[0], "unit_states").tick == 10)
    test("each player sees their own units", last(inbox[1], "unit_states").units[1].id == 2)
    test("events go out on the tick they happen", count(inbox[0], "events") == 1 and last(inbox[0], "events").events[1].tick == 3)
end

print("\n=== Orders ===")
do
    local s, inbox, sim = make_game(1)
    for now = 0, 80, 16 do beat(s, { 0 }, now); s:step(now) end
    local order = { order_id = 41, given_tick = 5, kind = messages.order_kind.move, target_x = 10, target_y = 20, target_unit = 0, units = { { id = 1 } } }
    s:receive(0, messages.encode("order", order), 81)
    local answer = last(inbox[0], "order_answer")
    test("a kept order is answered with its id", answer.order_id == 41 and answer.accepted == 1)
    test("it takes effect on the next tick", answer.effect_tick == s.tick + 1 and sim.orders[1].tick == s.tick + 1)
    order.order_id, order.units = 42, { { id = 99 } }
    s:receive(0, messages.encode("order", order), 82)
    answer = last(inbox[0], "order_answer")
    test("a refused order is answered with the reason", answer.order_id == 42 and answer.accepted == 0 and answer.refusal == messages.refusal.unknown_unit)
end

print("\n=== A silent player pauses everyone; nothing is rewound ===")
do
    local s, inbox = make_game(2)
    local now = 0
    -- player 1 goes quiet after the first beat; player 0 keeps beating
    beat(s, { 0, 1 }, 0)
    while now <= 2000 do beat(s, { 0 }, now); s:step(now); now = now + 16 end
    local tick_before = s.tick
    test("not paused within the starting tolerance (2 s)", not s.paused)
    beat(s, { 0 }, 2016); s:step(2016)
    test("paused once silent past it", s.paused)
    local w = last(inbox[0], "waiting")
    test("everyone is told who is silent", w.paused == 1 and #w.silent == 1 and w.silent[1].player == 1 and last(inbox[1], "waiting") ~= nil)
    test("the countdown starts at 30 s", w.silent[1].countdown_ms == 30000)
    test("the dialog opens with every player's slider", last(inbox[0], "tolerances") ~= nil and #last(inbox[0], "tolerances").players == 2)
    for t = 2032, 5000, 16 do beat(s, { 0 }, t); s:step(t) end
    test("no ticks while paused", s.tick == tick_before, s.tick .. " vs " .. tick_before)
    local order = { order_id = 1, given_tick = 1, kind = 1, target_x = 0, target_y = 0, target_unit = 0, units = { { id = 1 } } }
    s:receive(0, messages.encode("order", order), 5001)
    test("orders are refused while paused", last(inbox[0], "order_answer").refusal == messages.refusal.paused)
    beat(s, { 0, 1 }, 5010); s:step(5010)
    test("the silent player is heard: play resumes", not s.paused and last(inbox[0], "waiting").paused == 0)
    s:step(5026)
    test("from the tick it paused on, not from the clock", s.tick == tick_before + 1, s.tick .. " vs " .. tick_before + 1)
end

print("\n=== Sliders: the strictest is in force ===")
do
    local s, inbox = make_game(3)
    s:receive(1, messages.encode("tolerance", { ms = 500 }), 0)
    local t = last(inbox[2], "tolerances")
    test("everyone sees everyone's slider", t and #t.players == 3 and t.players[2].ms == 500 and t.players[1].ms == 2000)
    test("the lowest is in force", t.in_force_ms == 500 and s:tolerance_in_force() == 500)
    beat(s, { 0, 1 }, 400); s:step(400)
    beat(s, { 0, 1 }, 516); s:step(516)
    test("so a half-second silence pauses the game", s.paused)
    s:receive(0, messages.encode("tolerance", { ms = 100 }), 517)
    test("a value off the slider is refused", s.players[0].tolerance_ms == 2000 and s.refused[#s.refused].why:find("outside the slider"))
end

print("\n=== The drop vote ===")
test("votes needed: 1 of 1, 1 of 2, 2 of 3, 3 of 4, 6 of 8",
    server.votes_needed(1) == 1 and server.votes_needed(2) == 1 and server.votes_needed(3) == 2
    and server.votes_needed(4) == 3 and server.votes_needed(8) == 6)
do
    local s, inbox = make_game(4)
    beat(s, { 0, 1, 2, 3 }, 0)
    local now = 0
    while now <= 2100 do beat(s, { 0, 1, 2 }, now); s:step(now); now = now + 16 end
    test("player 3 silent: paused", s.paused)
    s:receive(0, messages.encode("drop_vote", { player = 3 }), now)
    test("a vote before the countdown ends is refused", s.refused[#s.refused].why:find("countdown"))
    while now <= 2100 + 30000 do beat(s, { 0, 1, 2 }, now); s:step(now); now = now + 16 end
    s:receive(0, messages.encode("drop_vote", { player = 0 }), now)
    test("a vote on oneself is refused", s.refused[#s.refused].why:find("themselves"))
    s:receive(0, messages.encode("drop_vote", { player = 3 }), now)
    local v = last(inbox[1], "votes")
    test("one vote of the two needed (3 connected)", v.needed == 2 and v.silent[1].votes == 1 and not s.players[3].dropped)
    s:receive(0, messages.encode("drop_vote", { player = 3 }), now)
    test("the same voter twice counts once", last(inbox[1], "votes").silent[1].votes == 1)
    s:receive(1, messages.encode("drop_vote", { player = 3 }), now)
    test("the second vote drops them", s.players[3].dropped)
    s:step(now + 1)
    test("and with no one silent, play resumes", not s.paused)
end

print("\n=== A clock with fractions of a millisecond ===")
do
    -- the real clock (net/clock.lua) has fractions; the waiting message
    -- carries whole milliseconds, and once refused to encode them
    local s, inbox = make_game(2)
    local ok, why = pcall(function()
        for now = 0.37, 2600, 16.01 do beat(s, { 0 }, now); s:step(now) end
    end)
    test("the waiting news goes out with a fractional clock", ok and s.paused and last(inbox[0], "waiting") ~= nil, tostring(why))
end

print("\n=== What a client may not send ===")
do
    local s = make_game(1)
    beat(s, { 0 }, 0)
    s:receive(0, "\255garbage", 1000)
    test("bytes that aren't a message are refused", s.refused[#s.refused].why:find("no message has type"))
    test("and don't count as hearing from the player", s.players[0].heard_ms == 0)
    s:receive(0, messages.encode("votes", { needed = 1, silent = {} }), 1001)
    test("a message only the server sends is refused", s.refused[#s.refused].why:find("doesn't send votes"))
end

print(string.format("\n%d/%d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
