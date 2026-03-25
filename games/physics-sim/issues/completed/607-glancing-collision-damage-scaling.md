# Issue 814: Glancing Collision Damage Scaling

## Current Behavior

- Damage calculated from total relative speed: `sqrt(rel_vx² + rel_vy²)`
- Two balls moving parallel but barely grazing deal high damage
- Glancing blows cause explosions when they should just deflect

## Intended Behavior

- Damage based on "closing speed" - velocity component along collision normal
- Head-on collisions: high damage (full relative velocity transfers)
- Glancing blows: low/no damage (balls sliding past each other)
- Feels physically intuitive: harder hits do more damage

## Technical Analysis

The collision normal `(nx, ny)` points from ball B to ball A. The relative velocity
is `(rel_vx, rel_vy) = A.vel - B.vel`.

The closing speed is: `vn = rel_vx * nx + rel_vy * ny`

- If `vn < 0`: balls are approaching (collision response needed)
- If `vn ≈ 0`: balls are moving perpendicular (glancing blow)
- Magnitude of `vn` indicates impact strength

Current damage: `damage = sqrt(rel_vx² + rel_vy²) * DAMAGE_VELOCITY_SCALE`
Fixed damage: `damage = abs(vn) * DAMAGE_VELOCITY_SCALE`

## Suggested Implementation Steps

1. In `ball_resolve_ball_collision`, change damage calculation:
   - Replace `rel_speed = sqrt(rel_vx² + rel_vy²)` with `abs(vn)`
   - `vn` is already calculated for collision response

2. Optionally adjust DAMAGE_VELOCITY_SCALE if damage feels too low/high

## Status

Complete

## Implementation Notes

Changed damage calculation in `ball_resolve_ball_collision`:
- Old: `damage = sqrt(rel_vx² + rel_vy²) * DAMAGE_VELOCITY_SCALE`
- New: `damage = (-vn) * DAMAGE_VELOCITY_SCALE`

Where `vn` is the velocity component along the collision normal (already calculated
for collision response). Since `vn < 0` when balls are approaching, `-vn` gives
positive closing speed.

Head-on collision: `vn ≈ -rel_speed`, full damage
Glancing blow: `vn ≈ 0`, minimal damage

Files: 007-ball.c
