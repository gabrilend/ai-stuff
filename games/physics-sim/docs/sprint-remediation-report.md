# Sprint Remediation Report

**Date**: 2026-03-21
**Status**: Investigation Complete
**Phases Involved**: Primarily Phase 9 (Issues 901, 902, 903)

## Executive Summary

After several sprints without review, the physics simulator has accumulated multiple interconnected bugs affecting rendering, spawning, collision, and zone systems. This report identifies root causes and provides a remediation plan.

## Observed Symptoms

| # | Symptom | Severity | Likely Cause |
|---|---------|----------|--------------|
| 1 | Strange textures all over | High | Polygon fill system (837) + coordinate mismatch |
| 2 | Player balls don't spawn | Critical | Spawner blocking check or position |
| 3 | Invisible obstacles | High | Polygon collision without render, rotor physics |
| 4 | Obstacles in wrong places | High | Grid coordinate transformation errors |
| 5 | Lines everywhere | Medium | Track segment rendering, debug mode |
| 6 | Wrap zones not working | High | Position calculation in wrap_zones_update |
| 7 | Particle effects broken | Medium | Gate detection, passed_gate flag management |

## Root Cause Analysis

### 1. Strange Textures (Polygon Fill System)

**Files**: `src/043-polygon.c`, `src/001-main.c:1287-1292`

**Issue**: The polygon manager (issue 837) renders closed polygon fills before board objects. The `polygon_manager_rebuild_offset` function applies origin offsets to polygon vertices, but if the board dimensions or cell sizes don't match expectations, polygons render at incorrect locations.

**Specific Problem**: In `find_all_intersections()` (line 299-333), guard rails are added at positions relative to `board_width` and `board_height`, which are calculated from grid dimensions. If the grid to pixel conversion uses different cell sizes at different stages, the polygon boundaries won't align with the actual board.

**Evidence**:
- Polygon vertices use: `obj->col * cell_size + cell_size / 2.0f` (line 307-311)
- Board objects use: `grid_to_pixel_x(&grid, obj->col, obj->row)` in main.c (line 201)
- These calculations may diverge if cell_size differs

### 2. Player Balls Not Spawning

**Files**: `src/041-spawner.c`, `src/001-main.c:866-882`

**Issue**: The `spawner_try_spawn` function (line 147-172) has three blocking conditions:
1. `credits < 1.0f` - Should be fine, player starts with 1.0
2. `spawner_is_blocked()` - Checks for same-owner balls within 3x radius
3. `manager->active_count >= manager->capacity` - Capacity check

**Specific Problem**: Looking at `spawner_is_blocked()` (lines 25-46), it filters by `owner_filter` but passes `spawner->owner` which is `OWNER_PLAYER (0)`. The loop checks `ball->owner != owner_filter` but with `owner_filter = 0`, it may be incorrectly skipping player balls when intended to check them, or there's an off-by-one issue.

**Secondary Issue**: The player spawner Y position comes from `slot_manager_get_player_spawn_y()` which returns `player_reticle_y`. If slot manager calculations are wrong, the spawn position could be outside valid bounds.

**Evidence**:
- Adversary uses same spawner code and works
- Adversary spawner is created with `adversary_create()` which uses its own positioning
- Difference: adversary spawner position set in `adversary.c`, player spawner set in `main.c`

### 3. Invisible Obstacles

**Files**: `src/043-polygon.c`, `src/044-rotor.c`, `src/007-ball.c`

**Issue**: Multiple collision systems can create invisible obstacles:

1. **Polygon Collision** (`polygon_check_ball_collision`, line 809-851): Balls collide with closed polygon fills, which may exist where no visible geometry is rendered if polygon detection found spurious cycles.

2. **Rotor Physics** (issue 901c): Lines attached to rotors move based on rotation angle, but if `rotor_manager_update_rotor_positions` isn't being called correctly, collision happens at original positions while rendering happens at rotated positions.

3. **Track Movers** (issues 902c, 902d): Similar to rotors - payload objects move along tracks, but collision vs rendering position mismatch.

**Evidence**:
- `is_dynamic` flag added in issue 901f marks moving objects
- Ball collision code checks `is_dynamic` for stress accumulation
- If rendering uses different positions than collision detection, invisible obstacles appear

