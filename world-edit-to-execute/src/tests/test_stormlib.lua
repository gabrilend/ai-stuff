#!/usr/bin/env luajit
-- test_stormlib.lua - StormLib binding checked against the project's own MPQ reader
--
-- Two independent readers of the same archive must agree byte for byte. For
-- every map in assets/, every file named in the map's (listfile) is read by
-- our reader (src/mpq/) and by StormLib (src/mpq/stormlib.lua) and compared.
-- A file only one reader can open is a failure, not a skip: it means one of
-- them is wrong.
--
-- Needs StormLib built (scripts/build-dependencies.sh); stops with a clear
-- message if it isn't.
--
-- Run: luajit src/tests/test_stormlib.lua [DIR]
-- Issue: issues/112a-stormlib-build-and-update-script.md

-- {{{ Setup
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local mpq = require("mpq")
local stormlib = require("mpq.stormlib")
-- }}}

-- {{{ Test utilities
local test_count, pass_count, fail_count = 0, 0, 0

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

local function test_section(name)
    print("\n=== " .. name .. " ===")
end
-- }}}

-- {{{ local function map_files
-- The .w3x/.w3m files in assets/, sorted so runs are repeatable.
local function map_files()
    local found = {}
    local listing = io.popen('ls "' .. DIR .. '/assets"')
    for name in listing:lines() do
        if name:match("%.w3[xm]$") then
            found[#found + 1] = DIR .. "/assets/" .. name
        end
    end
    listing:close()
    table.sort(found)
    return found
end
-- }}}

-- Protected maps often strip or falsify their (listfile), so the comparison
-- also tries the names a map normally holds.
local STANDARD_NAMES = require("mpq.standard_names").MAP_FILES

-- {{{ local function candidate_names
-- Standard names plus whatever the (listfile) names, without duplicates.
local function candidate_names(ours)
    local seen, names = {}, {}
    local function add(name)
        if name ~= "" and not name:match("\\$") and not seen[name:lower()] then
            seen[name:lower()] = true
            names[#names + 1] = name
        end
    end
    for _, name in ipairs(STANDARD_NAMES) do add(name) end
    local listed = ours:list()
    if listed then
        for _, name in ipairs(listed) do add(name) end
    end
    return names
end
-- }}}

-- {{{ local function compare_archive
-- Returns files compared, files matching, and a list of mismatch descriptions.
-- A name counts when at least one reader can read it; both must agree.
local function compare_archive(path)
    local ours = assert(mpq.open(path))
    local names = candidate_names(ours)
    local theirs = stormlib.open(path)
    local compared, matched, problems = 0, 0, {}
    for _, name in ipairs(names) do
        local our_bytes = ours:extract(name)
        local ok, storm_bytes = pcall(theirs.read, theirs, name)
        if our_bytes == nil and not ok then
            -- Listed but absent from both (listfiles can name deleted files): not a disagreement.
        else
            compared = compared + 1
            if our_bytes ~= nil and ok and our_bytes == storm_bytes then
                matched = matched + 1
            else
                problems[#problems + 1] = string.format("%s: ours=%s stormlib=%s", name,
                    our_bytes and (#our_bytes .. " bytes") or "unreadable",
                    ok and (#storm_bytes .. " bytes") or "unreadable")
            end
        end
    end
    theirs:close()
    ours:close()
    return compared, matched, problems
end
-- }}}

-- {{{ Tests
test_section("StormLib loads")
local loaded, load_err = pcall(stormlib.open, DIR .. "/assets/DAoW-2.1.w3x")
test("opens a map archive", loaded, tostring(load_err))
if loaded then load_err:close() end

test_section("Both readers agree on every file of every map")
local maps = map_files()
test("found maps in assets/", #maps > 0, "no .w3x/.w3m files in " .. DIR .. "/assets")
local total = 0
for _, path in ipairs(maps) do
    local compared, matched, problems = compare_archive(path)
    total = total + compared
    local name = path:match("[^/]+$")
    test(string.format("%s: %d of %d files identical", name, matched, compared),
        compared > 0 and matched == compared, problems[1])
end
print(string.format("\n  files compared across all maps: %d", total))
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed, %d total", pass_count, fail_count, test_count))
if fail_count > 0 then
    print("SOME TESTS FAILED")
    os.exit(1)
else
    print("ALL TESTS PASSED")
    os.exit(0)
end
-- }}}
