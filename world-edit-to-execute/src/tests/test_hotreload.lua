#!/usr/bin/env luajit
-- test_hotreload.lua - change a pack's file, see it without a restart (issue 606)
--
-- In plain terms: the cache can show an entry without touching it; the
-- loader reads one asset again, keeping the old one when the new file is
-- broken; and the hot-reloader, with each watcher (looking every so often,
-- and inotify where Linux allows it), notices a saved texture, waits for
-- the file to settle, reads it once, hands the new picture to its caller,
-- keeps the old one when the save is broken, finds a file that was missing
-- and is now there, ignores files nothing uses and files a higher pack
-- hides, falls back when an override is removed, holds everything while
-- paused, and survives a caller's own mistakes.
--
-- Run: luajit src/tests/test_hotreload.lua [DIR]
-- Issue: issues/completed/606-hot-reload-system.md

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local cache = require("assets.cache")
local loader = require("assets.loader")
local hotreload = require("assets.hotreload")
local inotify = require("assets.watch.inotify")

local pass, fail = 0, 0
local function test(name, ok, msg)
    if ok then pass = pass + 1; print("  [PASS] " .. name)
    else fail = fail + 1; print("  [FAIL] " .. name .. (msg and (": " .. msg) or "")) end
end
local function sh(s) return "'" .. s:gsub("'", "'\\''") .. "'" end

-- {{{ helpers
-- An uncompressed TGA, N by N, every pixel one colour, top row first.
-- Each colour gets its own size, so two saves never look alike to a
-- watcher that compares sizes and times.
local function tga(n, r, g, b)
    local head = string.char(0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                             n % 256, math.floor(n / 256), n % 256, math.floor(n / 256), 32, 0x28)
    return head .. string.char(b, g, r, 255):rep(n * n)
end
local RED, BLUE, GREEN, GREY = tga(2, 255, 0, 0), tga(3, 0, 0, 255), tga(4, 0, 255, 0), tga(5, 90, 90, 90)
local function colour(img)
    if not img then return "none" end
    local r, g, b = img.rgba:byte(1, 3)
    return r .. "," .. g .. "," .. b
end

local function write(path, bytes)
    os.execute("mkdir -p " .. sh(path:match("^(.*)/[^/]*$")))
    local f = assert(io.open(path, "wb"))
    f:write(bytes)
    f:close()
end
-- }}}

-- {{{ The cache's peek
print("\n=== The cache shows an entry without touching it ===")
local c = cache.new(100)
c:put("a", "A", 30)
c:put("b", "B", 30)
local v, bytes = c:peek("a")
test("peek gives the value and its charge", v == "A" and bytes == 30)
test("peek counts no hit and no miss", c:stats().hits == 0 and c:stats().misses == 0 and c:peek("z") == nil)
test("peek doesn't mark it used (a is still the oldest)", c:keys()[2] == "a")
-- }}}

-- {{{ The loader's reload
print("\n=== The loader reads one asset again ===")
local SCRATCH = os.tmpname()
os.remove(SCRATCH)
local DATA = SCRATCH .. "/player-data"
local MINE, BASE = DATA .. "/asset-packs/mine", DATA .. "/asset-packs/base"
write(MINE .. "/Textures/Grass.tga", RED)
write(BASE .. "/textures/grass.tga", GREY)
write(BASE .. "/textures/dirt.tga", GREY)

local L = loader.new({ packs = { "mine", "base" }, data = DATA, root = DIR })
local img, from = L:get("Textures\\Grass.tga")
test("the starting texture is mine's, red", colour(img) == "255,0,0" and from == "pack:mine", colour(img) .. " " .. tostring(from))
write(MINE .. "/Textures/Grass.tga", BLUE)
test("get still gives the cached red", colour(L:get("textures/grass.tga")) == "255,0,0")
local nv, nfrom = L:reload("textures/grass.tga")
test("reload reads the new blue", colour(nv) == "0,0,255" and nfrom == "pack:mine" and colour(L:get("Textures/Grass.tga")) == "0,0,255")
write(MINE .. "/Textures/Grass.tga", "not a picture at all")
local bv, msg, kept = L:reload("textures/grass.tga")
test("a broken file: nil, a message, and the old value kept", bv == nil and kept == true and type(msg) == "string"
    and colour(L:get("textures/grass.tga")) == "0,0,255", tostring(msg))
local gone, gmsg, gkept = L:reload("textures/nothing-here.tga")
test("a path no source has: nil, kept false", gone == nil and gkept == false and gmsg:match("not found"))
local key, matters = L:file_changed(BASE, "textures/grass.tga")
test("a change under a pack the one above hides doesn't matter", key == "textures/grass.tga" and matters == false)
key, matters = L:file_changed(MINE, "Textures/Grass.tga")
test("a change to the file in use matters", matters == true)
key, matters = L:file_changed(BASE, "textures/dirt.tga")
test("a change to a file nothing loaded doesn't", matters == false)
write(MINE .. "/textures/new.tga", RED)
test("before file_changed the new file isn't in the list", not L:exists("textures/new.tga"))
L:file_changed(MINE, "textures/new.tga")
test("after it, it is", L:exists("textures/new.tga") and colour(L:get("textures/new.tga")) == "255,0,0")
os.remove(MINE .. "/textures/new.tga")
L:file_changed(MINE, "textures/new.tga")
test("a removed file leaves the list", not L.packs[1].index["textures/new.tga"])
L:close()
os.execute("rm -rf " .. sh(SCRATCH))
-- }}}

