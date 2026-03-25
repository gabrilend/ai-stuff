# 823 - Random First Board Selection

## Status: COMPLETE

## Current Behavior

On game start, a random board is selected from the boards/ directory. Both
player and adversary boards use the same randomly selected layout. If no
boards are available or loading fails, falls back to programmatic generation.

## Implementation Details

### Changes to `src/001-main.c`

1. **Stage pool creation moved earlier** - Now created before peg generation
   to allow random board selection at startup

2. **Added helper functions:**
   - `apply_initial_board_data()` - Applies BoardData to world->pegs
   - `apply_adversary_board_data()` - Applies BoardData to world->adversary_pegs

3. **Random board selection flow:**
   - Create stage pool from boards/ directory
   - Select random board using `stage_pool_select_random()`
   - Load BoardData from selected path
   - Apply to player and adversary peg arrays
   - Fall back to `world_generate_pegs()` if any step fails

4. **Adversary board handling:**
   - Uses same BoardData as player
   - Positioned in adversary area (below zones)
   - Uses reddish color tint for visual distinction

### Code Flow

```
main()
  |
  +-> stage_pool_create()
  |
  +-> stage_pool_select_random()
  |
  +-> board_data_load_json()
  |
  +-> apply_initial_board_data() --or--> world_generate_pegs()
  |
  +-> apply_adversary_board_data() --or--> world_generate_adversary_pegs()
  |
  +-> board_data_destroy()
```

## Files Modified

- `src/001-main.c` - Added helper functions, modified initialization

## Related Issues

- 1207 - Generate default board on compile
- 1210 - Random adversary board option

## Notes

With only one board in boards/, the game will always start with that board.
Multiple boards enable variety - each startup picks randomly.

**Issue 1215 fix:** The run script was not changing to the project directory,
causing the relative `boards/` path to fail. Fixed by adding `cd "${DIR}"`
before executing the binary.
