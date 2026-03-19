# 901 - Rotor System

## Status: awaiting-work

## Problem

The game currently only supports static geometry. Adding rotating structures would create dynamic, interesting gameplay with moving obstacles and mechanisms.

## Overview

A rotor is a central pivot point from which lines extend and rotate. Any objects (pegs, other lines) connected to those lines rotate with them. Disconnected objects are passed through as if the rotating structure is a phantom.

## Requirements

- [ ] 1. Define rotor data structure (depends on: 901a)
- [ ] 2. Add rotor array to BoardData JSON schema (depends on: 901a)
- [ ] 3. Editor tool for placing rotors (depends on: 901b, req 1-2)
- [ ] 4. Implement line rotation physics (depends on: 901c, req 1)
- [ ] 5. Connected object detection algorithm (depends on: 901d, req 1)
- [ ] 6. Collision modes (solid vs pass-through) (depends on: 901e, req 4-5)
- [ ] 7. Ball crushing mechanics (depends on: 901f, 221 for sleep/stress)
- [ ] 8. Direction configuration UI (depends on: 901g, req 3)

## Sub-Issues

| ID   | Description                            | Status        | Depends on |
|------|----------------------------------------|---------------|------------|
| 901a | Rotor data structure and storage       | awaiting-work | -          |
| 901b | Editor rotor placement tool            | blocked       | 901a       |
| 901c | Line rotation physics                  | blocked       | 901a       |
| 901d | Connected object detection             | blocked       | 901a       |
| 901e | Collision mode (solid vs pass-through) | blocked       | 901c, 901d |
| 901f | Ball stress and crushing               | blocked       | 901e, 221  |
| 901g | Direction configuration UI             | blocked       | 901b       |

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

- 902 (Track Movers) shares ball crushing mechanics with 901f
- 221 (Ball Sleep System) provides stress source distinction needed for 901f
- Consider implementing shared "dynamic geometry" system across 901 and 902
