-- Camera Class
-- Represents cinematic and gameplay cameras from war3map.w3c.
-- Wraps parsed camera data with methods for position and rotation queries.
--
-- Implementation: 206e-implement-camera-class

-- {{{ Camera class
local Camera = {}
Camera.__index = Camera

-- {{{ new
-- Create a new Camera from parsed camera data.
-- @param data Table from w3c.parse() containing camera fields
-- @return Camera instance
function Camera.new(data)
    local self = setmetatable({}, Camera)
    -- TODO: Copy fields from data in 206e
    self.name = data.name
    self.target = data.target
    self.z_offset = data.z_offset
    self.rotation = data.rotation
    self.angle_of_attack = data.angle_of_attack
    self.distance = data.distance
    self.roll = data.roll
    self.fov = data.fov
    self.far_z = data.far_z
    -- 1.31+ fields
    self.local_pitch = data.local_pitch
    self.local_yaw = data.local_yaw
    self.local_roll = data.local_roll
    return self
end
-- }}}

-- {{{ Placeholder methods (implement in 206e)
function Camera:get_eye_position()
    -- TODO: Calculate eye position from target + rotation + distance
    -- This is a simplified placeholder
    if self.target then
        return {
            x = self.target.x,
            y = self.target.y,
            z = (self.target.z or 0) + (self.z_offset or 0),
        }
    end
    return { x = 0, y = 0, z = 0 }
end

function Camera:has_local_rotations()
    -- TODO: Check if 1.31+ local rotation fields are present
    return self.local_pitch ~= nil or self.local_yaw ~= nil or self.local_roll ~= nil
end
-- }}}

-- {{{ __tostring
function Camera:__tostring()
    return string.format("Camera<%s dist=%.0f fov=%.0f>",
        self.name or "?",
        self.distance or 0,
        self.fov or 70)
end
-- }}}
-- }}}

return Camera
