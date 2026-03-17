# Phase 8 Progress

## Phase Goal

Game mechanics expansion. This phase adds an upgrade system and an adversary
opponent, creating competitive gameplay with resource management.

## Issues

| ID  | Description                        | Status  |
|-----|------------------------------------|---------|
| 801 | Upgrade system framework           | Pending |
| 802 | Spawn rate upgrade                 | Pending |
| 803 | Ball radius upgrade                | Pending |
| 804 | Adversary board layout             | Pending |
| 805 | Adversary spawning AI              | Pending |
| 806 | Shared gates / ball passthrough    | Pending |
| 807 | Cross-board ball physics           | Pending |
| 808 | Gate bumpers                       | Complete |

## Progress Summary

**Completed:** 1/8 issues (12.5%)
**Phase 8:** In Progress

## Notes

Phase 8 introduces two major feature sets:

**Upgrade System:**
- Menu accessible via keypress
- Spend current score (not high score) on upgrades
- Initial upgrades: spawn rate, ball radius
- Future: special ball types (bouncy, heavy, etc.)

**Adversary System:**
- Mirrored board below player's board
- Shared gates pass balls between boards
- AI-controlled reticle movement
- Reversed gravity for enemy balls
- Momentum transfer on cross-board collisions

Success is measured by:
- Upgrades purchasable and functional
- Enemy board renders correctly (flipped orientation)
- Balls pass through shared gates to opposite board
- Enemy AI spawns at consistent rate
- Cross-board collisions transfer momentum correctly

## Dependencies

Phase 7 must be complete (spawn system and UI improvements).

## Implementation Log

### Issue 808 - Gate Bumpers (Complete)

Added low-restitution bumper caps at the top of each gate divider:

- Bumper struct added to World (x, y, radius)
- Bumpers auto-generated at zone boundaries (N-1 bumpers for N zones)
- Very low restitution (0.15) plus tangential velocity damping (0.7)
- Balls hitting bumpers "donk" softly and slide into gates
- Muted teal visual (80, 140, 140) with darker outline
- Integrated into parallel ball physics (ball_update_task)
- Adversary bumpers (bottom of dividers) deferred to Issue 804
