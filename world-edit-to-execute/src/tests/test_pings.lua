-- test_pings.lua - minimap pings: the ping messages, the server sending them to allies only, the trigger natives, and how a ping looks (issue 507f)
--
-- In plain terms: a player pings a point and the test checks who hears of
-- it; a script pings the minimap and the test checks what the local
-- player is shown; then it checks a ping's colour, fading and rings over
-- its life.
--
-- Run with: luajit src/tests/test_pings.lua [DIR]

local DIR = arg[1] or (arg[0] or ""):match("^(.*)/src/tests/[^/]*$")
    or ((arg[0] or ""):match("^src/tests/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local messages = require("net.messages")
local server = require("net.server")
local vm = require("jass.vm")
local pings = require("ui.wc3.pings")

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

local function section(name) print("\n=== " .. name .. " ===") end

local function near(a, b) return a ~= nil and b ~= nil and math.abs(a - b) < 1e-3 end
-- }}}

-- {{{ local function make_game(players, allied)
-- A made-up game that does nothing but say who is allied. Returns the
-- server and every player's inbox (decoded pinged messages only).
local function make_game(players, allied)
    local sim = { allied = allied }
    function sim.order() return true end
    function sim.tick() return {} end
    function sim.visible() return {} end
    local inbox = {}
    for p = 0, players - 1 do inbox[p] = {} end
    local s = server.new(sim, players, function(p, bytes)
        local name, m = messages.decode(bytes)
        if name == "pinged" then table.insert(inbox[p], m) end
    end, 0)
    return s, inbox
end

local function ping(s, player, x, y, now)
    s:receive(player, messages.encode("ping", { x = x, y = y }), now)
end
-- }}}

section("The messages")
do
    local name, m = messages.decode(messages.encode("ping", { x = -1536.5, y = 2048.25 }))
    test("a ping comes back as a ping", name == "ping")
    test("at its point", m.x == -1536.5 and m.y == 2048.25)
    name, m = messages.decode(messages.encode("pinged", { tick = 950, player = 2, x = 3.5, y = -4 }))
    test("a pinged comes back as pinged", name == "pinged")
    test("with tick, player and point", m.tick == 950 and m.player == 2 and m.x == 3.5 and m.y == -4)
end

