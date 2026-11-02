#!/usr/bin/env luajit
-- test_cache_loader.lua - any asset by its path, the player's packs first (issue 601)
--
-- In plain terms: the cache keeps what was used last within its byte limit
-- and drops what was used longest ago; the loader finds a file in the
-- player's asset packs before the map, whatever the case or slashes, and
-- in the map when no pack has it; decodes textures and models by their
-- extension; says where each came from; says what is missing and counts
-- it; and its numbers (memory, hits, evictions) add up.
--
-- Run: luajit src/tests/test_cache_loader.lua [DIR]
-- Issue: issues/completed/601-asset-loader-resolution.md

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local cache = require("assets.cache")
local loader = require("assets.loader")
local dedup = require("assets.dedup")

local pass, fail = 0, 0
local function test(name, ok, msg)
    if ok then pass = pass + 1; print("  [PASS] " .. name)
    else fail = fail + 1; print("  [FAIL] " .. name .. (msg and (": " .. msg) or "")) end
end
local function sh(s) return "'" .. s:gsub("'", "'\\''") .. "'" end

-- {{{ The cache
print("\n=== The cache ===")
local c = cache.new(100)
c:put("a", "A", 40)
c:put("b", "B", 40)
test("two entries within the limit", c:stats().count == 2 and c:stats().bytes == 80)
test("get gives the value and counts a hit", c:get("a") == "A" and c:stats().hits == 1)
c:put("c", "C", 40)
test("over the limit: the one used longest ago goes (b, not a)", not c:has("b") and c:has("a") and c:has("c"))
test("an eviction is counted", c:stats().evictions == 1 and c:stats().bytes == 80)
test("a miss is counted", c:get("b") == nil and c:stats().misses == 1)
test("most recently used first", table.concat(c:keys(), "") == "ca")
test("an entry bigger than the whole limit isn't kept", c:put("huge", "H", 101) == false and not c:has("huge")
    and c:stats().count == 2)
c:put("a", "A2", 10)
test("putting a key again replaces it and its charge", c:get("a") == "A2" and c:stats().bytes == 50)
local big = cache.new(1000)
for i = 1, 50 do big:put(i, i, 100) end
test("fifty puts into room for ten: the last ten stay", big:stats().count == 10 and big:has(50) and big:has(41)
    and not big:has(40) and big:stats().evictions == 40)
c:clear()
test("clear empties it", c:stats().count == 0 and c:stats().bytes == 0 and c:get("a") == nil)
test("a limit must be a number", not pcall(cache.new, "lots"))
-- }}}