### 4. Obstacles in Wrong Places

**Files**: `src/001-main.c`, `src/022-grid.c`, `src/021-board-data.c`

**Issue**: Grid-to-pixel coordinate conversion happens in multiple places with potential inconsistency:

1. **Player board**: `apply_initial_board_data()` (main.c:160-255)
   - Uses `grid_to_pixel_x(&grid, obj->col, obj->row)`
   - Grid created with `peg_start_x` and `peg_start_y`

2. **Adversary board**: `apply_adversary_board_data()` (main.c:258-369)
   - Uses vertical flip: `flipped_row = data->grid_rows - obj->row`
   - This inversion may cause off-by-one errors at grid boundaries

3. **Polygon manager**: `polygon_manager_rebuild_offset()`
   - Uses different calculation: `obj->col * cell_size + cell_size / 2.0f`

**Specific Problem**: The adversary flip formula `grid_rows - obj->row` doesn't account for 0-indexing properly. For a 22-row grid:
- Row 0 becomes row 22 (out of bounds conceptually)
- Row 21 becomes row 1

This should be `grid_rows - 1 - obj->row` for proper mirroring.

### 5. Lines Everywhere

**Files**: `src/035-object-render.c`, `src/001-main.c`

**Issue**: Track segments are rendered by `render_board_tracks()` (object-render.c:372-389), which renders ALL track segments in the board data. However:

1. Track segments should only be visible in the editor, not in gameplay
2. Debug rendering for wrap zones (`wrap_zones_render_debug`) is enabled by default (`debug_visible = 1` in wrap-zones.c:31)
3. Rotor-connected lines may be rendered at both original and rotated positions

**Evidence**:
- `wrap_zones->debug_visible = 1` at creation (wrap-zones.c:31)
- No conditional check before rendering tracks in main.c

### 6. Wrap Zones Not Working

**Files**: `src/037-wrap-zones.c`, `src/007-ball.c`

**Issue**: The `wrap_zones_check_ball()` function (lines 80-121) checks if balls should wrap based on:
- Player balls going DOWN into `bottom_zone_y`
- Adversary balls going UP into `top_zone_y`

**Specific Problems**:

1. **Zone position calculation** (wrap_zones_update, lines 51-77):
   ```c
   float viewable_top = world->table_top - screen_height;
   float viewable_bottom = world->adversary_table_bottom + screen_height;
   zones->top_zone_y = viewable_top - zones->zone_height;
   zones->bottom_zone_y = viewable_bottom;
   ```

   If `world->adversary_table_bottom` isn't set correctly (e.g., if slot_manager calculations are wrong), zones are positioned incorrectly.

2. **Ball wrap check** relies on `ball->owner`, but if balls have wrong owner assignments, they won't wrap.

3. **The wrap check isn't being called** - Looking at main.c, there's a comment "Wrap zone checking now happens in ball physics" (line 1259), but I need to verify this is actually implemented in `ball_update_task`.

### 7. Particle Effects Only on Left Side

**Files**: `src/001-main.c:1169-1224`, `src/007-ball.c`

**Issue**: Particle spawning happens in the main loop after physics, iterating through `ball_manager->task_data`. The check at line 1183:

```c
if (task->scored) {
    // Spawn ripple at task->score_pos_x, task->score_pos_y
}
```

**Specific Problems**:

1. **Gate scoring position**: `score_pos_x` and `score_pos_y` are set in ball physics when a ball scores. If zone boundaries are calculated incorrectly (only accurate on the left side), only left-side scoring triggers particles.

2. **passed_gate flag**: Ball's `passed_gate` flag (ball.h:177) prevents double-scoring. If this flag isn't being reset properly after wrap or respawn, balls won't score again.

3. **Multiple particle spawns**: The comment mentions "multiple times after exiting the gate" - this could happen if `task->scored` isn't being reset between frames, or if the score_delta calculation runs multiple times.

**Evidence**:
- Particles work "sometimes" and "only on left side"
- Zone boundaries are calculated from `world->table_x + i * zone_width`
- If `world->table_x` is wrong, zones shift

## Affected Systems Dependency Graph

