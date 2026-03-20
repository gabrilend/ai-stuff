# 902g - Track Mover Ball Interaction and Crushing

## Status: Completed

## Parent Issue: 902 - Track Mover System

## Problem

Mover payload objects need to interact with balls, including pushing them and crushing them when trapped.

## Solution

Implemented velocity transfer and crushing mechanics by:
1. Adding `mover_index` field to BoardObject for tracking mover attachment
2. Creating `board_data_compute_mover_payload()` to detect and mark mover-connected objects
3. Setting `is_dynamic = 1` on payload objects (lines/pegs connected to movers)
4. Adding velocity transfer in `ball_collide_with_line()` using existing `track_mover_get_line_velocity()`
5. Crushing already works via existing `ball_accumulate_dynamic_stress()` from issue 901f

## Implementation Details

### BoardObject Extension
- Added `mover_index` field (-1 if not connected, mover index if connected)
- Initialized to -1 in `board_data_add_peg_ex()` and `board_data_add_line_ex()`

### Payload Detection (board_data_compute_mover_payload)
- Uses BFS algorithm same as rotor connection detection
- Finds objects touching mover position and transitively connected objects
- Sets `is_dynamic = 1` and `mover_index = m` on connected objects
- Skips objects already connected to rotors (rotor takes priority)
- Called during board loading after track connectivity computation

### Velocity Transfer
- Modified `ball_collide_with_line()` to take World* and line_index parameters
- When `line->is_dynamic`, queries both rotor and mover managers for velocity
- Uses `DYNAMIC_LINE_PUSH_FACTOR = 0.5f` to scale velocity transfer
- Adds line velocity to ball after normal collision response

### Crushing
- Already implemented via issue 901f's dynamic stress system
- `ball_accumulate_dynamic_stress()` called when `line->is_dynamic`
- Ball crushed when `dynamic_stress > CRUSH_THRESHOLD`

## Files Modified

- `src/020-board-data.h` - Added `mover_index` field to BoardObject, declared compute function
- `src/021-board-data.c` - Implemented `board_data_compute_mover_payload()`, initialize mover_index
- `src/007-ball.c` - Added rotor/mover headers, modified `ball_collide_with_line()` for velocity transfer

## Testing

- Compilation successful
- Velocity transfer: balls pushed in mover travel direction on collision
- Crushing: balls trapped between mover payload and static objects accumulate stress

## Notes

- Shares collision mode logic with rotor system (both set `is_dynamic = 1`)
- Adversary mover support deferred (TODO comment in ball_collide_with_lines)
- Push factor can be tuned via `DYNAMIC_LINE_PUSH_FACTOR` constant
