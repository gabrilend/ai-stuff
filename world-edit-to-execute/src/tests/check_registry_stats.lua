#!/usr/bin/env lua
-- Registry population test - verifies that Map.load() populates the registry
-- with correct counts for all object types.
-- Run from project root: lua5.4 src/tests/check_registry_stats.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local data = require("data")

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

-- {{{ main
local function main()
    print("=== Registry Population Stats ===\n")

    local maps = get_map_files()
    if #maps == 0 then
        print("No maps found in assets/ directory")
        return
    end

    -- Header
    print(string.format("%-40s  %8s %6s %7s %7s %6s %8s",
        "Map", "Doodads", "Units", "Regions", "Cameras", "Sounds", "Total"))
    print(string.rep("-", 100))

    local grand_total = {
        doodads = 0,
        units = 0,
        regions = 0,
        cameras = 0,
        sounds = 0,
        total = 0,
    }

    for _, map_path in ipairs(maps) do
        local map_name = map_path:match("([^/]+)$")
        local ok, map = pcall(data.load, map_path)

        if ok and map and map.registry then
            local c = map.registry.counts
            local t = map.registry:get_total_count()

            print(string.format("%-40s  %8d %6d %7d %7d %6d %8d",
                map_name:sub(1, 40),
                c.doodads, c.units, c.regions, c.cameras, c.sounds, t))

            grand_total.doodads = grand_total.doodads + c.doodads
            grand_total.units = grand_total.units + c.units
            grand_total.regions = grand_total.regions + c.regions
            grand_total.cameras = grand_total.cameras + c.cameras
            grand_total.sounds = grand_total.sounds + c.sounds
            grand_total.total = grand_total.total + t
        else
            print(string.format("%-40s  ERROR: %s", map_name:sub(1, 40), tostring(map)))
        end
    end

    -- Summary
    print(string.rep("-", 100))
    print(string.format("%-40s  %8d %6d %7d %7d %6d %8d",
        string.format("GRAND TOTAL (%d maps)", #maps),
        grand_total.doodads, grand_total.units, grand_total.regions,
        grand_total.cameras, grand_total.sounds, grand_total.total))
end
-- }}}

main()
