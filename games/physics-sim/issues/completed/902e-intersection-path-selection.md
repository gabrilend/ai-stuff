# 902e - Intersection Detection and Path Selection

## Status: Completed

## Parent Issue: 902 - Track Mover System

## Problem

When a mover reaches a track intersection (junction), it needs to randomly select a valid path that continues roughly in its direction of travel (within 90° on each side).

## Implementation

Updated `src/053-track-mover.c` with:

### Helper Functions

1. `find_intersection_at_point()` - Looks up intersection data at grid coordinates
2. `get_segment_direction()` - Gets normalized direction vector for a segment at an endpoint
3. `is_valid_exit_direction()` - Checks if exit direction is within 90° of approach (dot product > 0)
4. `select_intersection_exit()` - Collects valid exits with direction filtering, returns random choice

### Integration with handle_segment_transition

Modified segment transition logic:
1. Get endpoint coordinates when reaching segment end
2. Look up intersection at that point
3. If intersection exists (3+ segments meeting):
   - Use `select_intersection_exit()` for random path with direction filtering
   - If no valid exits (all >90° from approach), reverse direction
4. If simple 2-way junction: take the only connection (existing behavior)

### Direction Filtering (90° Rule)

```c
static int is_valid_exit_direction(float approach_dx, float approach_dy,
                                    float exit_dx, float exit_dy) {
    // Dot product > 0 means angle < 90°
    float dot = approach_dx * exit_dx + approach_dy * exit_dy;
    return dot > 0.0f;
}
```

This prevents sharp U-turns while allowing natural path continuation.

## Files Modified

- `src/052-track-mover.h` - Added intersection fields to TrackMoverManager
- `src/053-track-mover.c` - Added helper functions and updated handle_segment_transition

## Intersection Data

Uses precomputed `TrackIntersection` data from `board_data_compute_track_intersections()`:
- `col, row` - Grid position
- `segment_indices[]` - All segments meeting at this point
- `segment_count` - Number of segments (3+ for true intersection)

## Testing Notes

- 2-way junctions (corners) use direct connection, no randomness
- Intersections use direction filtering + random selection
- Dead ends still trigger reversal (handled by 902f)
- Random seed from `rand()` - could be seeded for reproducibility

## Related Issues

- 902d: Provides segment transition framework
- 902f: Back-and-forth motion handles dead ends
