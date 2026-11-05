-- test_matchmaking_nat.lua - NAT detection and UDP hole punching on simulated networks (issue 801d)
--
-- In plain terms: builds pretend networks (natsim.lua) with every usual
-- kind of home router, and checks that the detector names each kind,
-- that two machines behind each pair of routers open a direct path (or
-- fail within five seconds where the kinds can't), at the rates the
-- issue asks for when datagrams get lost, that an open path stays open
-- on keepalives, and that a lobby of the client library, through the
-- matchmaking server's core, sets the punches going on both sides.
--
-- Run with: luajit src/tests/test_matchmaking_nat.lua [DIR]
-- (DIR defaults to the project this file is in.)

-- The project: the argument, or the folder this test sits in (run-tests.sh
-- runs each test by its full path, from the project), or the owner's.
local DIR = arg[1] or arg[0]:match("^(.+)/src/tests/[^/]+%.lua$") or (arg[0]:match("^src/tests/") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/tests/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local nat = require("matchmaking.nat")
local natsim = require("natsim")
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

local now = 0
local function clock() return now end

-- A network with a reflector on 1.0.0.1:3478 (and :3479, and 1.0.0.2:3478
-- unless `one_ip`).
local function world(options)
    options = options or {}
    local net = natsim.network({ clock = clock, loss = options.loss, seed = options.seed })
    local s1 = net:machine("1.0.0.1")
    local eps = { main = s1:udp(3478), alt_port = s1:udp(3479) }
    if not options.one_ip then eps.alt_ip = net:machine("1.0.0.2"):udp(3478) end
    local refl = nat.reflector(eps)
    return net, refl
end

-- An endpoint on a machine of `kind` ("open" is a public machine).
local next_router = 0
local function behind(net, kind, options)
    next_router = next_router + 1
    if kind == "open" then return net:machine("9.0.0." .. next_router):udp(6112) end
    local r = net:nat("8.0.0." .. next_router, kind, options)
    return r:machine("192.168.1.10"):udp(6112)
end

-- Steps `fns` every `dt` seconds until `done()` or `limit` seconds pass.
local function run(limit, dt, fns, done)
    local start = now
    while now - start < limit do
        for _, f in ipairs(fns) do f() end
        if done and done() then return true end
        now = now + dt
    end
    return false
end

local function detect(net, refl, ep)
    local d = nat.detector(ep, { server_ip = "1.0.0.1", server_port = 3478, clock = clock })
    local start = now
    run(10, 0.01, { function() refl:poll() end, function() d:step() end }, function() return d.result ~= nil end)
    return d.result, d, now - start
end
-- }}}

