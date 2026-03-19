# 901d - Connected Object Detection

## Status: Open

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
