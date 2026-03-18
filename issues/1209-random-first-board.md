# 1209 - Random First Board Selection

## Current Behavior

The game always loads `stage1-default.json` as the initial board for both
player and adversary. This means every game starts with the same layout.

## Intended Behavior

On game start, select a random board from the boards/ directory for the
initial stage. This provides variety in gameplay without requiring the
player to manually configure each session.

## Suggested Implementation Steps

1. On game initialization, scan boards/ directory for available JSON files
2. Select one at random using the existing stage pool mechanism
3. Load selected board as the initial stage
4. Ensure adversary mirrors the same board (current mirroring behavior)

## Considerations

- If boards/ is empty or only contains invalid files, fall back to
  generating a default programmatic board
- The stage pool already has random-without-repeat logic that could be
  reused or extended
- First board selection happens once at startup, not on each stage purchase

## Files to Modify

- `src/001-main.c` - Game initialization, initial board loading
- `src/027-stage-pool.c` - May need to expose random selection for startup

## Related Issues

- 1207 - Generate default board on compile
- 1210 - Random adversary board option

## Notes

This feature adds replay value by varying the starting conditions. Players
who want consistent starts can ensure only one board exists in boards/.
