#!/usr/bin/env luajit
-- test_patch_layers.lua - patch diffs, the 1.21b layer, and per-map game data chains
--
-- Needs the owner's Frozen Throne install (wc3-installs/frozen-throne) and
-- the 1.21b layer built by src/cli/build-patch-layer.lua
-- (wc3-installs/patch-layers/1.21b). Without them the dependent parts are
-- skipped with a loud notice: counted as neither pass nor fail.
--
-- Run: luajit src/tests/test_patch_layers.lua [DIR]
-- Issue: issues/112b-game-version-layers-per-map.md

-- {{{ Setup
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local bsd0 = require("gamedata.bsd0")
local chain = require("gamedata.chain")
local mpq = require("mpq")
local w3i_parser = require("parsers.w3i")

local INSTALL = DIR .. "/wc3-installs/frozen-throne"
local LAYERS = DIR .. "/wc3-installs/patch-layers"
-- }}}

-- {{{ Test utilities
local test_count, pass_count, fail_count, skip_count = 0, 0, 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        fail_count = fail_count + 1
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

local function skip(name, reason)
    skip_count = skip_count + 1
    print("  [SKIP] " .. name .. " -- " .. reason .. " --")
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end

local function exists(path)
    local f = io.open(path, "rb")
    if f then f:close() return true end
    return false
end
-- }}}

