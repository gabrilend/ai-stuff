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
    local patched = chain.open({ install = INSTALL, layers = LAYERS, w3i = w3i, editor_versions = {} })
    test("a Frozen Throne map uses the Custom_V1 data set", patched.data_set == "Custom_V1", patched.data_set)
    test("with no known editor version it falls back to the newest layer", patched.layer == "1.21b",
        tostring(patched.layer))
    test("and the fallback is reported as a warning", #patched.warnings == 1 and patched:report():match("WARNING") ~= nil)

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

    local roc = chain.open({ install = INSTALL, layers = LAYERS, w3i = { version = 18, editor_version = 0 },
        editor_versions = {} })
    local _, roc_from = roc:read("Units\\UnitWeapons.slk")
    test("a Reign of Chaos map (w3i version 18) uses Custom_V0", roc_from == "layer 1.21b: Custom_V0\\Units\\UnitWeapons.slk", roc_from)
    roc:close()

    local known = chain.open({ install = INSTALL, layers = LAYERS, w3i = w3i,
        editor_versions = { [w3i.editor_version] = { layer = "1.21b", evidence = "test" } } })
    test("a listed editor version picks its layer without a warning", known.layer == "1.21b" and #known.warnings == 0)
    known:close()
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
