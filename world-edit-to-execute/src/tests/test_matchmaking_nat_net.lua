-- test_matchmaking_nat_net.lua - the NAT reflector and a UDP punch over real sockets, on loopback (issue 801d)
--
-- In plain terms: runs itself in a network of its own (`unshare -rn`, see
-- netns.lua), starts the matchmaking daemon there with its NAT reflector
-- on, and checks over real UDP that the detector finds this machine open
-- and finds nothing where nothing answers; then a host and a player, each
-- a client library with a UDP socket, open a lobby, trade endpoints
-- through the server and punch through to each other. There is no NAT on
-- a loopback: the kinds of NAT are test_matchmaking_nat.lua's, simulated.
--
-- Run with: luajit src/tests/test_matchmaking_nat_net.lua [DIR]
-- (DIR defaults to the project this file is in.)

-- The project: the argument, or the folder this test sits in (run-tests.sh
-- runs each test by its full path, from the project), or the owner's.
local DIR = arg[1] or arg[0]:match("^(.+)/src/tests/[^/]+%.lua$") or (arg[0]:match("^src/tests/") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/tests/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

require("netns").enter(arg[0], { DIR })

local socket = require("socket")
local client = require("matchmaking.client")
local nat = require("matchmaking.nat")

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

local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

-- The daemon with `flags`; returns pid, the "listening" and "nat" lines' fields, the pipe.
local function daemon(flags)
    local pipe = io.popen("exec sh -c " .. quote("echo $$; exec luajit " .. quote(DIR .. "/src/cli/matchmaking-serve.lua") .. " "
        .. quote(DIR) .. " " .. flags .. " --seconds 60 --quiet 2>&1"), "r")
    local pid = tonumber(pipe:read("*l"))
    local line = pipe:read("*l") or ""
    local ip, port = line:match("^listening (%S+) (%d+)$")
    if not ip then pipe:read("*a") pipe:close() return nil, line end
    local nline = pipe:read("*l") or ""
    local nip, nport, nalt = nline:match("^nat (%S+) (%d+) (%d+)$")
    return pid, ip, tonumber(port), pipe, nip, tonumber(nport), tonumber(nalt), nline
end

local function kill(pid, pipe)
    os.execute("kill " .. pid)
    pipe:read("*a")
    pipe:close()
end

local function run_status(flags)
    local p = io.popen("luajit " .. quote(DIR .. "/src/cli/matchmaking-serve.lua") .. " " .. quote(DIR) .. " " .. flags
        .. " --seconds 1 --quiet 2>&1; echo \"exit $?\"", "r")
    local out = p:read("*a")
    p:close()
    return tonumber(out:match("exit (%d+)%s*$")), out
end
-- }}}

-- {{{ the daemon's reflector
print("the daemon's reflector")
local code, out = run_status("--bind 127.0.0.1:0 --nat-alt-ip 127.0.0.2")
test("--nat-alt-ip without --nat-port is refused", code == 2 and out:find("needs --nat-port", 1, true), out)
local taken = nat.udp("127.0.0.1", 0)
local _, taken_port = taken:local_address()
code, out = run_status("--bind 127.0.0.1:0 --nat-port " .. taken_port)
test("a NAT port in use stops the daemon, saying why", code == 1 and out:find("can't bind UDP", 1, true), out)
taken:close()

local pid, ip, port, pipe, nip, nport, nalt, nline = daemon("--bind 127.0.0.1:0 --nat-port 0 --nat-alt-ip 127.0.0.2")
test("the daemon listens and says where its reflector is", pid ~= nil and nip == "127.0.0.1" and nport and nalt and nport ~= nalt, nline)
if not (pid and nport) then os.exit(1) end

local ep = nat.udp("127.0.0.1", 0)
local lip, lport = ep:local_address()
local kind, mip, mport = nat.detect_type({ stun_server = nip .. ":" .. nport, endpoint = ep })
test("a machine with no NAT in front of it is found open", kind == "open", kind)
test("and its outside address is its own", mip == lip and mport == lport, tostring(mip) .. ":" .. tostring(mport))
ep:send(nat.encode({ kind = "BIND", token = 77, flags = nat.FLAG.ALT_IP }), nip, nport)
ep:wait(1)
local data, from = ep:receive()
test("the reflector answers from its second address when asked", data and nat.decode(data).token == 77 and from == "127.0.0.2", from)
ep:send(nat.encode({ kind = "BIND", token = 78 }), nip, nalt)
ep:wait(1)
local d2, from2, fport2 = ep:receive()
test("and questions to its other port are answered from there", d2 and nat.decode(d2).token == 78 and fport2 == nalt, fport2)
ep:close()

local t0 = socket.gettime()
local none = nat.detect_type({ stun_server = "127.0.0.1:" .. (nalt == 65535 and 1 or nalt + 1), local_ip = "127.0.0.1" })
local took = socket.gettime() - t0
test("where nothing answers, blocked, after a second", none == "blocked" and took >= 0.95 and took < 2, tostring(none) .. " " .. took)
-- }}}

-- {{{ a punch through the matchmaking server
print("a punch through the matchmaking server")
local host = assert(client.connect({ host = ip, port = port, name = "Host" }))
local player = assert(client.connect({ host = ip, port = port, name = "Ann" }))
local lobby = host:create_lobby({ map_name = "Punch", map_hash = "h", max_players = 2, game_mode = "x", region = "lo" })
local games = player:list_games({})
local plobby = player:join_game(games[1], "Ann")
test("a host and a player share a lobby", lobby and plobby and plobby.game_id == lobby.game_id)

local hep, pep = nat.udp("127.0.0.1", 0), nat.udp("127.0.0.1", 0)
local hkind, hip, hport = nat.detect_type({ stun_server = nip .. ":" .. nport, endpoint = hep })
local hs = nat.session(lobby, { endpoint = hep, mapped_ip = hip, mapped_port = hport })
local ps = nat.session(plobby, { endpoint = pep })        -- the server fills in its address
local got = {}
for name, s in pairs({ host = hs, player = ps }) do
    s:on("established", function(id) got[#got + 1] = name .. " open " .. id end)
    s:on("failed", function(id) got[#got + 1] = name .. " failed " .. id end)
    s:on("data", function(id, d) got[#got + 1] = name .. " got " .. d end)
end
local function has(want) for _, g in ipairs(got) do if g == want then return true end end return false end
local function until_(done, seconds)
    local t = socket.gettime()
    while not done() and socket.gettime() - t < seconds do
        host:poll(0.002) player:poll(0.002)
        hs:step() ps:step()
    end
    return done()
end

local t1 = socket.gettime()
ps:start()
test("both sides punch through, over real UDP",
    until_(function() return has("host open " .. plobby.player_id) and has("player open " .. lobby.player_id) end, 3), table.concat(got, ", "))
test("well within the five seconds", socket.gettime() - t1 < 1, socket.gettime() - t1)
local _, pport = pep:local_address()
test("the host punched to the player's own socket", hs:punch_for(plobby.player_id).remote_port == pport)
hs:punch_for(plobby.player_id):send("unit 4 moves")
ps:punch_for(lobby.player_id):send("unit 9 attacks")
test("the game's datagrams cross both ways", until_(function() return has("player got unit 4 moves") and has("host got unit 9 attacks") end, 2))
hep:close() pep:close()
host:disconnect() player:disconnect()
kill(pid, pipe)
-- }}}

print(string.format("\nTests: %d passed, %d failed", pass_count, test_count - pass_count))
print(string.format("matchmaking NAT over the network: %d of %d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
