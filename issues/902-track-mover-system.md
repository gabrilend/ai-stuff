# 902 - Track Mover System

## Status: awaiting-work

## Depends on

None - can be implemented independently.

## Sub-Issue Dependencies

| ID   | Status        | Depends on      |
|------|---------------|-----------------|
| 902a | awaiting-work | -               |
| 902b | blocked       | 902a            |
| 902c | blocked       | 902a            |
| 902d | blocked       | 902a            |
| 902e | blocked       | 902d            |
| 902f | blocked       | 902d            |
| 902g | blocked       | 902d, 221e      |

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

| ID    | Description                           | Status |
|-------|---------------------------------------|--------|
| 902a | Track data structure and storage      | Open   |
| 902b | Editor track drawing tool             | Open   |
| 902c | Mover placement and payload detection | Open   |
| 902d | Track following physics               | Open   |
| 902e | Intersection detection and path select| Open   |
| 902f | Back-and-forth motion logic           | Open   |
| 902g | Ball interaction and crushing         | Open   |

## Technical Considerations

### Track Network

- Track segments can connect at endpoints
- Intersection = point where 3+ segments meet
- Dead end = point where only 1 segment connects
- Need efficient path queries

### Approach Vector Calculation

At intersection:
1. Calculate approach direction from previous segment
2. Find all other segments at intersection
3. Filter to those within 90° of approach (180° cone)
4. Randomly select from valid options
5. Cache valid paths per intersection per approach direction

### Payload Movement

- Similar to rotor: payload objects have relative positions
- As mover advances along track, payload follows
- No rotation (unlike rotor) - payload maintains orientation

## Files to Create/Modify

- `src/0XX-track.h/c` - New track system
- `src/020-board-data.h/c` - Track storage in board format
- `src/032-editor-app.c` - Editor track tool
- `src/007-ball.c` - Shared crushing mechanics with 901

## Related Issues

- 901f (Ball Crushing) - shared mechanic
- 901e (Collision Modes) - similar pass-through logic
- 221e (Stress source distinction) - required for crushing mechanics
