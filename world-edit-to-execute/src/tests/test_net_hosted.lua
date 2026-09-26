-- test_net_hosted.lua - the server on its own thread, through queues that can behave like a bad network (issue 803)
--
-- In plain terms: starts the server on a thread of its own, as offline play
-- will, and plays against it for real (real time, real threads, bytes
-- through queues). First a clean connection, then the same with each kind
-- of trouble a network brings: delay, lost messages, and a player whose
-- connection drops for a while.
--
-- These run in real time, about seven seconds in all. Bounds are loose so
-- a busy machine doesn't fail them; what they check is the shape (states
-- arrive, late ones late, lost ones missing, the game pauses and resumes).
--
-- Run with: luajit src/tests/test_net_hosted.lua [DIR]

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
package.cpath = "/home/ritz/programming/ai-stuff/libs/lua/effil-jit/build/?.so;" .. package.cpath

local effil = require("effil")
local messages = require("net.messages")
local clock = require("net.clock")
local hosted = require("net.hosted")

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

-- {{{ local function play(h, players, ms, each)
-- Plays for `ms` milliseconds: every player beats every 16 ms (their
-- newest tick) and reads what has arrived. `each(p, name, message, now)` is
-- called for every message received. Returns what each player received:
-- { [p] = { {name, m, at}, ... } }.
local function play(h, players, ms, each)
    local ends, got, newest = {}, {}, {}
    for p = 0, players - 1 do ends[p], got[p], newest[p] = h:player(p), {}, 0 end
    local start = clock.now_ms()
    local next_beat = start
    while clock.now_ms() - start < ms do
        local now = clock.now_ms()
        for p = 0, players - 1 do
            for _, bytes in ipairs(ends[p]:take()) do
                local name, m = messages.decode(bytes)
                if name == "unit_states" then newest[p] = math.max(newest[p], m.tick) end
                table.insert(got[p], { name = name, m = m, at = now - start })
                if each then each(p, name, m, now - start, ends[p]) end
            end
        end
        if now >= next_beat then
            for p = 0, players - 1 do ends[p]:send(messages.encode("heard", { tick = newest[p] })) end
            next_beat = next_beat + 16
        end
        clock.sleep_ms(1)
    end
    return got
end
-- }}}