section("Only allies hear of a ping")
do
    -- 0 and 2 are allies; 1 and 3 are allied to each other
    local function allied(a, b) return a % 2 == b % 2 end
    local s, inbox = make_game(4, allied)
    s.tick = 17
    ping(s, 0, 100, 200, 0)
    test("the pinger hears of their own ping", #inbox[0] == 1)
    test("their ally hears of it", #inbox[2] == 1)
    test("an enemy does not", #inbox[1] == 0)
    test("nor the other enemy", #inbox[3] == 0)
    local m = inbox[2][1]
    test("it says who pinged", m and m.player == 0)
    test("where", m and m.x == 100 and m.y == 200)
    test("and on which tick", m and m.tick == 17)
    test("nothing was refused", #s.refused == 0)
end

do
    local s, inbox = make_game(3, function(a, b) return a ~= b end)
    ping(s, 1, 5, 5, 0)
    test("allied to everyone: everyone hears", #inbox[0] == 1 and #inbox[1] == 1 and #inbox[2] == 1)
end

do
    local s, inbox = make_game(3, nil)
    ping(s, 1, 5, 5, 0)
    test("a game that says nothing of allies: only the pinger hears", #inbox[1] == 1)
    test("no one else", #inbox[0] == 0 and #inbox[2] == 0)
end

do
    local s, inbox = make_game(3, function() return true end)
    s.players[2].dropped = true
    ping(s, 0, 1, 1, 0)
    test("a dropped player hears nothing", #inbox[2] == 0 and #inbox[1] == 1)
    ping(s, 2, 1, 1, 1000)
    test("and a dropped player's ping goes nowhere", #inbox[0] == 1 and #inbox[1] == 1)
end

section("Pinging too fast, and at no point")
do
    local s, inbox = make_game(2, function() return true end)
    ping(s, 0, 1, 1, 1000)
    ping(s, 0, 2, 2, 1000 + server.PING_EVERY_MS - 1)
    test("a second ping sooner than PING_EVERY_MS is refused", #inbox[1] == 1 and #s.refused == 1)
    test("saying why", s.refused[1] and s.refused[1].why:find("faster", 1, true) ~= nil)
    ping(s, 0, 3, 3, 1000 + server.PING_EVERY_MS)
    test("one PING_EVERY_MS after the last is taken", #inbox[1] == 2)
    test("timed from the ping taken, not the one refused", inbox[1][2] and inbox[1][2].x == 3)
    ping(s, 1, 4, 4, 1000 + server.PING_EVERY_MS)
    test("another player's pings are timed apart", #inbox[0] == 3)

    local nan = 0 / 0
    local refused = #s.refused
    ping(s, 1, nan, 4, 5000)
    test("a refused ping is recorded as one more refusal", #s.refused == refused + 1)
    test("a ping at no number is refused", #inbox[0] == 3 and s.refused[#s.refused].why:find("point", 1, true) ~= nil)
    ping(s, 1, 4, math.huge, 6000)
    test("a ping at infinity is refused", #inbox[0] == 3)
    ping(s, 1, -math.huge, 4, 7000)
    test("so is one at minus infinity", #inbox[0] == 3)
    ping(s, 1, 4, 4, 7000)
    test("a refused ping doesn't start the wait", #inbox[0] == 4)
end

do
    local s, inbox = make_game(2, function() return true end)
    s.paused = true
    ping(s, 0, 1, 1, 0)
    test("pings go through while the game is paused", #inbox[1] == 1)
end

section("A trigger pings the minimap")
do
    local V = vm.new(nil, { player = 0 })
    local N = V.natives
    test("PingMinimap is not a no-op any more", not V.noop.PingMinimap and not V.noop.PingMinimapForForceEx)
    N.PingMinimap(10, 20, 5)
    local p = V.pings[1]
    test("PingMinimap pings the local minimap", p and p.x == 10 and p.y == 20)
    test("for the time given", p and near(p.ends - p.at, 5))
    test("in yellow", p and p.r == 255 and p.g == 255 and p.b == 0 and not p.flashy)

    N.PingMinimapEx(1, 2, 4, 300, -5, 99.6, true)
    p = V.pings[2]
    test("PingMinimapEx keeps its colour, held to 0-255", p and p.r == 255 and p.g == 0 and p.b == 100)
    test("and flashes when asked", p and p.flashy == true)
    N.PingMinimapEx(1, 2, 4, nil, 7, 8, false)
    test("a colour not given is 0", V.pings[3] and V.pings[3].r == 0 and V.pings[3].g == 7)

    local mine, theirs = N.CreateForce(), N.CreateForce()
    N.ForceAddPlayer(mine, N.Player(0))
    N.ForceAddPlayer(theirs, N.Player(1))
    V.pings = {}
    N.PingMinimapForForce(theirs, 1, 1, 3)
    test("a force without the local player: no ping", #V.pings == 0)
    N.PingMinimapForForce(mine, 7, 8, 3)
    test("a force with the local player: a ping", #V.pings == 1 and V.pings[1].x == 7)
    N.PingMinimapLocForForce(mine, N.Location(30, 40), 2)
    test("PingMinimapLocForForce pings the location", V.pings[2] and V.pings[2].x == 30 and V.pings[2].y == 40)
    N.PingMinimapLocForForce(theirs, N.Location(30, 40), 2)
    test("but only for its force", #V.pings == 2)
    N.PingMinimapLocForForce(mine, nil, 2)
    test("a null location pings the middle of the map", V.pings[3] and V.pings[3].x == 0 and V.pings[3].y == 0)

    V.pings = {}
    N.PingMinimapForForceEx(mine, 1, 1, 3, 0, 100, 50, 0)
    p = V.pings[1]
    test("style 0 (simple): percent colour to 0-255", p and p.r == 255 and p.g == 128 and p.b == 0)
    test("not flashy", p and not p.flashy)
    N.PingMinimapForForceEx(mine, 1, 1, 3, 1, 0, 0, 100)
    p = V.pings[2]
    test("style 1 (flashy) flashes", p and p.flashy and p.b == 255)
    N.PingMinimapForForceEx(mine, 1, 1, 3, 2, 0, 100, 0)
    p = V.pings[3]
    test("style 2 (attack) is pure red whatever colour is given", p and p.r == 255 and p.g == 0 and p.b == 0)
    test("and counts as an attack ping", p and pings.is_attack(p))
    N.PingMinimapForForceEx(mine, 1, 1, 3, 0, 100, 0, 0)
    p = V.pings[4]
    test("a simple pure red ping is made 254 red, so it isn't an attack ping", p and p.r == 254 and not pings.is_attack(p))
    N.PingMinimapForForceEx(mine, 1, 1, 3, 1, 100, 0, 0)
    test("so is a flashy one", V.pings[5] and V.pings[5].r == 254)
    N.PingMinimapForForceEx(mine, 1, 1, 3, 0, 0, nil, 100)
    test("a percent not given is 0", V.pings[6] and V.pings[6].g == 0)
    V.pings[6] = nil
    N.PingMinimapForForceEx(theirs, 1, 1, 3, 2, 0, 0, 0)
    test("ForForceEx is for its force only", #V.pings == 5)
end

do
    local V = vm.new(nil, { player = 0 })
    V.natives.PingMinimap(0, 0, 1)
    V.natives.PingMinimap(0, 0, 3)
    V:tick(0.5)
    test("a ping shows until its time is up", #V.pings == 2)
    V:tick(0.6)
    test("then goes", #V.pings == 1 and near(V.pings[1].ends, 3))
    V:tick(2)
    test("every one goes in its time", #V.pings == 0)
    V.natives.PingMinimap(0, 0, 1)
    V:tick(0.5)
    V:tick(0.5)
    test("a ping is gone the moment its time is up", #V.pings == 0)
    for i = 1, vm.PINGS_KEPT + 3 do V.natives.PingMinimap(i, 0, 10) end
    test("no more than PINGS_KEPT are kept", #V.pings == vm.PINGS_KEPT)
    test("the oldest go first", V.pings[1].x == 4 and V.pings[vm.PINGS_KEPT].x == vm.PINGS_KEPT + 3)
    local p = V:ping(1, 2)
    test("a ping given no time shows for PING_SECONDS", near(p.ends - p.at, vm.PING_SECONDS))
    p = V:ping()
    test("a ping given no point is at the middle of the map", p.x == 0 and p.y == 0)
end

do
    local V = vm.new(nil, { player = 0 })
    local ok, err = V:load([[
function main takes nothing returns nothing
    call PingMinimap(-512.0, 256.0, 2.0)
    call PingMinimapEx(0.0, 0.0, 2.0, 255, 0, 0, false)
endfunction
]])
    test("a script calling the natives loads", ok, tostring(err))
    if ok then V:run_main() end
    test("and its pings are shown", #V.pings == 2 and V.pings[1].x == -512 and V.pings[1].y == 256)
    test("an Ex ping in pure red is an attack ping", V.pings[2] and pings.is_attack(V.pings[2]))
    test("with no errors", #V.errors == 0)
end

section("How a ping looks")
do
    local list = {}
    local p = pings.heard(list, { tick = 5, player = 3, x = 9, y = 8 }, 10)
    test("a heard ping is kept", #list == 1 and p.x == 9 and p.y == 8 and p.player == 3)
    test("for PLAYER_SECONDS", near(p.ends - p.at, pings.PLAYER_SECONDS))
    test("in the player colour", p.r == 255 and p.g == 255 and p.b == 0)

    test("nothing to see before it starts", pings.look(p, 9.99) == nil)
    local l = pings.look(p, 10)
    test("solid when made", l and l.alpha == 255 and near(l.ring, 0))
    test("and it says who pinged", l and l.player == 3)
    l = pings.look(p, 10.25)
    test("the ring spreads over RING_SECONDS", l and near(l.ring, 0.25))
    l = pings.look(p, 11.5)
    test("and starts again each RING_SECONDS", l and near(l.ring, 0.5))
    l = pings.look(p, 10 + pings.PLAYER_SECONDS - pings.FADE_SECONDS)
    test("still solid as the fade begins", l and l.alpha == 255)
    l = pings.look(p, 10 + pings.PLAYER_SECONDS - pings.FADE_SECONDS / 2)
    test("half faded half way through the fade", l and l.alpha == 128, l and tostring(l.alpha))
    l = pings.look(p, 10 + pings.PLAYER_SECONDS - 0.4)
    test("fading over the last half second", l and l.alpha < 255)
    l = pings.look(p, 10 + pings.PLAYER_SECONDS - 0.001)
    test("nearly gone at the end", l and l.alpha <= 1)
    test("gone when its time is up", pings.look(p, 10 + pings.PLAYER_SECONDS) == nil)

    local f = { x = 0, y = 0, at = 0, ends = 5, r = 0, g = 0, b = 255, flashy = true }
    l = pings.look(f, 0.25)
    test("a flashy ping's rings come twice as fast", l and near(l.ring, 0.25 / pings.FLASHY_RING_SECONDS))
    test("and it isn't an attack ping", l and not l.attack)
    l = pings.look({ x = 0, y = 0, at = 0.3, ends = 5, r = 0, g = 0, b = 255 }, 0.55)
    test("rings are timed from when the ping was made", l and near(l.ring, 0.25))
    l = pings.look({ x = 0, y = 0, at = 0, ends = 5, r = 255, g = 0, b = 0, flashy = false }, 1)
    test("a pure red unflashing ping looks like an attack", l and l.attack)
    test("red but flashing does not", not pings.is_attack({ r = 255, g = 0, b = 0, flashy = true }))
    test("nearly red does not", not pings.is_attack({ r = 254, g = 0, b = 0 }))
    test("red with green does not", not pings.is_attack({ r = 255, g = 1, b = 0 }))
    test("red with blue does not", not pings.is_attack({ r = 255, g = 0, b = 1 }))
end

do
    local list = {}
    for i = 1, pings.KEPT + 2 do pings.heard(list, { player = 0, x = i, y = 0 }, i) end
    test("no more than KEPT player pings", #list == pings.KEPT and list[1].x == 3)
    pings.forget(list, pings.KEPT + 2)
    test("forget drops those whose time is up", #list == 3 and list[1].x == pings.KEPT and list[3].x == pings.KEPT + 2)
    test("and leaves nothing after them", list[4] == nil)
    pings.forget(list, 0)
    test("forget keeps every ping still showing", #list == 3 and list[1].x == pings.KEPT)
    pings.forget(list, 1000)
    test("forget can empty the list", #list == 0 and list[1] == nil)
end

do
    local trig = { { x = 1, y = 0, at = 2, ends = 9, r = 255, g = 255, b = 0 },
                   { x = 2, y = 0, at = 0, ends = 1, r = 255, g = 255, b = 0 } }
    local heard = {}
    pings.heard(heard, { player = 1, x = 3, y = 0 }, 1)
    pings.heard(heard, { player = 1, x = 4, y = 0 }, 4)
    local out = pings.showing(3, trig, heard, nil)
    test("showing gathers every list's pings showing now", #out == 2)
    test("oldest first", out[1] ~= nil and out[1].x == 3 and out[2].x == 1)
    test("leaving out those not started and those over", out[3] == nil)
    test("each with when it was made", out[1] and out[1].at == 1)
    out = pings.showing(4.5, trig, heard)
    test("leaving out those whose time is up", #out == 2 and out[1].x == 1 and out[2].x == 4)
end

print(string.format("\n%d/%d passed", pass_count, test_count))
if pass_count ~= test_count then os.exit(1) end
