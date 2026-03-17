# Issue 808 - Gate Bumpers

## Status
Pending

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
