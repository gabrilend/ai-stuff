# Phase 2 Progress

## Phase Goal

World structure, ball physics, wrap behavior, and sleep optimization.

## Issues

| ID   | Description                        | Status        | Depends on |
|------|------------------------------------|---------------|------------|
| 201  | Create world state structure       | completed     | -          |
| 202  | Implement peg grid generation      | completed     | -          |
| 203  | Implement score zones              | completed     | -          |
| 204  | Integrate world rendering          | completed     | -          |
| 205  | Center table in window             | completed     | -          |
| 206  | Add guard rails                    | completed     | -          |
| 207  | Create ball state structure        | completed     | -          |
| 208  | Implement ball physics             | completed     | -          |
| 209  | Implement peg collision            | completed     | -          |
| 210  | Implement boundary collision       | completed     | -          |
| 211  | Implement ball spawning input      | completed     | -          |
| 212  | Add ball collisions                | completed     | -          |
| 213  | Fix player ball wrap position      | completed     | -          |
| 214  | Dynamic wrap zones                 | completed     | -          |
| 215  | Ball wrap gate reset               | completed     | -          |
| 216  | Unify line ramp abstraction        | completed     | -          |
| 217  | Line gravity assist wrong direction| completed     | -          |
| 218  | Pegs not anchored to guard rails   | completed     | -          |
| 219  | Slot based world layout            | completed     | -          |
| 220  | Velocity dependent restitution     | completed     | -          |
| 221  | Ball sleep system                  | in-progress   | -          |
| 221a | Sleep state tracking               | completed     | -          |
| 221b | Sleep transition logic             | completed     | 221a       |
| 221c | Wake conditions                    | completed     | 221b       |
| 221d | Soft collision response            | completed     | -          |
| 221e | Stress source distinction          | completed     | 221d       |
| 222  | Trajectory history overlap nudge   | partial       | -          |

## Progress Summary

**Completed:** 25/27 issues
**Awaiting work:** 1 (222)
**Blocked:** 0
**In progress:** 1 (221 parent issue)
**Phase status:** in-progress

## Technical Notes

### World Structure (201-206)
- Peg struct with position, radius
- ScoreZone struct with boundaries and point values
- World struct managing all game elements
- Staggered peg grid pattern for realistic ball paths
- Guard rails with collision detection

### Ball Physics (207-212)
- Double-buffered ball state for parallel-safe updates
- Semi-implicit Euler integration with gravity
- Circle-circle collision for pegs and balls
- 70% energy retention on peg collision

### Wrap System (213-215)
- Ball wrapping between boards
- Dynamic wrap zones
- Gate reset on wrap

### World Layout (216-220)
- Unified line/ramp abstraction
- Slot-based world layout
- Velocity-dependent restitution

### Ball Sleep (221, 222)
- Sleep state tracking (221a) - frames_at_rest counter, is_sleeping flag
- Sleep transition (221b) - ball_enter_sleep() when threshold reached
- Wake conditions (221c) - ball_wake(), ball_wake_with_impulse() on collision
- Soft collision response (221d) - gentle push instead of rigid collision for piles
- Stress distinction (221e) - static vs dynamic stress tracking for crushing
- Trajectory history (222) - partial, overlap nudge for stuck detection

## Issue-Level Dependencies

- 221b depends on 221a (sleep state tracking must exist before transition logic)
- 221c depends on 221b (wake conditions need transition logic)
- 221d depends on 221a (soft collision needs sleep state)
- 221e depends on 221d (stress distinction builds on soft collision)
- 901f, 902g (Phase 9) depend on 221e for crushing mechanics
