# 902d - Track Following Physics

## Status: Completed

## Parent Issue: 902 - Track Mover System

## Problem

Need physics for movers traveling along track segments, updating positions each frame.

## Implementation

Created track mover physics in `src/052-track-mover.h` and `src/053-track-mover.c`:

### Core Update Loop
```c
void track_mover_manager_update(TrackMoverManager* manager, float dt) {
    for each mover:
        // Advance position along segment
        float distance = mover->speed * dt;
        float seg_length = segment_get_length(segment, cell_size);
        mover->position_on_segment += (distance / seg_length) * mover->direction;

        // Handle segment boundaries
        if (position > 1.0) handle_segment_transition(END_POINT);
        if (position < 0.0) handle_segment_transition(START_POINT);

        // Update world position and payload
        interpolate_position(...);
        update_payload_positions(mover, world);
}
```

### Segment Transition
- `handle_segment_transition()` checks connectivity at endpoints
- Dead end: reverses direction (position clamped, direction *= -1)
- Connected segments: transitions to next segment
- Entry point determines initial position (0.0 or 1.0) and direction

### Position Calculation
- Parametric position (0.0 to 1.0) along segment
- `interpolate_position()` converts to world coordinates
- `segment_get_world_endpoints()` gets pixel coordinates from grid

### Integration
- Called in main loop after rotor updates, before ball physics
- Both player and adversary track mover managers updated
- Cleanup in shutdown sequence

## Files Modified

- `src/052-track-mover.h` - Created: MoverPhysics, TrackMoverManager structs
- `src/053-track-mover.c` - Created: update loop, segment transition, position calc
- `src/004-world.h` - Added track_mover_manager and adversary_track_mover_manager
- `src/005-world.c` - Initialize manager pointers to NULL
- `src/001-main.c`:
  - Include 052-track-mover.h
  - Create managers after board load (line 619-627)
  - Update managers in physics loop (line 1113-1120)
  - Destroy managers before world (line 1433-1442)
- `Makefile` - Added src/053-track-mover.c to GAME_SRCS

## Technical Notes

- Speed stored in pixels/second (converted from grid units/second at load)
- Segment length calculated from cell_size and grid coordinates
- Position overflow handled during transitions for smooth motion

## Unblocked Issues

- 902e (Intersection path selection) - needs 902d for segment transitions
- 902f (Back and forth motion) - needs 902d for direction reversal
- 902g (Track ball interaction) - needs 902d for mover velocity

## Remaining Work (Future Issues)

- `entry_end` variable currently unused (for complex intersection handling)
- `collision_x/y` parameters reserved for accurate velocity at collision point
