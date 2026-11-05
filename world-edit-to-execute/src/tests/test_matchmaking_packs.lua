-- test_matchmaking_packs.lua - the asset mirror's packs, what it tells players, what they lack (issue 801f)
--
-- In plain terms: makes a few pack files in a folder of its own, and
-- checks the mirror's list of them (hashes, adding, removing, files that
-- aren't packs), which of a lobby's packs a mirror holds, and where a
-- player should fetch each pack it lacks. Then the matchmaking server's
-- core with a mirror: whoever opens or joins a lobby whose packs it holds
-- is told so, with the mirror's rmail contact, through the client library.
--
-- The folder is made with `mktemp -d` (under $TMPDIR when set) and removed
-- at the end.
--
-- Run with: luajit src/tests/test_matchmaking_packs.lua [DIR]
-- (DIR defaults to the project this file is in.)

-- The project: the argument, or the folder this test sits in (run-tests.sh
-- runs each test by its full path, from the project), or the owner's.
local DIR = arg[1] or arg[0]:match("^(.+)/src/tests/[^/]+%.lua$") or (arg[0]:match("^src/tests/") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local packs = require("matchmaking.packs")
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

local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

local p = io.popen("mktemp -d -t wete-packs.XXXXXX")
local ROOT = p:read("*l")
p:close()
if not (ROOT and ROOT:match("wete%-packs%.") and io.open(ROOT .. "/.", "r")) then
    print("  [FAIL] no folder of its own to work in")
    os.exit(1)
end

local function write(path, data)
    local f = assert(io.open(path, "wb"))
    f:write(data)
    f:close()
end
local function exists(path)
    local f = io.open(path, "rb")
    if f then f:close() end
    return f ~= nil
end

local HELLO = "sha256:5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03"   -- "hello\n"
-- }}}

-- {{{ hashing
print("hashing")
write(ROOT .. "/hello.txt", "hello\n")
local h, size = packs.hash_file(ROOT .. "/hello.txt")
test("a file's hash is sha256: and its SHA-256", h == HELLO and size == 6, h)
write(ROOT .. "/it's here.txt", "hello\n")
test("a name with a quote in it is hashed the same", packs.hash_file(ROOT .. "/it's here.txt") == HELLO)
local none, why = packs.hash_file(ROOT .. "/nothing")
test("no file: nil and why", none == nil and why:find("no such file", 1, true))
-- }}}

