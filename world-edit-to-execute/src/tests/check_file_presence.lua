-- Check File Presence Across Maps
-- Utility to check which test maps contain a specific file type.
-- Run: lua src/tests/check_file_presence.lua [filename]
-- Example: lua src/tests/check_file_presence.lua war3map.w3c

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local mpq = require("mpq")

-- {{{ main
local function main()
    local target_file = arg[1] or "war3map.w3c"

    print("=== File Presence Check ===")
    print("Looking for: " .. target_file)
    print("")

    local handle = io.popen("ls " .. DIR .. "/assets/*.w3x 2>/dev/null")
    if not handle then
        print("ERROR: Cannot list assets directory")
        os.exit(1)
    end

    local maps = {}
    for line in handle:lines() do
        maps[#maps + 1] = line
    end
    handle:close()

    print("Found " .. #maps .. " map files\n")

    local found_count = 0
    for _, map_path in ipairs(maps) do
        local name = map_path:match("([^/]+)$")
        local archive, err = mpq.open(map_path)
        if archive then
            local has = archive:has(target_file)
            if has then
                local data = archive:extract(target_file)
                if data then
                    found_count = found_count + 1
                    print(string.format("%-50s %d bytes", name, #data))

                    -- Show hex dump of first 64 bytes
                    local hex = {}
                    for i = 1, math.min(64, #data) do
                        hex[#hex + 1] = string.format("%02x", data:byte(i))
                    end
                    print("  First 64 bytes: " .. table.concat(hex, " "))
                    print("")
                end
            end
            archive:close()
        end
    end

    print(string.format("\nMaps containing %s: %d / %d", target_file, found_count, #maps))
end
-- }}}

main()
