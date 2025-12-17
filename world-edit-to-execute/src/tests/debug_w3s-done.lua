#!/usr/bin/env lua5.4
-- Temporary debug script to explore w3s files
-- Delete after implementation complete

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

-- {{{ hex_dump
local function hex_dump(data, limit)
    limit = limit or 200
    print(string.format("\nHex dump (first %d bytes):", math.min(limit, #data)))
    for i = 1, math.min(limit, #data) do
        local byte = string.byte(data, i)
        io.write(string.format("%02X ", byte))
        if i % 16 == 0 then
            io.write(" | ")
            for j = i - 15, i do
                local c = string.byte(data, j)
                if c >= 32 and c < 127 then
                    io.write(string.char(c))
                else
                    io.write(".")
                end
            end
            io.write("\n")
        end
    end
    io.write("\n")
end
-- }}}

-- {{{ main
local function main()
    local maps = get_map_files()
    print("Checking " .. #maps .. " maps for war3map.w3s...")
    print()

    local with_w3s = {}
    for _, map_path in ipairs(maps) do
        local ok, archive = pcall(mpq.open, map_path)
        if ok then
            if archive:has("war3map.w3s") then
                local name = map_path:match("([^/]+)$")
                with_w3s[#with_w3s + 1] = { path = map_path, name = name, archive = archive }
                print("HAS w3s: " .. name)
            else
                archive:close()
            end
        end
    end

    print()
    print("Total maps with w3s: " .. #with_w3s .. "/" .. #maps)

    -- Extract and dump first w3s found
    if #with_w3s > 0 then
        print("\n=== Extracting first w3s file ===")
        local entry = with_w3s[1]
        local data = entry.archive:extract("war3map.w3s")
        print("File: " .. entry.name)
        print("Size: " .. #data .. " bytes")
        hex_dump(data, 400)

        -- Parse header
        local version = string.unpack("<I4", data, 1)
        local count = string.unpack("<I4", data, 5)
        print(string.format("Version: %d", version))
        print(string.format("Sound count: %d", count))

        -- Close all
        for _, e in ipairs(with_w3s) do
            e.archive:close()
        end
    end
end
-- }}}

-- {{{ check_map_contents
local function check_map_contents()
    local maps = get_map_files()
    if #maps == 0 then
        print("No test maps found")
        return
    end

    local map_path = maps[1]
    local ok, archive = pcall(mpq.open, map_path)
    if not ok then
        print("Failed to open: " .. tostring(archive))
        return
    end

    local name = map_path:match("([^/]+)$")
    print("=== Checking contents of: " .. name .. " ===\n")

    local common = {
        "war3map.w3i", "war3map.wts", "war3map.w3e", "war3map.doo",
        "war3mapUnits.doo", "war3map.w3r", "war3map.w3c", "war3map.w3s",
        "war3map.wtg", "war3map.wct", "war3map.j"
    }

    print("Common files check:")
    for _, f in ipairs(common) do
        local has = archive:has(f)
        print(string.format("  %-20s %s", f, has and "YES" or "no"))
    end

    archive:close()
end
-- }}}

-- Run
print("=== W3S Debug Script ===\n")
main()
print()
check_map_contents()
