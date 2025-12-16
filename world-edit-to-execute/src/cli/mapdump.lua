#!/usr/bin/env lua
-- mapdump.lua - WC3 Map Metadata Dump Tool
-- Dumps metadata from Warcraft 3 map files (.w3x/.w3m) in human-readable or JSON format.
--
-- Usage:
--   lua mapdump.lua <mapfile> [options]
--   lua mapdump.lua -I                      (interactive mode)
--
-- Options:
--   -f, --format <fmt>     Output format: text, json (default: text)
--   -c, --component <c>    Dump specific component: info, strings, terrain, files, all
--   -o, --output <file>    Write to file instead of stdout
--   -I, --interactive      Interactive mode
--   -v, --verbose          Verbose output
--   -h, --help             Show help
--
-- Examples:
--   lua mapdump.lua mymap.w3x
--   lua mapdump.lua mymap.w3x -f json -o output.json
--   lua mapdump.lua mymap.w3x -c terrain
--   lua mapdump.lua -I

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"

-- Allow DIR override via environment or first argument
if os.getenv("MAPDUMP_DIR") then
    DIR = os.getenv("MAPDUMP_DIR")
elseif arg[1] and arg[1]:match("^/") and not arg[1]:match("%.w3[xm]$") then
    DIR = table.remove(arg, 1)
end

package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local data = require("data")
local mpq = require("mpq")

-- {{{ Help text
local HELP = [[
WC3 Map Dump Tool

Usage:
  lua mapdump.lua <mapfile> [options]
  lua mapdump.lua -I

Options:
  -f, --format <fmt>     Output format: text, json (default: text)
  -c, --component <c>    Component to dump:
                           info    - Map metadata and players
                           strings - String table
                           terrain - Terrain summary
                           files   - Archive file list
                           all     - All components (default)
  -o, --output <file>    Write to file instead of stdout
  -I, --interactive      Interactive mode
  -v, --verbose          Verbose output
  -h, --help             Show this help

Examples:
  lua mapdump.lua mymap.w3x                    # Dump all info as text
  lua mapdump.lua mymap.w3x -f json            # Output as JSON
  lua mapdump.lua mymap.w3x -c terrain         # Terrain only
  lua mapdump.lua -I                           # Interactive mode
]]
-- }}}

