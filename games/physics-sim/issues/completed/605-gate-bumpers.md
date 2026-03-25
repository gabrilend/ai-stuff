# Issue 808 - Gate Bumpers

## Status
Complete

## Current Behavior
Gate dividers are simple vertical separators between score zones. Balls bounce
off them with standard wall collision physics (60% restitution). No special
behavior at the top of dividers where balls typically make first contact.

## Intended Behavior
- Add bumper caps at top of each gate divider (player board)
- Add bumper caps at bottom of each gate divider (adversary board)
- Bumpers have distinct color from dividers (softer/rubberier appearance)
- Bumpers have low restitution ("magnetic" or "dense" feel)
- Balls hitting bumpers donk softly and slide into adjacent gate
- Creates more predictable gate entry, reduces chaotic bouncing at gate level

## Suggested Implementation Steps

1. **Define bumper geometry**
   - Bumper is small circle or rounded cap on divider end
   - Radius: ~10-12 pixels (slightly wider than divider)
   - Position: centered on top of each divider (player side)
   - Position: centered on bottom of each divider (adversary side)

2. **Add bumper data to World structure**
   - Array of bumper positions (or derive from zone boundaries)
   - Bumper radius constant
   - Could reuse Peg struct or create Bumper struct

3. **Implement bumper collision**
   - Circle-circle collision (like pegs)
   - Very low restitution (0.2-0.3)
   - Possibly add slight downward bias to velocity
   - Formula: `vy += BUMPER_PULL * dt` after collision

4. **Render bumpers**
   - Distinct color: muted purple, dark teal, or rubber-brown
   - Slightly darker/different from gate colors
   - Could add subtle glow or soft edge effect

5. **Tune physics feel**
   - Test restitution values (0.2-0.4 range)
   - Consider adding velocity damping on contact
   - Goal: ball "sticks" briefly then slides into gate
   - Should feel satisfying, not frustrating

6. **Add adversary bumpers**
   - Same logic but at bottom of dividers
   - Adversary balls approaching from below hit these
   - Same physics behavior

## Physics Notes

**Standard wall bounce:**
```
vy = -vy * 0.6  // 60% energy retained
```

**Bumper bounce (proposed):**
```
// Low restitution
vx = vx * 0.3
vy = -vy * 0.25

// Optional: gentle pull toward gate center
// (applied after collision resolution)
vy += sign(vy) * BUMPER_PULL
```

**Alternative: "sticky" collision**
```
// Kill most horizontal velocity
vx *= 0.2
// Minimal vertical bounce
vy = -vy * 0.15
// Let gravity take over
```

## Visual Design Ideas

- **Rubber bumper**: Dark brown/gray, matte texture
- **Magnetic bumper**: Deep purple with subtle glow
- **Cushion bumper**: Teal/cyan, soft rounded appearance
- **Dense bumper**: Gunmetal gray, industrial look

## Dependencies
- None (can be implemented before adversary system)
- Will need adversary bumpers added when Issue 804 is complete

## Related Documents
- src/005-world.c (zone rendering, divider positions)
- src/007-ball.c (collision physics)

## Notes
- Bumpers should feel helpful, not punishing
- Player should learn to aim for bumpers to guide balls
- Creates skill expression: intentionally hitting bumper for zone targeting
- Consider particle effect when ball hits bumper (soft puff?)

## Implementation Log

### Changes Made

**src/004-world.h:**
- Added Bumper struct (x, y, radius)
- Added bumpers array and bumper_count to World struct
- Added world_generate_bumpers() and world_render_bumpers() declarations

**src/005-world.c:**
- Initialize bumpers to NULL in world_create()
- Free bumpers in world_destroy()
- Implemented world_generate_bumpers(): places bumpers at x_max of each zone
  at zone y_min (top of gates), creating N-1 bumpers for N zones
- Implemented world_render_bumpers(): muted teal circles (80, 140, 140)

**src/006-ball.h:**
- Added BUMPER_RADIUS (10.0f) and BUMPER_RESTITUTION (0.15f) constants

**src/007-ball.c:**
- Added ball_check_bumper_collision(): circle-circle detection like pegs
- Added ball_resolve_bumper_collision(): very low restitution (0.15) plus
  tangential velocity damping (0.7) for "sticky" feel that slides balls
  into gates
- Added ball_collide_with_bumpers(): checks all bumpers
- Integrated bumper collision into ball_manager_update() and ball_update_task()

**src/001-main.c:**
- Added world_generate_bumpers() call after zone generation
- Added world_generate_bumpers() call in resize handler
- Added world_render_bumpers() call in render loop

### Physics Tuning

- BUMPER_RESTITUTION = 0.15 (very low bounce)
- Tangential damping = 0.7 (reduces sideways deflection)
- Combined effect: balls hit bumper, lose most energy, drop straight down
- Adversary bumpers deferred until Issue 804 (board layout)
