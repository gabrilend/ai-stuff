# 824 - Random Adversary Board Option

## Status: COMPLETE

## Current Behavior

The adversary can now have a different board layout than the player using
the `--random-adversary` command line flag:

```bash
# Default: mirrored boards (symmetric)
./run

# Random adversary board (asymmetric)
./run --random-adversary
```

## Implementation Details

### Run Script (`run`)

Added `--random-adversary` flag parsing:
```bash
--random-adversary)
    GAME_FLAGS="--random-adversary"
    shift
    ;;
```

Flag is passed to the physics-sim binary when invoking.

### Main.c Changes

1. **Argument parsing:** Added command line argument handling with argc/argv
   ```c
   int main(int argc, char* argv[]) {
       int random_adversary_board = 0;
       for (int i = 1; i < argc; i++) {
           if (strcmp(argv[i], "--random-adversary") == 0) {
               random_adversary_board = 1;
           }
       }
   }
   ```

2. **Board selection logic:**
   - When flag is set: select different random board for adversary from pool
   - When flag not set: use same board as player (mirrored behavior)
   - Proper memory management to avoid double-free

3. **Fallback behavior:**
   - If flag set but no boards in pool: uses player's board (mirrors)
   - If flag set but adversary board load fails: uses player's board
   - If no boards available: uses programmatic generation for both

## Files Modified

- `run` - Added --random-adversary flag
- `src/001-main.c` - Added argument parsing and separate adversary board selection

## Related Issues

- 1209 - Random first board selection (foundation for this feature)

## Future Work (Phase 3 - Options Menu)

The issue originally planned for an in-game options menu toggle. This would:
- Add toggle in options/settings menu
- Persist setting to config file
- Allow changing mid-session or require restart

This was deferred as it requires additional UI infrastructure.

## Notes

With only one board in boards/, this flag has no effect (same board selected).
Adding multiple boards to boards/ enables asymmetric gameplay where player
and adversary face different obstacles.
