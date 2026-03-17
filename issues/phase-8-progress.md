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
| 804 | Adversary board layout             | Complete |
| 805 | Adversary spawning AI              | Complete |
| 806 | Shared gates / ball passthrough    | Complete |
| 807 | Cross-board ball physics           | Complete |
| 808 | Gate bumpers                       | Complete |

## Progress Summary

**Completed:** 8/8 issues (100%)
**Phase 8:** Complete

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
- Adversary bumpers (bottom of dividers) implemented in Issue 804

### Issues 804-807 - Adversary System (Complete)

Implemented complete adversary system with AI-controlled opponent:

**Issue 804 - Adversary Board Layout:**
- Extended World struct with adversary_pegs, adversary_bumpers, adversary_table_top/bottom
- world_generate_adversary_pegs() creates mirrored peg layout below gates
- world_render_adversary_pegs() draws red-tinted pegs (180, 140, 140)
- Adversary bumpers generated at bottom of gate dividers
- Pegs/bumpers regenerate on window resize

**Issue 805 - Adversary Spawning AI:**
- Created Adversary struct (spawn_x, spawn_y, spawn_direction, spawn_credits, etc.)
- Oscillating reticle at ADVERSARY_MOVE_SPEED (120 px/sec)
- Spawn rate of ADVERSARY_SPAWN_RATE (4 balls/sec)
- Red-tinted reticle with cooldown arc indicator
- Spawns balls with OWNER_ADVERSARY and gravity_dir=-1.0

**Issue 806 - Shared Gates / Ball Passthrough:**
- Added passed_gate flag to Ball struct
- Balls score points on gate entry but continue through (not destroyed)
- Player balls continue to adversary board, adversary balls to player board
- Balls destroyed only at far boundary (adversary_table_bottom or above spawn)
- Prevents double-scoring with passed_gate flag

**Issue 807 - Cross-Board Ball Physics:**
- Added gravity_dir (+1.0 downward, -1.0 upward) to Ball struct
- Added owner (OWNER_PLAYER, OWNER_ADVERSARY) to Ball struct
- Physics update: vy += GRAVITY * gravity_dir * dt
- Balls collide with both player and adversary pegs/bumpers
- Cross-board collisions apply 2x impulse multiplier for dramatic interactions

Files: 004-world.h, 005-world.c, 006-ball.h, 007-ball.c, 012-adversary.h, 013-adversary.c, 001-main.c
