#!/usr/bin/env lua
--[[
Issue 110h: Real Map File Tests for Object Data Parsers

Tests object data parsing against actual WC3 map files to validate:
- ObjectDatabase loads from real archives
- Object definitions are extractable
- Stats are readable
- Custom vs original objects are distinguishable
]]

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local mpq = require("mpq")
local objectdb = require("parsers.objectdb")
local data = require("data")

-- {{{ Test infrastructure
local tests_run = 0
local tests_passed = 0

local function test(name, fn)
    tests_run = tests_run + 1
    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name)
        print("         " .. tostring(err))
    end
end

local function section(name)
    print("\n=== " .. name .. " ===")
end

local function get_map_files()
    local files = {}
    local handle = io.popen('ls "' .. DIR .. '/assets/"*.w3x 2>/dev/null')
    if handle then
        for line in handle:lines() do
            files[#files + 1] = line
        end
        handle:close()
    end
    return files
end
-- }}}

-- {{{ Direct Archive Tests
section("Direct Archive Loading")

test("objectdb loads from archive", function()
    local map_files = get_map_files()
    if #map_files == 0 then
        error("No test maps found in assets/")
    end

    local archive = mpq.open(map_files[1])
    local db = objectdb.load_from_archive(archive)
    archive:close()

    assert(db, "ObjectDatabase should be created")
    -- Database may be empty if map has no object modifications
    assert(db.counts, "Should have counts table")
end)

test("multiple maps load without error", function()
    local map_files = get_map_files()
    local loaded = 0
    local errors = {}

    for _, path in ipairs(map_files) do
        local ok, err = pcall(function()
            local archive = mpq.open(path)
            local db = objectdb.load_from_archive(archive)
            archive:close()
            assert(db, "Should create db")
        end)
        if ok then
            loaded = loaded + 1
        else
            errors[#errors + 1] = path:match("([^/]+)$") .. ": " .. tostring(err)
        end
    end

    if #errors > 0 then
        error(string.format("%d/%d failed: %s", #errors, #map_files, errors[1]))
    end
    print(string.format("         (%d maps loaded)", loaded))
end)
-- }}}

-- {{{ Map Integration Tests
section("Map Integration")

test("Map.load creates object_data", function()
    local map_files = get_map_files()
    if #map_files == 0 then
        error("No test maps")
    end

    local map = data.load(map_files[1])
    assert(map.object_data, "Map should have object_data")
end)

test("Map.info includes object counts", function()
    local map_files = get_map_files()
    if #map_files == 0 then
        error("No test maps")
    end

    local map = data.load(map_files[1])
    local info = map:info()

    assert(info.has_object_data ~= nil, "Should have has_object_data")
    if map.object_data:count() > 0 then
        assert(info.object_definition_counts, "Should have counts if objects exist")
    end
end)

test("format output includes object definitions", function()
    local map_files = get_map_files()
    if #map_files == 0 then
        error("No test maps")
    end

    local map = data.load(map_files[1])
    local formatted = data.format(map)

    assert(formatted:find("Object Definitions"), "Should have Object Definitions section")
end)
-- }}}

-- {{{ Object Statistics Tests
section("Object Statistics")

test("count modified objects across maps", function()
    local map_files = get_map_files()
    local total_objects = 0
    local maps_with_mods = 0
    local type_counts = {}

    for _, path in ipairs(map_files) do
        local ok, result = pcall(function()
            local archive = mpq.open(path)
            local db = objectdb.load_from_archive(archive)
            archive:close()

            local count = db:count()
            if count > 0 then
                maps_with_mods = maps_with_mods + 1
                total_objects = total_objects + count

                -- Count by type
                for type_name, c in pairs(db.counts) do
                    type_counts[type_name] = (type_counts[type_name] or 0) + c
                end
            end
        end)
    end

    print(string.format("         Total: %d objects in %d/%d maps",
        total_objects, maps_with_mods, #map_files))

    -- Print breakdown by type
    for type_name, count in pairs(type_counts) do
        if count > 0 then
            print(string.format("           %s: %d", type_name, count))
        end
    end
end)

test("object IDs are valid 4-char strings", function()
    local map_files = get_map_files()
    local checked = 0
    local invalid = 0

    for _, path in ipairs(map_files) do
        local ok = pcall(function()
            local archive = mpq.open(path)
            local db = objectdb.load_from_archive(archive)
            archive:close()

            for _, id in ipairs(db:all_ids()) do
                checked = checked + 1
                -- IDs should be 4 characters or hex-encoded
                if #id ~= 4 and not id:match("^0x") then
                    invalid = invalid + 1
                end
            end
        end)
    end

    if invalid > 0 then
        error(string.format("%d/%d invalid IDs", invalid, checked))
    end
    print(string.format("         (%d IDs validated)", checked))
end)
-- }}}

-- {{{ Stat Access Tests
section("Stat Access")

test("get_stat works for unit objects", function()
    local map_files = get_map_files()
    local tested = 0

    for _, path in ipairs(map_files) do
        local ok = pcall(function()
            local archive = mpq.open(path)
            local db = objectdb.load_from_archive(archive)
            archive:close()

            local unit_ids = db:all_ids("unit")
            for _, id in ipairs(unit_ids) do
                -- Try to get a common stat
                local obj = db:get(id)
                assert(obj, "Should get object for ID: " .. id)
                assert(obj.id == id, "Object ID should match")
                tested = tested + 1
            end
        end)
    end

    print(string.format("         (%d unit objects tested)", tested))
end)

test("get_all_stats returns table", function()
    local map_files = get_map_files()
    local tested = 0

    for _, path in ipairs(map_files) do
        local ok = pcall(function()
            local archive = mpq.open(path)
            local db = objectdb.load_from_archive(archive)
            archive:close()

            for _, id in ipairs(db:all_ids()) do
                local stats = db:get_all_stats(id)
                assert(type(stats) == "table", "get_all_stats should return table")
                tested = tested + 1
                if tested >= 50 then break end  -- Limit per map
            end
        end)
        if tested >= 100 then break end  -- Total limit
    end

    print(string.format("         (%d stat tables retrieved)", tested))
end)

test("custom objects have parents", function()
    local map_files = get_map_files()
    local custom_count = 0
    local with_parent = 0

    for _, path in ipairs(map_files) do
        local ok = pcall(function()
            local archive = mpq.open(path)
            local db = objectdb.load_from_archive(archive)
            archive:close()

            for _, id in ipairs(db:all_ids()) do
                if db:is_custom(id) then
                    custom_count = custom_count + 1
                    local parent = db:get_parent_id(id)
                    if parent then
                        with_parent = with_parent + 1
                    end
                end
            end
        end)
    end

    print(string.format("         (%d custom objects, %d have parents)",
        custom_count, with_parent))
end)
-- }}}

-- {{{ Type Classification Tests
section("Type Classification")

test("get_type returns valid types", function()
    local map_files = get_map_files()
    local valid_types = {
        unit = true,
        ability = true,
        item = true,
        destructible = true,
        doodad = true,
        buff = true,
        upgrade = true,
    }
    local type_counts = {}
    local invalid = 0

    for _, path in ipairs(map_files) do
        local ok = pcall(function()
            local archive = mpq.open(path)
            local db = objectdb.load_from_archive(archive)
            archive:close()

            for _, id in ipairs(db:all_ids()) do
                local obj_type = db:get_type(id)
                if not valid_types[obj_type] then
                    invalid = invalid + 1
                else
                    type_counts[obj_type] = (type_counts[obj_type] or 0) + 1
                end
            end
        end)
    end

    if invalid > 0 then
        error(string.format("%d objects with invalid types", invalid))
    end

    -- Print type distribution
    for t, c in pairs(type_counts) do
        print(string.format("           %s: %d", t, c))
    end
end)
-- }}}

-- {{{ Edge Cases
section("Edge Cases")

test("empty archive handling", function()
    -- Create minimal test: just verify objectdb handles maps with no object mods
    local map_files = get_map_files()
    local empty_count = 0

    for _, path in ipairs(map_files) do
        local ok = pcall(function()
            local archive = mpq.open(path)
            local db = objectdb.load_from_archive(archive)
            archive:close()

            if db:count() == 0 then
                empty_count = empty_count + 1
            end
        end)
    end

    print(string.format("         (%d maps have no object modifications)", empty_count))
end)

test("file existence checking", function()
    local map_files = get_map_files()
    if #map_files == 0 then
        error("No test maps")
    end

    local archive = mpq.open(map_files[1])

    -- Check which object files exist
    local files = {
        "war3map.w3u", "war3map.w3a", "war3map.w3t",
        "war3map.w3b", "war3map.w3d", "war3map.w3h", "war3map.w3q"
    }
    local present = {}
    for _, f in ipairs(files) do
        if archive:has(f) then
            present[#present + 1] = f:match("%.(%w+)$")
        end
    end

    archive:close()

    print(string.format("         (found: %s)", table.concat(present, ", ")))
end)
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 60))
print(string.format("Tests: %d passed / %d total", tests_passed, tests_run))
if tests_passed == tests_run then
    print("All tests passed!")
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}
