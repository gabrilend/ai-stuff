# Phase 6 Progress

## Phase Goal

Bug fixes and advanced features. This phase addresses critical bugs discovered
during Phase 5 and adds new gameplay and rendering features.

## Issues

| ID  | Description                              | Status   |
|-----|------------------------------------------|----------|
| 506 | Fix ball scoring/disappearing bug        | Complete |
| 507 | Detect system thread count               | Complete |
| 508 | Add ball-to-ball collisions              | Complete |
| 509 | Improve particle effects                 | Complete |
| 510 | Add scrolling viewport                   | Complete |

## Progress Summary

**Completed:** 5/5 issues (100%)
**Phase 6:** Complete

## Notes

Phase 6 addresses bugs and adds features discovered during Phase 5 testing:

Critical bugs:
- Balls flash in/out of existence in score zones
- Repeated particle/scoring triggers

New features:
- Automatic thread detection
- Ball-to-ball collisions
- Spawn blocking when balls are in spawner
- Enhanced particle effects (colors, physics, iridescence)
- Scrolling viewport for large boards

## Dependencies

Phase 5 must be complete (scoring and polish).

## Implementation Log

### Issue 506 - Ball Scoring Bug Fix (Complete)

Fixed critical bug where balls flickered and triggered multiple scoring/particles.

Root cause: `scored` flag in BallTaskData was never reset for inactive balls. When
a ball scored and became inactive, no task was submitted for it on future frames,
so the `scored=1` flag persisted forever.

Fix: Modified `ball_manager_collect_scores()` to reset both `score_delta` AND `scored`
for all task entries. Reordered main loop to spawn particles BEFORE collecting scores
(while flags are still valid).

### Issue 507 - System Thread Detection (Complete)

Implemented automatic CPU core detection for optimal thread pool sizing.

- Added `get_optimal_thread_count()` using sysconf(_SC_NPROCESSORS_ONLN)
- Calculates: cores - 1, clamped to [2, 16]
- Main.c now uses detected count instead of hardcoded 4
- Logged at startup for visibility

### Issue 508 - Ball-to-Ball Collisions (Complete)

Implemented elastic collisions between balls and spawn area blocking.

Ball collision system:
- `ball_check_ball_collision()` detects circle-circle overlap
- `ball_resolve_ball_collision()` applies impulse-based response
- `ball_collide_with_balls()` iterates all other balls per task
- Added `capacity` field to BallTaskData for collision loop bounds
- Each ball handles its own collision response (thread-safe)

Spawn blocking system:
- `ball_manager_spawn_blocked()` checks for balls within 3x radius of spawn
- Updated main.c to prevent spawning when area is occupied
- Prevents overlapping balls and physics glitches at spawn point

### Issue 509 - Particle Effects Improvements (Complete)

Enhanced particles for more vibrant, dynamic visual effects.

Constants tuned:
- Smaller radius (2.0f vs 3.0f)
- Faster burst speed (220.0f vs 120.0f)
- Lower gravity for more hang time (200.0f vs 300.0f)
- Longer lifetime (1.0f vs 0.8f)

New features:
- Iridescence: Hue shifts over lifetime (60° shift creates rainbow shimmer)
- Color randomization: ±30° hue variation per particle
- Speed variation: ±80 px/s random speed per particle
- Position jitter: ±2 px random spawn offset
- Lifetime variation: +0 to +0.3s random per particle

Added HSV/RGB conversion utilities for color manipulation.

### Issue 510 - Scrolling Viewport (Complete)

Implemented scrollable world view using raylib's Camera2D system.

Camera system:
- Camera2D centers view and tracks scroll position
- World elements rendered in camera space (scrollable)
- UI elements rendered outside camera (screen-fixed)

Scroll mechanics:
- Mouse wheel controls viewport offset
- SCROLL_SPEED = 40 pixels per notch
- Offset clamped to valid range [0, world_height - screen_height]
- Currently world_height = screen_height (no scroll needed)

When board expands in future, increase world_height to enable scrolling.
All world elements (pegs, balls, zones, particles) scroll automatically.
