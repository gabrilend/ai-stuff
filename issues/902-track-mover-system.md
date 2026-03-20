# 902 - Track Mover System

## Status: in-progress

## Depends on

None - can be implemented independently.

## Sub-Issue Dependencies

| ID   | Status        | Depends on      |
|------|---------------|-----------------|
| 902a | completed     | -               |
| 902b | completed     | 902a ✓          |
| 902c | completed     | 902a ✓          |
| 902d | completed     | 902a ✓          |
| 902e | awaiting-work | 902d ✓          |
| 902f | awaiting-work | 902d ✓          |
| 902g | awaiting-work | 902d ✓, 221e ✓  |
| 902h | awaiting-work | 902d ✓, 902c ✓  |

## Problem

Need moving platforms/pushers that travel along defined tracks, creating dynamic elements that can clear clogs and interact with balls.

## Overview

A track mover consists of:
1. **Track**: A path defined by connected line segments (like a rail)
2. **Mover**: A point that travels along the track
3. **Payload**: Objects (lines, pegs) connected to the mover that travel with it

The mover travels back and forth along the track. At intersections, it randomly selects a path within 90° of its approach direction.

## Key Mechanics

1. **Track Definition**: Draw track segments like lines, but they form a path network
2. **Mover Placement**: Place mover origin on track
3. **Payload Connection**: Objects touching mover origin move with it (like rotor connections)
4. **Back-and-Forth**: Mover travels to track end, reverses, repeats
5. **Intersection Handling**: At junctions, select random path within momentum cone
6. **Ball Interaction**: Payload collides with balls, can push or crush them

## Sub-Issues

| ID   | Description                           | Status        | Depends on      |
|------|---------------------------------------|---------------|-----------------|
| 902a | Track data structure and storage      | completed     | -               |
| 902b | Editor track drawing tool             | completed     | 902a ✓          |
| 902c | Mover placement and payload detection | completed     | 902a ✓          |
| 902d | Track following physics               | completed     | 902a ✓          |
| 902e | Intersection detection and path select| awaiting-work | 902d ✓          |
| 902f | Back-and-forth motion logic           | awaiting-work | 902d ✓          |
| 902g | Ball interaction and crushing         | awaiting-work | 902d ✓, 221e ✓  |
| 902h | Parallel mover updates                | awaiting-work | 902d ✓, 902c ✓  |

## Progress Summary

**Completed:** 4/8 sub-issues (902a, 902b, 902c, 902d)
**Awaiting work:** 4 (902e, 902f, 902g, 902h)

## Technical Considerations

### Track Network (COMPLETED - 902a)

- TrackSegment struct with endpoints and connection arrays
- Track segments can connect at endpoints
- Intersection = point where 3+ segments meet
- Dead end = point where only 1 segment connects

### Payload Detection (COMPLETED - 902c)

- BFS algorithm finds connected objects from mover position
- `MoverPayload` stores offsets and line geometry
- No BoardData needed at runtime - geometry stored at detection

### Track Following (COMPLETED - 902d)

- Position update along track segments using parametric 0-1 values
- Segment transition with dead-end reversal and connectivity following
- `update_payload_positions()` moves lines/pegs with mover each frame

### Intersection Path Selection (902e - AWAITING)

At intersection:
1. Calculate approach direction from previous segment
2. Find all other segments at intersection
3. Filter to those within 90° of approach (180° cone)
4. Randomly select from valid options
5. Cache valid paths per intersection per approach direction

### Payload Movement (902f - AWAITING)

- Similar to rotor: payload objects have relative positions
- As mover advances along track, payload follows
- No rotation (unlike rotor) - payload maintains orientation

### Parallelization (902h - NEW)

- `track_mover_manager_update()` currently sequential
- Each mover update is independent (writes to disjoint line/peg sets)
- Follow ball/particle task pattern: prepare → submit → wait_all
- Can run in parallel with rotor updates (disjoint objects)

## Files

- `src/052-track-mover.h` - Track mover data structures
- `src/053-track-mover.c` - Track mover physics implementation
- `src/020-board-data.h/c` - Track storage in board format
- `src/032-editor-app.c` - Editor track tool

## Related Issues

- 901f (Ball Crushing) - shared mechanic with 902g
- 901e (Collision Modes) - similar pass-through logic
- 221e (Stress source distinction) ✓ - required for 902g crushing mechanics
- 901h (Rotor parallelization) - same pattern as 902h
