# Issue 802: Improve Spawn Point Visual Display

## Current Behavior

The spawn point has two visual elements:
1. Pulsing white circle (spawn indicator) - works well
2. Cooldown arc (DrawRing) - appears as a partial circle that fills up

The cooldown indicator appears as an incomplete circle (3/4 arc with top-right
missing) due to the arc starting at 0 degrees and filling clockwise. The reddish
color (255, 100, 100) may appear orange-ish to some users.

## Intended Behavior

Clean up the cooldown visual to be more polished:
1. Full ring that depletes smoothly rather than partial arc
2. Clearer visual distinction between "ready" and "cooling down"
3. Consider starting angle so the arc fills more intuitively
4. Potentially change color to better match visual theme

## Suggested Implementation Steps

1. Review DrawRing parameters and arc angles
2. Option A: Draw full ring, then overlay with depleting arc
3. Option B: Draw arc that shrinks from full to empty
4. Option C: Draw full ring with alpha based on cooldown
5. Consider starting from top (270 degrees) instead of right (0 degrees)
6. Adjust color to match overall color scheme

## Design Notes

Current code:
```c
DrawRing((Vector2){SPAWN_X, SPAWN_Y}, 18.0f, 20.0f,
         0, end_angle, 32, (Color){255, 100, 100, 200});
```

Raylib angles: 0 = right (3 o'clock), 90 = bottom, 180 = left, 270 = top
To start from top: use startAngle = -90 or 270

Possible improvements:
- Start from top, fill clockwise as cooldown depletes
- Or show remaining cooldown (shrinking arc) instead of elapsed

## Success Criteria

- Cooldown visual is clean and intuitive
- Clear indication of "ready to spawn" vs "cooling down"
- Consistent with overall visual design
- Compiles with no warnings

## Status

- [x] Complete

## Implementation Notes

Redesigned cooldown indicator (src/001-main.c:357-373).

New visual system:
1. **Cooling down state:**
   - Background: Full dim ring (60, 60, 80) shows circumference
   - Foreground: Bright cyan arc (100, 200, 255) shows remaining time
   - Arc starts from top (-90 degrees), shrinks clockwise as time passes

2. **Ready state:**
   - Full green ring (100, 255, 150) indicates spawn is ready

Visual improvements:
- Clear distinction between "ready" and "cooling down"
- Arc starts from intuitive top position (12 o'clock)
- Colors match overall theme (cyan/green vs old red)
- Background ring provides context for arc position
