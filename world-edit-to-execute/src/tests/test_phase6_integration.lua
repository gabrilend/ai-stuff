#!/usr/bin/env luajit
-- test_phase6_integration.lua - the asset system as a whole (issue 608)
--
-- In plain terms: a real map's textures and sounds load through the
-- loader, and a missing one gets the wire-frame fallback; a shared list
-- arrives from another player, only the missing files come over, and a
-- second time nothing does; two asset packs that share a file store it
-- once, and deleting one keeps the other whole until garbage collection
-- takes what nobody uses; the storage manager's totals add up; and a
-- texture saved in a pack is read again and swapped into the renderer
-- while a broken save keeps the old one.
--
-- Nothing touches the network and nothing needs a window: the other
-- player is an in-process transport, the renderer is a fake that records
-- its calls, and every file is made in a temporary folder that is
-- removed at the end.
--
-- Run: luajit src/tests/test_phase6_integration.lua [DIR] [--scenario=NAME] [--summary]
--      NAME: map_loading, fallback, download, dedup, storage, hotreload
-- Issue: issues/completed/608-phase6-integration-test.md

local DIR, ONLY, SUMMARY = nil, nil, false
for _, a in ipairs(arg) do
    if a:match("^%-%-scenario=") then ONLY = a:match("=(.*)$")
    elseif a == "--summary" then SUMMARY = true
    elseif not a:match("^%-%-") then DIR = a end
end
DIR = DIR or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

