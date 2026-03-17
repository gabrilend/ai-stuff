# Issue 501: Implement Score Zone Detection

## Current Behavior

Score zones are generated and rendered at the bottom of the screen, but
there is no detection logic. Balls fall through the bottom and are
deactivated when they leave the screen bounds, but no scoring occurs.

ScoreZone structure exists with x_min, x_max, and points fields.
ZONE_TOP_Y constant (560.0f) defines the top of the score zone area.

## Intended Behavior

Detection system that identifies when a ball enters a score zone:
- Check if ball y-position is below ZONE_TOP_Y
- Check if ball x-position is within zone x_min to x_max
- Return zone index and point value when ball is captured
- Integrate with ball update to check zones during physics

## Suggested Implementation Steps

1. Create ball_check_zone() function in src/007-ball.c:
   ```c
   // {{{ ball_check_zone
   // Checks if a ball has entered a score zone.
   // Returns zone index (0 to zone_count-1) if captured, -1 otherwise.
   //
   // Parameters:
   //   ball: Ball to check
   //   world: World containing score zones
   //
   // Returns:
   //   Zone index if captured, -1 if not in any zone
   int ball_check_zone(Ball* ball, World* world);
   // }}}
   ```

2. Implement ball_check_zone():
   - Check if ball->y > ZONE_TOP_Y (entered zone area)
   - Check if ball->active is true
   - Loop through world->zones
   - Check if ball->x >= zone->x_min && ball->x < zone->x_max
   - Return zone index if found, -1 otherwise

3. Add declaration to src/006-ball.h

4. Update src/006-ball.info.md documentation

5. Test compilation with no warnings

## Design Notes

Detection approach:
- Simple bounding box check (x within zone, y below threshold)
- Ball center point used for detection (not radius)
- Check happens after physics update completes
- Zone index returned for scoring lookup

Why return zone index:
- Caller can look up point value from world->zones[index].points
- Enables future zone-specific effects
- -1 indicates no zone (ball still falling or out of bounds)

Thread safety:
- ball_check_zone() is read-only on world
- Can be called from parallel ball update tasks
- No writes to shared state

## Success Criteria

- ball_check_zone() detects balls in score zones
- Returns correct zone index when ball is within zone bounds
- Returns -1 when ball is not in any zone
- Works with existing zone layout (7 zones)
- Compiles with no warnings

## Related Documents

- [004-world.h](../src/004-world.h)
- [006-ball.h](../src/006-ball.h)

## Dependencies

- Issue 201 (World state structure) - Completed (Phase 2)
- Phase 4 (Parallel processing) - Completed

## Status

- [ ] Pending
