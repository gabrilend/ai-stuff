# 317 - GateRow Scoring Never Called

## Status: awaiting-work

## Depends on

None - bug fix.

## Related Issues

- 316 (Multiple gate scoring) - related scoring behavior
- 318 (Zone dispatch) - would solve this more comprehensively
- 903 (Velocity statistics) - may help diagnose tunneling

## Problem

After stage expansion, new GateRows are created with their own ScoreZone arrays. However, `stage_manager_check_ball_score()` (which checks these zones) is never called in the main game loop. This means balls passing through expanded gate rows don't trigger scoring or particle effects.

## Current Behavior

- Original `world->zones` (7 zones) are checked by `ball_check_zone()` in `ball_update_task()`
- During expansion, `world->zones` are shifted down via `world_shift_zones()`
- New GateRows are added via `stage_manager_add_gate_row()` at the original position
- GateRows have their own `zones` array that is rendered but NEVER checked for scoring
- `stage_manager_check_ball_score()` exists but is never invoked

## Intended Behavior

- All gate zones (both `world->zones` and GateRow zones) should trigger scoring
- Balls passing through any visible gate should spawn ring particle effects
- Score should reflect the zone's point value (including multipliers for expanded gates)

## Technical Analysis

### Code Flow

1. **Initialization:**
   - `world_generate_zones()` creates 7 zones in `world->zones`
   - These are positioned at `table_bottom + 50px`

2. **During expansion:**
   - `world_shift_zones()` shifts `world->zones` down
   - `stage_manager_add_gate_row()` creates new GateRow with zones at original position
   - GateRow zones have their own bounds and multipliers

3. **Each frame:**
   - `ball_check_zone(ball, world)` only checks `world->zones` (shifted position)
   - `stage_manager_check_ball_score()` is NEVER called
   - Balls pass through visible GateRow without scoring

### Relevant Code

```c
// src/007-ball.c:963-973 - Only checks world->zones
if (next->active) {
    int zone_index = ball_check_zone(next, task->world);
    if (zone_index >= 0 && !next->passed_gate) {
        task->score_delta = task->world->zones[zone_index].points;
        task->scored = 1;
        // ...
    }
}

// src/015-stage.c:685-698 - Never called!
int stage_manager_check_ball_score(StageManager* manager, Ball* ball) {
    if (!manager || !ball) return 0;
    if (!ball->active) return 0;

    for (int i = 0; i < manager->gate_row_count; i++) {
        int points = gate_row_check_ball_score(&manager->gate_rows[i], ball);
        if (points > 0) {
            return points;
        }
    }
    return 0;
}
```

## Proposed Solution

### Option A: Integrate GateRow zones into world->zones

When creating GateRows, add their zones to `world->zones` instead of storing them separately:

```c
// In stage_manager_add_gate_row
for (int i = 0; i < zone_count; i++) {
    world_add_zone(world, zone_x_min, zone_x_max,
                   zone_y_min, zone_y_max, points);
}
```

**Pros:** Single unified zone checking system
**Cons:** Need to track which zones belong to which GateRow for rendering

### Option B: Call stage_manager_check_ball_score in game loop

Add the check to `ball_update_task()` after the existing zone check:

```c
// After existing world->zones check
if (!task->scored && world->stages) {
    int gate_points = stage_manager_check_ball_score(world->stages, next);
    if (gate_points > 0 && !next->passed_gate) {
        task->score_delta = gate_points;
        task->scored = 1;
        task->score_pos_x = next->x;
        task->score_pos_y = next->y;
        next->passed_gate = 1;
    }
}
```

**Pros:** Minimal changes, preserves existing structure
**Cons:** Two separate scoring systems, potential for inconsistencies

### Option C: Unified scoring function

Create a single `check_all_zones()` function that checks both systems:

```c
int check_all_zones(Ball* ball, World* world) {
    // Check world->zones first
    int zone_idx = ball_check_zone(ball, world);
    if (zone_idx >= 0) {
        return world->zones[zone_idx].points;
    }

    // Then check GateRow zones
    if (world->stages) {
        return stage_manager_check_ball_score(world->stages, ball);
    }

    return 0;
}
```

**Pros:** Clean API, single point of truth for scoring
**Cons:** Requires updating all callers

## Recommendation

**Option B** is the quickest fix. Option C is cleaner for long-term maintenance.

## Implementation Steps

1. In `ball_update_task()`, add check for `stage_manager_check_ball_score()` after existing zone check
2. Ensure `passed_gate` flag is respected for GateRow zones too
3. Test with stage expansion: balls should score at ALL gate rows
4. Verify ring particle effects trigger for GateRow scoring
5. Consider refactoring to Option C after confirming fix works

## Files to Modify

- `src/007-ball.c` - Add GateRow scoring check in `ball_update_task()`

## Testing Checklist

- [ ] Score at original gates (before expansion)
- [ ] Score at original gates (after expansion, now shifted down)
- [ ] Score at new GateRow gates (after expansion)
- [ ] Ring particle effects for all scoring events
- [ ] Multipliers applied correctly for expanded gates

## Related Issues

- **903** (Ball Velocity Statistics): May help diagnose tunneling through zones
- **316** (Multiple Gate Scoring): Scoring flag reset behavior

## Discovery Context

Found during investigation of "balls passing through gates without triggering ring particle effect". Initial hypothesis was tunneling (issue 903 may help diagnose), but analysis revealed this architectural issue with GateRow zones never being checked.
