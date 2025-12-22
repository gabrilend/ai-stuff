# Issue 206f: Implement Sound Class

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** Medium
**Dependencies:** 206a-create-gameobjects-module-structure, 205-parse-war3map-w3s
**Parent Issue:** 206-design-game-object-types

---

## Current Behavior

Sound parser (src/parsers/w3s.lua) returns plain tables. No Sound class exists
to provide flag interpretation or consistent API.

---

## Intended Behavior

A Sound class that wraps parsed sound data with:
- Sound property access
- Flag interpretation (looping, 3D, music)
- Effective value calculation (handling defaults)

```lua
local gameobjects = require("gameobjects")
local sound = gameobjects.Sound.new(parsed_sound)

print(sound.name)              -- "battle_music"
print(sound:is_looping())      -- true
print(sound:is_3d())           -- false
print(sound:get_effective_volume()) -- 100
```

---

## Suggested Implementation Steps

1. **Create Sound class**
   ```lua
   -- src/gameobjects/sound.lua
   local Sound = {}
   Sound.__index = Sound

   function Sound.new(parsed)
       return setmetatable({
           name = parsed.name,
           file = parsed.file,
           eax = parsed.eax,
           flags = parsed.flags or {},
           fade_in = parsed.fade_in,
           fade_out = parsed.fade_out,
           volume = parsed.volume,
           pitch = parsed.pitch,
           channel = parsed.channel,
           distance = parsed.distance or {},
           cone = parsed.cone or {},
       }, Sound)
   end
   ```

2. **Implement flag methods**
   ```lua
   function Sound:is_looping()
       return self.flags.looping == true
   end

   function Sound:is_3d()
       return self.flags.sound_3d == true
   end

   function Sound:is_music()
       return self.flags.music == true
   end

   function Sound:stops_out_of_range()
       return self.flags.stop_out_of_range == true
   end
   ```

3. **Implement effective value methods**
   ```lua
   function Sound:get_effective_volume()
       -- -1 means use default (100%)
       if self.volume < 0 then
           return 100
       end
       return self.volume
   end

   function Sound:get_effective_pitch()
       -- -1 means use default (1.0)
       if self.pitch < 0 then
           return 1.0
       end
       return self.pitch
   end

   function Sound:get_min_distance()
       return self.distance.min or 0
   end

   function Sound:get_max_distance()
       return self.distance.max or 10000
   end

   function Sound:get_cutoff_distance()
       return self.distance.cutoff or 3000
   end
   ```

4. **Add __tostring metamethod**
   ```lua
   function Sound:__tostring()
       local flags = {}
       if self:is_looping() then table.insert(flags, "loop") end
       if self:is_3d() then table.insert(flags, "3D") end
       if self:is_music() then table.insert(flags, "music") end
       local flag_str = #flags > 0 and " [" .. table.concat(flags, ",") .. "]" or ""
       return string.format("Sound<%s%s>", self.name or "unnamed", flag_str)
   end
   ```

5. **Update init.lua and create tests**

---

## Technical Notes

### Sound Flags

From w3s parser, flags is a table:
```lua
flags = {
    looping = true,
    sound_3d = true,
    stop_out_of_range = false,
    music = false,
}
```

### Default Values

WC3 uses -1 to indicate "use default":
- volume = -1 -> 100%
- pitch = -1 -> 1.0 (normal pitch)

### Distance Parameters

For 3D sounds:
```lua
distance = {
    min = 600.0,     -- Full volume inside this radius
    max = 10000.0,   -- Inaudible beyond this
    cutoff = 3000.0, -- Sharp cutoff distance
}
```

### Parser Output Fields

From src/parsers/w3s.lua:
```lua
{
    name = "battle_music",
    file = "Sound\\Music\\mp3Music\\War2IntroMusic.mp3",
    eax = "DefaultEAXON",
    flags = { looping = true, ... },
    fade_in = 10,
    fade_out = 10,
    volume = -1,     -- -1 = default
    pitch = -1,      -- -1 = default
    channel = 0,
    distance = { min, max, cutoff },
    cone = { inside_angle, outside_angle, outside_volume },
}
```

---

## Related Documents

- issues/205-parse-war3map-w3s.md (parser implementation)
- src/parsers/w3s.lua (input format)
- issues/206-design-game-object-types.md (parent)

---

## Acceptance Criteria

- [x] Sound class with constructor
- [x] is_looping() method
- [x] is_3d() method
- [x] is_music() method
- [x] stops_out_of_range() method
- [x] get_effective_volume() method
- [x] get_effective_pitch() method
- [x] get_min_distance() method
- [x] get_max_distance() method
- [x] get_cutoff_distance() method
- [x] __tostring metamethod
- [x] Unit tests for Sound class
- [x] init.lua exports Sound

---

## Notes

Sound is important for audio playback but relatively simple compared to
Unit or Region. The main complexity is handling the flags and default
values correctly.

---

## Implementation Notes

*Completed 2025-12-22*

### Constructor

The Sound.new() constructor copies all fields from parser output:
- Core: name, file, eax, eax_name
- Flags: supports both table format (parser output) and numeric format (legacy)
- Audio: volume (-1=default 100%), pitch (-1=default 1.0)
- Timing: fade_in, fade_out (in ms)
- Channel: channel number and channel_name
- 3D: distance {min, max, cutoff}
- Cone: cone {inside_angle, outside_angle, outside_volume}
- Reforged: label, asset_path

### Dual Flags Support

The constructor handles both formats:
- **Table format** (from parser): `{ looping=true, sound_3d=true, ... }`
- **Numeric format** (legacy): bits 0-3 for looping, 3d, stop_out_range, music

### Methods Implemented

| Method | Description |
|--------|-------------|
| `is_looping()` | Check if sound loops |
| `is_3d()` | Check if 3D positional sound |
| `is_music()` | Check if music track |
| `stops_out_of_range()` | Check if stops when out of range |
| `get_effective_volume()` | Volume (100 if -1) |
| `get_effective_pitch()` | Pitch (1.0 if -1) |
| `get_min_distance()` | Full volume radius |
| `get_max_distance()` | Inaudible radius |
| `get_cutoff_distance()` | Sharp cutoff distance |
| `get_fade_in()` | Fade-in rate in ms |
| `get_fade_out()` | Fade-out rate in ms |
| `get_channel()` | Returns number and name |
| `has_cone()` | Check if directional cone set |

### __tostring

Shows volume (if not 100%) and flag indicators:
- `Sound<battle_music>` - default volume, no flags
- `Sound<loop_sound [loop]>` - looping
- `Sound<music_3d [3D,music]>` - 3D and music
- `Sound<quiet vol=50>` - custom volume

### Tests Added

16 new tests added to test_gameobjects.lua (total now 259):
- Constructor with table flags
- Constructor with numeric flags (legacy)
- Default values when fields missing
- is_looping(), is_3d(), is_music(), stops_out_of_range()
- get_effective_volume() with -1 default
- get_effective_pitch() with -1 default
- get_min/max/cutoff_distance()
- get_fade_in(), get_fade_out()
- get_channel()
- has_cone()
- Distance table copied (no external mutation)
- __tostring shows flag indicators
