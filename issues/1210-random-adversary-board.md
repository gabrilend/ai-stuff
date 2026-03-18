# 1210 - Random Adversary Board Option

## Current Behavior

The adversary's board is always a mirror of the player's board. Both sides
play on identical layouts, just vertically flipped.

## Intended Behavior

Add a command-line flag to the run script (and eventually an in-game option)
that selects a random board for the adversary instead of mirroring the
player's board. This creates asymmetric gameplay where player and adversary
have different obstacles.

**Default behavior:** Mirrored (current behavior, symmetric)
**Optional behavior:** Random adversary board (asymmetric)

## Command Line Interface

```bash
# Default: mirrored boards (symmetric)
./run

# Random adversary board (asymmetric)
./run --random-adversary
```

## Suggested Implementation Steps

### Phase 1: Command Line Flag
1. Add `--random-adversary` flag to run script
2. Pass flag as argument to physics-sim binary
3. Parse argument in main.c

### Phase 2: Game Logic
4. On startup with flag, load different random board for adversary
5. Store board configuration per-player (player_board, adversary_board)
6. Update stage purchase to select from pool independently per side

### Phase 3: Future - Options Menu
7. Add toggle in options/settings menu
8. Persist setting to config file
9. Allow changing mid-session or require restart

## Files to Modify

- `run` - Add --random-adversary flag parsing, pass to binary
- `src/001-main.c` - Parse command line args, initialize boards differently
- `src/004-world.h` - May need separate board references per player
- `src/013-adversary.c` - Load from different board source

## Related Issues

- 1209 - Random first board selection

## Notes

Asymmetric boards add strategic depth - players must adapt to their own
layout while the adversary deals with different challenges. This could
make the game significantly harder or easier depending on board luck.

Consider: should stage purchases also be independent? Or should both
sides still get the same stage when either purchases one?
