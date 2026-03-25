# Issue 809 - Ball Health and Damage System

## Status
Completed

## Current Behavior
- Each ball has a health field starting at BALL_MAX_HEALTH (100)
- Cross-board collisions (player vs adversary balls) deal velocity-based damage
- Damage formula: relative_speed * DAMAGE_VELOCITY_SCALE (0.3)
- Faster collisions deal more damage, slower collisions deal less
- When health reaches zero, ball explodes with magenta particle burst (24 particles)
- Normal elastic collision physics still apply (no 2x impulse multiplier)

## Previous Behavior
- Cross-board collisions applied 2x impulse multiplier for dramatic effect
- Balls had no health system
- No way for balls to be destroyed by collisions

## Intended Behavior
- Replace violent 2x collision strength with health/damage system
- Faster moving balls deal more damage
- Slower moving balls deal less damage
- Balls explode with particle effects when destroyed

## Implementation Notes
- Added health field to Ball struct in src/006-ball.h
- Added BALL_MAX_HEALTH (100.0f) and DAMAGE_VELOCITY_SCALE (0.3f) constants
- ball_manager_spawn() initializes health to BALL_MAX_HEALTH
- ball_resolve_ball_collision() calculates damage for cross-board collisions:
  - rel_speed = sqrt(rel_vx^2 + rel_vy^2)
  - damage = rel_speed * DAMAGE_VELOCITY_SCALE
  - ball_a->health -= damage
- Added died_from_damage, death_pos_x, death_pos_y to BallTaskData
- ball_update_task() checks if health <= 0 and marks died_from_damage
- main.c spawns 24 magenta particles at death position

## Related Documents
- src/006-ball.h (Ball struct, constants)
- src/007-ball.c (collision and death handling)
- src/001-main.c (particle spawning)

## Notes
- Damage is applied to both balls in a cross-board collision (each ball's task handles its own damage)
- Same-owner collisions (player-player or adversary-adversary) do not deal damage
- Health does not regenerate
- Future: could add health bar visualization or healing mechanics