-- {{{ The loader on a test map
print("\n=== Packs first, then the map ===")
local MAP = DIR .. "/assets/Daow4.4.w3x"
local mpq = require("mpq")
local archive = mpq.open(MAP)
if not archive then
    print("  [SKIP] " .. MAP .. " isn't here (or StormLib isn't built)")
else
    local SCRATCH = os.tmpname()
    os.remove(SCRATCH)
    local DATA = SCRATCH .. "/player-data"
    -- An override pack holding one of the map's textures, under another
    -- case and with forward slashes, replaced by a different texture.
    local tex21 = archive:extract("File00000021.blp")
    local tex22 = archive:extract("File00000022.blp")
    archive:close()
    -- Packs are folders of links into the store (issue 604), as the
    -- storage manager (605) fills them.
    local store = dedup.open(DATA .. "/blobs")
    local S = {}
    function S:put(_, pack, path, bytes)
        store:link(store:store(bytes), DATA .. "/asset-packs/" .. pack .. "/" .. path)
    end
    S:put("pack", "overrides", "file00000021.BLP", tex22)
    S:put("pack", "overrides", "Sounds/hit.wav", "RIFF....WAVE")
    S:put("pack", "medieval", "file00000021.blp", "a texture the overrides pack hides")
    S:put("pack", "medieval", "broken.blp", "BLP1 but nothing after it")

    local L = loader.new({ map = MAP, packs = { "overrides", "medieval" }, data = DATA, root = DIR })
    local img, from = L:get("File00000021.blp")
    local want = require("parsers.blp").decode(tex22)
    test("a pack's file comes before the map's", from == "pack:overrides" and img.rgba == want.rgba, tostring(from))
    test("matched without regard to case or slashes", L:exists("FILE00000021.blp") and L:exists("sounds\\HIT.wav"))
    local img2, from2 = L:get("File00000022.blp")
    test("no pack has it: the map's", from2 == "map" and img2.width > 0 and #img2.rgba == img2.width * img2.height * 4,
        tostring(from2))
    local m, mfrom = L:get("File00000020.mdx")
    test("a model is parsed", mfrom == "map" and type(m) == "table" and m.version ~= nil, tostring(mfrom))
    local wav, wfrom = L:get("Sounds/hit.wav")
    test("anything else is its bytes", wav == "RIFF....WAVE" and wfrom == "pack:overrides")
    local raw, rfrom = L:read("File00000021.blp")
    test("read gives the bytes, from the same place", raw == tex22 and rfrom == "pack:overrides")

    local none, msg = L:get("Textures\\NoSuchThing.blp")
    test("missing: nil and where it looked", none == nil and msg:find("not found", 1, true)
        and msg:find("pack overrides, pack medieval, the map", 1, true), msg)
    local bad, bmsg = L:get("broken.blp")
    test("found but unreadable: nil, the source and the reader's reason", bad == nil
        and bmsg:find("from pack:medieval", 1, true), bmsg)
    test("exists says no for the missing", not L:exists("Textures\\NoSuchThing.blp"))

    print("\n=== The numbers ===")
    local before = L:stats()
    L:get("File00000021.blp")
    L:get("File00000021.blp")
    local after = L:stats()
    test("a second get is a cache hit", after.cache_hits == before.cache_hits + 2 and after.loads == before.loads)
    test("missing and failed are counted apart", after.missing == 1 and after.failed == 1,
        after.missing .. ", " .. after.failed)
    local m_bytes = #(require("mpq").open(MAP):extract("File00000020.mdx"))
    test("memory is the images' pixels, the model's file and the bytes kept",
        after.memory_bytes == #img.rgba + #img2.rgba + m_bytes + #wav, tostring(after.memory_bytes))
    test("memory_mb agrees", math.abs(after.memory_mb - after.memory_bytes / 1048576) < 1e-9)

    -- A limit that holds one texture only
    local small = loader.new({ map = MAP, packs = {}, data = DATA, root = DIR,
                               limit_mb = (#img2.rgba + 10) / 1048576 })
    small:get("File00000022.blp")
    small:get("File00000023.blp")
    local s = small:stats()
    test("a small limit evicts the older texture", s.loaded_count == 1 and s.evictions == 1, s.loaded_count .. ", " .. s.evictions)
    test("the evicted one loads again on asking", small:get("File00000022.blp") ~= nil and small:stats().loads == 3)
    small:close()

    local n, problems = L:preload({ "File00000024.blp", "File00000025.mdx", "nothing.blp" })
    test("preload loads what it can and says what it couldn't", n == 2 and #problems == 1)
    -- a file added to a pack after a miss is found after clear()
    S:put("pack", "medieval", "Textures/NoSuchThing.blp", tex21)
    test("a miss is remembered until clear", L:get("Textures\\NoSuchThing.blp") == nil)
    L:clear()
    test("after clear, the pack's new file is found", select(2, L:get("Textures\\NoSuchThing.blp")) == "pack:medieval")
    test("clear empties the cache and the counts", L:stats().loaded_count == 1 and L:stats().missing == 0)
    L:close()

    print("\n=== Which packs ===")
    local all = loader.new({ data = DATA, root = DIR })
    test("by default every pack, by name (medieval before overrides)", all.packs[1].name == "medieval"
        and all.packs[2].name == "overrides")
    test("with no map, only the packs", select(2, all:read("file00000021.blp")) == "pack:medieval"
    and select(2, all:read("File00000022.blp")):find("looked in pack medieval, pack overrides)", 1, true))
    test("a pack that isn't there is an error", not pcall(loader.new, { data = DATA, packs = { "nope" } }))
    test("a map that won't open is an error", not pcall(loader.new, { data = DATA, map = SCRATCH .. "/no.w3x", root = DIR }))
    os.execute("rm -rf " .. sh(SCRATCH))
end
-- }}}

print(string.format("\nTests: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
