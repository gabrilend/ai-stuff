# 902c - Mover Placement and Payload Detection

## Status: Completed

## Parent Issue: 902 - Track Mover System

## Problem

Need to detect which objects are connected to a mover and should travel with it along the track.

## Payload Definition

Objects connected to a mover form its "payload" - they move with the mover but maintain their relative positions (no rotation, unlike rotors).

Connection rules (same as rotor):
1. Object directly touches the mover origin point, OR
2. Object touches another object that is connected (transitive)

## Implementation

Created `src/052-track-mover.h` and `src/053-track-mover.c` with:

### MoverPayload Structure
Stores payload items with geometry data for runtime independence:
```c
typedef struct MoverPayload {
    int object_index;       // Index into board objects array
    ObjectType object_type; // Type of object (PEG or LINE)
    float offset_x;         // X offset from mover position
    float offset_y;         // Y offset from mover position
    float line_half_dx;     // Line half dimensions for reconstruction
    float line_half_dy;
} MoverPayload;
```

### Payload Detection (BFS Algorithm)
- `detect_payload_bfs()` finds connected objects using breadth-first search
- `point_touches_object()` checks proximity (tolerance = 1.1 cell widths)
- Stores line geometry (half_dx, half_dy) at detection time
- No BoardData needed at runtime

### Position Updates
- `update_payload_positions()` moves payload with mover each frame
- Lines reconstructed from stored midpoint offset + half dimensions
- Pegs use simple offset addition

## Files Modified

- `src/052-track-mover.h` - Created: MoverPayload, MoverPhysics, TrackMoverManager
- `src/053-track-mover.c` - Created: payload detection, position updates
- `src/004-world.h` - Added TrackMoverManager fields
- `src/005-world.c` - Initialize manager fields
- `src/001-main.c` - Create/update/destroy managers
- `Makefile` - Added 053-track-mover.c to GAME_SRCS

## Testing Notes

- Payload detection runs at board load time
- World line/peg positions update each frame
- Stored geometry ensures no BoardData dependency at runtime

## Related Issues

- 902d: Uses payload positions for track following
- 901c: Similar rotor connection detection (uses polar coordinates instead)
