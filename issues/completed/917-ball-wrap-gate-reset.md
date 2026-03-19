# 1117 - Ball Wrap Gate Reset

**Status:** Complete

## Current Behavior

When a ball wraps from the bottom zone to the top zone (or vice versa), it does not trigger gates on its next pass through the scoring area. The ball appears to still have its "already passed through this gate" flag set from before the wrap.

This means:
- Ball passes through gate, triggers score (correct)
- Ball wraps to opposite side of board
- Ball passes through same gate again, does NOT trigger score (incorrect)

## Intended Behavior

When a ball wraps through a wrap zone, its gate-tracking state should be reset so it can trigger gates again. Each pass through the playfield should be treated as a fresh opportunity to score.

The ball should:
1. Pass through gate, trigger score
2. Wrap to opposite side
3. Pass through same gate again, trigger score again

## Root Cause Analysis

The ball likely has a `zone_triggered` or similar field that tracks which gates it has already triggered. This field persists across wraps, preventing re-triggering.

Looking at `007-ball.c` and the zone collision logic, the triggered state needs to be reset when a ball is teleported via wrap zone.

## Suggested Implementation Steps

### Step 1: Identify gate tracking field

Find where balls track which zones they've triggered:

```c
// In Ball struct or BallTaskData
int zone_triggered;  // or similar field
```

### Step 2: Reset on wrap

In `wrap_zones_check_ball()` or the wrap handling code, reset the gate tracking:

```c
// When ball is wrapped/teleported
ball->zone_triggered = -1;  // Reset to "no zone triggered"
```

### Step 3: Test

1. Launch game
2. Spawn ball, let it score through a gate
3. Let ball wrap to other side
4. Ball passes through same gate - should score again

## Files to Modify

- `src/007-ball.c` - Ball physics and zone collision
- `src/037-wrap-zones.c` - Wrap zone teleportation (add reset call)

## Related Issues

- 1116-dynamic-wrap-zones.md (implemented wrap zones)

## Notes

This is a regression from the wrap zone implementation. The wrap logic needs to consider gameplay state that should reset on teleportation, not just position.

## Resolution

Added `ball->passed_gate = 0;` in `wrap_zones_check_ball()` after teleporting both player and adversary balls. This resets the gate tracking state so balls can trigger gates again after wrapping.
