#!/usr/bin/env luajit
-- test_stormlib.lua - StormLib reads every file every test map stores
--
-- Maps are read through StormLib (issue 114). This is the coverage check that
-- decided it: for every map in assets/, every stored file StormLib finds
-- (named by the map's listfile or the standard names, or by position when no
-- name is known) is read in full, and every name the map reader lists is
-- readable. It replaced a byte-for-byte comparison with the project's own
-- Lua reader, which agreed on all 369 files both could read, and which
-- couldn't read unnamed files at all.
--
-- Needs StormLib built (scripts/build-dependencies.sh); stops with a clear
-- message if it isn't.
--
-- Run: luajit src/tests/test_stormlib.lua [DIR]
-- Issue: issues/completed/114-read-maps-through-stormlib.md

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

local standard_names = require("mpq.standard_names")

-- {{{ Tests
test_section("StormLib loads")
local loaded, load_err = pcall(stormlib.open, DIR .. "/assets/DAoW-2.1.w3x")
test("opens a map archive", loaded, tostring(load_err))
if loaded then load_err:close() end

test_section("An empty extra listfile is an error")
-- It once made StormLib's search list nothing, silently.
do
    local a = stormlib.open(DIR .. "/assets/DAoW-2.1.w3x")
    local empty = os.tmpname()
    local ok, err = pcall(a.list, a, "*", empty)
    os.remove(empty)
    test("listing with an empty listfile raises", not ok and tostring(err):match("empty") ~= nil, tostring(err))
    a:close()
end

test_section("Every stored file of every map is read")
local maps = map_files()
test("found maps in assets/", #maps > 0, "no .w3x/.w3m files in " .. DIR .. "/assets")
local stored_total, unnamed_total = 0, 0
for _, path in ipairs(maps) do
    local name = path:match("[^/]+$")
    -- StormLib's own view: one entry per stored copy.
    local archive = stormlib.open(path)
    local listfile = standard_names.write_listfile()
    local entries = archive:list("*", listfile)
    os.remove(listfile)
    local copies = {}
    for _, e in ipairs(entries) do copies[e.name] = (copies[e.name] or 0) + 1 end
    local blocks, read_ok, problems = {}, 0, {}
    for _, e in ipairs(entries) do
        blocks[e.block_index] = true
        -- A known, unique name is read by name: some files can only be
        -- decrypted with it (Daow1.23.1B's (listfile) fails by position).
        -- A name stored twice is read by position, so each copy is read once.
        local extension = e.name:match("%.([^.\\]+)$") or "xxx"
        local position = string.format("File%08d.%s", e.block_index, extension)
        local how = copies[e.name] > 1 and position or e.name
        local ok, bytes = pcall(archive.read, archive, how)
        if ok and #bytes == e.size then
            read_ok = read_ok + 1
        else
            problems[#problems + 1] = e.name .. " (" .. position .. ")"
        end
        if e.name:match("^File%d+%.") then unnamed_total = unnamed_total + 1 end
    end
    archive:close()
    local stored = 0
    for _ in pairs(blocks) do stored = stored + 1 end
    stored_total = stored_total + stored

    -- The map reader's view: every name it lists is readable.
    local map = assert(mpq.open(path))
    local unreadable = {}
    for _, listed in ipairs(map:list()) do
        if not map:extract(listed) then unreadable[#unreadable + 1] = listed end
    end
    local counted = map:file_count()
    map:close()

    test(string.format("%s: %d stored files, all read", name, stored),
        read_ok == #entries and stored == #entries and #problems == 0, problems[1])
    test(string.format("%s: every listed name readable, file count %d", name, counted),
        #unreadable == 0 and counted == stored, unreadable[1])
end
print(string.format("\n  stored files across all maps: %d (%d with no known name)", stored_total, unnamed_total))
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
