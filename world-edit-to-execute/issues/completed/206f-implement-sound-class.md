# Issue 206f: Implement Sound Class

**Phase:** 2 - Data Model
**Type:** Implementation
**Priority:** High
**Dependencies:** 206a (module structure), 205 (sounds parser for input format)
**Parent:** 206-design-game-object-types.md

---

## Current Behavior

The Sound class is fully implemented in `src/gameobjects/sound.lua` with comprehensive
test coverage in `src/tests/test_gameobjects.lua`.

---

## Intended Behavior

Implement the Sound class for sound definitions and ambient loops from war3map.w3s
parser output. The class should wrap parsed sound data with methods for audio
property queries.

---

## Suggested Implementation Steps

1. Create `src/gameobjects/sound.lua` with Sound class
2. Constructor from parsed sound data
3. Methods: `is_looping()`, `is_3d()`, `is_music()`, `get_effective_volume()`
4. Unit tests for Sound class

---

## Acceptance Criteria

- [x] Sound class created with metatable
- [x] Constructor accepts w3s parser output
- [x] `is_looping()` - checks looping flag
- [x] `is_3d()` - checks 3D positional flag
- [x] `is_music()` - checks music flag
- [x] `stops_out_of_range()` - checks stop-out-of-range flag
- [x] `get_effective_volume()` - returns volume (100 if -1)
- [x] `get_effective_pitch()` - returns pitch (1.0 if -1)
- [x] Distance methods: `get_min_distance()`, `get_max_distance()`, `get_cutoff_distance()`
- [x] Fade methods: `get_fade_in()`, `get_fade_out()`
- [x] `get_channel()` - returns channel number and name
- [x] `has_cone()` - checks for directional cone parameters
- [x] `__tostring()` metamethod for debugging
- [x] Defensive copying of nested tables (distance, cone, flags)
- [x] Support for both table and numeric (legacy) flag formats
- [x] Unit tests covering all methods

---

## Implementation Notes

*Completed 2025-12-26*

The Sound class was implemented with all required functionality:

### File: `src/gameobjects/sound.lua`

**Constructor** (`Sound.new(data)`):
- Copies all fields from w3s parser output
- Handles both table flags (preferred) and numeric flags (legacy bitmask)
- Defensive copies of nested tables (distance, cone, flags)
- Sensible defaults for missing fields

**Flag Methods**:
- `is_looping()` - continuous playback
- `is_3d()` - positional audio
- `is_music()` - music track
- `stops_out_of_range()` - stops when listener exits range

**Volume/Pitch**:
- `get_effective_volume()` - returns 100 when volume is -1 (default)
- `get_effective_pitch()` - returns 1.0 when pitch is -1 (default)

**3D Audio**:
- `get_min_distance()` - full volume inside this radius
- `get_max_distance()` - inaudible beyond this
- `get_cutoff_distance()` - sharp cutoff distance
- `has_cone()` - checks if directional cone is configured

**Fade Rates**:
- `get_fade_in()` - fade-in rate in milliseconds
- `get_fade_out()` - fade-out rate in milliseconds

**Channel**:
- `get_channel()` - returns channel number and friendly name

**Reforged Support**:
- `label`, `asset_path` fields for v3 format

### Test Coverage

22 tests in `src/tests/test_gameobjects.lua` covering:
- Constructor with table and numeric flags
- Default values
- All flag accessor methods
- Volume/pitch with -1 defaults
- Distance methods
- Fade methods
- Channel method
- Cone detection
- Defensive copying
- `__tostring()` output

All 259 tests in the gameobjects test suite pass.

---

## Related Documents

- issues/206-design-game-object-types.md (parent issue)
- issues/205-parse-war3map-w3s.md (parser input format)
- src/parsers/w3s.lua (parser implementation)
- src/gameobjects/sound.lua (this implementation)
- src/tests/test_gameobjects.lua (tests)
