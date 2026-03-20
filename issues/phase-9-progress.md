# Phase 9 Progress

## Phase Goal

Dynamic systems: rotors, track movers, and analysis tools.

## Issues

| ID   | Description                   | Status        | Depends on      |
|------|-------------------------------|---------------|-----------------|
| 901  | Rotor system                  | in-progress   | -               |
| 901a | Rotor data structure          | completed     | -               |
| 901b | Editor rotor placement tool   | completed     | 901a ✓          |
| 901c | Line rotation physics         | completed     | 901a ✓          |
| 901d | Connected object detection    | completed     | 901a ✓          |
| 901e | Collision modes               | completed     | 901c ✓, 901d ✓  |
| 901f | Ball crushing                 | awaiting-work | 901e ✓, 221e ✓  |
| 901g | Direction config UI           | completed     | 901b ✓          |
| 901h | Parallel rotor updates        | awaiting-work | 901c ✓, 901d ✓  |
| 902  | Track mover system            | in-progress   | -               |
| 902a | Track data structure          | completed     | -               |
| 902b | Editor track drawing tool     | completed     | 902a ✓          |
| 902c | Mover payload detection       | completed     | 902a ✓          |
| 902d | Track following physics       | completed     | 902a ✓          |
| 902e | Intersection path selection   | awaiting-work | 902d ✓          |
| 902f | Back and forth motion         | awaiting-work | 902d ✓          |
| 902g | Track ball interaction        | awaiting-work | 902d ✓, 221e ✓  |
| 902h | Parallel mover updates        | awaiting-work | 902d ✓, 902c ✓  |
| 903  | Ball velocity statistics      | completed     | -               |

## Progress Summary

**Completed:** 11/19 issues (901a, 901b, 901c, 901d, 901e, 901g, 902a, 902b, 902c, 902d, 903)
**In progress:** 2 (901, 902)
**Awaiting work:** 6 (901f, 901h, 902e, 902f, 902g, 902h)
**Blocked:** 0
**Phase status:** in-progress

## New Issues Added

### 901h - Parallel rotor updates
- `rotor_manager_update()` currently runs sequentially
- Each rotor update is independent (writes to disjoint line/peg sets)
- Follow ball/particle task pattern: prepare → submit → wait_all
- Can run in parallel with track mover updates

### 902h - Parallel mover updates
- `track_mover_manager_update()` currently runs sequentially
- Each mover update is independent (writes to disjoint line/peg sets)
- Same pattern as 901h
- Both rotor and mover updates can run in parallel with each other

## Recent Completions

### 901g - Direction config UI
- Right-click rotor to open property panel
- CW/CCW direction toggle buttons (green highlight on active)
- Speed slider (0-100% mapped to 0-6.28 rad/s rotation)
- Connected objects count and current angle display
- R key reverses direction while rotor selected
- Yellow highlight ring around selected rotor
- ESC closes rotor panel

### 902d - Track following physics
- Created `src/052-track-mover.h` and `src/053-track-mover.c`
- `TrackMoverManager` provides centralized update for all movers
- Position update along track segments using parametric 0-1 values
- Segment transition with dead-end reversal and connectivity following
- Integrated in main loop after rotor updates, before ball physics
- Unblocked 902e, 902f, 902g

### 902c - Mover payload detection
- BFS algorithm finds connected objects from mover position
- `MoverPayload` stores offsets and line geometry for runtime independence
- No BoardData needed at runtime - geometry stored at detection
- `update_payload_positions()` moves lines/pegs with mover each frame

### 901e - Collision modes (pass-through)
- Added `is_dynamic` and `rotor_index` fields to BoardObject struct
- Initialize fields to 0/-1 when objects created in add_peg_ex and add_line_ex
- Set flags when rotor connections computed via BFS detection
- Engine architecture already supports pass-through (objects don't collide with each other)
- Flags prepared for future use in 901f (ball crushing detection)
- Unblocked 901f (Ball crushing)

### 901d - Connected object detection
- Implemented BFS-based touch detection algorithm
- Added geometry helpers: point_to_segment_distance_sq, segments_intersect_or_close
- Objects touching rotor center are detected, then transitively connected objects
- Uses TOUCH_THRESHOLD (0.5 grid units) for proximity detection
- Replaced simple Manhattan distance with proper geometric touch testing

### 901c - Line rotation physics
- Created `src/044-rotor.h` and `src/044-rotor.c` - rotor physics module
- `RotorPhysics` struct stores runtime state: center, angle, connected objects
- `RotorManager` provides update/query interface for all rotors
- Added `RotorManager*` fields to World structure
- Integrated `rotor_manager_update()` in main loop before ball physics
- Connected lines and pegs rotate around rotor centers
- Unblocked 901e (Collision modes)

### 902b - Editor track drawing tool
- Added `APP_TOOL_TRACK` enum value and key 6 binding
- Cyan track segments with endpoint circle markers (3px line, 4px radius circles)
- Two-click placement like line tool, right-click to cancel
- Rendering functions in 035-object-render.c
- Tracks render distinctly from collision lines (cyan vs orange)
- Also fixed bug in 044-rotor.c (wrong struct member names)

### 901b - Editor rotor placement tool
- Added `APP_TOOL_ROTOR` enum value and key 5 binding
- Gear-shaped visual with rotation direction indicator
- Placement, erasing, and board stats integration
- Unblocked 901g (Direction config UI)

## Technical Notes

### Rotor System (901, 901a-h)
- Rotating line segments attached to pivot points
- Connected object detection for rotation
- Collision modes and ball crushing
- Direction configuration in editor
- Parallelizable per-rotor updates

### Track Mover System (902, 902a-h)
- Objects that follow predefined paths
- Track drawing in editor
- Payload detection and attachment
- Back-and-forth motion modes
- Ball interaction with moving platforms
- Parallelizable per-mover updates

### Analysis (903)
- Ball velocity statistics for debugging

### Parallelization Architecture (901h, 902h)
- Both rotor and mover updates are independent per-object
- Each writes to disjoint line/peg index sets (enforced by BFS detection)
- Can run rotor and mover tasks concurrently with single sync point
- Must complete before ball physics starts (balls read line/peg positions)

## Issue-Level Dependencies

- 901f, 902g depend on 221e (Stress source distinction) for crushing mechanics
- 901b, 902b require editor infrastructure (801-814 complete)
- 901 and 902 share crushing mechanics - consider shared implementation
- 903 can leverage 222 (Trajectory history) for velocity data
- 901h and 902h are independent and can be worked in parallel