-- {{{ packets
print("packets")
local kinds = {
    { kind = "BIND", token = 7, flags = 3 },
    { kind = "BOUND", token = 4294967295, ip = "203.0.113.9", port = 65535, alt_port = 3479, alt_ip = "1.0.0.2" },
    { kind = "PROBE", token = 0, seq = 123456789 },
    { kind = "ACK", token = 99, seq = 4294967295 },
    { kind = "KEEPALIVE", token = 2147483648 },
}
for _, k in ipairs(kinds) do
    local back = nat.decode(nat.encode(k))
    local same = back ~= nil
    for f, v in pairs(k) do same = same and back[f] == v end
    test(k.kind .. " survives the trip to bytes and back", same)
end
test("a BOUND is 19 bytes", #nat.encode(kinds[2]) == 19)
test("an address that isn't one goes as 0.0.0.0", nat.decode(nat.encode({ kind = "BOUND", ip = "nope", alt_ip = "1.2.3.400" })).ip == "0.0.0.0"
    and nat.decode(nat.encode({ kind = "BOUND", ip = "nope", alt_ip = "1.2.3.400" })).alt_ip == "0.0.0.0")
test("a game's own datagram is not ours", nat.decode("hello, world") == nil)
test("nor one with only half the mark", nat.decode("WX\5\0\0\0\1") == nil and nat.decode("XN\5\0\0\0\1") == nil)
test("an address part over 255 goes as 0.0.0.0", nat.decode(nat.encode({ kind = "BOUND", ip = "1.2.3.256", alt_ip = "256.0.0.1" })).ip == "0.0.0.0")
test("nor one cut short", nat.decode(nat.encode(kinds[3]):sub(1, -2)) == nil)
test("nor one too long", nat.decode(nat.encode(kinds[3]) .. "x") == nil)
test("nor one of a kind there is none of", nat.decode("WN\9\0\0\0\1") == nil)
test("nor nothing at all", nat.decode(nil) == nil and nat.decode("WN") == nil)
test("an unknown kind can't be sent", refused(function() nat.encode({ kind = "HELLO" }) end, "no packet kind HELLO"))
test("each player of each game has a token of its own", nat.token(1, 2) ~= nat.token(1, 3) and nat.token(1, 2) ~= nat.token(2, 2))
test("tokens wrap at 32 bits", nat.decode(nat.encode({ kind = "KEEPALIVE", token = 4294967296 + 5 })).token == 5)
-- }}}

-- {{{ the reflector
print("the reflector")
do
    local net, refl = world()
    local m = net:nat("8.8.8.8", "full_cone"):machine("10.1.1.1")
    local ep = m:udp(5000)
    ep:send(nat.encode({ kind = "BIND", token = 11 }), "1.0.0.1", 3478)
    refl:poll()
    local data, ip, port = ep:receive()
    local p = nat.decode(data)
    test("a question is answered with the address it came from", p and p.kind == "BOUND" and p.token == 11 and p.ip == "8.8.8.8" and p.port == 40000)
    test("from the address and port it was asked at", ip == "1.0.0.1" and port == 3478)
    test("and names the reflector's other port and address", p and p.alt_port == 3479 and p.alt_ip == "1.0.0.2")
    ep:send(nat.encode({ kind = "BIND", token = 12, flags = nat.FLAG.ALT_PORT }), "1.0.0.1", 3478)
    refl:poll()
    data, ip, port = ep:receive()
    test("asked to, it answers from its other port", ip == "1.0.0.1" and port == 3479 and nat.decode(data).token == 12)
    ep:send(nat.encode({ kind = "BIND", token = 13, flags = nat.FLAG.ALT_IP }), "1.0.0.1", 3478)
    refl:poll()
    data, ip, port = ep:receive()
    test("or from its other address", ip == "1.0.0.2" and port == 3478 and nat.decode(data).token == 13)
    ep:send(nat.encode({ kind = "BIND", token = 14, flags = 3 }), "1.0.0.1", 3478)
    refl:poll()
    data, ip, port = ep:receive()
    test("asked for both, from its other address", ip == "1.0.0.2")
    ep:send(nat.encode({ kind = "BIND", token = 15 }), "1.0.0.1", 3479)
    refl:poll()
    data, ip, port = ep:receive()
    test("a question to its other port is answered from there", ip == "1.0.0.1" and port == 3479 and nat.decode(data).port == 40000)
    ep:send("not ours", "1.0.0.1", 3478)
    ep:send(nat.encode({ kind = "PROBE", token = 1 }), "1.0.0.1", 3478)
    test("anything else is read and dropped", refl:poll() == 2 and ep:receive() == nil and refl.answered == 5)

    local net2, refl2 = world({ one_ip = true })
    local ep2 = net2:machine("9.9.9.9"):udp(5000)
    ep2:send(nat.encode({ kind = "BIND", token = 16 }), "1.0.0.1", 3478)
    refl2:poll()
    test("with one address it says so (0.0.0.0)", nat.decode(ep2:receive()).alt_ip == "0.0.0.0")
    ep2:send(nat.encode({ kind = "BIND", token = 17, flags = nat.FLAG.ALT_IP }), "1.0.0.1", 3478)
    refl2:poll()
    test("and leaves a question for the other address unanswered", ep2:receive() == nil)
    test("a reflector needs two endpoints", refused(function() nat.reflector({ main = ep2 }) end, "another port"))
end
-- }}}

-- {{{ detection
print("detection")
local function detected(kind, options)
    local net, refl = world(options)
    local ep = behind(net, kind, options)
    return detect(net, refl, ep)
end
for _, k in ipairs({ "open", "full_cone", "restricted_cone", "port_restricted", "symmetric", "blocked" }) do
    local got, d, took = detected(k)
    test("a " .. k .. " machine is detected as one", got == k, got)
    test("  within five seconds", took < 5, took)
end
local got, d = detected("full_cone", { one_ip = true })
test("with one reflector address, a full cone reads as restricted", got == "restricted_cone", got)
got, d = detected("port_restricted")
test("the outside address is the router's", d.mapped_ip:match("^8%.0%.0%.") and d.mapped_port == 40000, tostring(d.mapped_ip) .. ":" .. tostring(d.mapped_port))
got, d = detected("open")
test("an open machine's outside address is its own", d.mapped_ip:match("^9%.0%.0%.") and d.mapped_port == 6112)
got, d, took = detected("blocked")
test("blocked is known after one unanswered second", took >= 1 and took < 1.1, took)
got = detected("symmetric", { loss = 0.3, seed = 7 })
test("detection holds through lost datagrams (repeats its questions)", got == "symmetric", got)
do
    local net, refl = world()
    local ep = behind(net, "full_cone")
    local others = {}
    local dd = nat.detector(ep, { server_ip = "1.0.0.1", server_port = 3478, clock = clock,
        other = function(data) others[#others + 1] = data end })
    dd:step()
    ep.queue[#ep.queue + 1] = { "game data", "5.5.5.5", 1 }
    ep.queue[#ep.queue + 1] = { nat.encode({ kind = "BOUND", token = 1, ip = "6.6.6.6", port = 1 }), "1.0.0.1", 3478 }
    refl:poll()
    dd:step()
    test("datagrams that aren't answers go to `other`", others[1] == "game data" and #others == 2)
    test("and an answer with the wrong token is not taken", dd.mapped_ip == "8.0.0." .. next_router, dd.mapped_ip)
    local spoof = nat.detector(behind(net, "full_cone"), { server_ip = "1.0.0.1", server_port = 3478, clock = clock })
    spoof:step()
    spoof.ep.queue[1] = { nat.encode({ kind = "BOUND", token = spoof.token, ip = "6.6.6.6", port = 1 }), "7.7.7.7", 3478 }
    spoof:step()
    test("nor one from another address", spoof.mapped_ip == nil)
    test("the detector needs the reflector's address", refused(function() nat.detector(ep, {}) end, "server_ip and server_port"))
    test("detect_type wants ip:port", refused(function() nat.detect_type({ stun_server = "stun.example:19302", endpoint = ep }) end, "stun_server is ip:port"))
    local result, ip, port = nat.detect_type({ server_ip = "1.0.0.1", server_port = 3478, clock = function() now = now + 0.01 return now end,
        endpoint = setmetatable({ receive = function(self) refl:poll() return ep.receive(self) end }, { __index = ep }) })
    test("detect_type gives the kind and the outside address", result == "full_cone" and ip:match("^8%.") and port == 40000, tostring(result))
end
-- }}}

-- {{{ the punch, kind against kind
print("the punch")
local KINDS = { "open", "full_cone", "restricted_cone", "port_restricted", "symmetric" }
local function hard(a, b)
    return (a == "symmetric" and (b == "symmetric" or b == "port_restricted"))
        or (b == "symmetric" and a == "port_restricted")
end

-- Detects both, then punches at once. Returns the two punches.
local function punch_pair(ka, kb, options)
    options = options or {}
    local net, refl = world(options)
    local ea, eb = behind(net, ka, options), behind(net, kb, options)
    local _, da = detect(net, refl, ea)
    local _, db = detect(net, refl, eb)
    if options.stale then now = now + options.stale end
    local pa = nat.create_punch({ endpoint = ea, remote_ip = db.mapped_ip, remote_port = db.mapped_port, token = 42, clock = clock })
    local pb = nat.create_punch({ endpoint = eb, remote_ip = da.mapped_ip, remote_port = da.mapped_port, token = 42, clock = clock })
    local start = now
    run(6, 0.01, { function() pa:poll() end, function() pb:poll() end },
        function() return pa.state ~= "punching" and pb.state ~= "punching" end)
    return pa, pb, now - start, net
end

local matrix = {}
for _, ka in ipairs(KINDS) do
    for _, kb in ipairs(KINDS) do
        local pa, pb, took = punch_pair(ka, kb)
        local open = pa:established() and pb:established()
        matrix[ka .. "/" .. kb] = open
        if hard(ka, kb) then
            test(ka .. " with " .. kb .. ": fails, both sides know within 5 s", pa:failed() and pb:failed() and took >= 5 and took < 5.1,
                pa.state .. "/" .. pb.state .. " " .. took)
        else
            test(ka .. " with " .. kb .. ": opens", open and took < 1, pa.state .. "/" .. pb.state .. " " .. took)
        end
    end
end
local pa, pb = punch_pair("symmetric", "restricted_cone")
test("a symmetric side is found at the port it really uses", pb.remote_port ~= 40000 + 0 and pa.state == "established" and pb.remote_port == pa.ep.machine.router.next_port - 1,
    pb.remote_port)
pa, pb = punch_pair("port_restricted", "port_restricted", { stale = 31 })
test("endpoints whose mappings have lapsed fail", pa:failed() and pb:failed())

-- The rates the issue asks for, with a fifth of all datagrams lost.
local function rate(ka, kb, n)
    local ok = 0
    for i = 1, n do
        local a, b = punch_pair(ka, kb, { loss = 0.2, seed = i * 7919 })
        if a:established() and b:established() then ok = ok + 1 end
    end
    return ok / n
end
local worst = 1
for _, k in ipairs(KINDS) do worst = math.min(worst, rate("full_cone", k, 10)) end
test("full cone with any kind, 20% loss: all open", worst == 1, worst)
local r = rate("restricted_cone", "restricted_cone", 20)
test(string.format("restricted with restricted, 20%% loss: over 90%% (%d%%)", r * 100), r > 0.9, r)
r = rate("port_restricted", "port_restricted", 20)
test(string.format("port-restricted with port-restricted, 20%% loss: over 70%% (%d%%)", r * 100), r > 0.7, r)
-- }}}

-- {{{ an open path
print("an open path")
do
    local net = natsim.network({ clock = clock })
    local ra, rb = net:nat("8.1.0.1", "port_restricted"), net:nat("8.1.0.2", "port_restricted")
    local ea, eb = ra:machine("10.0.0.1"):udp(7000), rb:machine("10.0.0.2"):udp(7000)
    -- Each learns the other's outside port from a first datagram out.
    ea:send("x", "8.1.0.2", 1) eb:send("x", "8.1.0.1", 1)
    local pa = nat.create_punch({ endpoint = ea, remote_ip = "8.1.0.2", remote_port = 40000, token = 5, clock = clock })
    local pb = nat.create_punch({ endpoint = eb, remote_ip = "8.1.0.1", remote_port = 40000, token = 5, clock = clock })
    test("a punch starts out punching", pa.state == "punching" and not pa:established())
    test("and won't carry the game's datagrams yet", refused(function() pa:send("hi") end, "punching, not established"))
    run(2, 0.05, { function() pa:poll() end, function() pb:poll() end }, function() return pa:established() and pb:established() end)
    test("both open", pa:established() and pb:established())
    test("the first probe was lost at the far router, a later one got through", pa.probes >= 1 and net.dropped >= 1)
    pa:send("hello")
    pb:poll()
    test("the game's datagram reaches the other side", pb:receive() == "hello" and pb:receive() == nil)
    eb.queue[#eb.queue + 1] = { "stranger", "6.6.6.6", 6 }
    pb:poll()
    test("one from anyone else is not kept", pb:receive() == nil)
    eb.queue[#eb.queue + 1] = { nat.encode({ kind = "PROBE", token = 6, seq = 1 }), "8.1.0.1", 40000 }
    local sent = net.sent
    pb:poll()
    test("a probe of another punch is not answered", net.sent == sent)
    test("nor kept as the game's", pb:receive() == nil)

    -- 90 seconds on: keepalives every 15 s keep the 30 s mappings alive.
    local before = pa.sent_at
    local keep_sent = 0
    local t0 = now
    while now - t0 < 90 do
        local s = net.sent
        pa:poll() pb:poll()
        keep_sent = keep_sent + (net.sent - s)
        now = now + 1
    end
    test("keepalives go out about every 15 s from each side", keep_sent >= 10 and keep_sent <= 14, keep_sent)
    test("the path is still open after 90 s", pa:established() and pb:established())
    pa:send("still here")
    pb:poll()
    test("and still carries datagrams", pb:receive() == "still here")

    -- Then the network goes dark.
    net.loss = 1
    local lost_at
    local t1 = now
    while now - t1 < 60 and not lost_at do
        pa:poll() pb:poll()
        if pa.state == "lost" then lost_at = now - t1 end
        now = now + 1
    end
    test("silence for three keepalives is lost", lost_at and lost_at >= 45 and lost_at <= 46, lost_at)
    test("the game may still try to send", pcall(pa.send, pa, "anyone?"))
    net.loss = 0
    -- the mappings lapsed in the dark; open them again from both sides
    ea:send("x", "8.1.0.2", 1) eb:send("x", "8.1.0.1", 1)
    pa.remote_port = rb.next_port - 1
    pb.remote_port = ra.next_port - 1
    run(40, 1, { function() pa:poll() end, function() pb:poll() end }, function() return pa:established() end)
    test("heard again, it is open again", pa:established())
    pa.state = "lost"
    pa:handle("a game datagram", pa.remote_ip, pa.remote_port)
    test("a game's datagram from the remote also brings it back", pa:established())
    pa.state = "lost"
    pa:handle("a game datagram", pa.remote_ip, pa.remote_port + 1)
    test("but not one from another port", pa.state == "lost")
    pa.state = "established"

    local t2 = now
    local slow_a = nat.create_punch({ endpoint = ea, remote_ip = "8.1.0.2", remote_port = 1, token = 9, clock = clock, punch_timeout = 2 })
    run(3, 0.1, { function() slow_a:poll() end }, function() return slow_a:failed() end)
    test("punch_timeout is the caller's to set", slow_a:failed() and now - t2 >= 2 and now - t2 < 2.15, now - t2)
    test("probes go every probe_interval", slow_a.probes >= 19 and slow_a.probes <= 21, slow_a.probes)
    local q = #ea.queue
    ea.queue[#ea.queue + 1] = { nat.encode({ kind = "PROBE", token = 9, seq = 1 }), "8.1.0.2", 1 }
    local sent_before = net.sent
    test("a failed punch takes its packets but answers none", slow_a:handle(nat.encode({ kind = "PROBE", token = 9, seq = 1 }), "8.1.0.2", 1)
        and slow_a.state == "failed" and net.sent == sent_before)
    test("a punch needs where to", refused(function() nat.create_punch({ endpoint = ea }) end, "remote_ip and remote_port"))
end
-- }}}

-- {{{ a lobby's session, through the matchmaking server
print("a lobby's session")
do
    local srv = server.new({ clock = clock, log = function() end })
    local wires = {}
    local function pump()
        local moved = true
        while moved do
            moved = false
            for _, w in ipairs(wires) do
                local up = w.c:output()
                if #up > 0 then srv:receive(w.id, up) moved = true end
                local down = srv:output(w.id)
                if #down > 0 then w.c:feed(down) moved = true end
            end
        end
    end
    local function wire(name, ip)
        local c = client.new({ name = name, clock = clock, pump = pump, log = function() end })
        wires[#wires + 1] = { c = c, id = srv:accept(ip, 50000 + #wires) }
        return c
    end

    local net, refl = world()
    local hr, pr, qr = net:nat("8.2.0.1", "port_restricted"), net:nat("8.2.0.2", "symmetric"), net:nat("8.2.0.3", "restricted_cone")
    local hep, pep, qep = hr:machine("10.0.0.1"):udp(6112), pr:machine("10.0.0.2"):udp(6112), qr:machine("10.0.0.3"):udp(6112)
    local _, hd = detect(net, refl, hep)
    local _, pd = detect(net, refl, pep)
    local _, qd = detect(net, refl, qep)

    local hc, pc, qc = wire("host", "8.2.0.1"), wire("p", "8.2.0.2"), wire("q", "8.2.0.3")
    local lobby = hc:create_lobby({ map_name = "m", map_hash = "h", asset_packs = {}, max_players = 4, game_mode = "x", region = "r" })
    local games = pc:list_games({})
    local plobby = pc:join_game(games[1], "p")
    local qlobby = qc:join_game(games[1], "q")

    local hs = nat.session(lobby, { endpoint = hep, mapped_ip = hd.mapped_ip, mapped_port = hd.mapped_port, clock = clock })
    local ps = nat.session(plobby, { endpoint = pep, mapped_port = pd.mapped_port, clock = clock })
    local qs = nat.session(qlobby, { endpoint = qep, mapped_ip = qd.mapped_ip, mapped_port = qd.mapped_port, clock = clock })
    local ev = {}
    for name, s in pairs({ host = hs, p = ps, q = qs }) do
        for _, e in ipairs({ "established", "failed", "lost", "data" }) do
            s:on(e, function(id, x) ev[#ev + 1] = name .. " " .. e .. " " .. id .. (type(x) == "string" and " " .. x or "") end)
        end
    end
    local function has(want) for _, e in ipairs(ev) do if e == want then return true end end return false end

    test("the host doesn't start a punch itself", refused(function() hs:start() end, "the host waits"))
    qs:start()
    pump()
    local qp = hs:punch_for(qlobby.player_id)
    test("a player's endpoint sets the host punching to it", qp and qp.remote_ip == qd.mapped_ip and qp.remote_port == qd.mapped_port)
    local hq = qs:punch_for(lobby.player_id)
    test("and the host's answer sets the player punching back", hq and hq.remote_ip == hd.mapped_ip and hq.remote_port == hd.mapped_port)
    test("both with the token of the game and the player", qp and hq and qp.token == hq.token and qp.token == nat.token(lobby.game_id, qlobby.player_id))
    run(2, 0.02, { function() hs:step() end, function() qs:step() end }, function() return has("host established " .. qlobby.player_id) and has("q established " .. lobby.player_id) end)
    test("host and restricted player are through to each other", has("host established " .. qlobby.player_id) and has("q established " .. lobby.player_id))

    ps:start()
    pump()
    local pp = hs:punch_for(plobby.player_id)
    test("without mapped_ip, the server fills in the address it sees", pp and pp.remote_ip == "8.2.0.2" and pp.remote_port == pd.mapped_port)
    run(6, 0.05, { function() hs:step() end, function() ps:step() end, function() qs:step() end },
        function() return has("host failed " .. plobby.player_id) end)
    test("port-restricted host and symmetric player: both told it failed", has("host failed " .. plobby.player_id) and has("p failed " .. lobby.player_id))
    test("the other player's path stays open meanwhile", qp:established())

    local n = #ev
    hs:step()
    test("a state is reported once", #ev == n)
    qp:send("move 3 4")
    qs:step()
    test("the game's datagrams come out as data, with who sent them", has("q data " .. lobby.player_id .. " move 3 4"))
    local same = hs:punch_for(qlobby.player_id)
    qs:start()
    pump()
    test("the same endpoint again doesn't restart an open punch", hs:punch_for(qlobby.player_id) == same)
    ps:start()
    pump()
    test("a failed one is tried again when the endpoint comes again", hs:punch_for(plobby.player_id) ~= pp and hs:punch_for(plobby.player_id).state == "punching")
    local rr = net:nat("8.2.0.4", "full_cone")
    local rep = rr:machine("10.0.0.4"):udp(6112)
    local _, rd = detect(net, refl, rep)
    local rc = wire("r", "8.2.0.4")
    local rlobby = rc:join_game(games[1], "r")
    local rs = nat.session(rlobby, { endpoint = rep, mapped_ip = rd.mapped_ip, mapped_port = rd.mapped_port, clock = clock })
    for _, e in ipairs({ "established", "data" }) do
        rs:on(e, function(id, x) ev[#ev + 1] = "r " .. e .. " " .. id .. (type(x) == "string" and " " .. x or "") end)
    end
    rs:start()
    pump()
    run(2, 0.02, { function() hs:step() end, function() rs:step() end, function() qs:step() end },
        function() return has("host established " .. rlobby.player_id) end)
    rs:punch_for(lobby.player_id):send("from r")
    qs:punch_for(lobby.player_id):send("from q")
    hs:step()
    test("with two players open, each datagram is put down to its sender",
        has("host data " .. rlobby.player_id .. " from r") and has("host data " .. qlobby.player_id .. " from q"))
    hs:close()
    local before = hs:punch_for(plobby.player_id)
    plobby:punch("", 7777)            -- a new endpoint would start a new punch
    pump()
    test("a closed session stops listening to the lobby", hs:punch_for(plobby.player_id) == before)
    test("a session needs an endpoint", refused(function() nat.session(lobby, {}) end, "needs an endpoint"))
end
-- }}}

print(string.format("\nTests: %d passed, %d failed", pass_count, test_count - pass_count))
print(string.format("matchmaking NAT: %d of %d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
