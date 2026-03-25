# 316 - Allow Multiple Gate Scoring

## Status: complete

## Depends on

None - self-contained feature change.

## Related Issues

- 317 (GateRow scoring bug) - related scoring behavior
- 318 (Zone dispatch) - would provide cleaner solution for this

## Problem

Currently, balls can only score once per gate passage due to the `passed_gate` flag. If a ball passes through a gate, bounces back up, and goes through again, it doesn't score the second time. This prevents rewarding audacious plays.

## Current Behavior

- Ball enters gate zone → scores → `passed_gate = 1`
- Ball bounces back up and re-enters zone → no score (flag already set)
- Flag only resets on wrap to other board (`037-wrap-zones.c`)

## Intended Behavior

- Ball can score multiple times through the same gate
- Each passage triggers score and ring particle effect
- Reward skillful/lucky plays that send balls back through gates

## Design Options

### Option A: Cooldown Timer

After scoring, brief cooldown before ball can score again at same gate:

```c
typedef struct Ball {
    // ...
    float gate_cooldown;  // Seconds until can score again (0 = ready)
} Ball;

// In ball_update_task
if (zone_index >= 0 && ball->gate_cooldown <= 0) {
    task->scored = 1;
    ball->gate_cooldown = 0.5f;  // Half second cooldown
}

// Decrement each frame
ball->gate_cooldown -= dt;
if (ball->gate_cooldown < 0) ball->gate_cooldown = 0;
```

### Option B: Exit-Based Reset

Reset scoring eligibility when ball fully exits the zone:

```c
typedef struct Ball {
    // ...
    int in_gate_zone;     // Currently inside a gate zone
    int scored_this_zone; // Already scored in current zone visit
} Ball;

// In ball_update_task
int zone_index = ball_check_zone(ball, world);

if (zone_index >= 0) {
    // Entering or inside zone
    if (!ball->in_gate_zone) {
        // Just entered
        ball->in_gate_zone = 1;
        ball->scored_this_zone = 0;
    }

    if (!ball->scored_this_zone) {
        task->scored = 1;
        ball->scored_this_zone = 1;
    }
} else {
    // Outside all zones - reset for next entry
    ball->in_gate_zone = 0;
    ball->scored_this_zone = 0;
}
```

### Option C: Remove Flag Entirely

Simply remove the `passed_gate` check - score every frame ball is in zone:

```c
// In ball_update_task
if (zone_index >= 0) {
    task->scored = 1;  // No flag check
}
```

**Warning:** This would score many times per passage (every frame). Points would multiply rapidly. Not recommended unless combined with per-frame point reduction.

## Recommendation

**Option B (Exit-Based Reset)** provides the cleanest behavior:
- Score once per zone entry
- Ball must fully leave zone before it can score again
- Natural, intuitive behavior
- No arbitrary timers

## Implementation

```c
// Ball struct changes
typedef struct Ball {
    // ... existing fields ...
    int in_zone;          // Currently inside any gate zone (-1 = none, else zone index)
    int scored_current;   // Scored during current zone visit
} Ball;

// In ball_update_task (007-ball.c)
int zone_index = ball_check_zone(next, task->world);

if (zone_index >= 0) {
    // Inside a zone
    if (next->in_zone != zone_index) {
        // Entered new zone (or first time entering)
        next->in_zone = zone_index;
        next->scored_current = 0;
    }

    if (!next->scored_current) {
        task->score_delta = task->world->zones[zone_index].points;
        task->scored = 1;
        task->score_pos_x = next->x;
        task->score_pos_y = next->y;
        next->scored_current = 1;
    }
} else {
    // Outside all zones
    next->in_zone = -1;
    next->scored_current = 0;
}
```

## Files to Modify

- `src/006-ball.h` - Add in_zone and scored_current fields to Ball struct
- `src/007-ball.c` - Update ball_update_task with new scoring logic
- `src/037-wrap-zones.c` - Reset new fields on wrap (if needed)

## Notes

- This encourages creative board designs with bounce-back paths
- High-bounce materials near gates become more valuable
- Could add bonus multiplier for "return trips" (2x on second pass?)
- Ring particle effect will trigger each time, providing feedback

---

## Resolution Notes (2026-03-19)

### Already Fixed by Issue 318 (Zone Dispatch System)

This issue was resolved as part of the zone dispatch system implementation (318).

The zone dispatch system uses a grid-based approach where different zones have different handlers:

1. **Background zones** reset `passed_gate = 0` when ball passes through
2. **Gate zones** score only if `!passed_gate`, then set `passed_gate = 1`
3. **Wrap zones** also reset `passed_gate = 0`

This means balls can score multiple times:
- Ball enters gate from background → scores, `passed_gate = 1`
- Ball exits gate back into background → `passed_gate = 0`
- Ball re-enters gate → scores again!

See `src/046-zone-dispatch.c`:
- Line 72-76: `zone_background()` handler with comment "This is the key to fixing issue 316"
- Line 159, 183: Wrap zone handlers also reset `passed_gate`

### Implementation: Option B (Exit-Based Reset)

The zone dispatch system effectively implements "Option B" from this issue - the ball must exit the gate zone (entering background or wrap zone) before it can score again.

No code changes were required - just verification that 318's implementation solves 316.
