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
| 809 | Ball health and damage system      | Complete |
| 810 | Granular upgrade levels            | Complete |
| 811 | Escape key behavior / Q to quit    | Complete |
| 812 | Particle effects overhaul          | Complete |
| 813 | Fix persistent splash particles    | Complete |

## Progress Summary

**Completed:** 13/13 issues (100%)
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
- Cross-board collisions originally used 2x impulse (replaced by health system in 809)

**Issue 809 - Ball Health and Damage System:**
- Added health field to Ball struct (starts at BALL_MAX_HEALTH = 100)
- Cross-board collisions deal damage based on relative velocity
- Damage formula: relative_speed * DAMAGE_VELOCITY_SCALE (0.3)
- Replaced 2x impulse with health/damage for more strategic gameplay
- Balls explode with 24 magenta particles when health reaches zero
- Added died_from_damage tracking to BallTaskData

Files: 004-world.h, 005-world.c, 006-ball.h, 007-ball.c, 012-adversary.h, 013-adversary.c, 001-main.c

### Issue 810 - Granular Upgrade Levels (Complete)

Converted upgrade system to incremental/clicker-style with 100x more levels:

- Spawn rate: 5 → 500 levels, +0.01/level (same +5 total at max)
- Ball size: 3 → 300 levels, -0.01/level (same -3 total at max)
- Base costs reduced: 100 → 1, 150 → 2 for incremental purchasing
- Hold-to-purchase: initial 0.3s delay, then 30 purchases/second repeat
- Progress bar UI replaces level counters for cleaner display
- Percentage indicator next to each progress bar

Files: 010-upgrades.h, 011-upgrades.c

### Issue 811 - Escape Key Behavior (Complete)

Improved quit key handling for better menu interaction:

- SetExitKey(0) disables raylib's default ESC-to-quit
- ESC closes upgrade menu if open, only quits if menu closed
- Q key always quits immediately
- upgrade_manager_handle_input() returns 1 if ESC was consumed

Files: 001-main.c, 010-upgrades.h, 011-upgrades.c

### Issue 812 - Particle Effects Overhaul (Complete)

Complete rewrite of particle system with three new effect types:

**Gate Ripple:**
- Expanding ring effect replaces burst particles at gates
- Color based on point value, fades as ring grows

**Collision Splash:**
- Small particles along collision tangent for ball-vs-ball hits
- Tracks cross-owner collisions via BallTaskData

**Explosion Fragments:**
- Ball splits into 3/4/6/8 physics-enabled fragments
- 20% chance of corkscrew motion (sinusoidal perpendicular offset)
- Fragments collide with pegs/bumpers/walls but don't affect them
- Iridescent trailing ribbons with hue shift

Files: 006-ball.h, 007-ball.c, 008-particles.h, 009-particles.c, 001-main.c

### Issue 813 - Fix Persistent Splash Particles (Complete)

Bug fix for splash particles spawning continuously (fountain effect):

**Root causes identified:**
1. Collision tracking fired every frame during overlap, not just on impact
2. Both balls in collision set had_collision (double-detection)
3. Velocity comparison used different time points (write vs read buffer)
4. Stale task_data persisted for inactive balls

**Fixes applied:**
- Velocity check before collision resolution (vn < -10.0f threshold)
- `ball_index < i` check prevents double-detection
- Use read buffer for both balls' velocities (same time point)
- Main loop skips inactive balls to avoid stale task_data

Files: 007-ball.c, 001-main.c
