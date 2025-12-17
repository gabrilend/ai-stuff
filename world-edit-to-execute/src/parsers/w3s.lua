-- war3map.w3s Parser
-- Parses WC3 sound definition files containing sound configurations.
-- Supports Frozen Throne (version 1) and Reforged (version 3) formats.
-- Compatible with both LuaJIT and Lua 5.3+.

local compat = require("compat")
local band = compat.band

local w3s = {}

-- {{{ Constants
local SOUND_FLAGS = {
    LOOPING        = 0x00000001,
    SOUND_3D       = 0x00000002,
    STOP_OUT_RANGE = 0x00000004,
    MUSIC          = 0x00000008,
}

local SOUND_CHANNELS = {
    [0]  = "General",
    [1]  = "Unit Selection",
    [2]  = "Unit Acknowledgement",
    [3]  = "Unit Movement",
    [4]  = "Unit Ready",
    [5]  = "Combat",
    [6]  = "Error",
    [7]  = "Music",
    [8]  = "User Interface",
    [9]  = "Looping Movement",
    [10] = "Looping Ambient",
    [11] = "Animations",
    [12] = "Constructions",
    [13] = "Birth",
    [14] = "Fire",
}

local EAX_EFFECTS = {
    ["DefaultEAXON"]     = "Default",
    ["CombatSoundsEAX"]  = "Combat",
    ["KotoDrumsEAX"]     = "Drums",
    ["SpellsEAX"]        = "Spells",
    ["MissilesEAX"]      = "Missiles",
    ["HeroAcksEAX"]      = "Hero Speech",
    ["DoodadsEAX"]       = "Doodads",
}

local SOUND_DEFAULTS = {
    volume = -1,
    pitch = 1.0,
    fade_in = 10,
    fade_out = 10,
}
-- }}}

