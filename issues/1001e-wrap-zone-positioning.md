# 1001e - Wrap Zone Positioning

## Status: Needs Testing (likely fixed by 1001c)

## Parent Issue: 1001 - Sprint Remediation

## Current Behavior

Adversary balls are not being removed when they reach the top wrap zone. Balls continue upward past the expected wrap boundary.

## Intended Behavior

1. Player balls falling past bottom of screen should wrap to top
2. Adversary balls rising past top of screen should wrap to bottom
3. Both should reset `passed_gate` flag after wrapping
4. Ball should appear at mirrored position in opposite zone

## Investigation Areas

### 1. Zone Position Calculation (wrap-zones.c:51-77)

```c
float viewable_top = world->table_top - screen_height;
float viewable_bottom = world->adversary_table_bottom + screen_height;
zones->top_zone_y = viewable_top - zones->zone_height;
zones->bottom_zone_y = viewable_bottom;
```

**Potential Issue**: If `world->adversary_table_bottom` isn't set correctly by slot manager, zones are in wrong positions.

### 2. Ball Wrap Check (wrap-zones.c:80-121)

The check for adversary balls (lines 104-117):
```c
float top_zone_bottom = zones->top_zone_y + zones->zone_height;
if (ball->y + ball->radius < top_zone_bottom) {
    // Wrap ball to bottom zone
}
```

**Potential Issue**: The comparison `ball->y + ball->radius < top_zone_bottom` may never be true if:
- Ball Y values don't match zone coordinate space
- Zone is positioned below where balls actually travel

### 3. Wrap Zone Check Not Being Called

Comment in main.c:1259 says wrap checking happens in ball physics, but need to verify:
- `ball_update_task` calls `wrap_zones_check_ball`
- World has `wrap_zones` pointer set correctly

## Debugging Steps

1. Print wrap zone Y positions at startup
2. Print ball Y positions as they move
3. Verify `world->wrap_zones` is not NULL in ball physics
4. Add printf when wrap check succeeds/fails

## Files to Modify

- `src/037-wrap-zones.c` - Verify position calculations
- `src/007-ball.c` - Verify wrap check is called
- `src/001-main.c` - Verify wrap zones attached to world

## Analysis

After reviewing the code:
- `wrap_zones_check_ball()` is correctly called in ball physics (ball.c:1424)
- `world->wrap_zones` is correctly attached in main.c:791
- Zone calculations look mathematically correct

The wrap zone failure was likely a downstream effect of the adversary board flip formula bug (1001c).
With objects at correct positions, balls should now travel to wrap zones correctly.

## Related Issues

- Issue 1001c: Adversary flip formula fix (likely root cause)
- Issue 1221: Slot manager positioning
