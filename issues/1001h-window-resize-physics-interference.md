# 1001h - Window Resize Affects Ball Physics

## Status: Open

## Parent Issue: 1001 - Sprint Remediation

## Current Behavior

Resizing the window causes unexpected changes to ball physics behavior. Balls may:
- Jump to different positions
- Change velocity
- Collide with objects at wrong positions
- Phase through obstacles they shouldn't

## Intended Behavior

Window resize should ONLY affect:
- Viewport/camera positioning
- UI element positioning
- Table horizontal centering

Ball physics should be completely unaffected by window resize operations.

## Investigation Areas

### 1. Resize Handler (main.c:989-1059)

On resize, the code:
```c
// Update world dimensions
world->width = screen_width;
world->height = screen_height;

// Shift pegs/lines by dx
float dx = new_table_x - old_table_x;
for (int i = 0; i < world->peg_count; i++) {
    world->pegs[i].x += dx;
}
// ... same for lines, adversary objects, spawner
```

**Critical Issue**: Pegs and lines are shifted, but **balls are NOT shifted**. This means:
- Ball positions stay at old X coordinates
- Peg/line collision targets move to new X coordinates
- Collision detection fails or produces wrong results

### 2. Zone Regeneration

```c
world_generate_zones(world, 7, zone_height);
world_generate_bumpers(world);
```

Zones and bumpers are completely regenerated on resize, which may:
- Create new zone boundaries at different positions
- Invalidate any ball's current zone state
- Reset scoring positions

### 3. World Dimension Changes

```c
world->width = screen_width;
world->height = screen_height;
```

If physics calculations use `world->width` or `world->height` directly:
- Ball boundary checking changes
- Wrap zone calculations change mid-flight
- Position clamping behavior changes

### 4. Wrap Zone Update

```c
wrap_zones_update(wrap_zones, (float)screen_height);
```

Wrap zones recalculate positions based on new screen height, which could:
- Move wrap boundaries past where balls currently are
- Cause immediate wrapping of balls in old valid positions

## Root Cause

**Balls must be shifted along with world geometry** when the table re-centers on resize.

## Fix Strategy

### Option A: Shift balls with geometry

In the resize handler, add after shifting pegs/lines:
```c
// Shift active balls to maintain relative position to table
for (int i = 0; i < ball_manager->capacity; i++) {
    if (ball_manager->balls_current[i].active) {
        ball_manager->balls_current[i].x += dx;
        ball_manager->balls_next[i].x += dx;
    }
}
```

### Option B: Pause physics during resize

Set a flag that prevents physics updates during resize, only resuming once positions are stable.

### Option C: Use relative coordinates

Store ball positions relative to table origin, not absolute window coordinates. This is a larger refactor.

## Recommended Fix

**Option A** is the simplest and most direct fix. Balls should move with the table.

## Files to Modify

- `src/001-main.c` - Add ball shifting in resize handler

## Testing

1. Start game, spawn several balls
2. Let balls settle into physics (bouncing on pegs)
3. Resize window horizontally
4. Verify balls maintain same relative position to pegs
5. Verify collision detection still works correctly
6. Verify wrap zones still function

## Priority

**High** - This affects gameplay unpredictably whenever user resizes window.