-- {{{ infrastructure
local results, current = {}, nil
local function test(name, ok, msg)
    local r = results[current]
    if ok then r.pass = r.pass + 1; print("  [PASS] " .. name)
    else r.fail = r.fail + 1; print("  [FAIL] " .. name .. (msg and (": " .. msg) or "")) end
end
local function sh(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function write(path, bytes)
    os.execute("mkdir -p " .. sh(path:match("^(.*)/[^/]*$")))
    local f = assert(io.open(path, "wb")); f:write(bytes); f:close()
end
local function read(path) local f = io.open(path, "rb"); if not f then return nil end local t = f:read("*a"); f:close(); return t end
local function exists(path) return os.rename(path, path) ~= nil end
-- an uncompressed N by N TGA of one colour
local function tga(n, r, g, b)
    return string.char(0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, n % 256, math.floor(n / 256), n % 256, math.floor(n / 256), 32, 0x28)
        .. string.char(b, g, r, 255):rep(n * n)
end
local function colour(img) if type(img) ~= "table" then return "none" end local r, g, b = img.rgba:byte(1, 3); return r .. "," .. g .. "," .. b end
local function fake_render()
    local calls = { created = {}, updated = {} }
    return {
        tex_create = function(w, h, rgba) calls.created[#calls.created + 1] = { w = w, h = h, rgba = rgba }; return #calls.created end,
        tex_update = function(id, w, h, rgba) calls.updated[#calls.updated + 1] = { id = id, w = w, h = h, rgba = rgba } end,
        mesh_create = function() return 1 end, model_create = function() return 1 end,
        calls = calls,
    }
end

local SCRATCH = os.tmpname()
os.remove(SCRATCH)
local function scratch(name) local d = SCRATCH .. "/" .. name; os.execute("mkdir -p " .. sh(d)); return d end
local MAP = DIR .. "/assets/DAoW-2.1.w3x"
-- }}}

local scenarios, order = {}, {}
local function scenario(name, title, needs, fn)
    order[#order + 1] = name
    scenarios[name] = { title = title, needs = needs, fn = fn }
end

-- {{{ Scenario 1: a WC3 map's assets
scenario("map_loading", "Loading a WC3 map's assets", { "assets.loader", "mpq" }, function()
    local loader = require("assets.loader")
    local mpq = require("mpq")
    test("the test map is here", exists(MAP), MAP)
    -- the test maps carry no sounds of their own, so a pack brings one: a
    -- tiny 16-bit mono WAV at 22050 Hz
    local data = scratch("map-data")
    local function u32(n) return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216)) end
    local function u16(n) return string.char(n % 256, math.floor(n / 256)) end
    local samples = ("\0\0"):rep(64)
    write(data .. "/asset-packs/sounds/Sound/Horn.wav", "RIFF" .. u32(36 + #samples) .. "WAVE" .. "fmt " .. u32(16)
        .. u16(1) .. u16(1) .. u32(22050) .. u32(44100) .. u16(2) .. u16(16) .. "data" .. u32(#samples) .. samples)
    local L = loader.new({ map = MAP, packs = { "sounds" }, data = data, root = DIR })
    local tex
    local ar = mpq.open(MAP)
    for _, name in ipairs(ar:list()) do
        if not tex and name:lower():match("%.blp$") then tex = name end
    end
    ar:close()
    test("the map's archive lists a texture", tex ~= nil)
    local img, from = L:get(tex)
    test("a texture loads from the map, with its size", type(img) == "table" and img.width > 0 and img.height > 0
        and #img.rgba == img.width * img.height * 4 and from == "map", tostring(from))
    local bytes, sfrom = L:get("Sound\\Horn.wav")
    local function le(at, n) local v = 0; for k = n - 1, 0, -1 do v = v * 256 + bytes:byte(at + k) end return v end
    test("a sound loads as its bytes: a RIFF WAVE, PCM, mono, 22050 Hz", type(bytes) == "string" and bytes:sub(1, 4) == "RIFF"
        and bytes:sub(9, 12) == "WAVE" and le(21, 2) == 1 and le(23, 2) == 1 and le(25, 4) == 22050 and sfrom == "pack:sounds",
        tostring(sfrom))
    local none, why = L:get("Textures\\NotInThisMap.blp")
    test("a missing texture: nil and where it was looked for", none == nil and type(why) == "string" and why:match("map"), why)
    local before = L:stats()
    L:get(tex)
    local after = L:stats()
    test("the second get is a cache hit", after.cache_hits == before.cache_hits + 1 and after.loads == before.loads)
    test("the cache counts what it holds", after.memory_bytes >= #img.rgba and after.missing >= 1)
    L:close()
end)
-- }}}

-- {{{ Scenario: the wire-frame fallback
scenario("fallback", "The wire-frame fallback for missing assets", { "assets.loader", "assets.fallback" }, function()
    local loader = require("assets.loader")
    local fallback = require("assets.fallback")
    local L = loader.new({ map = MAP, packs = {}, data = scratch("fb-data"), root = DIR })
    local F = fallback.new({ loader = L, has_model = function(obj) return obj.type_id == "real" end })
    local ph = F:texture("Textures\\NotInThisMap.blp", "unit")
    test("a missing texture gets a placeholder picture", type(ph) == "table" and ph.width > 0 and #ph.rgba == ph.width * ph.height * 4)
    test("and is drawn by the fallback from then on", F:is_active("Textures\\NotInThisMap.blp"))
    test("a texture the map has isn't", (function()
        local name
        local ar = require("mpq").open(MAP)
        for _, n in ipairs(ar:list()) do if n:lower():match("%.blp$") then name = n; break end end
        ar:close()
        F:texture(name)
        return not F:is_active(name)
    end)())
    local out = F:build({ terrain = fallback.blank(8, 8),
                          objects = { { kind = "unit", type_id = "gone", x = 0, y = 0 }, { kind = "unit", type_id = "real", x = 64, y = 0 } } })
    test("an object with no model is a wire box; one with a model is left to it", out.drawn.unit == 1 and out.skipped == 1)
    test("a blank map is a grid of lines", out.lines > 2 * 8 * 9 and #out.prims > 0)
    F:force_wireframe(true)
    test("forced wire-frame draws everything", F:build({ objects = { { kind = "unit", type_id = "real", x = 0, y = 0 } } }).drawn.unit == 1)
    L:close()
end)
-- }}}

-- {{{ Scenario 2: from another player (the in-process "server")
scenario("download", "Assets from another player", { "share.list", "share.exchange", "share.profile", "assets.loader" }, function()
    local list = require("share.list")
    local exchange = require("share.exchange")
    local loader = require("assets.loader")
    local dedup = require("assets.dedup")
    local A, B = scratch("ana"), scratch("ben")
    local PACK = A .. "/asset-packs/mine"
    write(PACK .. "/Textures/Grass.tga", tga(2, 200, 0, 0))
    write(PACK .. "/Textures/Dirt.tga", tga(2, 0, 200, 0))
    write(PACK .. "/sounds/horn.wav", "RIFF....WAVE a horn")
    write(SCRATCH .. "/castle.w3x", "a map's bytes")
    local l = list.build({ map = SCRATCH .. "/castle.w3x", map_name = "Castle", pack = PACK, author = "Ana", created = "2026-11-03" })
    -- the mock network: queues, delivered by hand; counts what crossed
    local queues, crossed = { ana = {}, ben = {} }, { list = 0, want = 0, files = 0, file_count = 0 }
    local function transport(me)
        return { send = function(to, msg)
            msg.from = me
            crossed[msg.kind] = crossed[msg.kind] + 1
            if msg.kind == "files" then crossed.file_count = crossed.file_count + #msg.files end
            table.insert(queues[to], msg)
        end }
    end
    local function deliver(X, who) while #queues[who] > 0 do X:on_message(table.remove(queues[who], 1)) end end
    local ready = {}
    local ana = exchange.new({ data = A, me = "ana", pack = PACK, transport = transport("ana") })
    local ben = exchange.new({ data = B, me = "ben", transport = transport("ben"),
                               on_ready = function(pack) ready[#ready + 1] = pack end })
    -- Ben already has the horn
    write(SCRATCH .. "/horn.wav", "RIFF....WAVE a horn")
    dedup.open(B .. "/blobs"):store_file(SCRATCH .. "/horn.wav")
    local id = ana:offer("ben", l)
    deliver(ben, "ben")
    test("the manifest (the list) arrives and waits for Ben's yes", crossed.list == 1 and #ben:pending() == 1
        and ben:pending()[1].missing == 2)
    ben:answer(id, "yes")
    test("Ben reports what he already has: he asks for 2 of 3", crossed.want == 1 and #queues.ana[1].hashes == 2)
    deliver(ana, "ana")
    deliver(ben, "ben")
    test("only the two missing files came over", crossed.files == 1 and crossed.file_count == 2)
    test("and the list was kept as a pack of Ben's own", #ready == 1 and ready[1] == B .. "/asset-packs/share-" .. id)
    local L = loader.new({ packs = { "share-" .. id }, data = B, root = DIR })
    test("every asset is there through the loader", colour(L:get("textures/grass.tga")) == "200,0,0"
        and colour(L:get("Textures\\Dirt.tga")) == "0,200,0" and L:get("sounds/horn.wav") == "RIFF....WAVE a horn")
    -- disconnect and reconnect: the same list again
    ana:sent(id)
    local files_before = crossed.files
    local id2 = ana:offer("ben", l)
    deliver(ben, "ben")
    ben:answer(id2, "yes")
    test("offered again: nothing is downloaded again (all stored)", crossed.files == files_before and crossed.want == 1
        and #ready == 2)
    L:close()
end)
-- }}}

-- {{{ Scenario 3: deduplication between two packs
scenario("dedup", "Deduplication between two asset packs", { "assets.storage", "assets.dedup" }, function()
    local storage = require("assets.storage")
    local D = scratch("dedup-data")
    local S = storage.open(D)
    local shared, a_only, b_only = ("shared texture "):rep(64), ("server A only "):rep(32), ("server B only "):rep(16)
    S:put("pack", "server-a", "textures/shared.blp", shared)
    S:put("pack", "server-a", "textures/a.blp", a_only)
    S:put("pack", "server-b", "textures/shared.blp", shared)
    S:put("pack", "server-b", "textures/b.blp", b_only)
    local o = S:overview()
    test("three different files stored, the shared one once", o.blob_count == 3
        and o.total_bytes == #shared + #a_only + #b_only, o.blob_count .. " " .. o.total_bytes)
    test("the savings are the shared file's size", o.savings_bytes == #shared and o.naive_bytes == 2 * #shared + #a_only + #b_only)
    test("the shared file is counted as shared", o.shared_bytes == #shared)
    S:delete("pack", "server-a")
    test("server A deleted: B's shared file is still there", read(D .. "/asset-packs/server-b/textures/shared.blp") == shared)
    S:gc()
    test("and after gc too", read(D .. "/asset-packs/server-b/textures/shared.blp") == shared and S:overview().blob_count == 2)
    S:delete("pack", "server-b")
    local removed = S:gc()
    test("server B deleted, gc: every orphan removed", removed == 2 and S:overview().blob_count == 0
        and S:overview().total_bytes == 0, tostring(removed))
end)
-- }}}

-- {{{ Scenario 4: storage management
scenario("storage", "Storage management", { "assets.storage" }, function()
    local storage = require("assets.storage")
    local D = scratch("storage-data")
    local S = storage.open(D)
    local common, map_own, pack_own = ("C"):rep(1000), ("M"):rep(300), ("P"):rep(200)
    S:put("map", "castle", "war3map.w3e", map_own)
    S:put("map", "castle", "textures/common.blp", common)
    S:put("pack", "hd", "textures/common.blp", common)
    S:put("pack", "hd", "textures/hd.blp", pack_own)
    local o = S:overview()
    test("the overview's total is every different file once", o.total_bytes == 1500 and o.naive_bytes == 2500)
    local m, p = S:info("map", "castle"), S:info("pack", "hd")
    test("the map: 1300 in all, 300 its own, 1000 shared", m.total_bytes == 1300 and m.unique_bytes == 300 and m.shared_bytes == 1000)
    test("the pack: 1200 in all, 200 its own", p.total_bytes == 1200 and p.unique_bytes == 200)
    local freed = S:delete("pack", "hd")
    test("deleting the pack frees its own bytes", freed == 200, tostring(freed))
    local _, bytes = S:gc()
    test("gc removes them", bytes == 200 and S:overview().total_bytes == 1300, tostring(bytes))
    test("the map is untouched", read(D .. "/maps/castle/textures/common.blp") == common)
end)
-- }}}

-- {{{ Scenario 5: hot-reload
scenario("hotreload", "Hot-reload", { "assets.loader", "assets.hotreload", "assets.gpu.on_reload" }, function()
    local loader = require("assets.loader")
    local hotreload = require("assets.hotreload")
    local gpu = require("assets.gpu")
    local D = scratch("hot-data")
    local PACK = D .. "/asset-packs/mine"
    write(PACK .. "/Textures/Shield.tga", tga(2, 255, 0, 0))
    local L = loader.new({ packs = { "mine" }, data = D, root = DIR })
    local R = fake_render()
    local cache = gpu.new(R, L)
    local tid = cache:texture({ path = "Textures\\Shield.tga", replaceable = 0 })
    test("the texture is loaded into the engine", R.calls.created[tid] and R.calls.created[tid].w == 2)
    local t, reloaded, errored = 0, {}, {}
    local swap = gpu.on_reload(cache)
    local H = hotreload.new(L, { backend = "poll", poll_interval = 0.5, quiet = 0.1, clock = function() return t end,
        on_reload = function(path, value, source) reloaded[#reloaded + 1] = path; swap(path, value) end,
        on_error = function(path, err, kept) errored[#errored + 1] = { path = path, kept = kept } end })
    local function settle()
        local r0, e0 = #reloaded, #errored
        for _ = 1, 30 do t = t + 0.1; H:poll(); if #reloaded > r0 or #errored > e0 then return true end end
        return false
    end
    write(PACK .. "/Textures/Shield.tga", tga(3, 0, 0, 255))
    test("a saved texture: the reload callback fires", settle() and reloaded[1] == "Textures/Shield.tga", tostring(reloaded[1]))
    test("the asset is updated in memory", colour(L:get("Textures/Shield.tga")) == "0,0,255")
    test("and in the engine's texture", R.calls.updated[1] and R.calls.updated[1].id == tid and R.calls.updated[1].w == 3)
    write(PACK .. "/Textures/Shield.tga", "half a save")
    test("a broken save: the error callback fires", settle() and #errored == 1 and errored[1].kept == true)
    test("the old asset still works", colour(L:get("Textures/Shield.tga")) == "0,0,255" and #R.calls.updated == 1)
    H:close()
    L:close()
end)
-- }}}

-- {{{ run
local clock0 = os.clock()
local wall0 = os.time()
for _, name in ipairs(order) do
    if not ONLY or ONLY == name then
        local sc = scenarios[name]
        current = name
        results[name] = { pass = 0, fail = 0 }
        print("\n=== " .. sc.title .. " (" .. name .. ") ===")
        local missing
        -- a need is a module, or a module's function ("assets.gpu.on_reload")
        for _, need in ipairs(sc.needs) do
            local ok = pcall(require, need)
            if not ok then
                local mod, field = need:match("^(.*)%.([%w_]+)$")
                local got, m = pcall(require, mod or "")
                ok = got and type(m) == "table" and m[field] ~= nil
            end
            if not ok then missing = need; break end
        end
        if missing then
            results[name].skipped = missing
            print("  (skipped: " .. missing .. " isn't here yet)")
        else
            local ok, err = xpcall(sc.fn, debug.traceback)
            if not ok then test("the scenario ran to the end", false, err) end
        end
    end
end
if ONLY and not scenarios[ONLY] then
    print("no scenario named " .. ONLY .. "; they are: " .. table.concat(order, ", "))
    os.exit(2)
end
os.execute("rm -rf " .. sh(SCRATCH))

local pass, fail, skipped = 0, 0, 0
for _, name in ipairs(order) do
    local r = results[name]
    if r then pass, fail = pass + r.pass, fail + r.fail; if r.skipped then skipped = skipped + 1 end end
end
if SUMMARY or not ONLY then
    print("\n=== Phase 6 summary ===")
    for _, name in ipairs(order) do
        local r = results[name]
        if r then
            print(string.format("  %-12s %s", name, r.skipped and ("skipped (" .. r.skipped .. " isn't here yet)")
                or (r.fail == 0 and ("passed, " .. r.pass .. " checks") or (r.fail .. " of " .. (r.pass + r.fail) .. " failed"))))
        end
    end
    print(string.format("  %.2fs of processor time; temporary files removed: %s", os.clock() - clock0,
        exists(SCRATCH) and "no" or "yes"))
end
print(string.format("\nTests: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
-- }}}
