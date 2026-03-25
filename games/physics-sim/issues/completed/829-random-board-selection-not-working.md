# 829 - Random Board Selection Not Working

## Current Behavior (Fixed)

When running the game via the `run` script, the random board selection from issue 1209 was not working. The game always loaded the default board instead of randomly selecting from available boards in `boards/`.

## Root Cause

The `run` script executed the game binary without first changing to the project directory:
```bash
"${DIR}/bin/physics-sim" ${GAME_FLAGS}
```

The stage pool code uses a relative path `"boards"` to scan for board files. When the game was run from a different working directory (e.g., the user's home directory), `opendir("boards")` would fail because `boards/` doesn't exist relative to that directory.

## Fix

Modified `run` script to change to the project directory before executing:
```bash
cd "${DIR}"
"${DIR}/bin/physics-sim" ${GAME_FLAGS}
```

This ensures the relative path `boards/` resolves correctly.

## Files Modified

- `run` - Added `cd "${DIR}"` before executing binary

## Related Issues

- 1209 - Random first board selection (original implementation)
- 1207 - Generate default board on compile

## Additional Fix

Also updated `scripts/compile` to use the canonical diamond-shaped peg layout with diagonal corner lines, matching the user's `boards/stage1-default.json`.

## Status

**Completed** - Random board selection now works correctly.