-- {{{ the registry
print("the registry")
local MIRROR = ROOT .. "/mirror"
os.execute("mkdir " .. quote(MIRROR))
write(MIRROR .. "/medieval-v1.pack", "hello\n")
write(MIRROR .. "/sci-fi_v1.0.pack", string.rep("x", 1000))
write(MIRROR .. "/-bad.pack", "x")
write(MIRROR .. "/readme.txt", "not a pack")
os.execute("mkdir " .. quote(MIRROR .. "/folder.pack"))
local reg = packs.registry(MIRROR .. "/")
local list = reg:list()
test("it holds every *.pack file with a good id, by id", #list == 2 and list[1].id == "medieval-v1" and list[2].id == "sci-fi_v1.0")
test("each with its hash, size and file", list[1].hash == HELLO and list[1].size == 6 and list[2].size == 1000
    and list[1].file == MIRROR .. "/medieval-v1.pack")
test("a file whose name isn't a pack id is skipped, and said", #reg.skipped == 1 and reg.skipped[1]:find("-bad.pack", 1, true))
test("has: by id, and by id and hash", reg:has("medieval-v1") and reg:has("medieval-v1", HELLO) and not reg:has("medieval-v1", "sha256:00")
    and not reg:has("nope"))
write(ROOT .. "/fantasy.bin", "fantasy\n")
local added = reg:add("fantasy-v2", ROOT .. "/fantasy.bin")
test("add copies a file in as a pack", added and added.id == "fantasy-v2" and exists(MIRROR .. "/fantasy-v2.pack")
    and added.hash == packs.hash_file(ROOT .. "/fantasy.bin") and reg:has("fantasy-v2"))
test("and leaves nothing half-written", not exists(MIRROR .. "/fantasy-v2.pack.part"))
test("the source stays", exists(ROOT .. "/fantasy.bin"))
local big = string.rep("0123456789abcdef", 200000)                -- over one chunk
write(ROOT .. "/big.bin", big)
local bp = reg:add("big", ROOT .. "/big.bin")
test("a file over a chunk is copied whole", bp and bp.size == #big and bp.hash == packs.hash_file(ROOT .. "/big.bin"))
local n1, w1 = reg:add("bad id", ROOT .. "/fantasy.bin")
test("a bad id is refused", n1 == nil and w1:find("a pack id is", 1, true))
test("so are ids with a slash or too long", reg:add("../up", ROOT .. "/fantasy.bin") == nil and select(2, reg:add("a/b", ROOT .. "/fantasy.bin")):find("a pack id is", 1, true) and reg:add(string.rep("a", 65), ROOT .. "/fantasy.bin") == nil
    and reg:add(string.rep("a", 64), ROOT .. "/fantasy.bin") ~= nil)
local n2, w2 = reg:add("ghost", ROOT .. "/nothing")
test("a missing source is refused", n2 == nil and w2:find("no such file", 1, true) and not exists(MIRROR .. "/ghost.pack"))
test("remove takes it off and deletes its file", reg:remove("fantasy-v2") == true and not reg:has("fantasy-v2")
    and not exists(MIRROR .. "/fantasy-v2.pack"))
local n3, w3 = reg:remove("fantasy-v2")
test("removing what isn't there says so", n3 == nil and w3 == "no pack fantasy-v2")
write(MIRROR .. "/late.pack", "late\n")
os.remove(MIRROR .. "/big.pack")
test("reload sees the folder as it is now", not reg:has("late") and reg:reload():has("late") and not reg:has("big"))
for _, id in ipairs({ "zeta", "alpha", "mid", "beta2", "omega", "k" }) do reg:add(id, ROOT .. "/fantasy.bin") end
local ids, sorted = {}, true
for i, q in ipairs(reg:list()) do ids[i] = q.id if i > 1 and ids[i - 1] >= q.id then sorted = false end end
test("the list is by id", sorted and #ids == 10, table.concat(ids, ","))
for _, id in ipairs({ "zeta", "alpha", "mid", "beta2", "omega", "k" }) do reg:remove(id) end
test("a registry needs a folder", refused(function() packs.registry() end, "needs a folder"))
test("an empty or missing folder is an empty registry", #packs.registry(ROOT .. "/none"):list() == 0)
-- }}}

-- {{{ for a lobby
print("for a lobby")
local required = { { id = "medieval-v1", hash = HELLO }, { id = "sci-fi_v1.0", hash = "sha256:other" }, { id = "rare", hash = "sha256:r" } }
local av = packs.available(reg, required)
test("the mirror offers the lobby's packs it holds, same hash only", #av == 1 and av[1].id == "medieval-v1" and av[1].hash == HELLO and av[1].size == 6)
test("none without a mirror or a list", #packs.available(nil, required) == 0 and #packs.available(reg, nil) == 0)
local plan = packs.plan(required, { ["sci-fi_v1.0"] = "sha256:other" }, av)
test("a plan: what's missing, the mirror first", #plan == 2 and plan[1].id == "medieval-v1" and plan[1].from == "mirror" and plan[1].size == 6)
test("the host for what the mirror doesn't hold", plan[2].id == "rare" and plan[2].from == "host" and plan[2].size == nil)
plan = packs.plan(required, { ["medieval-v1"] = "sha256:old" }, av)
test("another version of a pack counts as missing", #plan == 3 and plan[1].from == "mirror")
plan = packs.plan(required, reg, nil)
test("a registry can be what the player has", #plan == 2 and plan[1].id == "sci-fi_v1.0" and plan[1].from == "host")
test("nothing needed, nothing to fetch", #packs.plan({}, {}, av) == 0 and #packs.plan(nil, nil, nil) == 0)
test("a mirror pack under another hash is no help", packs.plan({ { id = "medieval-v1", hash = "sha256:new" } }, {}, av)[1].from == "host")
-- }}}

-- {{{ through the server
print("through the server")
test("a mirror needs a contact and a registry", refused(function() server.new({ mirror = { packs = reg } }) end, "mirror should be")
    and refused(function() server.new({ mirror = { contact = "", packs = reg } }) end, "mirror should be")
    and refused(function() server.new({ mirror = { contact = "m", packs = {} } }) end, "mirror should be")
    and refused(function() server.new({ mirror = "yes" }) end, "mirror should be"))

local now = 0
local srv, wires
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
local function wire(name)
    local c = client.new({ name = name, clock = function() return now end, pump = pump, log = function() end })
    wires[#wires + 1] = { c = c, id = srv:accept("10.0.0." .. (#wires + 1), 40000 + #wires) }
    return c
end
local logged = {}
srv = server.new({ clock = function() return now end, mirror = { contact = "mirror@matchmaking.example", packs = reg },
    log = function(l) logged[#logged + 1] = l end })
wires = {}
local hc, pc, qc = wire("Host"), wire("Ann"), wire("Bo")
local game = { map_name = "Castle", map_hash = "h", asset_packs = required, max_players = 4, game_mode = "x", region = "r" }
local lobby = hc:create_lobby(game)
test("the host is told which of its packs the mirror holds", lobby.mirror and lobby.mirror.contact == "mirror@matchmaking.example"
    and #lobby.mirror.packs == 1 and lobby.mirror.packs[1].id == "medieval-v1" and lobby.mirror.packs[1].size == 6)
local games = pc:list_games({})
test("the list carries a lobby's packs", #games[1].asset_packs == 3 and games[1].asset_packs[1].hash == HELLO)
local got
local pl = pc:join_game(games[1], "Ann", function(l) l:on("asset_packs", function(m) got = m end) end)
pump()
test("a player joining hears it as an event too", got and got.contact == "mirror@matchmaking.example" and got.packs[1].hash == HELLO)
local missing = pl:missing_packs({ ["sci-fi_v1.0"] = "sha256:other" })
test("missing_packs: what to fetch, and from where", #missing == 2 and missing[1].from == "mirror" and missing[2].from == "host" and missing[2].id == "rare")
local ql = qc:join_game(lobby.game_id, "Bo")
local m2, w4 = ql:missing_packs({})
test("joined by id alone, the lobby's packs aren't known", m2 == nil and w4 == "the lobby's packs are not known" and ql.mirror ~= nil)
local plain = wire("Plain")
local pl2 = plain:create_lobby({ map_name = "Plain", map_hash = "h", asset_packs = { { id = "rare", hash = "sha256:r" } }, max_players = 2,
    game_mode = "x", region = "r" })
test("a lobby needing nothing the mirror holds hears nothing of it", pl2 and pl2.mirror == nil)
test("and has everything to fetch from its host", #pl2:missing_packs({}) == 1 and pl2:missing_packs({})[1].from == "host")
reg:add("rare", ROOT .. "/fantasy.bin")
local late = wire("Late")
local ll = late:join_game(pl2.game_id, "Late")
test("a pack added under another hash is not that lobby's", ll.mirror == nil)
local again = wire("Again")
local al = again:create_lobby({ map_name = "Again", map_hash = "h", asset_packs = { { id = "rare", hash = reg:get("rare").hash } },
    max_players = 2, game_mode = "x", region = "r" })
test("a pack added to the mirror counts at once, for a lobby with its hash", al.mirror and al.mirror.packs[1].id == "rare")
local nomirror = server.new({ clock = function() return now end })
srv, wires = nomirror, {}
local nc = wire("N")
local nl = nc:create_lobby(game)
test("a server without a mirror says nothing of packs", nl and nl.mirror == nil and #nl:missing_packs({}) == 3)
-- }}}

-- the folder this test made, and nothing else
if ROOT:match("/wete%-packs%.[%w]+$") then os.execute("rm -rf -- " .. quote(ROOT)) end
test("its folder is gone", not io.open(ROOT .. "/.", "r"))

print(string.format("\nTests: %d passed, %d failed", pass_count, test_count - pass_count))
print(string.format("matchmaking asset packs: %d of %d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