```
SlotManager (positioning source of truth)
    │
    ├── World bounds (table_x, table_width, etc.)
    │       │
    │       ├── Zone generation
    │       │       └── Gate scoring
    │       │               └── Particle effects
    │       │
    │       ├── Wrap zone positioning
    │       │       └── Ball wrapping
    │       │
    │       └── Board positioning
    │               ├── Peg/Line positions
    │               └── Polygon detection
    │
    ├── Player spawner position
    │       └── Ball spawning
    │
    └── Adversary spawner position
            └── Ball spawning (working)
```

## Remediation Plan

### Phase 1: Critical Fixes (Player Spawning)

1. **Issue 10XX-a**: Verify spawner position bounds
   - Check `slot_manager_get_player_spawn_y()` returns valid Y
   - Verify `spawner_set_bounds()` sets valid X range
   - Add debug logging to spawner_try_spawn

2. **Issue 10XX-b**: Fix spawner blocking logic
   - Review `owner_filter` logic in `spawner_is_blocked()`
   - Ensure correct comparison for owner matching

### Phase 2: Coordinate System Fixes

3. **Issue 10XX-c**: Fix adversary board flip formula
   - Change `grid_rows - obj->row` to `grid_rows - 1 - obj->row`
   - Apply to both peg and line flipping

4. **Issue 10XX-d**: Unify grid-to-pixel conversion
   - Create single source of truth for coordinate conversion
   - Use `grid_to_pixel_x/y` consistently everywhere
   - Update polygon manager to use same conversion

### Phase 3: Rendering Fixes

5. **Issue 10XX-e**: Disable debug rendering by default
   - Set `wrap_zones->debug_visible = 0` at creation
   - Add runtime toggle if needed

6. **Issue 10XX-f**: Conditionally render track segments
   - Only render in editor mode, not gameplay
   - Add game/editor mode flag

7. **Issue 10XX-g**: Fix polygon fill alignment
   - Ensure polygon vertices use same coordinate system as board objects
   - Verify origin offsets are applied correctly

### Phase 4: Physics System Fixes

8. **Issue 10XX-h**: Verify wrap zone ball checking
   - Confirm `wrap_zones_check_ball` is called in ball physics
   - Fix zone position calculations

9. **Issue 10XX-i**: Fix particle spawn positioning
   - Verify score position tracking in ball physics
   - Reset `passed_gate` flag appropriately
   - Clear `task->scored` between frames

### Phase 5: Integration Testing

10. **Issue 10XX-j**: Create validation test
    - Test all systems together
    - Verify ball lifecycle: spawn → physics → score → wrap → respawn
    - Verify rendering matches collision positions

## Files Requiring Changes

| File | Changes Needed |
|------|---------------|
| `src/001-main.c` | Coordinate conversion, debug flags |
| `src/037-wrap-zones.c` | Default debug off, position calculation |
| `src/041-spawner.c` | Blocking logic review |
| `src/043-polygon.c` | Coordinate alignment |
| `src/007-ball.c` | Wrap zone integration, scoring |
| `src/039-slot-manager.c` | Verify calculations |

## Testing Strategy

1. **Unit tests**: Add coordinate conversion tests
2. **Integration tests**: Ball lifecycle test
3. **Visual validation**: Screenshot comparison before/after fixes
4. **Performance check**: Ensure fixes don't regress performance

## Notes

- The root cause appears to be a coordinate system mismatch introduced during Phase 9 development
- Many systems depend on `SlotManager` for positioning - if it's wrong, everything downstream breaks
- The adversary board flip formula is likely the most impactful bug to fix first
- Debug rendering being enabled by default explains the "lines everywhere" symptom

## Related Issues

- Issue 837: Closed polygon detection and fill
- Issue 838: Standardize board dimensions
- Issue 901: Rotor system
- Issue 902: Track mover system
- Issue 903: Ball velocity statistics (debugging tool)
- Issue 1220: Board positioning on resize
- Issue 1221: Slot manager positioning

## Next Steps

1. Create tracking issue `10XX-sprint-remediation`
2. Create sub-issues for each fix item
3. Begin with Phase 1 (player spawning) as it's critical functionality
4. Progress through phases, testing at each milestone
