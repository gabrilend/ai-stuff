# 1306f - Back-and-Forth Motion Logic

## Status: Open

## Parent Issue: 1306 - Track Mover System

## Problem

When a mover reaches a dead end (track endpoint with no other connections), it should reverse direction and travel back.

## Dead End Detection

A point is a dead end if:
- It's a segment endpoint
- Only 1 segment connects there

```c
int is_dead_end(TrackSegment* seg, int endpoint) {
    if (endpoint == START_POINT) {
        return seg->connections_start_count == 0;
    } else {
        return seg->connections_end_count == 0;
    }
}
```

## Reversal Logic

When mover reaches dead end:
```c
void handle_dead_end(TrackMover* mover) {
    // Reverse direction
    mover->direction *= -1;

    // Clamp position to valid range
    if (mover->position_on_segment > 1.0f) {
        mover->position_on_segment = 1.0f;
    } else if (mover->position_on_segment < 0.0f) {
        mover->position_on_segment = 0.0f;
    }

    // Optional: brief pause at end
    // mover->pause_timer = 0.2f;
}
```

## Motion State Machine

```
States:
- MOVING_FORWARD: position_on_segment increasing
- MOVING_BACKWARD: position_on_segment decreasing
- PAUSED: waiting at endpoint (optional)

Transitions:
- MOVING_FORWARD + reach_end -> PAUSED or MOVING_BACKWARD
- MOVING_BACKWARD + reach_start -> PAUSED or MOVING_FORWARD
- PAUSED + timer_expired -> opposite direction
```

## Optional: Pause at Endpoints

For more natural motion, mover can pause briefly at dead ends:
```c
typedef struct TrackMover {
    // ... existing fields ...
    float pause_timer;        // Time remaining in pause
    float pause_duration;     // Configurable pause time
} TrackMover;
```

## Track Network Behavior

On a complex track with intersections:
- Mover may never return to starting point (random path at each intersection)
- Creates unpredictable, interesting motion patterns
- Dead ends still cause reversal

## Implementation Steps

1. Implement dead end detection
2. Implement direction reversal
3. Integrate with segment transition logic
4. Optional: add pause at endpoints
5. Test with simple back-forth track
6. Test with complex network

## Files to Modify

- `src/0XX-track.c` - Dead end handling, reversal logic

## Notes

- Reversal is instant (no deceleration/acceleration)
- Could add easing for more polished feel (future enhancement)
- Pause duration could be configurable per-mover
