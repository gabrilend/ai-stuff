#!/usr/bin/env luajit
-- test_share.lua - a shared map-and-model list, applied for one game (issue 609)
--
-- In plain terms: a sharer's pack becomes a list of its art and sound
-- files by hash (data files are left out, so gameplay can't differ); the
-- list is written and read back without ever running it, and anything
-- other than plain data, or a file that isn't art, is refused; the
-- receiver works out which files it lacks, the sharer copies only those;
-- every arriving file is checked against its hash and one bad file refuses
-- the whole list; an applied list comes before the player's own packs for
-- that game and is gone after it, or kept as a pack of their own; and
-- "always from this player" or "always for this map" turns the prompt off.
--
-- Run: luajit src/tests/test_share.lua [DIR]
-- Issue: issues/completed/609-shared-map-and-model-list.md

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local list = require("share.list")
local profile = require("share.profile")
local dedup = require("assets.dedup")
local loader = require("assets.loader")

local pass, fail = 0, 0
local function test(name, ok, msg)
    if ok then pass = pass + 1; print("  [PASS] " .. name)
    else fail = fail + 1; print("  [FAIL] " .. name .. (msg and (": " .. msg) or "")) end
end
local function sh(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function write(path, bytes)
    os.execute("mkdir -p " .. sh(path:match("^(.*)/[^/]*$")))
    local f = assert(io.open(path, "wb")); f:write(bytes); f:close()
end
local function exists(path) return os.rename(path, path) ~= nil end
local function tga(r, g, b)
    return string.char(0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 32, 0x28) .. string.char(b, g, r, 255)
end
local function colour(img) if not img then return "none" end local r, g, b = img.rgba:byte(1, 3); return r .. "," .. g .. "," .. b end
local function deep_equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not deep_equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local SCR = os.tmpname()
os.remove(SCR)
local A, B = SCR .. "/ana", SCR .. "/ben"     -- the sharer's and the receiver's player data
local MINE = A .. "/asset-packs/mine"
write(MINE .. "/Textures/Grass.tga", tga(200, 0, 0))
write(MINE .. "/units/knight/knight.mdx", "MDLX a knight, by Ana")
write(MINE .. "/sounds/horn.wav", "RIFF a horn")
write(MINE .. "/notes.txt", "not art")
write(MINE .. "/war3map.w3u", "unit data: would change the game")
write(SCR .. "/maps/castle.w3x", "a map's bytes")

-- {{{ Building and writing a list
print("\n=== A list from the sharer's pack ===")
local l, left = list.build({ map = SCR .. "/maps/castle.w3x", map_name = "Castle Fight", pack = MINE,
                             types = { hfoo = "units/knight/knight.mdx" }, author = "Ana", created = "2026-11-02" })
test("one entry for each art or sound file, and one for the unit type", #l.entries == 4, tostring(#l.entries))
test("data and other files are left out, and named", table.concat(left, ",") == "notes.txt,war3map.w3u", table.concat(left, ","))
test("keys are lower case with forward slashes", l.entries[1].key == "sounds/horn.wav" and l.entries[2].key == "textures/grass.tga")
local knight
for _, e in ipairs(l.entries) do if e.key == "hfoo" then knight = e end end
test("the unit type's entry names its model and shares its hash", knight and knight.path == "units/knight/knight.mdx"
    and knight.hash == l.entries[3].hash and knight.size == #"MDLX a knight, by Ana")
test("the map is named by its hash", l.map.hash == list.hash_file(SCR .. "/maps/castle.w3x") and l.map.name == "Castle Fight")
local text = list.encode(l)
local back, err = list.decode(text)
test("written and read back, the same list", back and deep_equal(back, l), err)
test("the same list writes the same text", list.encode(back) == text)
local odd = { author = "a \"quoted\"\nname\0with\\odd bytes\255", created = "x", map = l.map, entries = {} }
local odd_back = list.decode(list.encode(odd))
test("odd characters in text survive", odd_back and odd_back.author == odd.author)
test("a list that names a type with no model path is refused", not pcall(list.check,
    { map = l.map, entries = { { key = "hfoo", hash = knight.hash, size = 1 } } }))
-- }}}

-- {{{ Reading a list never runs it
print("\n=== A received list is read, never run ===")
local function refused(t, why)
    local v, e = list.decode(t)
    test(why, v == nil and type(e) == "string", e)
end
refused("return os.execute('touch " .. SCR .. "/ran')", "a function call is refused")
test("... and nothing ran", not exists(SCR .. "/ran"))
refused("while true do end", "a loop is refused (no return)")
refused("return { map = { hash = (function() return 'x' end)() }, entries = {} }", "an expression is refused")
refused("return { author = 'x' .. 'y', map = {}, entries = {} }", "concatenation is refused")
refused("return " .. string.rep("{", 40) .. string.rep("}", 40), "tables nested too deep are refused")
refused("return {} extra", "anything after the table is refused")
refused(string.rep(" ", list.MAX_BYTES + 1), "a list larger than the limit is refused")
local function with_entry(key, extra)
    local e = { key = key, hash = knight.hash, size = 1 }
    for k, v in pairs(extra or {}) do e[k] = v end
    return list.serialize({ map = l.map, entries = { e } })
end
refused(with_entry("units/unitdata.slk"), "a data file (unit table) is refused: gameplay can't differ")
refused(with_entry("war3map.j"), "a map script is refused")
refused(with_entry("../../.bashrc.blp"), "a path that climbs out is refused")
refused(with_entry("C:/windows/x.blp"), "an absolute path is refused")
refused(list.serialize({ map = l.map, entries = { { key = "a.blp", hash = "sha256:00", size = 1 } } }), "a short hash is refused")
refused(list.serialize({ map = l.map, entries = { { key = "a.blp", hash = knight.hash, size = -1 } } }), "a negative size is refused")
refused(list.serialize({ map = l.map, entries = { { key = "a.blp", hash = knight.hash, size = 1 },
                                                   { key = "a.blp", hash = knight.hash, size = 1 } } }), "a repeated key is refused")
test("comments are fine", list.decode("-- hello\n--[[ a\nblock ]]\n" .. list.serialize(l)) ~= nil)
-- }}}

-- {{{ Only what's missing is sent
print("\n=== Only what's missing is sent ===")
local bstore = dedup.open(B .. "/blobs")
bstore:store("RIFF a horn")       -- Ben has the horn already (from another pack)
local wanted = list.missing(l, bstore)
test("the receiver lacks two files (the horn is there; the knight counted once)", #wanted == 2, tostring(#wanted))
local BUNDLE = SCR .. "/arrived"
test("the sharer copies just those, named by hash", list.bundle(l, MINE, wanted, BUNDLE) == 2
    and exists(BUNDLE .. "/" .. wanted[1]:sub(8)) and exists(BUNDLE .. "/" .. wanted[2]:sub(8)))
test("asking for a hash the list doesn't hold is an error", not pcall(list.bundle, l, MINE, { "sha256:" .. string.rep("0", 64) }, BUNDLE))
-- }}}

-- {{{ Checked, refused whole when anything is wrong
print("\n=== Every file checked; one bad file refuses the list ===")
local TAMPER = SCR .. "/tampered"
os.execute("cp -r " .. sh(BUNDLE) .. " " .. sh(TAMPER))
write(TAMPER .. "/" .. wanted[1]:sub(8), "something else entirely")
local none, problems = profile.apply(l, { data = B, store = bstore, bundle = TAMPER, name = "game-1" })
test("a file that doesn't match its hash: refused and named", none == nil and #problems == 1
    and problems[1].problem == "doesn't match its hash")
test("... and nothing was applied", not exists(B .. "/profiles/game-1"))
os.remove(TAMPER .. "/" .. wanted[1]:sub(8))
none, problems = profile.apply(l, { data = B, store = bstore, bundle = TAMPER, name = "game-1" })
test("a file that wasn't sent: refused and named", none == nil and problems[1].problem == "not sent")
-- }}}

-- {{{ Applied for one game, then reverted
print("\n=== Applied for one game, then reverted ===")
write(B .. "/asset-packs/own/textures/grass.tga", tga(0, 0, 200))
write(B .. "/asset-packs/own/units/unitdata.slk", "Ben's unit table")
write(MINE .. "/units/unitdata.slk", "Ana's unit table")     -- in Ana's pack, but never in her list
local L = loader.new({ packs = { "own" }, data = B, root = DIR })
test("before: Ben sees his own grass", colour(L:get("Textures\\Grass.tga")) == "0,0,200")
local slk_before = { L:read("Units\\UnitData.slk") }
local P, perr = profile.apply(l, { data = B, store = bstore, bundle = BUNDLE, name = "game-1" })
test("the list applies", P ~= nil, perr and perr[1] and perr[1].problem)
P:attach(L)
local img, from = L:get("Textures\\Grass.tga")
test("during the game: Ana's grass, from the list's layer", colour(img) == "200,0,0" and from == "layer:share:game-1",
    tostring(from))
test("the unit type's model is named", P.types.hfoo == "units/knight/knight.mdx"
    and L:read("units/knight/knight.mdx") == "MDLX a knight, by Ana")
test("the horn Ben already had is used, not sent again", L:read("sounds/horn.wav") == "RIFF a horn")
test("gameplay data reads the same with the list on (Ben's unit table, not Ana's)",
    slk_before[1] == "Ben's unit table" and L:read("Units\\UnitData.slk") == slk_before[1])
P:revert(L)
test("after the game: Ben's own grass again", colour(L:get("textures/grass.tga")) == "0,0,200")
test("the profile is gone", not exists(B .. "/profiles/game-1") and not exists(B .. "/profiles/game-1.list.lua"))
local removed = bstore:gc()
test("its stored files are collected (the horn was never linked by Ben: it goes too)", removed == 3, tostring(removed))
-- }}}

-- {{{ Kept as a pack
print("\n=== Kept as a pack of the player's own ===")
local P2 = profile.apply(l, { data = B, store = bstore, bundle = BUNDLE, name = "game-2" })
test("missing again after gc, so the bundle is needed again", P2 == nil)
bstore:store("RIFF a horn")
P2 = profile.apply(l, { data = B, store = bstore, bundle = BUNDLE, name = "game-2" })
P2:attach(L)
local dir = P2:keep("ana", L)
test("kept: a pack of Ben's own, the profile gone", dir == B .. "/asset-packs/ana" and not exists(B .. "/profiles/game-2"))
local L2 = loader.new({ packs = { "ana", "own" }, data = B, root = DIR })
test("the kept pack serves Ana's grass", colour(L2:get("textures/grass.tga")) == "200,0,0" and select(2, L2:get("textures/grass.tga")) == "pack:ana")
test("and gc keeps its files", bstore:gc() == 0)
test("a second list can't take an applied name", (function()
    local P3 = profile.apply(l, { data = B, store = bstore, bundle = BUNDLE, name = "game-3" })
    local ok = not pcall(profile.apply, l, { data = B, store = bstore, bundle = BUNDLE, name = "game-3" })
    P3:revert()
    return ok
end)())
test("a profile name can't climb out", not pcall(profile.apply, l, { data = B, store = bstore, bundle = BUNDLE, name = "../x" }))
-- }}}

-- {{{ Trust
print("\n=== Always from this player, always for this map ===")
local T = profile.trust(B)
test("by default: ask", T:decide("Ana", l) == "ask")
T:always_from("Ana", true)
test("always from Ana: applied without asking", T:decide("Ana", l) == "apply" and T:decide("Cy", l) == "ask")
test("remembered", profile.trust(B):decide("Ana", l) == "apply")
T:always_from("Ana", false)
T:always_for_map(l.map.hash, true)
test("always for this map: from anyone", profile.trust(B):decide("Cy", l) == "apply")
T:always_for_map(l.map.hash, false)
test("turned off again", profile.trust(B):decide("Ana", l) == "ask")
write(B .. "/share-trust.lua", "return os.exit(3)")
test("a damaged trust file is ignored, not run", profile.trust(B):decide("Ana", l) == "ask")
-- }}}

-- {{{ The tool
print("\n=== The tool ===")
local function run(cmd)
    local p = io.popen("( " .. cmd .. " ) 2>&1; echo \"exit $?\"")
    local out = p:read("*a")
    p:close()
    local body, code = out:match("^(.-)exit (%d+)\n$")
    return body, tonumber(code)
end
local TOOL = "luajit " .. sh(DIR .. "/src/cli/share.lua") .. " --dir " .. sh(DIR)
local LISTF = SCR .. "/castle.list.lua"
local out, code = run(TOOL .. " --data " .. sh(A) .. " make " .. sh(SCR .. "/maps/castle.w3x") .. " mine --author Ana --type hfoo=units/knight/knight.mdx -o " .. sh(LISTF))
test("make writes the list and names what it left out", code == 0 and out:find("entries", 1, true)
    and out:find("left out (not art or sound): notes.txt", 1, true) and list.decode(io.open(LISTF):read("*a")) ~= nil, out)
local C = SCR .. "/cy"
out, code = run(TOOL .. " --data " .. sh(C) .. " missing " .. sh(LISTF) .. " > " .. sh(SCR .. "/wanted"))
local wl = io.open(SCR .. "/wanted"):read("*a")
test("missing lists every hash a new player lacks", code == 0 and select(2, wl:gsub("\n", "")) == 3, wl)
out, code = run(TOOL .. " --data " .. sh(A) .. " bundle " .. sh(LISTF) .. " mine " .. sh(SCR .. "/wanted") .. " " .. sh(SCR .. "/to-cy"))
test("bundle copies them", code == 0 and out:find("Copied 3 files", 1, true), out)
out, code = run(TOOL .. " --data " .. sh(C) .. " check " .. sh(LISTF) .. " " .. sh(SCR .. "/to-cy"))
test("check: all there", code == 0 and out:find("All 4 entries", 1, true), out)
local first = wl:match("sha256:(%x+)")
write(SCR .. "/to-cy/" .. first, "tampered")
out, code = run(TOOL .. " --data " .. sh(C) .. " check " .. sh(LISTF) .. " " .. sh(SCR .. "/to-cy"))
test("check: a tampered file is named and the list refused", code == 1 and out:find("doesn't match its hash", 1, true)
    and out:find("Refused", 1, true), out)
out, code = run(TOOL .. " frobnicate")
test("an unknown command is refused", code == 2, out)
-- }}}

os.execute("rm -rf " .. sh(SCR))
print(string.format("\nTests: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
