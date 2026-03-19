# 902d - Track Following Physics

## Status: Open

## Parent Issue: 902 - Track Mover System

## Problem

Need physics for movers traveling along track segments, updating positions each frame.

## Movement Update

Each frame:
```c
void track_mover_update(TrackMover* mover, float delta_time) {
    TrackSegment* seg = &segments[mover->current_segment];

    // Advance position along segment
    float distance = mover->speed * delta_time;
    float segment_length = seg->length;
    float position_delta = distance / segment_length;

    mover->position_on_segment += position_delta * mover->direction;

    // Check for segment end
    if (mover->position_on_segment > 1.0f) {
        handle_segment_end(mover, seg, END_POINT);
    } else if (mover->position_on_segment < 0.0f) {
        handle_segment_end(mover, seg, START_POINT);
    }

    // Update payload positions
    Vector2 mover_pos = get_mover_world_position(mover);
    for (int i = 0; i < mover->payload_count; i++) {
        update_payload_position(mover, i, mover_pos);
    }
}
```

## Segment Transition

When mover reaches segment end:
1. Check for connected segments at that endpoint
2. If dead end: reverse direction (see 1306f)
3. If intersection: select next segment (see 1306e)
4. Transfer to new segment, adjust position

```c
void transition_to_segment(TrackMover* mover, int new_segment, int entry_end) {
    mover->current_segment = new_segment;

    // If entering at start, position = 0, direction = +1
    // If entering at end, position = 1, direction = -1
    if (entry_end == START_POINT) {
        mover->position_on_segment = 0.0f;
        mover->direction = 1;
    } else {
        mover->position_on_segment = 1.0f;
        mover->direction = -1;
    }
}
```

## Smooth Movement

- Position is parametric (0-1) for easy interpolation
- Convert to world coordinates for physics/rendering
- Payload follows without jerking

## Implementation Steps

1. Implement basic position update along segment
2. Implement segment end detection
3. Implement segment transition
4. Implement payload position updates
5. Test with simple track (single segment, back-forth)

## Files to Modify

- `src/0XX-track.c` - Movement update logic
- `src/001-main.c` - Call track_update in physics loop

## Notes

- Run track updates before ball physics
- Mover velocity affects ball collisions (like rotor)
- May need to handle very short segments specially
