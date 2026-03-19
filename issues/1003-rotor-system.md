# 1305 - Rotor System

## Status: Open

## Problem

The game currently only supports static geometry. Adding rotating structures would create dynamic, interesting gameplay with moving obstacles and mechanisms.

## Overview

A rotor is a central pivot point from which lines extend and rotate. Any objects (pegs, other lines) connected to those lines rotate with them. Disconnected objects are passed through as if the rotating structure is a phantom.

## Key Mechanics

1. **Central Rotor Peg**: Acts as the pivot point. Visually can remain static.
2. **Connected Lines**: Lines drawn from the rotor pivot rotate around it.
3. **Connected Objects**: Pegs/lines that intersect with rotor lines rotate with the structure.
4. **Disconnected Objects**: Static objects not connected to the rotor are passed through (no collision during rotation).
5. **Ball Interaction**: Balls collide with rotating structure. Under intense stress (crushing), balls are destroyed.
6. **Direction Control**: Right-click menu to configure rotation direction (clockwise/counter-clockwise).

## Sub-Issues

| ID    | Description                           | Status |
|-------|---------------------------------------|--------|
| 1305a | Rotor data structure and storage      | Open   |
| 1305b | Editor rotor placement tool           | Open   |
| 1305c | Line rotation physics                 | Open   |
| 1305d | Connected object detection            | Open   |
| 1305e | Collision mode (solid vs pass-through)| Open   |
| 1305f | Ball stress and crushing              | Open   |
| 1305g | Direction configuration UI            | Open   |

## Technical Considerations

### Static to Dynamic Transition
- Current physics assumes static peg/line positions
- Need to update positions each frame for rotating objects
- May need separate "dynamic object" list for performance

### Connected Object Detection
- At rotor creation time, trace all objects connected to rotor lines
- Build a "rigid body" group that rotates together
- Store relative positions/angles from rotor center

### Collision Modes
- Connected objects: Full collision with balls
- Disconnected objects during rotation: Pass-through (ghost mode)
- This prevents rotating arm from "pushing" static pegs

### Ball Crushing
- Detect when ball is trapped between rotating and static geometry
- If ball velocity is constrained while structure applies force, crush it
- Need stress accumulation metric

## Files to Create/Modify

- `src/0XX-rotor.h/c` - New rotor system
- `src/020-board-data.h/c` - Rotor storage in board format
- `src/032-editor-app.c` - Editor placement tool
- `src/007-ball.c` - Crushing mechanics
- `src/001-main.c` - Rotor update loop integration

## Dependencies

- Issue 1306 (Track Movers) shares ball crushing mechanics
- May want to implement shared "dynamic geometry" system first