-- {{{ Tests: diff entries built by hand
test_section("BSD0 entries (hand-built)")
-- {{{ local function header
local function header(kind, old_crc, old_size, new_size)
    local function u32(n)
        return string.char(n % 256, math.floor(n / 256) % 256,
            math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
    end
    return string.char(0x18, 0x00, 0x04, kind) .. u32(old_crc) .. u32(old_size) .. u32(new_size)
        .. string.rep("\0", 8)
end
-- }}}
local whole = header(0x01, 0, 0, 5) .. "hello"
test("a whole-file entry returns its body", bsd0.apply(whole) == "hello")
local short = header(0x01, 0, 0, 9) .. "hello"
test("a whole file of the wrong size is refused", bsd0.apply(short) == nil)
local diff_for_wrong_base = header(0x04, 0x12345678, 3, 3) .. "\4\0\0\0\131abc"
local _, crc_err = bsd0.apply(diff_for_wrong_base, "xyz")
test("a diff against a file with the wrong CRC32 is refused", crc_err and crc_err:match("CRC32") ~= nil, tostring(crc_err))
test("an unknown entry kind is refused", bsd0.apply(header(0x07, 0, 0, 1) .. "x") == nil)
-- }}}

-- {{{ Tests: the 1.21b layer and per-map chains
test_section("The 1.21b layer and per-map chains")
if not exists(INSTALL .. "/War3x.mpq") then
    skip("layer and chain tests", "no Frozen Throne install at " .. INSTALL)
elseif not exists(LAYERS .. "/1.21b/manifest.lua") then
    skip("layer and chain tests", "1.21b layer not built (src/cli/build-patch-layer.lua)")
else
    local manifest = dofile(LAYERS .. "/1.21b/manifest.lua")
    test("manifest records 714 entries", #manifest.entries == 714, tostring(#manifest.entries))
    test("manifest records the patch's version limit 1.21.1.6300",
        manifest.requires_older_than == "1.21.1.6300", tostring(manifest.requires_older_than))

    -- The layer keeps patch.lst's spelling ("game.dll"); find it through the manifest.
    local game_dll
    for _, e in ipairs(manifest.entries) do
        if e.place == "install" and e.target:lower() == "game.dll" then
            game_dll = LAYERS .. "/1.21b/install/" .. e.target
        end
    end
    game_dll = game_dll or (LAYERS .. "/1.21b/install/game.dll")
    local f = io.open(game_dll, "rb")
    local dll = f and f:read("*a") or ""
    if f then f:close() end
    local wide = ("FileVersion"):gsub(".", "%0\0")
    local at = dll:find(wide, 1, true)
    local version = at and dll:sub(at + 24, at + 70):gsub("%z", ""):match("[%d, ]+") or "?"
    test("the patched Game.dll reports 1.21.1.6300", version:match("^1, 21, 1, 6300") ~= nil, version)

    -- {{{ local function map_w3i
    local function map_w3i(name)
        local a = assert(mpq.open(DIR .. "/assets/" .. name))
        local parsed = w3i_parser.parse(a:extract("war3map.w3i"))
        a:close()
        return parsed
    end
    -- }}}
    local w3i = map_w3i("DAoW-2.1.w3x")
    -- With no known editor version the newest built layer is used; which one
    -- that is depends on how many layers are built, so it is read from the
    -- layers folder (the one whose manifest names the highest version).
    local fallback = chain.open({ install = INSTALL, layers = LAYERS, w3i = w3i, editor_versions = {} })
    local newest, newest_order = nil, nil
    local listing = io.popen("ls '" .. LAYERS .. "'")
    for name in listing:lines() do
        local chunk = loadfile(LAYERS .. "/" .. name .. "/manifest.lua")
        local m = chunk and chunk()
        if m then
            local a, b, c = name:match("^(%d+)%.(%d+)(%a?)$")
            local order = tonumber(a) * 10000 + tonumber(b) * 100 + (c ~= "" and c:byte() - 96 or 0)
            if not newest_order or order > newest_order then newest, newest_order = name, order end
        end
    end
    listing:close()
    test("with no known editor version it falls back to the newest layer", fallback.layer == newest,
        tostring(fallback.layer) .. " vs " .. tostring(newest))
    test("and the fallback is reported as a warning", #fallback.warnings == 1 and fallback:report():match("WARNING") ~= nil)
    fallback:close()

    local patched = chain.open({ install = INSTALL, layers = LAYERS, w3i = w3i, layer = "1.21b" })
    test("a Frozen Throne map uses the Custom_V1 data set", patched.data_set == "Custom_V1", patched.data_set)

    local weapons_patched, from = patched:read("Units\\UnitWeapons.slk")
    test("unit weapons come from the layer's Custom_V1 copy", from == "layer 1.21b: Custom_V1\\Units\\UnitWeapons.slk", from)
    local _, data_from = patched:read("Units\\UnitData.slk")
    test("a table the data set doesn't override comes from the plain path", data_from:match(": Units\\UnitData%.slk$") ~= nil, data_from)

    local unpatched = chain.open({ install = INSTALL, layers = LAYERS, w3i = w3i, layer = false })
    local weapons_unpatched, from_unpatched = unpatched:read("Units\\UnitWeapons.slk")
    test("unpatched, unit weapons come from War3x.mpq", from_unpatched == "War3x.mpq: Custom_V1\\Units\\UnitWeapons.slk", from_unpatched)
    test("the patch changes the stock values", weapons_patched ~= weapons_unpatched)
    test("the layer's copy matches its manifest CRC32", (function()
        for _, e in ipairs(manifest.entries) do
            if e.target == "Custom_V1\\Units\\UnitWeapons.slk" then
                return e.crc32 == bsd0.crc32(weapons_patched)
            end
        end
        return false
    end)())
    patched:close()
    unpatched:close()

    local roc = chain.open({ install = INSTALL, layers = LAYERS, w3i = { version = 18, editor_version = 0, game_data_set = 1, flags = { melee_map = false } },
        layer = "1.21b" })
    local _, roc_from = roc:read("Units\\UnitWeapons.slk")
    test("a Reign of Chaos map (w3i version 18) uses Custom_V0", roc_from == "layer 1.21b: Custom_V0\\Units\\UnitWeapons.slk", roc_from)
    roc:close()

    -- The data set is the map's own choice (w3i "game data set": 0 Default by
    -- melee flag, 1 Custom, 2 Melee latest patch). Patches rebalance only the
    -- melee tables: 1.22a's Knight is 28 damage / 1.40 cooldown there, and
    -- still 25 / 1.50 in the custom copy. The chain once gave every Frozen
    -- Throne map the custom copy, whatever it chose.
    if exists(LAYERS .. "/1.22a/manifest.lua") then
        local slk = require("parsers.slk")
        local function knight(choice, melee_flag)
            local c = chain.open({ install = INSTALL, layers = LAYERS, layer = "1.22a",
                w3i = { version = 25, editor_version = 0, game_data_set = choice, flags = { melee_map = melee_flag } } })
            local bytes, from = c:read("Units\\UnitWeapons.slk")
            c:close()
            return slk.parse(bytes).rows.hkni, from
        end
        local melee, melee_from = knight(2, false)
        test("Melee (2) reads the patched melee table", melee.dmgplus1 == 28 and melee.cool1 == 1.4
            and melee_from == "layer 1.22a: Units\\UnitWeapons.slk", melee_from)
        local custom, custom_from = knight(1, true)
        test("Custom (1) reads the 1.07 custom copy, even on a melee map", custom.dmgplus1 == 25
            and custom_from == "layer 1.22a: Custom_V1\\Units\\UnitWeapons.slk", custom_from)
        local default_melee = knight(0, true)
        local default_custom = knight(0, false)
        test("Default (0) follows the map's melee flag", default_melee.dmgplus1 == 28 and default_custom.dmgplus1 == 25)
        local ok, err = pcall(knight, 3, false)
        test("a data set the editor doesn't offer is an error", not ok and tostring(err):match("game data set 3") ~= nil,
            tostring(err))
    else
        skip("data set choice", "needs the 1.22a layer (build-patch-layer.lua --stack)")
    end

    local known = chain.open({ install = INSTALL, layers = LAYERS, w3i = w3i,
        editor_versions = { [w3i.editor_version] = { layer = "1.21b", evidence = "test" } } })
    test("a listed editor version picks its layer without a warning", known.layer == "1.21b" and #known.warnings == 0)
    known:close()
end
-- }}}

-- {{{ The stack of layers
test_section("The stack: every patch program, in the order of the versions it produces")
local PROGRAMS = DIR .. "/wc3-installs/patch-programs"
if not exists(PROGRAMS .. "/sources.tsv") or not exists(INSTALL .. "/War3x.mpq") then
    skip("stack", "needs the Frozen Throne install and the programs from scripts/fetch-patch-programs.sh")
else
    local patch_layer = require("gamedata.patch_layer")
    local scratch = os.tmpname()
    os.remove(scratch)
    -- 1.25b's own script says "older than 1.99.99.9999", a placeholder; the
    -- order once put 1.27b before it. The version comes from the War3.exe
    -- each program writes.
    local v125 = patch_layer.target_version(PROGRAMS .. "/War3TFT_125b_English.exe", scratch, INSTALL)
    local v127 = patch_layer.target_version(PROGRAMS .. "/War3TFT_127b_English.exe", scratch, INSTALL)
    local v121 = patch_layer.target_version(PROGRAMS .. "/War3TFT_121b_English.exe", scratch, INSTALL)
    os.execute("rm -rf '" .. scratch .. "'")
    test("1.21b's program produces 1.21.1.6300", v121 == "1.21.1.6300", v121)
    test("1.25b's program produces 1.25.1.6397, despite its placeholder check", v125 == "1.25.1.6397", v125)
    test("1.27b's program produces 1.27.1.7085", v127 == "1.27.1.7085", v127)

    -- Each built layer's Game.dll carries the version its program produces.
    local expected = { ["1.21b"] = "1, 21, 1, 6300", ["1.23a"] = "1, 23, 0, 6352", ["1.24e"] = "1, 24, 4, 6387",
        ["1.25b"] = "1, 25, 1, 6397", ["1.26a"] = "1, 26, 0, 6401", ["1.27b"] = "1, 27, 1, 7085" }
    for layer, want in pairs(expected) do
        local finder = io.popen("find '" .. LAYERS .. "/" .. layer .. "/install' -iname game.dll")
        local path = finder:read("*l")
        finder:close()
        if not path then
            skip("layer " .. layer, "not built; run build-patch-layer.lua --stack")
        else
            local f = assert(io.open(path, "rb"))
            local dll = f:read("*a")
            f:close()
            -- The numeric version block (signature 0xFEEF04BD), not the
            -- version text: 1.27b writes its text as "1.27.1.7085", the
            -- others as "1, 21, 1, 6300".
            local at = dll:find("\189\4\239\254", 1, true)
            local function u16(o) return dll:byte(o) + dll:byte(o + 1) * 256 end
            local got = at and string.format("%d, %d, %d, %d", u16(at + 10), u16(at + 8), u16(at + 14), u16(at + 12)) or "?"
            test("layer " .. layer .. "'s Game.dll reports " .. want, got == want, got)
        end
    end

    -- Building the stack again changes nothing: every layer is reported present.
    local out = io.popen("luajit '" .. DIR .. "/src/cli/build-patch-layer.lua' --dir '" .. DIR .. "' --stack 2>&1")
    local text = out:read("*a")
    out:close()
    local built = select(2, text:gsub("\nlayer ", ""))
    local present = select(2, text:gsub("present;", ""))
    test("a second stack build rebuilds nothing", built == 0 and present >= 10,
        built .. " built, " .. present .. " present")

    -- Every editor build in the evidence table names a built layer.
    local table_ = dofile(DIR .. "/src/gamedata/editor_versions.lua")
    for build, row in pairs(table_) do
        test("editor " .. build .. " names a built layer (" .. row.layer .. ")",
            exists(LAYERS .. "/" .. row.layer .. "/manifest.lua"))
    end
end
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed, %d total (%d skipped)",
    pass_count, fail_count, test_count, skip_count))
if fail_count > 0 then
    print("SOME TESTS FAILED")
    os.exit(1)
else
    print("ALL TESTS PASSED")
    os.exit(0)
end
-- }}}
