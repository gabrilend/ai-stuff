# 1216 - JSON Board Overwritten on Window Resize

## Status: COMPLETE

## Problem

When the game started, a random board was loaded from the `boards/` directory via the stage pool. However, immediately after startup, the window was resized from 800x600 to 800x[90% monitor height] via `SetWindowSize()`. This triggered `IsWindowResized()` to return true on the first frame, causing the resize handler to regenerate pegs programmatically, overwriting the JSON-loaded board data.

Additionally, lines (ramps) from JSON boards were not being applied to the initial world state.

## Solution

1. **Removed all programmatic peg generation** - JSON boards are now the only source of peg/ramp layouts
2. **Simplified resize handler** - Only regenerates dynamic elements (zones, bumpers), preserves JSON board data
3. **Added ramp support** - Lines from JSON boards are now converted to Ramp objects

## Implementation

### Changes to `src/001-main.c`

1. Removed `--random-adversary` command line flag and parsing
2. Rewrote board loading to require JSON (fails if no boards in `boards/`)
3. Updated `apply_initial_board_data()` to process OBJECT_LINE types into world->ramps
4. Updated `apply_adversary_board_data()` similarly for adversary ramps
5. Simplified resize handler to only regenerate zones/bumpers
6. Added ramp rendering calls to main loop

### Changes to `src/004-world.h`

- Added `Ramp* ramps` and `int ramp_count` fields to World struct
- Added `Ramp* adversary_ramps` and `int adversary_ramp_count` fields
- Added forward declaration for Ramp struct
- Added `world_render_ramps()` and `world_render_adversary_ramps()` function declarations

### Changes to `src/005-world.c`

- Added `#include "016-ramp.h"`
- Initialize ramp fields in `world_create()`
- Free ramp arrays in `world_destroy()`
- Implemented `world_render_ramps()` and `world_render_adversary_ramps()`

### Changes to `run` script

- Removed `--random-adversary` flag handling
- Simplified to just run the binary

## Files Modified

- `src/001-main.c`
- `src/004-world.h`
- `src/005-world.c`
- `run`

## Related Issues

- 1209 - Random first board selection
- 1215 - Random board selection not working (run script fix)