-- {{{ local function of(list, name)
-- The received entries of one message name.
local function of(list, name)
    local out = {}
    for _, e in ipairs(list) do if e.name == name then out[#out + 1] = e end end
    return out
end
-- }}}

print("\n=== Resting really rests ===")
do
    -- effil.sleep(1, "ms") returned at once, and the server's thread spun
    -- a whole core; the server now rests through the operating system
    local t = clock.now_ms()
    for _ = 1, 50 do clock.sleep_ms(1) end
    local took = clock.now_ms() - t
    test("fifty 1 ms rests take at least 50 ms", took >= 50, string.format("%.2f ms", took))
end

print("\n=== A clean connection ===")
do
    local h = hosted.start({ dir = DIR, players = 1, sim = "net.circling_sim", sim_config = { units = 64, players = 1, deaths = { [10] = 5 } } })
    local order_sent = false
    local got = play(h, 1, 800, function(p, name, m, at, me)
        if name == "unit_states" and m.tick >= 5 and not order_sent then
            order_sent = true
            me:send(messages.encode("order", { order_id = 9, given_tick = m.tick, kind = messages.order_kind.move,
                target_x = 1, target_y = 2, target_unit = 0, units = { { id = 1 } } }))
        end
    end)
    local report = h:stop()
    local states = of(got[0], "unit_states")
    test("states arrive, about 62.5 a second", #states >= 35 and #states <= 55, #states .. " in 0.8 s")
    local rising = true
    for i = 2, #states do if states[i].m.tick <= states[i - 1].m.tick then rising = false end end
    test("each state's tick is newer than the last", rising)
    test("every state has the 64 units, then 63 once one died", #states[1].m.units == 64 and #states[#states].m.units == 63)
    local deaths = of(got[0], "events")
    test("the death arrives as an event at its tick", #deaths == 1 and deaths[1].m.events[1].tick == 10 and deaths[1].m.events[1].unit == 5)
    local answers = of(got[0], "order_answer")
    test("the order is answered, kept", #answers == 1 and answers[1].m.order_id == 9 and answers[1].m.accepted == 1)
    test("the server refused nothing", report.refused == 0, report.why)
    test("the server ran its ticks", report.ticks >= 40, tostring(report.ticks))
end

print("\n=== Delay: 100 ms toward the player ===")
do
    local h = hosted.start({ dir = DIR, players = 1, sim = "net.circling_sim", sim_config = { units = 8, players = 1 },
        to_client = { [0] = { delay_ms = 100 } } })
    local got = play(h, 1, 600)
    h:stop()
    local states = of(got[0], "unit_states")
    test("nothing arrives in the first 100 ms", #states > 0 and states[1].at >= 100, #states > 0 and string.format("first at %.0f ms", states[1].at) or "none")
    -- a state for tick N is made at about N*16 ms and arrives 100 ms later
    local late = states[#states].at - states[#states].m.tick * 16
    test("each arrives about 100 ms after it was made", late >= 90 and late <= 150, string.format("%.0f ms", late))
end

print("\n=== Loss: half the messages toward the player ===")
do
    local h = hosted.start({ dir = DIR, players = 1, sim = "net.circling_sim", sim_config = { units = 8, players = 1 },
        to_client = { [0] = { loss = 0.5, seed = 11 } } })
    local got = play(h, 1, 800)
    local report = h:stop()
    local states = of(got[0], "unit_states")
    local share = #states / report.ticks
    test("about half the states arrive", share > 0.3 and share < 0.7, string.format("%d of %d", #states, report.ticks))
    test("the server counted the lost ones", report.lost > 0)
end

print("\n=== A player's connection drops for a while ===")
do
    -- player 1's messages don't reach the server from 0.3 s to 1.6 s; the
    -- starting tolerance (2 s) rides that out, so the game never pauses
    local h = hosted.start({ dir = DIR, players = 2, sim = "net.circling_sim", sim_config = { units = 8, players = 2 },
        to_server = { [1] = { silent = { { 300, 1600 } } } } })
    local got = play(h, 2, 2000)
    h:stop()
    test("within the 2 s tolerance: never paused", #of(got[0], "waiting") == 0)

    -- the same drop, with player 0's slider at 0.5 s: now it pauses, and
    -- resumes when player 1 is heard again
    h = hosted.start({ dir = DIR, players = 2, sim = "net.circling_sim", sim_config = { units = 8, players = 2 },
        to_server = { [1] = { silent = { { 300, 1600 } } } } })
    local slider_sent = false
    got = play(h, 2, 2400, function(p, name, m, at, me)
        if p == 0 and not slider_sent then
            slider_sent = true
            me:send(messages.encode("tolerance", { ms = 500 }))
        end
    end)
    h:stop()
    local waits = of(got[0], "waiting")
    local paused_at, resumed_at
    for _, w in ipairs(waits) do
        if w.m.paused == 1 and not paused_at then paused_at = w end
        if w.m.paused == 0 then resumed_at = w end
    end
    test("everyone is told the tolerance in force", #of(got[1], "tolerances") >= 1 and of(got[1], "tolerances")[1].m.in_force_ms == 500)
    test("paused about 0.5 s into the silence", paused_at and paused_at.at >= 750 and paused_at.at <= 1000 and paused_at.m.silent[1].player == 1,
        paused_at and string.format("at %.0f ms", paused_at.at) or "never")
    test("resumed once player 1 is heard again", resumed_at and resumed_at.at >= 1600 and resumed_at.at <= 1800,
        resumed_at and string.format("at %.0f ms", resumed_at.at) or "never")
    -- nothing rewound: the first state after the pause is the tick after the one it paused on
    local after
    for _, e in ipairs(got[0]) do
        if e.name == "unit_states" and resumed_at and e.at >= resumed_at.at then after = e; break end
    end
    test("play resumes from the paused tick", after and after.m.tick == paused_at.m.tick + 1,
        after and (after.m.tick .. " after pausing on " .. paused_at.m.tick) or "no state after")
end

print(string.format("\n%d/%d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
