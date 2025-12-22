#!/usr/bin/env lua
-- Diagnostic script to check which Phase 2 files exist in test maps.
-- Run from project root: lua5.4 src/tests/check_map_files.lua
-- Useful for understanding why certain registry types may be empty.

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local mpq = require("mpq")

-- {{{ get_map_files
local function get_map_files()
    local files = {}
    local handle = io.popen('ls "' .. DIR .. '/assets"/*.w3x 2>/dev/null')
    if handle then
        for line in handle:lines() do
            files[#files + 1] = line
        end
        handle:close()
    end
    return files
end
-- }}}

-- {{{ check_map
local function check_map(map_path)
    local files_to_check = {
        { name = "war3map.doo", desc = "Doodads" },
        { name = "war3mapUnits.doo", desc = "Units" },
        { name = "war3map.w3r", desc = "Regions" },
        { name = "war3map.w3c", desc = "Cameras" },
        { name = "war3map.w3s", desc = "Sounds" },
    }

    local ok, archive = pcall(mpq.open, map_path)
    if not ok then
        return nil, archive
    end

    local results = {}
    for _, file_info in ipairs(files_to_check) do
        results[file_info.name] = archive:has(file_info.name)
    end

    archive:close()
    return results
end
-- }}}

-- {{{ main
local function main()
    print("=== Phase 2 File Availability Check ===\n")

    local maps = get_map_files()
    if #maps == 0 then
        print("No maps found in assets/ directory")
        return
    end

    -- Header
    print(string.format("%-40s  %-8s %-8s %-8s %-8s %-8s",
        "Map", "Doodads", "Units", "Regions", "Cameras", "Sounds"))
    print(string.rep("-", 90))

    -- Count totals
    local totals = {
        ["war3map.doo"] = 0,
        ["war3mapUnits.doo"] = 0,
        ["war3map.w3r"] = 0,
        ["war3map.w3c"] = 0,
        ["war3map.w3s"] = 0,
    }

    for _, map_path in ipairs(maps) do
        local map_name = map_path:match("([^/]+)$")
        local results, err = check_map(map_path)

        if results then
            local function yn(key)
                if results[key] then
                    totals[key] = totals[key] + 1
                    return "YES"
                else
                    return "no"
                end
            end

            print(string.format("%-40s  %-8s %-8s %-8s %-8s %-8s",
                map_name:sub(1, 40),
                yn("war3map.doo"),
                yn("war3mapUnits.doo"),
                yn("war3map.w3r"),
                yn("war3map.w3c"),
                yn("war3map.w3s")))
        else
            print(string.format("%-40s  ERROR: %s", map_name:sub(1, 40), err))
        end
    end

    -- Summary
    print(string.rep("-", 90))
    print(string.format("%-40s  %-8s %-8s %-8s %-8s %-8s",
        string.format("TOTALS (%d maps)", #maps),
        totals["war3map.doo"],
        totals["war3mapUnits.doo"],
        totals["war3map.w3r"],
        totals["war3map.w3c"],
        totals["war3map.w3s"]))
end
-- }}}

main()