-- {{{ JSON encoding (simple implementation)
-- {{{ json_encode
local function json_encode(value, indent)
    indent = indent or 0
    local pad = string.rep("  ", indent)
    local pad_inner = string.rep("  ", indent + 1)

    local t = type(value)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return value and "true" or "false"
    elseif t == "number" then
        if value ~= value then  -- NaN
            return "null"
        elseif value == math.huge or value == -math.huge then
            return "null"
        else
            return tostring(value)
        end
    elseif t == "string" then
        -- Escape special characters
        local escaped = value:gsub('[\\"\n\r\t]', {
            ['\\'] = '\\\\',
            ['"'] = '\\"',
            ['\n'] = '\\n',
            ['\r'] = '\\r',
            ['\t'] = '\\t',
        })
        return '"' .. escaped .. '"'
    elseif t == "table" then
        -- Check if array
        local is_array = true
        local n = 0
        for k in pairs(value) do
            if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
                is_array = false
                break
            end
            n = math.max(n, k)
        end
        if n > 0 and n ~= #value then
            is_array = false
        end
        if is_array and n == 0 then
            is_array = #value == 0
        end

        if is_array then
            if #value == 0 then
                return "[]"
            end
            local items = {}
            for i, v in ipairs(value) do
                items[#items + 1] = pad_inner .. json_encode(v, indent + 1)
            end
            return "[\n" .. table.concat(items, ",\n") .. "\n" .. pad .. "]"
        else
            local items = {}
            local keys = {}
            for k in pairs(value) do
                keys[#keys + 1] = k
            end
            table.sort(keys, function(a, b)
                return tostring(a) < tostring(b)
            end)
            for _, k in ipairs(keys) do
                local v = value[k]
                items[#items + 1] = pad_inner .. '"' .. tostring(k) .. '": ' .. json_encode(v, indent + 1)
            end
            if #items == 0 then
                return "{}"
            end
            return "{\n" .. table.concat(items, ",\n") .. "\n" .. pad .. "}"
        end
    else
        return '"<' .. t .. '>"'
    end
end
-- }}}
-- }}}

-- {{{ Argument parsing
-- {{{ parse_args
local function parse_args(args)
    local options = {
        format = "text",
        component = "all",
        output = nil,
        interactive = false,
        verbose = false,
        mapfile = nil,
    }

    local i = 1
    while i <= #args do
        local a = args[i]
        if a == "-f" or a == "--format" then
            i = i + 1
            options.format = args[i]
        elseif a == "-c" or a == "--component" then
            i = i + 1
            options.component = args[i]
        elseif a == "-o" or a == "--output" then
            i = i + 1
            options.output = args[i]
        elseif a == "-I" or a == "--interactive" then
            options.interactive = true
        elseif a == "-v" or a == "--verbose" then
            options.verbose = true
        elseif a == "-h" or a == "--help" then
            print(HELP)
            os.exit(0)
        elseif not a:match("^-") then
            options.mapfile = a
        else
            io.stderr:write("Unknown option: " .. a .. "\n")
            io.stderr:write("Use -h for help\n")
            os.exit(1)
        end
        i = i + 1
    end

    return options
end
-- }}}
-- }}}

-- {{{ Interactive mode
-- {{{ list_maps
local function list_maps(dir)
    local maps = {}
    local handle = io.popen('ls "' .. dir .. '"/*.w3x 2>/dev/null')
    if handle then
        for line in handle:lines() do
            maps[#maps + 1] = line:match("([^/]+)$")
        end
        handle:close()
    end
    return maps
end
-- }}}

-- {{{ interactive_mode
local function interactive_mode()
    print("=== WC3 Map Dump Tool ===")
    print()

    -- List available maps
    local maps_dir = DIR .. "/assets"
    local maps = list_maps(maps_dir)

    if #maps == 0 then
        io.write("Enter map file path: ")
        local path = io.read()
        if not path or path == "" then
            print("Error: No map file specified")
            os.exit(1)
        end
        return { mapfile = path, format = "text", component = "all" }
    end

    print("Available maps in assets/:")
    for i, map in ipairs(maps) do
        print(string.format("  [%d] %s", i, map))
    end
    print()
    io.write("Select map (number or path): ")
    local choice = io.read()

    local mapfile
    if tonumber(choice) then
        local idx = tonumber(choice)
        if idx < 1 or idx > #maps then
            print("Error: Invalid selection")
            os.exit(1)
        end
        mapfile = maps_dir .. "/" .. maps[idx]
    else
        mapfile = choice
    end

    -- Select component
    print()
    print("Components:")
    print("  [1] All (default)")
    print("  [2] Info only")
    print("  [3] Strings only")
    print("  [4] Terrain summary")
    print("  [5] File list")
    io.write("Select component [1]: ")
    local comp_choice = io.read()
    local component = "all"
    if comp_choice == "2" then component = "info"
    elseif comp_choice == "3" then component = "strings"
    elseif comp_choice == "4" then component = "terrain"
    elseif comp_choice == "5" then component = "files"
    end

    -- Select format
    print()
    print("Output format:")
    print("  [1] Text (default)")
    print("  [2] JSON")
    io.write("Select format [1]: ")
    local format_choice = io.read()
    local format = "text"
    if format_choice == "2" then format = "json" end

    print()
    return { mapfile = mapfile, format = format, component = component }
end
-- }}}
-- }}}

-- {{{ Dump functions
-- {{{ dump_info
local function dump_info(map, format)
    local info = {
        name = map:get_display_name(),
        author = map:get_display_author(),
        description = map:get_display_description(),
        suggested_players = map.suggested_players,
        dimensions = { width = map.width, height = map.height },
        playable = { width = map.playable_width, height = map.playable_height },
        tileset = map.tileset,
        tileset_code = map.tileset_code,
        version = map.version,
        players = {},
        forces = {},
    }

    for _, player in ipairs(map.players) do
        info.players[#info.players + 1] = {
            number = player.number or player.id,
            name = map:resolve_string(player.name or ""),
            type = player.type,
            race = player.race,
            start_x = player.start_x,
            start_y = player.start_y,
        }
    end

    for i, force in ipairs(map.forces) do
        info.forces[#info.forces + 1] = {
            index = i,
            name = map:resolve_string(force.name or ""),
            flags = force.flags,
            player_mask = force.player_mask,
        }
    end

    if format == "json" then
        return json_encode(info)
    else
        local lines = {}
        lines[#lines + 1] = "=== Map Info ==="
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Name: " .. info.name
        lines[#lines + 1] = "Author: " .. info.author
        if info.description and info.description ~= "" then
            lines[#lines + 1] = "Description: " .. info.description:gsub("\n", "\n             ")
        end
        lines[#lines + 1] = "Suggested Players: " .. (info.suggested_players or "")
        lines[#lines + 1] = ""
        lines[#lines + 1] = string.format("Dimensions: %dx%d tiles", info.dimensions.width, info.dimensions.height)
        lines[#lines + 1] = string.format("Playable: %dx%d tiles", info.playable.width, info.playable.height)
        lines[#lines + 1] = string.format("Tileset: %s (%s)", info.tileset, info.tileset_code)
        lines[#lines + 1] = string.format("Format Version: %d", info.version)
        lines[#lines + 1] = ""

        lines[#lines + 1] = string.format("=== Players (%d) ===", #info.players)
        lines[#lines + 1] = ""
        for _, p in ipairs(info.players) do
            local color = data.PLAYER_COLORS[p.number]
            local color_name = color and color.name or "Unknown"
            lines[#lines + 1] = string.format("[%d] %s - %s (%s, %s)",
                p.number, color_name, p.name, p.type or "?", p.race or "?")
            if p.start_x and p.start_y then
                lines[#lines + 1] = string.format("     Start: (%.0f, %.0f)", p.start_x, p.start_y)
            end
        end
        lines[#lines + 1] = ""

        lines[#lines + 1] = string.format("=== Forces (%d) ===", #info.forces)
        lines[#lines + 1] = ""
        for _, f in ipairs(info.forces) do
            lines[#lines + 1] = string.format("[%d] %s (mask: %d)",
                f.index, f.name, f.player_mask or 0)
        end

        return table.concat(lines, "\n")
    end
end
-- }}}

-- {{{ dump_strings
local function dump_strings(map, format)
    if not map.strings then
        if format == "json" then
            return json_encode({ error = "No string table" })
        else
            return "No string table loaded"
        end
    end

    local ids = map.strings:ids()
    local strings = {}
    for _, id in ipairs(ids) do
        strings[#strings + 1] = {
            id = id,
            content = map.strings:get(id)
        }
    end

    if format == "json" then
        return json_encode({ count = #strings, strings = strings })
    else
        local lines = {}
        lines[#lines + 1] = string.format("=== String Table (%d strings) ===", #strings)
        lines[#lines + 1] = ""

        for i, s in ipairs(strings) do
            if i > 50 then
                lines[#lines + 1] = string.format("... and %d more strings", #strings - 50)
                break
            end
            local content = s.content
            if #content > 80 then
                content = content:sub(1, 77) .. "..."
            end
            content = content:gsub("\n", "\\n")
            lines[#lines + 1] = string.format("[%d] %s", s.id, content)
        end

        return table.concat(lines, "\n")
    end
end
-- }}}

-- {{{ dump_terrain
local function dump_terrain(map, format)
    if not map.terrain then
        if format == "json" then
            return json_encode({ error = "No terrain data" })
        else
            return "No terrain data loaded"
        end
    end

    local stats = map:terrain_stats()
    local terrain_info = {
        width = map.terrain.width,
        height = map.terrain.height,
        tileset = map.terrain.tileset,
        tileset_code = map.terrain.tileset_code,
        ground_tilesets = map.terrain.ground_tilesets,
        cliff_tilesets = map.terrain.cliff_tilesets,
        offset_x = map.terrain.offset_x,
        offset_y = map.terrain.offset_y,
        stats = stats,
    }

    if format == "json" then
        return json_encode(terrain_info)
    else
        local lines = {}
        lines[#lines + 1] = "=== Terrain ==="
        lines[#lines + 1] = ""
        lines[#lines + 1] = string.format("Dimensions: %dx%d tilepoints", terrain_info.width, terrain_info.height)
        lines[#lines + 1] = string.format("Tileset: %s (%s)", terrain_info.tileset, terrain_info.tileset_code)
        lines[#lines + 1] = string.format("Center offset: (%.1f, %.1f)", terrain_info.offset_x, terrain_info.offset_y)
        lines[#lines + 1] = ""

        lines[#lines + 1] = string.format("Ground Tilesets (%d):", #terrain_info.ground_tilesets)
        for i, ts in ipairs(terrain_info.ground_tilesets) do
            lines[#lines + 1] = string.format("  [%d] %s", i - 1, ts)
        end
        lines[#lines + 1] = ""

        lines[#lines + 1] = string.format("Cliff Tilesets (%d):", #terrain_info.cliff_tilesets)
        for i, ts in ipairs(terrain_info.cliff_tilesets) do
            lines[#lines + 1] = string.format("  [%d] %s", i - 1, ts)
        end
        lines[#lines + 1] = ""

        lines[#lines + 1] = "Statistics:"
        lines[#lines + 1] = string.format("  Total tilepoints: %d", stats.total_tilepoints)
        lines[#lines + 1] = string.format("  Height range: %.1f to %.1f", stats.min_height, stats.max_height)
        lines[#lines + 1] = string.format("  Water tiles: %d", stats.water_count)
        lines[#lines + 1] = string.format("  Blight tiles: %d", stats.blight_count)
        lines[#lines + 1] = string.format("  Ramp tiles: %d", stats.ramp_count)
        lines[#lines + 1] = string.format("  Boundary tiles: %d", stats.boundary_count)

        -- Layer distribution
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Cliff Layers:"
        local layers = {}
        for layer in pairs(stats.layer_counts) do
            layers[#layers + 1] = layer
        end
        table.sort(layers)
        for _, layer in ipairs(layers) do
            local count = stats.layer_counts[layer]
            local pct = count / stats.total_tilepoints * 100
            lines[#lines + 1] = string.format("  Layer %d: %d (%.1f%%)", layer, count, pct)
        end

        return table.concat(lines, "\n")
    end
end
-- }}}

-- {{{ dump_files
local function dump_files(mapfile, format)
    local ok, archive = pcall(mpq.open, mapfile)
    if not ok then
        if format == "json" then
            return json_encode({ error = "Could not open archive: " .. tostring(archive) })
        else
            return "Error: Could not open archive"
        end
    end

    local files, err = archive:list()
    archive:close()

    if not files then
        if format == "json" then
            return json_encode({ error = err or "Could not list files" })
        else
            return "Error: " .. (err or "Could not list files")
        end
    end

    if format == "json" then
        return json_encode({ count = #files, files = files })
    else
        local lines = {}
        lines[#lines + 1] = string.format("=== Files in Archive (%d) ===", #files)
        lines[#lines + 1] = ""
        for _, file in ipairs(files) do
            lines[#lines + 1] = "  " .. file
        end
        return table.concat(lines, "\n")
    end
end
-- }}}

-- {{{ dump_all
local function dump_all(map, mapfile, format)
    if format == "json" then
        local result = {
            source = mapfile,
            info = nil,
            strings = nil,
            terrain = nil,
        }

        -- Parse individual JSON sections and combine
        -- (This is a bit hacky but avoids writing a full merge function)
        local info_data = {
            name = map:get_display_name(),
            author = map:get_display_author(),
            dimensions = { width = map.width, height = map.height },
            tileset = map.tileset,
            player_count = map:player_count(),
            force_count = map:force_count(),
        }
        result.info = info_data

        if map.strings then
            result.strings = { count = map.strings:count() }
        end

        if map.terrain then
            local stats = map:terrain_stats()
            result.terrain = {
                dimensions = { width = map.terrain.width, height = map.terrain.height },
                stats = stats,
            }
        end

        return json_encode(result)
    else
        local parts = {}
        parts[#parts + 1] = dump_info(map, format)
        parts[#parts + 1] = ""
        parts[#parts + 1] = dump_terrain(map, format)
        parts[#parts + 1] = ""
        if map.strings and map.strings:count() > 0 then
            parts[#parts + 1] = string.format("=== String Table (%d strings) ===", map.strings:count())
            parts[#parts + 1] = "(Use -c strings to see full string table)"
        end
        parts[#parts + 1] = ""
        parts[#parts + 1] = "(Use -c files to see archive file list)"
        return table.concat(parts, "\n")
    end
end
-- }}}
-- }}}

-- {{{ Main
local function main()
    local options = parse_args(arg)

    if options.interactive then
        options = interactive_mode()
    end

    if not options.mapfile then
        io.stderr:write("Error: No map file specified\n")
        io.stderr:write("Use -h for help or -I for interactive mode\n")
        os.exit(1)
    end

    -- Check file exists
    local f = io.open(options.mapfile, "r")
    if not f then
        io.stderr:write("Error: Could not open '" .. options.mapfile .. "': File not found\n")
        os.exit(1)
    end
    f:close()

    -- Load map
    local load_ok, map = pcall(data.load, options.mapfile)
    if not load_ok then
        io.stderr:write("Error: Could not load map: " .. tostring(map) .. "\n")
        os.exit(1)
    end

    -- Generate output
    local output
    if options.component == "all" then
        output = dump_all(map, options.mapfile, options.format)
    elseif options.component == "info" then
        output = dump_info(map, options.format)
    elseif options.component == "strings" then
        output = dump_strings(map, options.format)
    elseif options.component == "terrain" then
        output = dump_terrain(map, options.format)
    elseif options.component == "files" then
        output = dump_files(options.mapfile, options.format)
    else
        io.stderr:write("Error: Unknown component '" .. options.component .. "'\n")
        io.stderr:write("Valid components: info, strings, terrain, files, all\n")
        os.exit(1)
    end

    -- Write output
    if options.output then
        local outfile = io.open(options.output, "w")
        if not outfile then
            io.stderr:write("Error: Could not open output file '" .. options.output .. "'\n")
            os.exit(1)
        end
        outfile:write(output)
        outfile:write("\n")
        outfile:close()
        if options.verbose then
            print("Output written to " .. options.output)
        end
    else
        print(output)
    end
end

main()
-- }}}
