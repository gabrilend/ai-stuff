-- Testing Room Demo (Issue 508d)
-- Main entry point for the vertical slice demo.
-- Loads a WC3 map and renders it using the map_renderer.
--
-- Usage (from Lua):
--   local testing_room = require("demo.testing_room")
--   testing_room.run("/path/to/map.w3x")
--
-- Or with the default test map:
--   testing_room.run_default()

-- {{{ Path setup
-- Allow running from any directory by finding project root
local function find_project_root()
    -- Check common locations
    local paths = {
        "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute",
        "./",
        "../",
    }
    for _, path in ipairs(paths) do
        local f = io.open(path .. "/CLAUDE.md", "r")
        if f then
            f:close()
            return path
        end
    end
    return "."
end

local PROJECT_ROOT = find_project_root()

-- Add source paths to package.path
package.path = PROJECT_ROOT .. "/src/?.lua;" ..
               PROJECT_ROOT .. "/src/?/init.lua;" ..
               package.path
-- }}}

local render = require("render")

-- {{{ testing_room module
local testing_room = {}

-- {{{ testing_room.run
-- Load and display a WC3 map file.
-- map_path: Path to .w3x or .w3m file
function testing_room.run(map_path)
    print("=== Testing Room Demo (508d) ===")

    if not map_path then
        print("[error] No map path provided")
        return false
    end

    print("[info] Loading map: " .. map_path)

    -- Check if file exists
    local f = io.open(map_path, "rb")
    if not f then
        print("[error] Cannot open map file: " .. map_path)
        return false
    end
    f:close()

    -- Load required modules
    local ok, Map = pcall(require, "data")
    if not ok then
        print("[error] Failed to load data module: " .. tostring(Map))
        print("[info] Falling back to demo terrain")
        return testing_room.run_demo()
    end

    local ok2, map_renderer = pcall(require, "demo.map_renderer")
    if not ok2 then
        print("[error] Failed to load map_renderer: " .. tostring(map_renderer))
        return false
    end

    -- Load the map
    local map_ok, map = pcall(Map.load, map_path)
    if not map_ok or not map then
        print("[error] Failed to load map: " .. tostring(map))
        return false
    end

    print("[info] Map loaded: " .. (map:get_display_name() or "unnamed"))
    print("[info] Dimensions: " .. map.width .. "x" .. map.height)
    print("[info] Players: " .. map:player_count())

    -- Render the map
    local render_ok = map_renderer.load(map)
    if not render_ok then
        print("[error] Failed to render map")
        return false
    end

    print("[info] Map rendered successfully")
    print("[info] Use mouse/keyboard to interact")

    return true
end
-- }}}

-- {{{ testing_room.run_demo
-- Creates a demo terrain without loading a real map.
-- Used for testing when no map file is available.
function testing_room.run_demo()
    print("=== Testing Room Demo Mode ===")

    local size = 32
    local tile_size = 1.0

    -- Create terrain grid
    local ok = render.terrain_create(size, size, tile_size)
    if not ok then
        print("[error] Failed to create terrain")
        return false
    end

    -- Center terrain
    render.terrain_set_offset(-size * tile_size / 2, -size * tile_size / 2)

    -- Generate interesting terrain pattern
    local tiles = {}
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local r, g, b

            -- Distance from center
            local cx, cy = size / 2, size / 2
            local dx, dy = x - cx, y - cy
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist < 3 then
                -- Center: water (blue)
                r, g, b = 30, 100, 180
            elseif dist < 6 then
                -- Beach: sand (tan)
                r, g, b = 194, 145, 87
            elseif dist < 12 then
                -- Land: grass (green)
                local shade = 0.8 + 0.2 * math.sin(x * 0.5 + y * 0.5)
                r, g, b = math.floor(34 * shade), math.floor(139 * shade), math.floor(34 * shade)
            else
                -- Edge: dirt/rock (gray-brown)
                r, g, b = 100, 80, 60
            end

            table.insert(tiles, { x, y, r, g, b })
        end
    end

    render.terrain_set_tiles(tiles)
    print("[demo] Created " .. size .. "x" .. size .. " terrain")

    -- Create some demo entities
    local entities = {
        { id = 1, x = 0, z = 5, r = 255, g = 0, b = 0 },     -- Red unit north
        { id = 2, x = 5, z = 0, r = 0, g = 0, b = 255 },     -- Blue unit east
        { id = 3, x = 0, z = -5, r = 0, g = 255, b = 0 },    -- Green unit south
        { id = 4, x = -5, z = 0, r = 255, g = 255, b = 0 },  -- Yellow unit west
    }

    for _, e in ipairs(entities) do
        local slot = render.create_entity(e.id, render.MESH_CIRCLE, e.x, 0.3, e.z)
        if slot >= 0 then
            render.set_color(slot, e.r, e.g, e.b, 255)
            render.set_scale(slot, 0.5)
        end
    end

    print("[demo] Created " .. #entities .. " demo entities")
    print("[demo] Demo ready - use mouse/keyboard to interact")

    return true
end
-- }}}

-- {{{ testing_room.run_default
-- Attempts to run with a default test map, falls back to demo mode.
function testing_room.run_default()
    -- Try common test map locations
    local test_maps = {
        PROJECT_ROOT .. "/input/test.w3x",
        PROJECT_ROOT .. "/assets/maps/test.w3x",
        "/home/ritz/wc3maps/test.w3x",
    }

    for _, path in ipairs(test_maps) do
        local f = io.open(path, "rb")
        if f then
            f:close()
            return testing_room.run(path)
        end
    end

    -- No test map found, use demo mode
    print("[info] No test map found, using demo mode")
    return testing_room.run_demo()
end
-- }}}

-- {{{ testing_room.list_maps
-- Lists available map files in common locations.
function testing_room.list_maps()
    print("=== Available Maps ===")

    local map_dirs = {
        PROJECT_ROOT .. "/input",
        PROJECT_ROOT .. "/assets/maps",
        "/home/ritz/wc3maps",
    }

    local found = 0
    for _, dir in ipairs(map_dirs) do
        -- Use ls to list .w3x and .w3m files
        local handle = io.popen("ls -1 " .. dir .. "/*.w3x " .. dir .. "/*.w3m 2>/dev/null")
        if handle then
            local output = handle:read("*a")
            handle:close()
            if output and #output > 0 then
                print("In " .. dir .. ":")
                for line in output:gmatch("[^\n]+") do
                    print("  " .. line)
                    found = found + 1
                end
            end
        end
    end

    if found == 0 then
        print("No maps found. Place .w3x or .w3m files in:")
        for _, dir in ipairs(map_dirs) do
            print("  " .. dir)
        end
    end

    return found
end
-- }}}

return testing_room
-- }}}
