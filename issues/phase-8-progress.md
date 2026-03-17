# Phase 8 Progress

## Phase Goal

Game mechanics expansion. This phase adds an upgrade system and an adversary
opponent, creating competitive gameplay with resource management.

## Issues

| ID  | Description                        | Status  |
|-----|------------------------------------|---------|
| 801 | Upgrade system framework           | Complete |
| 802 | Spawn rate upgrade                 | Complete |
| 803 | Ball radius upgrade                | Complete |
| 804 | Adversary board layout             | Pending |
| 805 | Adversary spawning AI              | Pending |
| 806 | Shared gates / ball passthrough    | Pending |
| 807 | Cross-board ball physics           | Pending |
| 808 | Gate bumpers                       | Complete |

## Progress Summary

**Completed:** 4/8 issues (50%)
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

### Issues 801-803 - Upgrade System (Complete)

Implemented complete upgrade system with menu UI and two upgrades:

- Created UpgradeManager with Upgrade struct (name, description, base_cost, level, max_level)
- Tab key toggles upgrade menu overlay
- Up/Down selects upgrade, Enter purchases, Escape closes
- Purchases deduct from current score (not high score)
- Cost scaling: base_cost * (level + 1)

**Spawn Rate Upgrade (802):**
- +1 ball/sec per level, max 5 levels
- Base cost 100, scales to 500 at level 5
- Bonus credits added to spawn_credits each frame

**Ball Size Upgrade (803):**
- -1 radius per level, max 3 levels (minimum radius 5)
- Base cost 150, scales to 450 at level 3
- Modified ball_manager_spawn() to accept radius parameter

Files: 010-upgrades.h, 011-upgrades.c, 001-main.c, 006-ball.h, 007-ball.c

### Issue 808 - Gate Bumpers (Complete)

Added low-restitution bumper caps at the top of each gate divider:

- Bumper struct added to World (x, y, radius)
- Bumpers auto-generated at zone boundaries (N-1 bumpers for N zones)
- Very low restitution (0.15) plus tangential velocity damping (0.7)
- Balls hitting bumpers "donk" softly and slide into gates
- Muted teal visual (80, 140, 140) with darker outline
- Integrated into parallel ball physics (ball_update_task)
- Adversary bumpers (bottom of dividers) deferred to Issue 804
