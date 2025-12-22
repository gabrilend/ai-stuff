# Issue 206e: Implement Camera Class

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** Medium
**Dependencies:** 206a-create-gameobjects-module-structure, 204-parse-war3map-w3c
**Parent Issue:** 206-design-game-object-types

---

## Current Behavior

Camera parser (src/parsers/w3c.lua) returns plain tables. No Camera class exists
to provide eye position calculation or consistent API.

---

## Intended Behavior

A Camera class that wraps parsed camera data with:
- Camera parameter access
- Eye position calculation from target/angles
- 1.31+ local rotation support detection

```lua
local gameobjects = require("gameobjects")
local camera = gameobjects.Camera.new(parsed_camera)

print(camera.name)               -- "intro_cam"
print(camera:get_eye_position()) -- { x, y, z }
print(camera:has_local_rotations()) -- true/false
```

---

## Suggested Implementation Steps

1. **Create Camera class**
   ```lua
   -- src/gameobjects/camera.lua
   local Camera = {}
   Camera.__index = Camera

   function Camera.new(parsed)
       return setmetatable({
           name = parsed.name,
           target = {
               x = parsed.target.x,
               y = parsed.target.y,
           },
           z_offset = parsed.z_offset,
           rotation = parsed.rotation,     -- Degrees
           aoa = parsed.aoa,               -- Angle of attack (degrees)
           distance = parsed.distance,
           roll = parsed.roll,
           fov = parsed.fov,
           far_clip = parsed.far_clip,
           near_clip = parsed.near_clip,
           -- 1.31+ fields (nil for older formats)
           local_pitch = parsed.local_pitch,
           local_yaw = parsed.local_yaw,
           local_roll = parsed.local_roll,
       }, Camera)
   end
   ```

2. **Implement eye position calculation**
   ```lua
   function Camera:get_eye_position()
       -- Calculate camera eye position from target + angles
       -- Rotation is around Z axis, AoA is vertical angle
       local rad_rot = math.rad(self.rotation)
       local rad_aoa = math.rad(self.aoa)

       -- Distance projected onto horizontal plane
       local horizontal = self.distance * math.cos(rad_aoa)
       -- Vertical component
       local vertical = self.distance * math.sin(rad_aoa)

       return {
           x = self.target.x - horizontal * math.sin(rad_rot),
           y = self.target.y - horizontal * math.cos(rad_rot),
           z = self.z_offset + vertical,
       }
   end
   ```

3. **Implement accessor methods**
   ```lua
   function Camera:has_local_rotations()
       return self.local_pitch ~= nil
   end

   function Camera:get_target_position()
       return {
           x = self.target.x,
           y = self.target.y,
           z = self.z_offset,
       }
   end

   function Camera:get_fov_radians()
       return math.rad(self.fov)
   end
   ```

4. **Add __tostring metamethod**
   ```lua
   function Camera:__tostring()
       return string.format("Camera<%s dist=%.0f fov=%.0f>",
           self.name or "unnamed", self.distance, self.fov)
   end
   ```

5. **Update init.lua and create tests**

---

## Technical Notes

### Camera Coordinate System

WC3 cameras use:
- Target: The point the camera looks at (x, y on ground)
- Z offset: Height of target above ground
- Distance: How far camera is from target
- Rotation: Horizontal angle around target (degrees, 0 = North)
- AoA: Angle of attack / pitch (degrees, 0 = horizontal)
- Roll: Camera tilt (rarely used)

### Eye Position Math

```
horizontal_dist = distance * cos(aoa)
vertical_dist = distance * sin(aoa)

eye.x = target.x - horizontal_dist * sin(rotation)
eye.y = target.y - horizontal_dist * cos(rotation)
eye.z = z_offset + vertical_dist
```

### Parser Output Fields

From src/parsers/w3c.lua:
```lua
{
    name = "intro_cam",
    target = { x = 0.0, y = 0.0 },
    z_offset = 0.0,
    rotation = 90.0,
    aoa = 304.0,       -- Angle of attack
    distance = 1650.0,
    roll = 0.0,
    fov = 70.0,
    far_clip = 5000.0,
    near_clip = 100.0,
    -- 1.31+ only:
    local_pitch = 0.0,
    local_yaw = 0.0,
    local_roll = 0.0,
}
```

---

## Related Documents

- issues/204-parse-war3map-w3c.md (parser implementation)
- src/parsers/w3c.lua (input format)
- issues/206-design-game-object-types.md (parent)

---

## Acceptance Criteria

- [ ] Camera class with constructor
- [ ] get_eye_position() method with correct math
- [ ] get_target_position() method
- [ ] has_local_rotations() method
- [ ] get_fov_radians() method
- [ ] __tostring metamethod
- [ ] Unit tests for Camera class
- [ ] Test eye position calculation with known values
- [ ] init.lua exports Camera

---

## Notes

Camera is used for cinematics and gameplay camera positioning. The eye position
calculation is critical for rendering - must match WC3's camera math exactly.
Consider testing against known camera setups from real maps.