-- {{{ Binary reading utilities
local function read_int32(data, pos)
    return compat.unpack_int32(data, pos)
end

local function read_uint32(data, pos)
    return compat.unpack_uint32(data, pos)
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

-- {{{ parse_flags
-- Parses sound flags bitmask into a table of boolean values.
local function parse_flags(value)
    return {
        raw = value,
        looping = band(value, SOUND_FLAGS.LOOPING) ~= 0,
        sound_3d = band(value, SOUND_FLAGS.SOUND_3D) ~= 0,
        stop_out_range = band(value, SOUND_FLAGS.STOP_OUT_RANGE) ~= 0,
        music = band(value, SOUND_FLAGS.MUSIC) ~= 0,
    }
end
-- }}}

-- {{{ parse_sound_v1
-- Parses a single sound entry in version 1 (TFT) format.
-- Returns the sound entry and the next read position.
local function parse_sound_v1(data, pos)
    local sound = {}

    -- Strings
    sound.name, pos = read_string(data, pos)
    sound.file, pos = read_string(data, pos)
    sound.eax, pos = read_string(data, pos)
    sound.eax_name = EAX_EFFECTS[sound.eax] or sound.eax

    -- Flags
    local flags_raw = read_uint32(data, pos); pos = pos + 4
    sound.flags = parse_flags(flags_raw)

    -- Fade rates
    sound.fade_in = read_int32(data, pos); pos = pos + 4
    sound.fade_out = read_int32(data, pos); pos = pos + 4

    -- Volume and pitch
    sound.volume = read_int32(data, pos); pos = pos + 4
    sound.pitch = read_float32(data, pos); pos = pos + 4

    -- Unknown float (usually 0)
    sound.unknown = read_float32(data, pos); pos = pos + 4

    -- Channel
    local channel_raw = read_int32(data, pos); pos = pos + 4
    sound.channel = channel_raw
    sound.channel_name = SOUND_CHANNELS[channel_raw] or ("Unknown_" .. channel_raw)

    -- 3D distance parameters
    sound.distance = {
        min = read_float32(data, pos),
        max = read_float32(data, pos + 4),
        cutoff = read_float32(data, pos + 8),
    }
    pos = pos + 12

    -- Cone parameters
    sound.cone = {
        inside_angle = read_float32(data, pos),
        outside_angle = read_float32(data, pos + 4),
        outside_volume = read_int32(data, pos + 8),
        orientation = {
            x = read_float32(data, pos + 12),
            y = read_float32(data, pos + 16),
            z = read_float32(data, pos + 20),
        },
    }
    pos = pos + 24

    return sound, pos
end
-- }}}

-- {{{ parse_sound_v3_extension
-- Parses additional fields for version 3 (Reforged) format.
-- Appends to an existing sound entry parsed by v1.
local function parse_sound_v3_extension(data, pos, sound)
    -- Additional string fields
    sound.label, pos = read_string(data, pos)
    sound.base_label, pos = read_string(data, pos)
    sound.asset_path, pos = read_string(data, pos)

    -- Dialogue ID
    sound.dialogue_id = read_int32(data, pos); pos = pos + 4

    -- Production comments
    sound.comments, pos = read_string(data, pos)

    -- Speaker name ID
    sound.speaker_id = read_int32(data, pos); pos = pos + 4

    -- Listener name
    sound.listener, pos = read_string(data, pos)

    -- Instance flags
    local instance_flags = read_int32(data, pos); pos = pos + 4
    sound.instance_flags = {
        raw = instance_flags,
        conversation = band(instance_flags, 0x01) ~= 0,
        hd_only = band(instance_flags, 0x02) ~= 0,
        sd_only = band(instance_flags, 0x04) ~= 0,
    }

    return pos
end
-- }}}

-- {{{ w3s.parse
-- Parses a war3map.w3s file.
-- data: raw binary data string
-- Returns: structured sound table, or nil and error message
function w3s.parse(data)
    if not data or #data < 8 then
        return nil, "Invalid data: too short"
    end

    local pos = 1
    local result = {}

    -- Header
    result.version = read_int32(data, pos); pos = pos + 4
    local count = read_int32(data, pos); pos = pos + 4

    -- Version check
    if result.version ~= 1 and result.version ~= 3 then
        result._version_warning = "Unknown w3s version: " .. result.version
    end

    -- Parse sound entries
    result.sounds = {}
    for i = 1, count do
        -- Check if we have enough data
        if pos > #data then
            return nil, string.format("Unexpected end of data at sound %d (pos %d, size %d)", i, pos, #data)
        end

        local sound, new_pos = parse_sound_v1(data, pos)

        -- For version 3, parse additional fields
        if result.version >= 3 then
            new_pos = parse_sound_v3_extension(data, new_pos, sound)
        end

        result.sounds[i] = sound
        pos = new_pos
    end

    return result
end
-- }}}

-- {{{ w3s.format
-- Returns a human-readable summary of the sound definitions.
function w3s.format(result)
    local lines = {}

    lines[#lines + 1] = "=== Sound Definitions (w3s) ==="
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("Version: %d", result.version)
    lines[#lines + 1] = string.format("Sound count: %d", #result.sounds)
    lines[#lines + 1] = ""

    if result._version_warning then
        lines[#lines + 1] = "Warning: " .. result._version_warning
        lines[#lines + 1] = ""
    end

    for i, sound in ipairs(result.sounds) do
        if i > 20 then
            lines[#lines + 1] = string.format("... and %d more sounds", #result.sounds - 20)
            break
        end

        -- Build flags string
        local flags = {}
        if sound.flags.looping then flags[#flags + 1] = "looping" end
        if sound.flags.sound_3d then flags[#flags + 1] = "3D" end
        if sound.flags.music then flags[#flags + 1] = "music" end
        local flags_str = #flags > 0 and (" [" .. table.concat(flags, ", ") .. "]") or ""

        lines[#lines + 1] = string.format("[%d] %s%s", i, sound.name, flags_str)
        lines[#lines + 1] = string.format("    File: %s", sound.file)
        lines[#lines + 1] = string.format("    Channel: %s, EAX: %s", sound.channel_name, sound.eax_name)

        if sound.flags.sound_3d then
            lines[#lines + 1] = string.format("    Distance: min=%.1f, max=%.1f, cutoff=%.1f",
                sound.distance.min, sound.distance.max, sound.distance.cutoff)
        end

        if sound.volume ~= -1 then
            lines[#lines + 1] = string.format("    Volume: %d", sound.volume)
        end

        if sound.pitch ~= 1.0 then
            lines[#lines + 1] = string.format("    Pitch: %.2f", sound.pitch)
        end

        lines[#lines + 1] = ""
    end

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ SoundTable class
local SoundTable = {}
SoundTable.__index = SoundTable

-- {{{ new
-- Create a new SoundTable from w3s content.
function SoundTable.new(w3s_data)
    local self = setmetatable({}, SoundTable)
    self.sounds = {}
    self.by_name = {}
    self.version = 1
    if w3s_data then
        self:load(w3s_data)
    end
    return self
end
-- }}}

-- {{{ load
-- Load sounds from w3s binary data.
function SoundTable:load(w3s_data)
    local result, err = w3s.parse(w3s_data)
    if not result then
        error("Failed to parse w3s: " .. tostring(err))
    end

    self.version = result.version
    self.sounds = result.sounds

    -- Build name lookup
    self.by_name = {}
    for _, sound in ipairs(self.sounds) do
        self.by_name[sound.name] = sound
    end
end
-- }}}

-- {{{ get
-- Get a sound by name. Returns nil if not found.
function SoundTable:get(name)
    return self.by_name[name]
end
-- }}}

-- {{{ count
-- Return the number of sounds.
function SoundTable:count()
    return #self.sounds
end
-- }}}

-- {{{ names
-- Return a list of all sound names.
function SoundTable:names()
    local result = {}
    for _, sound in ipairs(self.sounds) do
        result[#result + 1] = sound.name
    end
    return result
end
-- }}}

-- {{{ pairs
-- Iterate over all sounds (index, sound).
function SoundTable:pairs()
    return ipairs(self.sounds)
end
-- }}}
-- }}}

-- {{{ Module interface
w3s.SoundTable = SoundTable
w3s.SOUND_FLAGS = SOUND_FLAGS
w3s.SOUND_CHANNELS = SOUND_CHANNELS
w3s.EAX_EFFECTS = EAX_EFFECTS
w3s.SOUND_DEFAULTS = SOUND_DEFAULTS

-- {{{ new
-- Convenience function to create a SoundTable.
function w3s.new(data)
    return SoundTable.new(data)
end
-- }}}
-- }}}

return w3s
