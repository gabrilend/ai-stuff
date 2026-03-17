# Issue 803 - Ball Radius Upgrade

## Status
Pending

## Current Behavior
Ball radius is fixed at BALL_RADIUS (8.0f). All balls are the same size.

## Intended Behavior
- "Ball Size" upgrade available in upgrade menu
- Each level decreases ball radius slightly
- Smaller balls navigate peg grid differently
- Affects collision detection and visual rendering

## Suggested Implementation Steps

1. **Define upgrade parameters**
   - Base cost: 150 points
   - Radius reduction per level: -1.0f
   - Maximum level: 3 (minimum radius 5.0f)
   - Cost scaling: 150, 300, 450

2. **Add radius modifier to World or BallManager**
   - ball_radius_modifier field (negative value)
   - Effective radius = BALL_RADIUS + ball_radius_modifier
   - Clamp minimum to prevent zero/negative radius

3. **Register upgrade in UpgradeManager**
   - ID: UPGRADE_BALL_SIZE
   - Name: "Ball Size"
   - Description: "-1 radius"
   - Apply function: decreases ball_radius_modifier

4. **Update ball spawning**
   - ball_manager_spawn() uses effective radius
   - New balls spawn with modified radius

5. **Verify physics interactions**
   - Peg collision uses ball->radius (already dynamic)
   - Wall collision uses ball->radius
   - Ball-ball collision uses ball->radius
   - Spawn blocking uses effective radius

6. **Update visual elements**
   - Spawn reticle size matches effective ball radius
   - Highlight rendering scales with ball size

## Dependencies
- Issue 801 (Upgrade System Framework) must be complete

## Related Documents
- src/006-ball.h (Ball struct, BALL_RADIUS constant)
- src/007-ball.c (ball_manager_spawn, collision functions)

## Notes
- Smaller balls may score more (fit through tighter gaps)
- Smaller balls may score less (affected more by peg bounces)
- This creates interesting strategic choice for players
- Consider visual distinction (color/shade by size?)
