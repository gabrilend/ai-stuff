# 902c - Mover Placement and Payload Detection

## Status: Open

## Parent Issue: 902 - Track Mover System

## Problem

Need to detect which objects are connected to a mover and should travel with it along the track.

## Payload Definition

Objects connected to a mover form its "payload" - they move with the mover but maintain their relative positions (no rotation, unlike rotors).

Connection rules (same as rotor):
1. Object directly touches the mover origin point, OR
2. Object touches another object that is connected (transitive)

## Algorithm

Same BFS/DFS approach as rotor connections (issue 1305d):

```
function detect_payload(mover):
    connected = set()
    queue = [mover_position]

    while queue not empty:
        current = queue.pop()

        for each object in board:
            if object not in connected:
                if touches(current, object):
                    connected.add(object)
                    queue.append(object)

    return connected
```

## Relative Position Calculation

Unlike rotor (which uses angle/distance), mover uses simple offset:

```c
for each payload object:
    object.offset_x = object.x - mover.x
    object.offset_y = object.y - mover.y
```

When mover moves:
```c
object.x = mover.x + object.offset_x
object.y = mover.y + object.offset_y
```

## Mover Position on Track

```c
float get_mover_position(TrackMover* mover, TrackSegment* segment) {
    float x1 = grid_to_pixel_x(segment->col1);
    float y1 = grid_to_pixel_y(segment->row1);
    float x2 = grid_to_pixel_x(segment->col2);
    float y2 = grid_to_pixel_y(segment->row2);

    return (Vector2){
        x1 + (x2 - x1) * mover->position_on_segment,
        y1 + (y2 - y1) * mover->position_on_segment
    };
}
```

## Implementation Steps

1. Reuse touch detection from rotor system
2. Implement payload detection for movers
3. Store payload offsets (not angles like rotor)
4. Implement mover world position calculation
5. Update payload positions when mover moves

## Files to Modify

- `src/0XX-track.c` - Payload detection, position updates
- `src/020-board-data.h` - Payload storage in TrackMover

## Notes

- Can share touch detection code with rotor system
- Payload maintains orientation (no rotation)
- Consider extracting shared "connected object detection" utility
