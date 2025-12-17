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

- [x] Can parse war3map.w3s from all test archives
- [x] Correctly extracts sound variable names
- [x] Correctly extracts file paths
- [x] Correctly extracts EAX effects
- [x] Correctly parses flags
- [x] Correctly extracts volume and pitch
- [x] Correctly extracts channel assignment
- [x] Correctly extracts 3D distance parameters
- [x] Correctly extracts cone parameters
- [x] Handles version 3 (Reforged) format
- [x] Returns structured Lua table
- [x] Unit tests for parser

---

## Notes

The sound format has many parameters, most of which use default values
in typical maps. The cone parameters are rarely used in practice.

Sound playback implementation will come in later phases - this issue
focuses only on parsing the definition data.

Reference: [WC3MapSpecification](https://github.com/ChiefOfGxBxL/WC3MapSpecification)
Reference: [HiveWE Issue #61](https://github.com/stijnherfst/HiveWE/issues/61)

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-16 05:36*

Looking at this issue, I'll analyze whether it benefits from splitting into sub-issues.

## Analysis

This issue covers parsing the `war3map.w3s` sound definition file. Let me evaluate the complexity:

**Factors suggesting it could be split:**
- Two distinct format versions (v1 classic, v3 Reforged)
- Multiple data structures (flags, channels, EAX effects, 3D params)
- 12 acceptance criteria

**Factors suggesting it should stay unified:**
- Single file format with straightforward sequential parsing
- Version differences are additive (v3 extends v1, doesn't replace it)
- All parsing happens in one pass through the file
- No complex interdependencies between parts
- Similar in scope to other completed parsers (w3r, w3c, doo files)

## Recommendation: Keep as Single Issue

This issue is **appropriately scoped** and does not benefit from splitting. Here's why:

1. **Sequential parsing pattern** - The file is read linearly: header → sound entries. Splitting would create artificial boundaries in what is naturally a single parse loop.

2. **Shared context** - The version number from the header determines parsing behavior throughout. Sub-issues would need to pass state around awkwardly.

3. **Comparable scope** - Looking at the related issues (201-204), they follow the same pattern and are implemented as single issues.

4. **Cohesive functionality** - Extracting flags, channels, EAX effects are all just field parsing within the same sound entry structure, not separate concerns.

5. **Testing efficiency** - A single test suite can validate the entire parser more effectively than testing fragmented pieces.

If this were to be split, the only reasonable boundary would be:
- 205a: Version 1 (classic) parsing
- 205b: Version 3 (Reforged) extensions

But even that split is suboptimal because:
- Version 3 parsing builds directly on version 1
- They share the same entry loop, just with conditional extra fields
- Testing requires both versions anyway

**Suggested approach:** Implement as-is, following the established pattern from the other Phase 2 parsers. The suggested implementation steps in the issue are already well-organized and can serve as internal checkpoints during development.

---

## Implementation Notes

*Completed 2025-12-16*

### Files Created

| File | Description |
|------|-------------|
| `src/parsers/w3s.lua` | Sound definitions parser module |
| `src/tests/test_w3s.lua` | Test suite with synthetic data |

### Implementation Details

1. **Parser module** (`src/parsers/w3s.lua`):
   - `w3s.parse(data)` - Parses binary w3s data, returns structured result
   - `w3s.format(result)` - Human-readable summary
   - `w3s.SoundTable` class with name lookup functionality
   - Version 1 (TFT) fully implemented
   - Version 3 (Reforged) extension parsing implemented
   - Uses `compat.lua` for LuaJIT/Lua 5.3+ compatibility

2. **Test suite** (`src/tests/test_w3s.lua`):
   - Uses synthetic binary data construction (test maps lack w3s files)
   - Tests: empty file, single sound, multiple sounds, flags, channels, EAX effects
   - Tests: SoundTable class, format output, invalid data handling
   - Real map test gracefully reports "no w3s" (expected for melee maps)

3. **Key findings**:
   - All 16 test maps are melee maps without custom sounds (no war3map.w3s)
   - Parser implementation based on WC3MapSpecification format docs
   - Synthetic test data validates all parsing paths

### API Example

```lua
local w3s = require("parsers.w3s")

-- Direct parsing
local result = w3s.parse(binary_data)
print(result.version)           -- 1 or 3
print(#result.sounds)           -- sound count

for i, sound in ipairs(result.sounds) do
    print(sound.name)           -- "gg_snd_RainLoop"
    print(sound.file)           -- "Sound\\Ambient\\RainLoop.wav"
    print(sound.flags.looping)  -- true/false
    print(sound.channel_name)   -- "Looping Ambient"
end

-- Using SoundTable class
local st = w3s.new(binary_data)
local sound = st:get("gg_snd_RainLoop")  -- lookup by name
print(st:count())                         -- total sounds
```

### Test Results

```
=== W3S Parser Tests ===
Testing empty file...                    PASS
Testing single sound entry...            PASS
Testing multiple sound entries...        PASS
Testing flag combinations...             PASS
Testing channel parsing...               PASS
Testing EAX effect parsing...            PASS
Testing SoundTable class...              PASS
Testing format output...                 PASS
Testing invalid data handling...         PASS
Testing against real map files...        0 passed, 0 failed, 16 no w3s
=== All tests completed ===
```
