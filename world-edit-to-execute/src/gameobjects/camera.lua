-- Camera Class
-- Represents cinematic and gameplay cameras from war3map.w3c.
-- Wraps parsed camera data with methods for position and rotation queries.
--
-- WC3 cameras use a target-based system:
-- - Target: Point the camera looks at (x, y on ground plane)
-- - Z offset: Height of target above ground
-- - Distance: How far camera is from target
-- - Rotation: Horizontal angle around target (0 = North, increases clockwise)
-- - AoA: Angle of attack / pitch (0 = horizontal, 90 = looking straight down)
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

    -- Core identification
    self.name = data.name or ""

    -- Target position (point camera looks at)
    -- Defensive copy to prevent external modification
    if data.target then
        self.target = {
            x = data.target.x or 0,
            y = data.target.y or 0,
        }
    else
        self.target = { x = 0, y = 0 }
    end

    -- Z offset: height of target above ground
    self.z_offset = data.z_offset or 0

    -- Camera orientation (all in degrees)
    self.rotation = data.rotation or 90      -- Horizontal angle (0 = North)
    self.aoa = data.aoa or 304               -- Angle of attack (vertical tilt)
    self.roll = data.roll or 0               -- Camera roll

    -- Camera distance from target
    self.distance = data.distance or 1650

    -- Field of view (degrees)
    self.fov = data.fov or 70

    -- Clipping planes
    self.far_clip = data.far_clip or 5000
    self.near_clip = data.near_clip or 100

    -- 1.31+ local rotation fields (nil for older formats)
    self.local_pitch = data.local_pitch
    self.local_yaw = data.local_yaw
    self.local_roll = data.local_roll

    return self
end
-- }}}

-- {{{ get_eye_position
-- Calculate the camera's eye (actual camera) position in world space.
-- Uses spherical coordinates relative to target point.
--
-- The camera is positioned at `distance` units from the target,
-- offset by rotation (horizontal angle) and aoa (vertical angle).
--
-- @return Table with x, y, z coordinates of camera position
function Camera:get_eye_position()
    -- Convert angles from degrees to radians
    local rad_rot = math.rad(self.rotation)
    local rad_aoa = math.rad(self.aoa)

    -- Distance projected onto horizontal plane
    -- cos(aoa) gives the horizontal component of the distance
    local horizontal = self.distance * math.cos(rad_aoa)

    -- Vertical component of distance
    -- sin(aoa) gives the vertical offset
    local vertical = self.distance * math.sin(rad_aoa)

    -- Calculate eye position:
    -- - sin(rotation) gives X offset (East-West)
    -- - cos(rotation) gives Y offset (North-South)
    -- WC3 uses: 0° = North, 90° = East (clockwise from North)
    return {
        x = self.target.x - horizontal * math.sin(rad_rot),
        y = self.target.y - horizontal * math.cos(rad_rot),
        z = self.z_offset + vertical,
    }
end
-- }}}

-- {{{ get_target_position
-- Get the target position (the point the camera looks at).
-- @return Table with x, y, z coordinates
function Camera:get_target_position()
    return {
        x = self.target.x,
        y = self.target.y,
        z = self.z_offset,
    }
end
-- }}}

-- {{{ has_local_rotations
-- Check if this camera uses 1.31+ extended format with local rotations.
-- @return true if local rotation fields are present
function Camera:has_local_rotations()
    return self.local_pitch ~= nil
end
-- }}}

-- {{{ get_fov_radians
-- Get the field of view in radians.
-- @return FOV in radians
function Camera:get_fov_radians()
    return math.rad(self.fov)
end
-- }}}

-- {{{ get_rotation_radians
-- Get the horizontal rotation angle in radians.
-- @return Rotation in radians
function Camera:get_rotation_radians()
    return math.rad(self.rotation)
end
-- }}}

-- {{{ get_aoa_radians
-- Get the angle of attack (vertical tilt) in radians.
-- @return AoA in radians
function Camera:get_aoa_radians()
    return math.rad(self.aoa)
end
-- }}}

-- {{{ get_look_direction
-- Get the normalized direction vector the camera is looking.
-- This is the direction from eye position toward target.
-- @return Table with x, y, z components (normalized)
function Camera:get_look_direction()
    local eye = self:get_eye_position()
    local target = self:get_target_position()

    -- Direction from eye to target
    local dx = target.x - eye.x
    local dy = target.y - eye.y
    local dz = target.z - eye.z

    -- Normalize
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length < 0.0001 then
        -- Avoid division by zero; return default forward direction
        return { x = 0, y = 1, z = 0 }
    end

    return {
        x = dx / length,
        y = dy / length,
        z = dz / length,
    }
end
-- }}}

-- {{{ __tostring
function Camera:__tostring()
    local suffix = self:has_local_rotations() and " [1.31+]" or ""
    return string.format("Camera<%s dist=%.0f fov=%.0f%s>",
        self.name ~= "" and self.name or "unnamed",
        self.distance,
        self.fov,
        suffix)
end
-- }}}
-- }}}

return Camera
