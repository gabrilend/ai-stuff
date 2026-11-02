#!/usr/bin/env luajit
-- test_dedup.lua - each file stored once, by its hash (issue 604)
--
-- In plain terms: the same bytes stored twice are kept once, under the
-- SHA-256 the standard gives for them; ten maps linking one texture make
-- one blob and ten references; deleting a map's folder drops its references
-- with no call; gc() removes only what nothing links to and nothing pins;
-- the store reads back the same after a restart and after the whole player
-- data folder is moved; and the player data folder is in the project unless
-- the config file moves it.
--
-- Run: luajit src/tests/test_dedup.lua [DIR]
-- Issue: issues/completed/604-asset-deduplication-system.md

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local dedup = require("assets.dedup")
local player_data = require("assets.player_data")

local pass, fail = 0, 0
local function test(name, ok, msg)
    if ok then pass = pass + 1; print("  [PASS] " .. name)
    else fail = fail + 1; print("  [FAIL] " .. name .. (msg and (": " .. msg) or "")) end
end

local function sh(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function read(path)
    local f = io.open(path, "rb"); if not f then return nil end
    local t = f:read("*a"); f:close(); return t
end
local function write(path, text)
    local f = assert(io.open(path, "wb")); f:write(text); f:close()
end
local function run(cmd)
    local p = io.popen(cmd); local out = p:read("*a"); p:close(); return out
end
local function errors(f, ...)
    local ok, err = pcall(f, ...)
    return not ok, tostring(err)
end

local SCRATCH = os.tmpname()
os.remove(SCRATCH)
os.execute("mkdir -p " .. sh(SCRATCH))

local ABC = "sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
local EMPTY = "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

-- {{{ Storing
print("\n=== Storing ===")
local S = dedup.open(SCRATCH .. "/data/blobs")
local h, new = S:store("abc")
test("the hash is the standard's SHA-256 of the bytes", h == ABC, h)
test("the first store is new", new == true)
test("the empty file has its standard hash too", S:store("") == EMPTY)
local h2, new2 = S:store("abc")
test("the same bytes again: same hash, not new", h2 == ABC and new2 == false)
test("kept once: one blob per distinct content", #S:list() == 2)
test("the blob sits in a folder named by its first two hex digits",
    S:path(ABC) == S.dir .. "/ba/ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
test("the blob holds the bytes", read(S:path(ABC)) == "abc")
test("exists: yes for a stored hash", S:exists(ABC))
test("exists: no for one never stored", not S:exists("sha256:" .. string.rep("0", 64)))
test("nothing is left half-written", run("ls " .. sh(S.dir .. "/incoming")) == "")

local bad, msg = errors(S.exists, S, "md5:abc")
test("a hash of another kind is refused, by name", bad and msg:find("not a hash", 1, true), msg)
bad, msg = errors(S.exists, S, "sha256:" .. string.rep("A", 64))
test("upper-case hex is refused (one spelling per blob)", bad, msg)
bad = errors(S.store, S, 42)
test("store wants bytes", bad)

-- A file a few pieces long, by store_file and by store.
local parts = {}
for i = 1, 200000 do parts[i] = string.char(i % 251) end
local big = table.concat(parts)
write(SCRATCH .. "/big.bin", big)
local hf, newf = S:store_file(SCRATCH .. "/big.bin")
test("store_file: new, and the same hash store gives the bytes", newf == true and hf == S:store(big))
test("store_file: the blob is the file", read(S:path(hf)) == big)
test("store_file again: not new", select(2, S:store_file(SCRATCH .. "/big.bin")) == false)
local sum = run("sha256sum " .. sh(SCRATCH .. "/big.bin") .. " 2>/dev/null"):match("^(%x+)")
if sum then
    test("agrees with sha256sum", hf == "sha256:" .. sum, sum)
end
-- }}}

-- {{{ Linking
print("\n=== Linking ===")
local MAPS = SCRATCH .. "/data/maps"
for i = 1, 10 do
    S:link(ABC, MAPS .. "/map" .. i .. "/assets/grass.blp")
end
local first = MAPS .. "/map1/assets/grass.blp"
test("a link reads as the blob", read(first) == "abc")
local target = run("readlink " .. sh(first)):gsub("\n$", "")
test("the link is relative, so the folder can move", target:sub(1, 1) ~= "/" and target:find("^%.%./"), target)
test("ten maps, one texture: one blob, ten references", S:refcount(ABC) == 10 and #S:list() == 3)
test("references names each link", S:references(ABC)[1]:find("/map1/assets/grass.blp$") ~= nil)
S:link(ABC, first)
test("linking the same path again changes nothing", S:refcount(ABC) == 10)

bad, msg = errors(S.link, S, "sha256:" .. string.rep("1", 64), MAPS .. "/x/y.blp")
test("no link to a blob that isn't stored", bad and msg:find("no blob", 1, true), msg)
write(MAPS .. "/map1/assets/own.txt", "the player's own file")
bad, msg = errors(S.link, S, ABC, MAPS .. "/map1/assets/own.txt")
test("a real file is never replaced", bad and read(MAPS .. "/map1/assets/own.txt") == "the player's own file", msg)

S:link(EMPTY, MAPS .. "/map10/assets/grass.blp")
test("relinking a path moves its reference", S:refcount(ABC) == 9 and S:refcount(EMPTY) == 1
    and read(MAPS .. "/map10/assets/grass.blp") == "")

test("release removes the link and its reference", S:release(MAPS .. "/map9/assets/grass.blp")
    and S:refcount(ABC) == 8 and read(MAPS .. "/map9/assets/grass.blp") == nil)
test("release of a path that isn't a reference says so", S:release(MAPS .. "/map9/assets/grass.blp") == false)

os.execute("rm -rf " .. sh(MAPS .. "/map8"))
test("deleting a map's folder drops its references, with no call", S:refcount(ABC) == 7)
-- }}}

-- {{{ Stats
print("\n=== Stats ===")
local st = S:stats()
test("unique blobs and live references", st.unique_blobs == 3 and st.total_references == 8,
    st.unique_blobs .. " blobs, " .. st.total_references .. " refs")
test("storage is each blob once", st.storage_bytes == 3 + 0 + #big, tostring(st.storage_bytes))
-- abc: 7 links of 3 bytes; empty: 1 link of 0; big: no links, still on disk once.
test("naive is each link as a copy", st.naive_bytes == 7 * 3 + 0 + #big, tostring(st.naive_bytes))
local stub = dedup.open(SCRATCH .. "/stats-only")
local tex = stub:store(string.rep("x", 1000))
for i = 1, 5 do stub:link(tex, SCRATCH .. "/stats-maps/" .. i .. ".blp") end
local s5 = stub:stats()
test("savings: one copy where five would be is 80%", s5.savings_percent == 80
    and s5.storage_bytes == 1000 and s5.naive_bytes == 5000, tostring(s5.savings_percent))
test("an empty store has no savings and no division by zero", dedup.open(SCRATCH .. "/empty"):stats().savings_percent == 0)
-- }}}

-- {{{ After a restart
print("\n=== After a restart ===")
local R = dedup.open(SCRATCH .. "/data/blobs")
test("the list reads back", #R:list() == 3 and R:list()[1] == ABC)
test("the references read back", R:refcount(ABC) == 7 and R:refcount(EMPTY) == 1)
test("a released reference stays released", R.refs[R.dir:gsub("/blobs$", "") .. "/maps/map9/assets/grass.blp"] == nil)
-- }}}

-- {{{ Garbage collection
print("\n=== Garbage collection ===")
local pinned = R:store("keep me")
R:pin(pinned)
local lonely = R:store("nobody links to me")
local before = R:orphans()
test("orphans: what gc would remove (not the pinned one)", #before == 2 and R:refcounts()[ABC:sub(8)] == 7)
local removed, freed = R:gc()
test("gc removes what nothing links to and nothing pins", removed == 2 and freed == #big + #"nobody links to me",
    removed .. " removed, " .. freed .. " bytes")
test("the removed blobs are gone from disk and the list",
    not R:exists(hf) and not R:exists(lonely) and #R:list() == 3)
local shards = {}
for _, hash in ipairs(R:list()) do shards[hash:sub(8, 9)] = true end
test("an emptied shard folder goes too", shards[lonely:sub(8, 9)]
    or not os.rename(R.dir .. "/" .. lonely:sub(8, 9), R.dir .. "/" .. lonely:sub(8, 9)))
test("a pinned blob stays", R:exists(pinned) and R:pinned(pinned))
test("linked blobs stay", R:exists(ABC) and R:exists(EMPTY) and read(first) == "abc")
test("gc forgets references whose links are gone", select(2, read(R.dir .. "/references"):gsub("\n", "")) == 8)
local again = dedup.open(SCRATCH .. "/data/blobs")
test("the rewritten index reads back", #again:list() == 3 and again:pinned(pinned))
R:unpin(pinned)
test("unpinned, it goes at the next gc", R:gc() == 1 and not R:exists(pinned))
test("a second gc has nothing to do", R:gc() == 0)
-- }}}

-- {{{ Verify
print("\n=== Verify ===")
test("a sound store has no problems", #R:verify() == 0)
local victim = R:path(ABC)
os.execute("chmod u+w " .. sh(victim))
write(victim, "tampered")
local problems = R:verify()
test("a changed blob is found", #problems == 1 and problems[1].hash == ABC
    and problems[1].problem:find("no longer match", 1, true))
write(victim, "abc")
-- }}}

-- {{{ Moving the whole folder
print("\n=== Moving the player data folder ===")
os.execute("mv " .. sh(SCRATCH .. "/data") .. " " .. sh(SCRATCH .. "/moved"))
local M = dedup.open(SCRATCH .. "/moved/blobs")
test("the links still lead to the blobs", read(SCRATCH .. "/moved/maps/map1/assets/grass.blp") == "abc")
test("the references moved with it (recorded from the store, as the links are)", M:refcount(ABC) == 7
    and M:references(ABC)[1] == SCRATCH .. "/moved/maps/map1/assets/grass.blp", tostring(M:refcount(ABC)))
-- }}}

-- {{{ The module-level store
print("\n=== dedup.init, as the issue sketches it ===")
dedup.default = nil
bad, msg = errors(dedup.store, "x")
test("before init: a clear error", bad and msg:find("dedup.init", 1, true), msg)
dedup.init(SCRATCH .. "/module")
test("after init: store, exists, list", dedup.store("abc") == ABC and dedup.exists(ABC) and #dedup.list() == 1)
-- }}}

-- {{{ Player data folder
print("\n=== Where the player data lives ===")
local ROOT = SCRATCH .. "/project"
os.execute("mkdir -p " .. sh(ROOT .. "/config"))
local folder, from = player_data.folder(ROOT)
test("by default: player-data in the project", folder == ROOT .. "/player-data" and from == "default")
test("the store goes in its blobs folder", player_data.blobs(ROOT) == ROOT .. "/player-data/blobs")
write(ROOT .. "/config/player-data.lua", 'return { folder = "/srv/games/" }')
folder, from = player_data.folder(ROOT)
test("the config file moves it", folder == "/srv/games" and from == ROOT .. "/config/player-data.lua")
write(ROOT .. "/config/player-data.lua", 'return { folder = "../elsewhere" }')
test("a relative folder is read from the project", player_data.folder(ROOT) == ROOT .. "/../elsewhere")
write(ROOT .. "/config/player-data.lua", 'return { folder = "~/games" }')
test("~/ is the home folder", player_data.folder(ROOT) == os.getenv("HOME") .. "/games")
write(ROOT .. "/config/player-data.lua", 'return { place = "x" }')
bad, msg = errors(player_data.folder, ROOT)
test("a config file without a folder is an error, not a quiet default", bad and msg:find("folder =", 1, true), msg)
write(ROOT .. "/config/player-data.lua", 'return {')
test("a config file that doesn't load is an error", (errors(player_data.folder, ROOT)))
-- }}}

-- {{{ A real map
print("\n=== A real map ===")
local MAP = DIR .. "/assets/DAoW-2.1.w3x"
if io.open(MAP, "rb") then
    local real = dedup.open(SCRATCH .. "/real")
    local hm = real:store_file(MAP)
    local want = run("sha256sum " .. sh(MAP) .. " 2>/dev/null"):match("^(%x+)")
    test("a map's hash agrees with sha256sum", not want or hm == "sha256:" .. want, want)
    real:link(hm, SCRATCH .. "/real-maps/a/DAoW-2.1.w3x")
    real:link(hm, SCRATCH .. "/real-maps/b/DAoW-2.1.w3x")
    local mpq = require("mpq")
    local archive = mpq.open(SCRATCH .. "/real-maps/b/DAoW-2.1.w3x")
    test("the map opens through its link", archive ~= nil)
    if archive and archive.close then archive:close() end
    test("two places, one copy: savings 50%", real:stats().savings_percent == 50)
else
    print("  [SKIP] " .. MAP .. " isn't here")
end
-- }}}

os.execute("rm -rf " .. sh(SCRATCH))
print(string.format("\nTests: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
