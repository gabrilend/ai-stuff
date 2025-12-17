-- war3map.w3r Parser
-- Parses WC3 region files containing rect definitions for triggers, waygates,
-- weather zones, and ambient sound areas. Compatible with LuaJIT and Lua 5.3+.

local compat = require("compat")

local w3r = {}

-- {{{ Constants
local WEATHER_EFFECTS = {
    ["RAhr"] = "ashenvale_rain_heavy",
    ["RAlr"] = "ashenvale_rain_light",
    ["MEds"] = "dungeon_mist_blue",
    ["FDbh"] = "dungeon_fog_heavy_brown",
    ["FDbl"] = "dungeon_fog_light_brown",
    ["FDgh"] = "dungeon_fog_heavy_green",
    ["FDgl"] = "dungeon_fog_light_green",
    ["FDrh"] = "dungeon_fog_heavy_red",
    ["FDrl"] = "dungeon_fog_light_red",
    ["FDwh"] = "dungeon_fog_heavy_white",
    ["FDwl"] = "dungeon_fog_light_white",
    ["SNbs"] = "northrend_blizzard",
    ["SNhs"] = "northrend_snow_heavy",
    ["SNls"] = "northrend_snow_light",
    ["WNcw"] = "rays_of_light",
    ["WNlr"] = "rays_of_moonlight",
    ["WOcw"] = "wind_outland",
    ["WOlw"] = "wind_outland_light",
    ["LRaa"] = "lordaeron_rain_ashenvale",
    ["LRma"] = "lordaeron_rain",
}
-- }}}

-- {{{ Binary reading utilities
local function read_int32(data, pos)
    return compat.unpack_int32(data, pos)
end

local function read_float32(data, pos)
    return compat.unpack_float(data, pos)
end

local function read_byte(data, pos)
    return data:byte(pos), pos + 1
end

local function read_string(data, pos)
    local str_end = data:find("\0", pos, true)
    if not str_end then
        return "", pos
    end
    return data:sub(pos, str_end - 1), str_end + 1
end

local function read_char4(data, pos)
    return data:sub(pos, pos + 3), pos + 4
end
-- }}}

-- {{{ parse_region
-- Parses a single region entry.
local function parse_region(data, pos)
    local region = {}

    -- Bounding box (4 floats: left, bottom, right, top)
    region.bounds = {}
    region.bounds.left = read_float32(data, pos); pos = pos + 4
    region.bounds.bottom = read_float32(data, pos); pos = pos + 4
    region.bounds.right = read_float32(data, pos); pos = pos + 4
    region.bounds.top = read_float32(data, pos); pos = pos + 4

    -- Region name (null-terminated string)
    region.name, pos = read_string(data, pos)

    -- Creation number (unique editor ID, used for waygate targeting)
    region.creation_number = read_int32(data, pos); pos = pos + 4

    -- Weather effect ID (4 chars, or null bytes for none)
    local weather_id
    weather_id, pos = read_char4(data, pos)
    -- Check if it's null (no weather)
    if weather_id == "\0\0\0\0" then
        region.weather = nil
        region.weather_id = nil
    else
        region.weather_id = weather_id
        region.weather = WEATHER_EFFECTS[weather_id] or weather_id
    end

    -- Ambient sound name (null-terminated string, references w3s)
    region.ambient_sound, pos = read_string(data, pos)
    if region.ambient_sound == "" then
        region.ambient_sound = nil
    end

    -- Editor color (RGBA, 4 bytes)
    region.color = {}
    region.color.b, pos = read_byte(data, pos)
    region.color.g, pos = read_byte(data, pos)
    region.color.r, pos = read_byte(data, pos)
    region.color.a, pos = read_byte(data, pos)

    return region, pos
end
-- }}}

-- {{{ w3r.parse
-- Parses a war3map.w3r file.
-- data: raw binary data string
-- Returns: structured regions table with lookup index, or nil and error message
function w3r.parse(data)
    if not data or #data < 8 then
        return nil, "Invalid data: too short"
    end

    local pos = 1
    local result = {}

    -- Header
    result.version = read_int32(data, pos); pos = pos + 4
    local region_count = read_int32(data, pos); pos = pos + 4

    -- Version check (5 is TFT standard)
    if result.version ~= 5 then
        result._version_warning = "Unknown w3r version: " .. result.version
    end

    -- Parse regions
    result.regions = {}
    for i = 1, region_count do
        local region, new_pos = parse_region(data, pos)
        result.regions[i] = region
        pos = new_pos
    end

    -- Build lookup index by creation number
    result.by_creation_number = {}
    for _, region in ipairs(result.regions) do
        result.by_creation_number[region.creation_number] = region
    end

    return result
end
-- }}}

-- {{{ w3r.get_region
-- Looks up a region by its creation number (used for waygate destinations).
-- Returns: region table or nil
function w3r.get_region(result, creation_number)
    if not result or not result.by_creation_number then
        return nil
    end
    return result.by_creation_number[creation_number]
end
-- }}}

-- {{{ w3r.format
-- Returns a human-readable summary of the regions.
function w3r.format(result)
    local lines = {}

    lines[#lines + 1] = "=== Regions (w3r) ==="
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Version: " .. result.version
    lines[#lines + 1] = "Region Count: " .. #result.regions
    lines[#lines + 1] = ""

    if #result.regions == 0 then
        lines[#lines + 1] = "(No regions defined)"
    else
        for i, r in ipairs(result.regions) do
            lines[#lines + 1] = string.format("[%d] %s (id=%d)",
                i, r.name, r.creation_number)
            lines[#lines + 1] = string.format("    Bounds: (%.1f, %.1f) to (%.1f, %.1f)",
                r.bounds.left, r.bounds.bottom, r.bounds.right, r.bounds.top)

            local extras = {}
            if r.weather then
                extras[#extras + 1] = "Weather: " .. r.weather
            end
            if r.ambient_sound then
                extras[#extras + 1] = "Sound: " .. r.ambient_sound
            end
            if #extras > 0 then
                lines[#lines + 1] = "    " .. table.concat(extras, ", ")
            end

            lines[#lines + 1] = string.format("    Color: rgba(%d,%d,%d,%d)",
                r.color.r, r.color.g, r.color.b, r.color.a)
        end
    end

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ Exports
w3r.WEATHER_EFFECTS = WEATHER_EFFECTS
-- }}}

return w3r
