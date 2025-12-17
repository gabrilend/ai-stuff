-- war3map.w3c Parser
-- Parses WC3 camera preset files containing cinematic and gameplay camera definitions.
-- Supports both standard format (pre-1.31) and extended format (1.31+ with local rotations).
-- Compatible with LuaJIT and Lua 5.3+.

local compat = require("compat")

local w3c = {}

-- {{{ Constants
-- Default camera values as used in WC3 editor
local CAMERA_DEFAULTS = {
    z_offset = 0.0,
    rotation = 90.0,       -- 0 = north, increases clockwise
    aoa = 304.0,           -- Typical RTS camera angle
    distance = 1650.0,
    roll = 0.0,
    fov = 70.0,
    far_clip = 5000.0,
    near_clip = 100.0,
}
-- }}}

-- {{{ Binary reading utilities
local function read_int32(data, pos)
    return compat.unpack_int32(data, pos)
end

local function read_float32(data, pos)
    return compat.unpack_float(data, pos)
end

local function read_string(data, pos)
    local str_end = data:find("\0", pos, true)
    if not str_end then
        return "", pos
    end
    return data:sub(pos, str_end - 1), str_end + 1
end
-- }}}

-- {{{ parse_camera
-- Parses a single camera entry.
-- extended: if true, parses 1.31+ format with local rotations
local function parse_camera(data, pos, extended)
    local camera = {}

    -- Target position (X, Y coordinates)
    camera.target = {}
    camera.target.x = read_float32(data, pos); pos = pos + 4
    camera.target.y = read_float32(data, pos); pos = pos + 4

    -- Z offset (height above target)
    camera.z_offset = read_float32(data, pos); pos = pos + 4

    -- Rotation (degrees, 0 = north, clockwise)
    camera.rotation = read_float32(data, pos); pos = pos + 4

    -- Angle of Attack (degrees, 0 = horizontal, 90 = looking down)
    camera.aoa = read_float32(data, pos); pos = pos + 4

    -- Distance from camera to target
    camera.distance = read_float32(data, pos); pos = pos + 4

    -- Roll (degrees)
    camera.roll = read_float32(data, pos); pos = pos + 4

    -- Field of View (degrees)
    camera.fov = read_float32(data, pos); pos = pos + 4

    -- Far clipping plane
    camera.far_clip = read_float32(data, pos); pos = pos + 4

    -- Near clipping plane
    camera.near_clip = read_float32(data, pos); pos = pos + 4

    -- Camera name (null-terminated string)
    camera.name, pos = read_string(data, pos)

    -- 1.31+ extended format: local rotations
    if extended then
        camera.local_pitch = read_float32(data, pos); pos = pos + 4
        camera.local_yaw = read_float32(data, pos); pos = pos + 4
        camera.local_roll = read_float32(data, pos); pos = pos + 4
    end

    return camera, pos
end
-- }}}

-- {{{ detect_format
-- Attempts to detect if w3c uses extended format by checking file size.
-- Returns: true if extended format, false otherwise
-- This is a heuristic since Blizzard didn't update file version in 1.31.
local function detect_format(data, camera_count, header_size)
    if camera_count == 0 then
        return false
    end

    local data_size = #data - header_size
    -- Base camera entry: 10 floats (40 bytes) + variable string
    -- Extended: adds 3 floats (12 bytes)

    -- We can't precisely detect without parsing, but we can estimate
    -- Average camera name is ~20 chars, so ~60 bytes per camera standard
    -- or ~72 bytes extended

    -- Simple heuristic: if average bytes per camera > 65, likely extended
    local avg_bytes = data_size / camera_count
    return avg_bytes > 65
end
-- }}}

-- {{{ w3c.parse
-- Parses a war3map.w3c file.
-- data: raw binary data string
-- editor_version: optional editor version from w3i (>= 131 means extended format)
-- Returns: structured cameras table, or nil and error message
function w3c.parse(data, editor_version)
    if not data or #data < 8 then
        return nil, "Invalid data: too short"
    end

    local pos = 1
    local result = {}

    -- Header
    result.version = read_int32(data, pos); pos = pos + 4
    local camera_count = read_int32(data, pos); pos = pos + 4

    -- Determine format based on editor version or heuristic
    local extended = false
    if editor_version and editor_version >= 131 then
        extended = true
    elseif not editor_version and camera_count > 0 then
        -- Try to detect based on file size
        extended = detect_format(data, camera_count, 8)
    end
    result.extended = extended

    -- Parse cameras
    result.cameras = {}
    for i = 1, camera_count do
        if pos > #data then
            return nil, string.format("Unexpected end of data at camera %d", i)
        end
        local camera, new_pos = parse_camera(data, pos, extended)
        result.cameras[i] = camera
        pos = new_pos
    end

    -- Build lookup index by name
    result.by_name = {}
    for _, camera in ipairs(result.cameras) do
        result.by_name[camera.name] = camera
    end

    return result
end
-- }}}

-- {{{ w3c.get_camera
-- Looks up a camera by name.
-- Returns: camera table or nil
function w3c.get_camera(result, name)
    if not result or not result.by_name then
        return nil
    end
    return result.by_name[name]
end
-- }}}

-- {{{ w3c.format
-- Returns a human-readable summary of the cameras.
function w3c.format(result)
    local lines = {}

    lines[#lines + 1] = "=== Cameras (w3c) ==="
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Version: " .. result.version
    lines[#lines + 1] = "Camera Count: " .. #result.cameras
    lines[#lines + 1] = "Format: " .. (result.extended and "Extended (1.31+)" or "Standard")
    lines[#lines + 1] = ""

    if #result.cameras == 0 then
        lines[#lines + 1] = "(No cameras defined)"
    else
        for i, c in ipairs(result.cameras) do
            lines[#lines + 1] = string.format("[%d] %s", i, c.name)
            lines[#lines + 1] = string.format("    Target: (%.1f, %.1f), Z offset: %.1f",
                c.target.x, c.target.y, c.z_offset)
            lines[#lines + 1] = string.format("    Rotation: %.1f°, AOA: %.1f°, Roll: %.1f°",
                c.rotation, c.aoa, c.roll)
            lines[#lines + 1] = string.format("    Distance: %.1f, FOV: %.1f°",
                c.distance, c.fov)
            lines[#lines + 1] = string.format("    Clipping: %.1f - %.1f",
                c.near_clip, c.far_clip)

            if result.extended and c.local_pitch then
                lines[#lines + 1] = string.format("    Local: pitch=%.1f°, yaw=%.1f°, roll=%.1f°",
                    c.local_pitch, c.local_yaw, c.local_roll)
            end
        end
    end

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ Exports
w3c.CAMERA_DEFAULTS = CAMERA_DEFAULTS
-- }}}

return w3c
