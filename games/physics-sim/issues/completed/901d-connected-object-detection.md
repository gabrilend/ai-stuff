# 901d - Connected Object Detection

## Status: Completed

## Parent Issue: 901 - Rotor System

## Problem

Need an algorithm to detect which objects are connected to a rotor and should rotate with it.

## Connection Definition

An object is connected to a rotor if:
1. It directly touches a line originating from the rotor center, OR
2. It touches another object that is connected (transitive)

## Algorithm

### Graph-Based Approach

```
function detect_connections(rotor):
    connected = set()
    queue = [rotor_center]

    while queue not empty:
        current = queue.pop()

        for each object in board:
            if object not in connected:
                if touches(current, object):
                    connected.add(object)
                    queue.append(object)

    return connected
```

### Touch Detection

- Peg touches line: Distance from peg center to line segment < peg_radius + threshold
- Line touches line: Line segments intersect or endpoints within threshold
- Peg touches peg: Distance between centers < sum of radii + threshold

### Relative Position Calculation

Once connected objects identified:
```c
for each connected object:
    dx = object.x - rotor.x
    dy = object.y - rotor.y
    object.relative_angle = atan2(dy, dx)
    object.relative_distance = sqrt(dx*dx + dy*dy)
```

## Implementation Steps

1. Implement touch detection functions for all object type pairs
2. Implement BFS/DFS graph traversal for connection detection
3. Calculate and store relative positions
4. Run detection on rotor creation and when objects modified
5. Invalidate connections when connected objects deleted

## Files to Modify

- `src/021-board-data.c` or `src/0XX-rotor.c` - Detection algorithm
- `src/020-board-data.h` - Connection storage

## Notes

- Use small threshold (1-2 pixels) to account for floating point
- Consider caching touch relationships for performance
- Lines have two endpoints - calculate relative position for both

## Implementation Complete

### Changes Made

Added touch detection helpers and BFS-based connection detection in `src/021-board-data.c`:

1. **`point_to_segment_distance_sq()`** - Squared distance from point to line segment
   - Projects point onto segment, clamped to endpoints
   - Used for peg-to-line distance checks

2. **`segments_intersect_or_close()`** - Check if two segments touch
   - Tests endpoint proximity to opposite segment
   - Tests actual segment intersection via cross product

3. **`objects_touch()`** - Unified touch test for any object pair
   - Handles PEG-PEG, PEG-LINE, LINE-PEG, LINE-LINE cases
   - Uses TOUCH_THRESHOLD (0.5 grid units)

4. **`object_touches_point()`** - Check if object touches a grid point
   - Used for initial seed from rotor center

5. **Rewrote `board_data_rotor_detect_connections()`**
   - Now uses BFS traversal instead of simple Manhattan distance
   - Seeds from objects touching rotor center
   - Transitively finds all connected objects
   - Calculates and stores relative angle/distance for each

### Algorithm Details

```
BFS Connection Detection:
1. Find all objects touching rotor center → add to queue
2. While queue not empty:
   a. Pop current object
   b. For each unvisited object:
      - If touches current → mark visited, add to queue, add connection
3. Return connection count
```

### Touch Threshold

- `TOUCH_THRESHOLD = 0.5f` grid units
- Objects must be within half a grid cell to be considered "touching"
- Allows for small gaps due to floating point or artistic placement

### Unblocks

- 901e (Collision modes) - can now identify which objects belong to rotors
