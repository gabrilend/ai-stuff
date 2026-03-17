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
| 509 | Improve particle effects                 | Pending  |
| 510 | Add scrolling viewport                   | Pending  |

## Progress Summary

**Completed:** 3/5 issues (60%)
**Phase 6:** In Progress

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
