-- Sound Class
-- Represents sound definitions and ambient loops from war3map.w3s.
-- Wraps parsed sound data with methods for audio property queries.
--
-- Implementation: 206f-implement-sound-class

-- {{{ Sound class
local Sound = {}
Sound.__index = Sound

-- {{{ new
-- Create a new Sound from parsed sound data.
-- @param data Table from w3s.parse() containing sound fields
-- @return Sound instance
function Sound.new(data)
    local self = setmetatable({}, Sound)
    -- TODO: Copy fields from data in 206f
    self.name = data.name
    self.file = data.file
    self.eax_effect = data.eax_effect
    self.flags = data.flags
    self.fade_in_rate = data.fade_in_rate
    self.fade_out_rate = data.fade_out_rate
    self.volume = data.volume
    self.pitch = data.pitch
    self.channel = data.channel
    self.min_distance = data.min_distance
    self.max_distance = data.max_distance
    self.distance_cutoff = data.distance_cutoff
    return self
end
-- }}}

-- {{{ Placeholder methods (implement in 206f)
function Sound:is_looping()
    -- TODO: Check looping flag
    if self.flags then
        -- Bit 0 is typically looping flag
        return (self.flags % 2) == 1
    end
    return false
end

function Sound:is_3d()
    -- TODO: Check 3D sound flag
    if self.flags then
        -- Bit 1 is typically 3D flag
        return (math.floor(self.flags / 2) % 2) == 1
    end
    return false
end

function Sound:is_music()
    -- TODO: Check if this is a music track
    -- Music typically uses channel 1 or has specific flags
    return self.channel == 1
end

function Sound:get_effective_volume()
    -- TODO: Return volume as 0-100 percentage
    return self.volume or 100
end
-- }}}

-- {{{ __tostring
function Sound:__tostring()
    local flags_str = ""
    if self:is_looping() then flags_str = flags_str .. " loop" end
    if self:is_3d() then flags_str = flags_str .. " 3D" end
    return string.format("Sound<%s vol=%d%s>",
        self.name or "?",
        self:get_effective_volume(),
        flags_str)
end
-- }}}
-- }}}

return Sound
