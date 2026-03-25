# 902f - Back-and-Forth Motion Logic

## Status: Completed

## Parent Issue: 902 - Track Mover System

## Problem

When a mover reaches a dead end (track endpoint with no other connections), it should reverse direction and travel back.

## Implementation

Already implemented in 902d's `handle_segment_transition()`:

```c
if (connection_count == 0) {
    // Dead end - reverse direction (issue 902f behavior)
    mover->direction = -mover->direction;
    mover->position_on_segment = (endpoint == 1) ? 1.0f : 0.0f;
    return;
}
```

Also handles 902e case where no valid exits exist (all paths >90° from approach):

```c
if (next_segment < 0) {
    // No valid exits within 90° - reverse direction
    mover->direction = -mover->direction;
    mover->position_on_segment = (endpoint == 1) ? 1.0f : 0.0f;
    return;
}
```

## Dead End Detection

A point is a dead end if:
- It's a segment endpoint
- `connections_start_count == 0` or `connections_end_count == 0`

## Behavior

1. Mover reaches segment endpoint
2. Check connection count at that endpoint
3. If no connections: reverse direction, clamp position
4. Next frame: mover travels back along same segment

## Files

- `src/053-track-mover.c` - `handle_segment_transition()` function

## Testing Notes

- Reversal is instant (no pause or deceleration)
- Position clamped to 0.0 or 1.0 to prevent overshooting
- Works correctly with complex track networks
- 902e integration: also reverses when no valid directional exits

## Optional Enhancement (Not Implemented)

Pause at endpoints could be added:
```c
typedef struct MoverPhysics {
    float pause_timer;        // Time remaining in pause
    float pause_duration;     // Configurable pause time
} MoverPhysics;
```

This would create more natural motion but adds complexity.

## Related Issues

- 902d: Provides segment transition framework
- 902e: Uses reversal when no valid directional exits