-- {{{ The hot-reloader, with each watcher
local function run(backend)
    print("\n=== Hot-reload with the " .. backend .. " watcher ===")
    local SCR = os.tmpname()
    os.remove(SCR)
    local D = SCR .. "/player-data"
    local mine, base = D .. "/asset-packs/mine", D .. "/asset-packs/base"
    write(mine .. "/Textures/Grass.tga", RED)
    write(mine .. "/textures/unused.tga", RED)
    write(base .. "/textures/grass.tga", GREY)
    write(base .. "/textures/water.tga", GREY)

    local LL = loader.new({ packs = { "mine", "base" }, data = D, root = DIR })
    local t = 0
    local reloaded, errored = {}, {}
    local H = hotreload.new(LL, {
        backend = backend, poll_interval = 0.5, quiet = 0.1,
        clock = function() return t end,
        on_reload = function(path, value, source) reloaded[#reloaded + 1] = { path = path, value = value, source = source } end,
        on_error = function(path, err, kept) errored[#errored + 1] = { path = path, err = err, kept = kept } end,
    })
    test("it says which watcher and how many packs", H:status().backend == backend and H:status().watching == 2)

    -- Steps the fake clock a tenth of a second at a time, polling, until
    -- something is read or reported (or two seconds pass); gives the time
    -- it took.
    local function settle()
        local start, r0, e0 = t, #reloaded, #errored
        for _ = 1, 20 do
            t = t + 0.1
            H:poll()
            if #reloaded > r0 or #errored > e0 then return t - start end
        end
        return nil
    end
    local function quiet_for(seconds)
        local r0, e0 = #reloaded, #errored
        for _ = 1, seconds * 10 do t = t + 0.1; H:poll() end
        return #reloaded == r0 and #errored == e0
    end

    test("starting value red", colour(LL:get("textures/grass.tga")) == "255,0,0")
    LL:get("textures/water.tga")
    test("nothing changed: nothing read", quiet_for(1))

    -- a save
    write(mine .. "/Textures/Grass.tga", BLUE)
    local took = settle()
    local last = reloaded[#reloaded]
    local limit = backend == "poll" and 0.75 or 0.25
    test("a save is read within the interval and the quiet time", took and took <= limit + 1e-9, tostring(took))
    test("on_reload gets the path, the new picture and its pack", last and last.path == "Textures/Grass.tga"
        and colour(last.value) == "0,0,255" and last.source == "pack:mine")
    test("get gives the new one now", colour(LL:get("textures/grass.tga")) == "0,0,255")
    test("read once, not again", quiet_for(1) and #reloaded == 1)

    -- a broken save, then a good one
    write(mine .. "/Textures/Grass.tga", "half a file")
    settle()
    local e = errored[#errored]
    test("a broken save calls on_error, old value kept", e and e.path == "Textures/Grass.tga" and e.kept == true
        and colour(LL:get("textures/grass.tga")) == "0,0,255")
    write(mine .. "/Textures/Grass.tga", GREEN)
    settle()
    test("the next good save is read", colour(LL:get("textures/grass.tga")) == "0,255,0" and #reloaded == 2)

    -- files nothing uses, and files a higher pack hides
    write(mine .. "/textures/unused.tga", BLUE)
    write(base .. "/textures/grass.tga", BLUE)
    local before = H:status().changes
    test("a file nothing loaded, or one a higher pack hides: not read", quiet_for(1) and H:status().changes >= before + 2)

    -- a lower pack's file in use, changed
    write(base .. "/textures/water.tga", GREEN)
    settle()
    test("a change to the base pack's file in use is read", colour(LL:get("textures/water.tga")) == "0,255,0"
        and reloaded[#reloaded].source == "pack:base")

    -- missing, then added (in a new folder)
    test("a missing texture is missing", LL:get("units/new/rock.tga") == nil)
    write(mine .. "/units/new/rock.tga", RED)
    settle()
    test("added in a new folder: found and read", colour(LL:get("Units\\New\\Rock.tga")) == "255,0,0"
        and reloaded[#reloaded].path:lower() == "units/new/rock.tga")

    -- an override removed: falls back; then nothing left: kept
    os.remove(mine .. "/Textures/Grass.tga")
    settle()
    test("the override removed: the base pack's file now", colour(LL:get("textures/grass.tga")) == "0,0,255"
        and reloaded[#reloaded].source == "pack:base")
    os.remove(base .. "/textures/grass.tga")
    settle()
    test("no source left: on_error, old value kept", errored[#errored].kept == true
        and colour(LL:get("textures/grass.tga")) == "0,0,255")

    -- saved twice in quick succession: read once
    local r0 = #reloaded
    write(mine .. "/units/new/rock.tga", BLUE)
    if backend ~= "poll" then t = t + 0.05; H:poll() end
    write(mine .. "/units/new/rock.tga", GREEN)
    settle()
    quiet_for(1)
    test("two quick saves: read once, the last one", #reloaded == r0 + 1
        and colour(LL:get("units/new/rock.tga")) == "0,255,0", tostring(#reloaded - r0))

    -- paused
    H:pause()
    r0 = #reloaded
    write(mine .. "/units/new/rock.tga", RED)
    test("paused: nothing read", quiet_for(1) and H:status().paused)
    test("paused: the change waits", backend == "poll" or H:status().pending == 1)
    H:resume()
    settle()
    test("resumed: read once", #reloaded == r0 + 1 and colour(LL:get("units/new/rock.tga")) == "255,0,0")

    -- by hand
    local hv = H:reload("textures/water.tga")
    test("reload by hand reads it and tells on_reload", colour(hv) == "0,255,0" and reloaded[#reloaded].path == "textures/water.tga")
    local loaded_n = #LL.cache:keys()
    local ok_n, bad_n = H:reload_all("textures")
    test("reload_all textures tries every texture loaded (grass has no source left: kept, counted bad)",
        ok_n + bad_n == loaded_n and bad_n == 1 and colour(LL:get("textures/grass.tga")) == "0,0,255", ok_n .. "/" .. bad_n)
    test("reload_all models: none loaded", H:reload_all("models") == 0)
    test("an unknown kind is an error", not pcall(H.reload_all, H, "smells"))

    -- the caller's mistakes
    H.on_reload = function() error("my renderer broke") end
    local errs = H:status().errors
    test("an error in on_reload doesn't escape", pcall(H.reload, H, "textures/water.tga") and H:status().errors == errs + 1)

    local st = H:status()
    test("status counts reloads and errors", st.reloads >= 8 and st.errors >= 3 and st.enabled == true, st.reloads .. "/" .. st.errors)
    H:close()
    test("closed: nothing more", H:status().enabled == false and H:poll() == 0)
    LL:close()
    os.execute("rm -rf " .. sh(SCR))
end

run("poll")
if inotify.available() then
    run("inotify")
else
    print("  [SKIP] inotify isn't available here")
end
-- }}}

-- {{{ Mistakes
print("\n=== Mistakes ===")
test("hotreload.new wants a loader", not pcall(hotreload.new, {}))
local SCR = os.tmpname()
os.remove(SCR)
os.execute("mkdir -p " .. sh(SCR .. "/asset-packs/a"))
local L2 = loader.new({ data = SCR, root = DIR })
test("an unknown watcher is an error", not pcall(hotreload.new, L2, { backend = "telepathy" }))
local H2 = hotreload.new(L2)
test("the default watcher is inotify where available, else poll",
    H2:status().backend == (inotify.available() and "inotify" or "poll"))
H2:close()
L2:close()
os.execute("rm -rf " .. sh(SCR))
-- }}}

print(string.format("\nTests: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
