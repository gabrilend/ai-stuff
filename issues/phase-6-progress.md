# Phase 6 Progress

## Phase Goal

Bug fixes and advanced features. This phase addresses critical bugs discovered
during Phase 5 and adds new gameplay and rendering features.

## Issues

| ID  | Description                              | Status   |
|-----|------------------------------------------|----------|
| 506 | Fix ball scoring/disappearing bug        | Complete |
| 507 | Detect system thread count               | Pending  |
| 508 | Add ball-to-ball collisions              | Pending  |
| 509 | Improve particle effects                 | Pending  |
| 510 | Add scrolling viewport                   | Pending  |

## Progress Summary

**Completed:** 1/5 issues (20%)
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
