# Phase 13 Progress

## Phase Goal

Game polish, bug fixes, and major new dynamic geometry features (rotors and track movers).

## Issues

| ID    | Description                        | Status    |
|-------|------------------------------------|-----------|
| 1301  | Random ball colors                 | Re-opened |
| 1302  | Adversary board flip axis          | Complete  |
| 1303  | Progress bar color flip            | Complete  |
| 1304  | Stage spawn mechanic broken        | Complete  |
| 1305  | Rotor system                       | Open      |
| 1305a | - Rotor data structure             | Open      |
| 1305b | - Editor rotor placement tool      | Open      |
| 1305c | - Line rotation physics            | Open      |
| 1305d | - Connected object detection       | Open      |
| 1305e | - Collision modes (solid/ghost)    | Open      |
| 1305f | - Ball stress and crushing         | Open      |
| 1305g | - Direction configuration UI       | Open      |
| 1306  | Track mover system                 | Open      |
| 1306a | - Track data structure             | Open      |
| 1306b | - Editor track drawing tool        | Open      |
| 1306c | - Mover payload detection          | Open      |
| 1306d | - Track following physics          | Open      |
| 1306e | - Intersection path selection      | Open      |
| 1306f | - Back-and-forth motion            | Open      |
| 1306g | - Ball interaction and crushing    | Open      |
| 1307  | Ball sleep system                  | Open      |
| 1307a | - Sleep state tracking             | Open      |
| 1307b | - Sleep transition logic           | Open      |
| 1307c | - Wake conditions                  | Open      |
| 1307d | - Soft collision response          | Open      |
| 1307e | - Stress source distinction        | Open      |
| 1308  | Expand grid dimensions             | Complete  |
| 1309  | Unified spawner system             | Complete  |
| 1310  | Compile-time config system         | Complete  |
| 1311  | Trajectory history and overlap nudge | Open    |
| 1312  | Closed polygon detection and fill  | Open      |
| 1313  | Standardize board dimensions       | Open      |
| 1314  | Editor panel UI system             | Open      |
| 1315  | Hide game UI keybind               | Open      |
| 1316  | Minimum window width               | Open      |
| 1317  | Collapsible drawer UI              | Open      |
| 1318  | Separate player/adversary scores   | Open      |
| 1319  | Material type selector             | Open      |
| 1320  | Remove adversary board tinting     | Open      |
| 1321  | Allow multiple gate scoring        | Open      |
| 1322  | Ball velocity statistics           | Open      |
| 1323  | GateRow scoring never called       | Open      |
| 1324  | Grid-based zone dispatch system    | Open      |

## Progress Summary

**Completed:** 6/40 issues (15%)
**Status:** In Progress

## Major Features

### Bug Fixes (1301-1304)

Quick fixes for existing issues:
- **1301**: Re-opened - Ball colors work, but particles need color integration
- **1302**: ✓ Vertical flip for adversary board (X-axis mirror)
- **1303**: ✓ Spawn count tracking for visual continuity (instead of credits floor)
- **1304**: ✓ Stage spawn flipping for adversary stages

### Rotor System (1305)

Rotating structures that add dynamic obstacles:
- Central pivot point with rotating arms
- Connected objects rotate together
- Disconnected objects are passed through (ghost mode)
- Ball crushing when trapped
- Editor tool for placement and configuration

### Track Mover System (1306)

Moving platforms that travel along defined tracks:
- Track network with segments and intersections
- Movers carry payload objects along track
- Back-and-forth motion with random path selection at junctions
- Ball pushing and crushing for clearing clogs
- Editor tools for track drawing and mover placement

### Ball Sleep System (1307)

Solves pile instability where balls explode from accumulated energy:
- Sleeping balls don't apply gravity or forces to each other
- Sleeping balls still receive collisions (wake up when hit)
- Soft collision response for nearly-stationary balls
- Distinguishes static stress (ball weight) from dynamic stress (rotors/movers)
- Only dynamic stress causes crushing

**Rollback available:** If system makes things worse, use `git checkout phase12-complete-stable`

## Technical Notes

### Shared Components

Issues 1305 and 1306 share several mechanics:
- Connected object detection algorithm
- Ball crushing/stress system
- Pass-through collision mode
- Dynamic object physics integration

Consider implementing shared utilities:
- `detect_connected_objects()` - BFS/DFS connection tracing
- `calculate_ball_stress()` - Crushing detection
- `should_collide()` - Dynamic vs static collision filtering

### Static to Dynamic Transition

Current physics assumes static geometry. These features require:
- Per-frame position updates for dynamic objects
- Velocity tracking for collision response
- Separate dynamic object list for performance

## Dependencies

Phase 12 complete (editor modularization).
