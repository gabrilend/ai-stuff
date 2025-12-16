# Issue 204: Parse war3map.w3c (Cameras)

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** Medium
**Dependencies:** 102-implement-mpq-archive-parser

---

## Current Behavior

Cannot read camera preset definitions. Cinematic cameras, gameplay cameras,
and camera bounds are inaccessible for rendering and scripting.

---

## Intended Behavior

A parser that extracts all camera definitions from war3map.w3c:
- Camera names
- Target positions
- Camera angles (rotation, AOA, roll)
- Distance and field of view
- Clipping planes

---

## Suggested Implementation Steps

1. **Create parser module**
   ```
   src/parsers/
   └── w3c.lua          (this issue)
   ```

2. **Implement header parsing**
   ```lua
   -- war3map.w3c header structure:
   -- Offset  Type      Description
   -- 0x00    int32     File version (0 for original)
   -- 0x04    int32     Number of cameras
   ```

3. **Implement camera entry parsing (pre-1.31)**
   ```lua
   -- Each camera entry (variable size):
   -- float:   Target X coordinate
   -- float:   Target Y coordinate
   -- float:   Z offset (height above target)
   -- float:   Rotation (degrees, 0 = north, clockwise)
   -- float:   Angle of Attack (degrees, 0 = horizontal)
   -- float:   Distance from target
   -- float:   Roll (degrees)
   -- float:   Field of View (degrees, default 70)
   -- float:   Far clipping plane
   -- float:   Near clipping plane (100.0 default placeholder)
   -- string:  Camera name (null-terminated)
   ```

4. **Implement camera entry parsing (1.31+)**
   ```lua
   -- Extended format adds local rotations after name:
   -- float:   Local pitch (degrees)
   -- float:   Local yaw (degrees)
   -- float:   Local roll (degrees)
   ```

5. **Detect version from war3map.w3i**
   ```lua
   -- Check editor version in w3i to determine format:
   -- < 1.31: Standard format (no local rotations)
   -- >= 1.31: Extended format with local rotations
   ```

6. **Return structured data**
   ```lua
   return {
       version = 0,
       cameras = {
           {
               name = "gg_cam_Camera_001",
               target = { x = 0.0, y = 0.0 },
               z_offset = 1650.0,
               rotation = 90.0,       -- Degrees
               aoa = 304.0,           -- Angle of attack
               distance = 1650.0,
               roll = 0.0,
               fov = 70.0,
               far_clip = 5000.0,
               near_clip = 100.0,
               -- 1.31+ only:
               local_pitch = 0.0,
               local_yaw = 0.0,
               local_roll = 0.0,
           },
           -- ...
       },
   }
   ```

---

## Technical Notes

### Camera Coordinate System

- Target X/Y: World coordinates (same as units/regions)
- Z offset: Height above the target point
- Rotation: 0 = camera facing north, increases clockwise
- AOA: Angle downward from horizontal (90 = looking straight down)
- Distance: Distance from camera to target point

### Default Camera Values

```lua
local CAMERA_DEFAULTS = {
    z_offset = 0.0,
    rotation = 90.0,
    aoa = 304.0,      -- Typical RTS camera angle
    distance = 1650.0,
    roll = 0.0,
    fov = 70.0,
    far_clip = 5000.0,
    near_clip = 100.0,
}
```

### Camera Naming Convention

Editor-generated cameras follow pattern: `gg_cam_<name>`

### Version Detection Problem

Blizzard did not update the file version when adding local rotations in 1.31.
This means we must check the editor version from war3map.w3i to correctly
parse the format. Maps saved in 1.31+ will have 12 extra bytes per camera.

### Usage in Scripts

Cameras are typically used for:
- Cinematic sequences (`SetCameraTargetController`, `SetCameraPosition`)
- Gameplay camera presets
- Map intro/outro sequences

---

## Related Documents

- docs/formats/w3c-cameras.md (to be created)
- issues/102-implement-mpq-archive-parser.md (provides file access)
- issues/103-parse-war3map-w3i.md (provides editor version for format detection)

---

## Acceptance Criteria

- [ ] Can parse war3map.w3c from all test archives
- [ ] Correctly extracts camera names
- [ ] Correctly extracts target positions
- [ ] Correctly extracts rotation, AOA, roll
- [ ] Correctly extracts distance and FOV
- [ ] Correctly extracts clipping planes
- [ ] Detects 1.31+ format and parses local rotations
- [ ] Returns structured Lua table
- [ ] Unit tests for parser

---

## Notes

Camera parsing is straightforward but has a version detection caveat.
Since Blizzard didn't update the file version in 1.31, we need to
check the editor version from w3i to know which format to expect.

A robust implementation might try to detect the format by checking
if the file size matches expected size for N cameras in either format.

Reference: [WC3MapSpecification](https://github.com/ChiefOfGxBxL/WC3MapSpecification)
Reference: [HIVE Forums](https://www.hiveworkshop.com/threads/parsing-old-new-war3map-w3c-files.328473/)
