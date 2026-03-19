# 902e - Intersection Detection and Path Selection

## Status: Open

## Parent Issue: 902 - Track Mover System

## Problem

When a mover reaches a track intersection (junction), it needs to randomly select a valid path that continues roughly in its direction of travel (within 90° on each side).

## Intersection Definition

An intersection exists at a point where 3+ track segment endpoints meet. (2 segments meeting is just a corner, not an intersection for path selection purposes.)

## Approach Vector

The approach vector is the direction the mover was traveling when reaching the intersection:

```c
Vector2 get_approach_vector(TrackMover* mover, TrackSegment* seg) {
    float x1 = grid_to_pixel(seg->col1);
    float y1 = grid_to_pixel(seg->row1);
    float x2 = grid_to_pixel(seg->col2);
    float y2 = grid_to_pixel(seg->row2);

    Vector2 dir;
    if (mover->direction > 0) {
        dir = normalize(x2 - x1, y2 - y1);  // Moving toward end
    } else {
        dir = normalize(x1 - x2, y1 - y2);  // Moving toward start
    }
    return dir;
}
```

## Valid Path Selection

A path is valid if its direction is within 90° of the approach vector:

```c
int is_valid_path(Vector2 approach, Vector2 path_dir) {
    float dot = dot_product(approach, path_dir);
    return dot > 0;  // cos(90°) = 0, so dot > 0 means < 90°
}
```

## Precomputation

For performance, precompute valid paths at load time:

```c
void precompute_intersection_paths(TrackIntersection* inter) {
    for (int approach_seg = 0; approach_seg < inter->segment_count; approach_seg++) {
        // For each possible approach direction (entering this intersection)
        // Calculate which exit segments are valid

        Vector2 approach = get_segment_approach(approach_seg, inter);
        int* valid_exits = malloc(...);
        int valid_count = 0;

        for (int exit_seg = 0; exit_seg < inter->segment_count; exit_seg++) {
            if (exit_seg == approach_seg) continue;  // Can't go back same way

            Vector2 exit_dir = get_segment_exit(exit_seg, inter);
            if (is_valid_path(approach, exit_dir)) {
                valid_exits[valid_count++] = exit_seg;
            }
        }

        inter->approach_paths[approach_seg] = valid_exits;
        inter->approach_path_counts[approach_seg] = valid_count;
    }
}
```

## Random Selection

At runtime:
```c
int select_exit_path(TrackMover* mover, TrackIntersection* inter, int approach_seg) {
    int count = inter->approach_path_counts[approach_seg];
    if (count == 0) {
        return -1;  // Dead end, reverse
    }
    int choice = rand() % count;
    return inter->approach_paths[approach_seg][choice];
}
```

## Implementation Steps

1. Implement intersection detection from segment data
2. Calculate approach vectors for each segment at each intersection
3. Precompute valid exit paths
4. Implement random path selection at runtime
5. Handle edge cases (dead ends, 2-way junctions)

## Files to Modify

- `src/0XX-track.c` - Intersection detection, path selection
- `src/021-board-data.c` - Precomputation on load

## Notes

- 2-way junction (corner) always has 1 valid exit, no randomness needed
- Dead end (1 segment) causes reversal, handled by 1306f
- Cache is invalidated if track topology changes
