# 901 - Rotor System

## Status: in-progress

## Problem

The game currently only supports static geometry. Adding rotating structures would create dynamic, interesting gameplay with moving obstacles and mechanisms.

## Overview

A rotor is a central pivot point from which lines extend and rotate. Any objects (pegs, other lines) connected to those lines rotate with them. Disconnected objects are passed through as if the rotating structure is a phantom.

## Requirements

- [x] 1. Define rotor data structure (901a ✓)
- [x] 2. Add rotor array to BoardData JSON schema (901a ✓)
- [x] 3. Editor tool for placing rotors (901b ✓)
- [x] 4. Implement line rotation physics (901c ✓)
- [x] 5. Connected object detection algorithm (901d ✓)
- [x] 6. Collision modes (solid vs pass-through) (901e ✓)
- [ ] 7. Ball crushing mechanics (901f)
- [x] 8. Direction configuration UI (901g ✓)
- [ ] 9. Parallel rotor updates (901h - NEW)

## Sub-Issues

| ID   | Description                            | Status        | Depends on      |
|------|----------------------------------------|---------------|-----------------|
| 901a | Rotor data structure and storage       | completed     | -               |
| 901b | Editor rotor placement tool            | completed     | 901a ✓          |
| 901c | Line rotation physics                  | completed     | 901a ✓          |
| 901d | Connected object detection             | completed     | 901a ✓          |
| 901e | Collision mode (solid vs pass-through) | completed     | 901c ✓, 901d ✓  |
| 901f | Ball stress and crushing               | awaiting-work | 901e ✓, 221e ✓  |
| 901g | Direction configuration UI             | completed     | 901b ✓          |
| 901h | Parallel rotor updates                 | awaiting-work | 901c ✓, 901d ✓  |

## Progress Summary

**Completed:** 6/8 sub-issues (901a, 901b, 901c, 901d, 901e, 901g)
**Awaiting work:** 2 (901f, 901h)

## Technical Considerations

### Static to Dynamic Transition
- Current physics assumes static peg/line positions
- Need to update positions each frame for rotating objects
- May need separate "dynamic object" list for performance

### Connected Object Detection (COMPLETED - 901d)
- BFS-based touch detection algorithm
- Point-to-segment and segment intersection testing
- TOUCH_THRESHOLD (0.5 grid units) for proximity detection

### Collision Modes (COMPLETED - 901e)
- `is_dynamic` and `rotor_index` fields added to BoardObject
- Connected objects collide with balls
- Pass-through for disconnected objects during rotation

### Ball Crushing (901f - AWAITING)
- Detect when ball is trapped between rotating and static geometry
- If ball velocity is constrained while structure applies force, crush it
- Depends on 221e stress source distinction (completed)

### Parallelization (901h - NEW)
- `rotor_manager_update()` currently sequential
- Each rotor update is independent (writes to disjoint line/peg sets)
- Follow ball/particle task pattern: prepare → submit → wait_all
- Can run in parallel with track mover updates (disjoint objects)

## Files

- `src/044-rotor.h` - Rotor data structures
- `src/044-rotor.c` - Rotor physics implementation
- `src/020-board-data.h/c` - Rotor storage in board format
- `src/032-editor-app.c` - Editor placement tool

## Dependencies

- 902 (Track Movers) shares ball crushing mechanics with 901f
- 221e (Stress source distinction) ✓ - needed for 901f
- Consider implementing shared "dynamic geometry" system across 901 and 902
