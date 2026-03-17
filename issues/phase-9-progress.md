# Phase 9 Progress

## Phase Goal

Bug fixes discovered during Phase 7-8 testing.

## Issues

| ID  | Description                              | Status   |
|-----|------------------------------------------|----------|
| 901 | Fix info box positioning on resize       | Complete |
| 902 | Spawn buffering system                   | Complete |

## Progress Summary

**Completed:** 2/2 issues (100%)
**Phase 9:** Complete

## Notes

Bug discovered: Controls panel doesn't reposition when window is resized
because screen_width is not updated in the resize handler.

## Dependencies

Phase 8 must be complete.

## Implementation Log

### Issue 901 - Fix Info Box Positioning on Resize (Complete)

Fixed bug where controls panel didn't reposition on window resize.

Root cause: `screen_width` was declared const and never updated.
The resize handler used a local `new_screen_width` variable.

Fix: Made `screen_width` mutable and update it directly in resize handler.
All references to `new_screen_width` replaced with `screen_width`.

UI now correctly anchors to viewport corners on resize.

### Issue 902 - Spawn Buffering System (Complete)

Implemented credit-based spawn system for consistent ball output rate.

System design:
- Credits accumulate at SPAWN_RATE (10/sec)
- Cap at MAX_SPAWN_CREDITS (3.0)
- Spawning costs 1 credit
- Blocked spawns don't consume credits

This prevents rapid mouse movement from bypassing spawn blocking,
and ensures players aren't penalized when spawn is temporarily blocked.
Supports future upgrade mechanics for spawn rate modification.

**Fix (Session 2):** Made spawn blocking position-independent.
Changed `ball_manager_spawn_blocked()` to check Y distance only,
blocking if ANY ball is near spawn height regardless of X position.

**Fix (Session 3):** Restored circular distance checking.
Y-only was too conservative. Now uses Euclidean distance centered on
reticle (spawn_x, spawn_y). Balls with horizontal velocity exit blocking
zone quickly, allowing more natural spawn flow.

**Fix (Session 3b):** Moved spawning to after buffer swap.
Balls now spawn into post-swap buffer and render at exact spawn position.
Added GetScreenToWorld2D for proper mouse coordinate conversion.
