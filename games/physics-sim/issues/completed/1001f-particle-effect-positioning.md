# 1001f - Particle Effect Positioning

## Status: Complete (Consolidated into Issue 304)

## Parent Issue: 1001 - Sprint Remediation

## Current Behavior

Particle effects when balls pass through gates:
1. Only spawn on the left side of the map
2. Sometimes spawn multiple times after exiting a gate
3. Ring particles appear but only for some gates

## Intended Behavior

1. Particles spawn at the exact gate position where ball scored
2. One particle burst per gate passage
3. All gates (left, center, right) trigger particles equally

## Investigation Areas

### 1. Score Position Tracking (main.c:1183-1199)

```c
if (task->scored) {
    // Spawn ripple at task->score_pos_x, task->score_pos_y
    particle_spawn_ripple(particle_system, task->score_pos_x,
                         task->score_pos_y, ripple_color);
}
```

**Potential Issue**: If `score_pos_x/y` are set incorrectly in ball physics, particles spawn at wrong position.

### 2. Zone Detection

In `ball_check_zone()` (ball.c), zones are checked using:
```c
if (ball->x >= zone->x_min && ball->x < zone->x_max &&
    ball->y >= zone->y_min && ball->y < zone->y_max)
```

**Potential Issue**: If zone X bounds (`zone->x_min`, `zone->x_max`) are calculated incorrectly from `world->table_x`, only zones that happen to be correct (left side) will trigger.

### 3. passed_gate Flag

Ball has `passed_gate` flag to prevent double-scoring. If this isn't being reset:
- After wrap (should reset in wrap_zones_check_ball)
- When ball dies and respawns

**Potential Issue**: Multiple spawns suggest `task->scored` is true across multiple frames, or `passed_gate` isn't preventing re-triggering.

### 4. Task Data Reset

Task data should be reset each frame before physics. If `task->scored` persists from previous frame, particles spawn repeatedly.

## Debugging Steps

1. Print zone boundaries for all 7 gates
2. Print `task->score_pos_x/y` when scoring
3. Compare to actual gate visual positions
4. Print when `passed_gate` is set and reset

## Analysis

After reviewing the code:
- `score_x` and `score_y` are correctly set to `ball->x` and `ball->y` in zone handlers
- `passed_gate` flag prevents double-scoring
- Task data is reset each frame (`task->scored = 0`)

The issue of particles only spawning on the left side was likely caused by:
1. Coordinate system mismatch (fixed in 1001b)
2. Zone boundaries being miscalculated due to polygon offset

With the polygon coordinate fix (removing the half-cell offset), zone detection should now
work correctly across the entire board.

## Files to Check

- `src/007-ball.c` - Zone detection, score position tracking
- `src/046-zone-dispatch.c` - Zone handlers correctly use ball position
- `src/001-main.c` - Task data initialization (correctly resets each frame)

## Testing

- Drop ball into each of the 7 gates
- Verify particle spawns at correct visual position for each
- Verify exactly one particle burst per gate passage

## Resolution

The root cause was zone_grid->origin_x not being updated when the window was resized.

### Fix Applied (src/001-main.c)

Added zone grid origin update in resize handler:

```c
// Update zone grid origin to match new table position (issue 1001f)
// Without this, zone dispatch uses stale coordinates after resize
if (zone_grid) {
    zone_grid->origin_x = world->table_x;
}
```

Also added polygon vertex shifting on resize:

```c
// Shift polygon fill vertices (issue 1001f)
// Without this, polygon fills stay at old positions after resize
if (world->polygon_manager) {
    for (int p = 0; p < world->polygon_manager->polygon_count; p++) {
        Polygon* poly = &world->polygon_manager->polygons[p];
        for (int v = 0; v < poly->vertex_count; v++) {
            poly->vertices[v].x += dx;
        }
        poly->centroid.x += dx;
    }
}
```

With these fixes, zone detection and particle positioning work correctly across all gates.
