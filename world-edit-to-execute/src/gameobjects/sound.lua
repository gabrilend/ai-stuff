-- Sound Class
-- Represents sound definitions and ambient loops from war3map.w3s.
-- Wraps parsed sound data with methods for audio property queries.
--
-- Implementation: 206f-implement-sound-class
--
-- Parser output fields (from src/parsers/w3s.lua):
--   name: sound name
--   file: file path (e.g., "Sound\\Music\\mp3Music\\War2IntroMusic.mp3")
--   eax: EAX effect string (e.g., "DefaultEAXON")
--   eax_name: friendly EAX name
--   flags: { raw, looping, sound_3d, stop_out_range, music }
--   fade_in, fade_out: fade rates in ms
--   volume: int (-1 = use default 100%)
--   pitch: float (1.0 = normal)
--   channel: channel number (0-14)
--   channel_name: friendly channel name
--   distance: { min, max, cutoff } for 3D sounds
--   cone: { inside_angle, outside_angle, outside_volume, orientation }

-- {{{ Sound class
local Sound = {}
Sound.__index = Sound

-- {{{ new
-- Create a new Sound from parsed sound data.
-- @param data Table from w3s.parse() containing sound fields
-- @return Sound instance
function Sound.new(data)
    local self = setmetatable({}, Sound)

    -- Core identification
    self.name = data.name or ""
    self.file = data.file or ""

    -- EAX effect
    self.eax = data.eax
    self.eax_name = data.eax_name

    -- Flags (defensive copy if table, handle legacy numeric format)
    if type(data.flags) == "table" then
        self.flags = {
            raw = data.flags.raw or 0,
            looping = data.flags.looping or false,
            sound_3d = data.flags.sound_3d or false,
            stop_out_range = data.flags.stop_out_range or false,
            music = data.flags.music or false,
        }
    elseif type(data.flags) == "number" then
        -- Legacy numeric flags support (bit 0=looping, bit 1=3d, bit 2=stop, bit 3=music)
        local f = data.flags
        self.flags = {
            raw = f,
            looping = (f % 2) == 1,
            sound_3d = (math.floor(f / 2) % 2) == 1,
            stop_out_range = (math.floor(f / 4) % 2) == 1,
            music = (math.floor(f / 8) % 2) == 1,
        }
    else
        self.flags = {
            raw = 0,
            looping = false,
            sound_3d = false,
            stop_out_range = false,
            music = false,
        }
    end

    -- Fade rates (in milliseconds)
    self.fade_in = data.fade_in or 10
    self.fade_out = data.fade_out or 10

    -- Volume and pitch
    -- -1 means use default (100% volume, 1.0 pitch)
    self.volume = data.volume or -1
    self.pitch = data.pitch or 1.0

    -- Channel
    self.channel = data.channel or 0
    self.channel_name = data.channel_name

    -- 3D distance parameters (defensive copy)
    if data.distance then
        self.distance = {
            min = data.distance.min or 0,
            max = data.distance.max or 10000,
            cutoff = data.distance.cutoff or 3000,
        }
    else
        self.distance = { min = 0, max = 10000, cutoff = 3000 }
    end

    -- Cone parameters (defensive copy)
    if data.cone then
        self.cone = {
            inside_angle = data.cone.inside_angle or 0,
            outside_angle = data.cone.outside_angle or 0,
            outside_volume = data.cone.outside_volume or 0,
        }
        if data.cone.orientation then
            self.cone.orientation = {
                x = data.cone.orientation.x or 0,
                y = data.cone.orientation.y or 0,
                z = data.cone.orientation.z or 0,
            }
        end
    else
        self.cone = { inside_angle = 0, outside_angle = 0, outside_volume = 0 }
    end

    -- Reforged (v3) fields
    self.label = data.label
    self.asset_path = data.asset_path

    return self
end
-- }}}

-- {{{ is_looping
-- Check if this sound loops continuously.
-- @return boolean
function Sound:is_looping()
    return self.flags.looping == true
end
-- }}}

-- {{{ is_3d
-- Check if this is a 3D positional sound.
-- @return boolean
function Sound:is_3d()
    return self.flags.sound_3d == true
end
-- }}}

-- {{{ is_music
-- Check if this is a music track.
-- @return boolean
function Sound:is_music()
    return self.flags.music == true
end
-- }}}

-- {{{ stops_out_of_range
-- Check if this sound stops when listener is out of range.
-- @return boolean
function Sound:stops_out_of_range()
    return self.flags.stop_out_range == true
end
-- }}}

-- {{{ get_effective_volume
-- Get the effective volume (0-100 scale).
-- Returns 100 if volume is -1 (default).
-- @return number
function Sound:get_effective_volume()
    if self.volume < 0 then
        return 100
    end
    return self.volume
end
-- }}}

-- {{{ get_effective_pitch
-- Get the effective pitch multiplier.
-- Returns 1.0 if pitch is -1 (default).
-- @return number
function Sound:get_effective_pitch()
    if self.pitch < 0 then
        return 1.0
    end
    return self.pitch
end
-- }}}

-- {{{ get_min_distance
-- Get the minimum distance for 3D sound (full volume inside this radius).
-- @return number
function Sound:get_min_distance()
    return self.distance.min
end
-- }}}

-- {{{ get_max_distance
-- Get the maximum distance for 3D sound (inaudible beyond this).
-- @return number
function Sound:get_max_distance()
    return self.distance.max
end
-- }}}

-- {{{ get_cutoff_distance
-- Get the sharp cutoff distance for 3D sound.
-- @return number
function Sound:get_cutoff_distance()
    return self.distance.cutoff
end
-- }}}

-- {{{ get_fade_in
-- Get the fade-in rate in milliseconds.
-- @return number
function Sound:get_fade_in()
    return self.fade_in
end
-- }}}

-- {{{ get_fade_out
-- Get the fade-out rate in milliseconds.
-- @return number
function Sound:get_fade_out()
    return self.fade_out
end
-- }}}

-- {{{ get_channel
-- Get the sound channel number and name.
-- @return number, string
function Sound:get_channel()
    return self.channel, self.channel_name
end
-- }}}

-- {{{ has_cone
-- Check if this sound has directional cone parameters set.
-- @return boolean
function Sound:has_cone()
    return self.cone and (
        self.cone.inside_angle ~= 0 or
        self.cone.outside_angle ~= 0
    )
end
-- }}}

-- {{{ __tostring
function Sound:__tostring()
    local flags = {}
    if self:is_looping() then flags[#flags + 1] = "loop" end
    if self:is_3d() then flags[#flags + 1] = "3D" end
    if self:is_music() then flags[#flags + 1] = "music" end

    local flag_str = ""
    if #flags > 0 then
        flag_str = " [" .. table.concat(flags, ",") .. "]"
    end

    local vol_str = ""
    local vol = self:get_effective_volume()
    if vol ~= 100 then
        vol_str = string.format(" vol=%d", vol)
    end

    return string.format("Sound<%s%s%s>",
        self.name ~= "" and self.name or "unnamed",
        vol_str,
        flag_str)
end
-- }}}
-- }}}

return Sound
