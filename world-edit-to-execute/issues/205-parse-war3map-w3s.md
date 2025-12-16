# Issue 205: Parse war3map.w3s (Sounds)

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** Medium
**Dependencies:** 102-implement-mpq-archive-parser

---

## Current Behavior

Cannot read sound definitions. Map-specific sounds, ambient loops, and
sound configuration are inaccessible for audio playback.

---

## Intended Behavior

A parser that extracts all sound definitions from war3map.w3s:
- Sound variable names
- Sound file paths
- EAX effect settings
- Volume, pitch, and channel
- 3D positioning parameters
- Distance and cone settings

---

## Suggested Implementation Steps

1. **Create parser module**
   ```
   src/parsers/
   └── w3s.lua          (this issue)
   ```

2. **Implement header parsing**
   ```lua
   -- war3map.w3s header structure:
   -- Offset  Type      Description
   -- 0x00    int32     File version (1 for TFT, 3 for Reforged)
   -- 0x04    int32     Number of sounds
   ```

3. **Implement sound entry parsing (version 1)**
   ```lua
   -- Each sound entry (variable size):
   -- string:  Variable name (e.g., "gg_snd_HumanGlueScreenLoop1")
   -- string:  File path (e.g., "Sound\Ambient\HumanGlueScreenLoop1.wav")
   -- string:  EAX effect (e.g., "DefaultEAXON")
   -- int32:   Flags (see below)
   -- int32:   Fade in rate (ms)
   -- int32:   Fade out rate (ms)
   -- int32:   Volume (-1 = default)
   -- float:   Pitch (1.0 = normal)
   -- float:   Unknown (usually 0)
   -- int32:   Channel (see below)
   -- float:   Minimum distance (3D cutoff)
   -- float:   Maximum distance (3D cutoff)
   -- float:   Distance cutoff
   -- float:   Cone inside angle
   -- float:   Cone outside angle
   -- int32:   Cone outside volume
   -- float:   Cone orientation X
   -- float:   Cone orientation Y
   -- float:   Cone orientation Z
   ```

4. **Parse flags**
   ```lua
   local SOUND_FLAGS = {
       LOOPING        = 0x00000001,
       SOUND_3D       = 0x00000002,
       STOP_OUT_RANGE = 0x00000004,
       MUSIC          = 0x00000008,
   }
   ```

5. **Parse channel**
   ```lua
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
   ```

6. **Parse EAX effects**
   ```lua
   local EAX_EFFECTS = {
       ["DefaultEAXON"]     = "Default",
       ["CombatSoundsEAX"]  = "Combat",
       ["KotoDrumsEAX"]     = "Drums",
       ["SpellsEAX"]        = "Spells",
       ["MissilesEAX"]      = "Missiles",
       ["HeroAcksEAX"]      = "Hero Speech",
       ["DoodadsEAX"]       = "Doodads",
   }
   ```

7. **Implement version 3 parsing (Reforged)**
   ```lua
   -- Version 3 adds:
   -- string:  Sound label
   -- string:  Base master sound entry label
   -- string:  Asset entry file path
   -- int32:   Dialogue ID
   -- string:  Production comments
   -- int32:   Speaker name ID
   -- string:  Listener name
   -- int32:   Instance flags (0x01=CONVERSATION, 0x02=HD_ONLY, 0x04=SD_ONLY)
   ```

8. **Return structured data**
   ```lua
   return {
       version = 1,
       sounds = {
           {
               name = "gg_snd_RainLoop",
               file = "Sound\\Ambient\\RainLoop.wav",
               eax = "DefaultEAXON",
               flags = {
                   looping = true,
                   sound_3d = false,
                   stop_out_range = false,
                   music = false,
               },
               fade_in = 10,
               fade_out = 10,
               volume = -1,
               pitch = 1.0,
               channel = 10,  -- Looping Ambient
               distance = {
                   min = 0.0,
                   max = 10000.0,
                   cutoff = 3000.0,
               },
               cone = {
                   inside_angle = 0.0,
                   outside_angle = 0.0,
                   outside_volume = 127,
                   orientation = { x = 0.0, y = 0.0, z = 0.0 },
               },
           },
           -- ...
       },
   }
   ```

---

## Technical Notes

### Sound File Paths

Paths use backslash separators and reference either:
- Internal WC3 sounds: `Sound\Ambient\*.wav`
- Imported sounds: `war3mapImported\*.wav`

### Naming Convention

Editor-generated sounds follow pattern: `gg_snd_<name>`

### 3D Sound Parameters

For 3D positional audio:
- Min distance: Full volume within this range
- Max distance: Sound audible up to this range
- Distance cutoff: Sound completely stops beyond this
- Cone: Directional audio (usually unused for ambient)

### Region Ambient Sounds

Regions (w3r) reference sounds by their variable name.
The sound system must provide lookup by name.

### Default Values

```lua
local SOUND_DEFAULTS = {
    volume = -1,          -- Use file's native volume
    pitch = 1.0,          -- Normal pitch
    fade_in = 10,         -- 10ms fade
    fade_out = 10,
}
```

---

## Related Documents

- docs/formats/w3s-sounds.md (to be created)
- issues/102-implement-mpq-archive-parser.md (provides file access)
- issues/203-parse-war3map-w3r.md (regions reference sounds)

---

## Acceptance Criteria

- [ ] Can parse war3map.w3s from all test archives
- [ ] Correctly extracts sound variable names
- [ ] Correctly extracts file paths
- [ ] Correctly extracts EAX effects
- [ ] Correctly parses flags
- [ ] Correctly extracts volume and pitch
- [ ] Correctly extracts channel assignment
- [ ] Correctly extracts 3D distance parameters
- [ ] Correctly extracts cone parameters
- [ ] Handles version 3 (Reforged) format
- [ ] Returns structured Lua table
- [ ] Unit tests for parser

---

## Notes

The sound format has many parameters, most of which use default values
in typical maps. The cone parameters are rarely used in practice.

Sound playback implementation will come in later phases - this issue
focuses only on parsing the definition data.

Reference: [WC3MapSpecification](https://github.com/ChiefOfGxBxL/WC3MapSpecification)
Reference: [HiveWE Issue #61](https://github.com/stijnherfst/HiveWE/issues/61)
