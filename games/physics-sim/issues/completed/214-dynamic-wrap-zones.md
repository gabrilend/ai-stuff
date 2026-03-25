# 214 - Dynamic Wrap Zones

## Current Behavior

Ball wrapping uses hardcoded Y positions that don't update properly:

```c
// src/007-ball.c - ball_check_bounds()
float despawn_buffer = (float)world->height;

if (ball->owner == OWNER_PLAYER) {
    float bottom_bound = world->adversary_table_bottom + despawn_buffer;
    if (ball->y - ball->radius > bottom_bound) {
        ball->y = world->table_top - despawn_buffer + ball->radius;
    }
}
```

**Problems:**
1. `world->height` is the initial window height, doesn't update on resize
2. Wrap positions don't account for stage additions
3. Balls wrap to incorrect positions after world expansion
4. The viewable area is defined by camera scroll limits, not world bounds

## Intended Behavior

Create **rectangular wrap zones** similar to portal zones that:
1. Dynamically reposition when window resizes
2. Dynamically reposition when stages are added
3. Are positioned exactly at the edges of the maximum viewable area
4. Trigger ball teleportation when balls fully enter them

### Viewable Area Calculation

From `001-main.c` camera scroll code:
```c
// Camera scroll limits
float min_offset = world->table_top - (float)screen_height;
float max_offset = world->adversary_table_bottom;

// When scrolled to min_offset, camera shows:
//   Y range: [table_top - screen_height, table_top]

// When scrolled to max_offset, camera shows:
//   Y range: [adversary_table_bottom, adversary_table_bottom + screen_height]
```

**Maximum viewable Y range:**
- Top edge: `world->table_top - screen_height`
- Bottom edge: `world->adversary_table_bottom + screen_height`

### Wrap Zone Positions

```
    Top Wrap Zone (receives adversary balls, sends player balls)
    ============================================================
    Y = table_top - screen_height - zone_height

    +---------------------------------------------------------+
    |                                                         |
    |                   VIEWABLE AREA                         |
    |              (can scroll anywhere here)                 |
    |                                                         |
    +---------------------------------------------------------+

    Bottom Wrap Zone (receives player balls, sends adversary balls)
    ================================================================
    Y = adversary_table_bottom + screen_height

```

## Suggested Implementation Steps

### Step 1: Define wrap zone structure

```c
// src/036-wrap-zones.h

typedef struct WrapZones {
    // Zone bounds (in world coordinates)
    float top_zone_y;       // Y position of top wrap zone
    float bottom_zone_y;    // Y position of bottom wrap zone
    float zone_height;      // Height of each zone (e.g., 100px)

    // Full table X bounds (balls must be within table width)
    float table_x;
    float table_width;

    // Screen height (needed to calculate viewable area)
    float screen_height;

    // World reference for dynamic updates
    struct World* world;
} WrapZones;

WrapZones* wrap_zones_create(struct World* world, float screen_height);
void wrap_zones_destroy(WrapZones* zones);
void wrap_zones_update(WrapZones* zones, float screen_height);
int wrap_zones_check_ball(WrapZones* zones, Ball* ball);
```

### Step 2: Implement zone position calculation

```c
// src/037-wrap-zones.c

void wrap_zones_update(WrapZones* zones, float screen_height) {
    if (!zones || !zones->world) return;

    World* world = zones->world;
    zones->screen_height = screen_height;

    // Calculate viewable area bounds
    float viewable_top = world->table_top - screen_height;
    float viewable_bottom = world->adversary_table_bottom + screen_height;

    // Position zones just outside viewable area
    zones->zone_height = 100.0f;  // Buffer zone height
    zones->top_zone_y = viewable_top - zones->zone_height;
    zones->bottom_zone_y = viewable_bottom;

    // Table bounds for X checking
    zones->table_x = world->table_x;
    zones->table_width = world->table_width;
}
```

### Step 3: Implement ball checking and wrapping

```c
int wrap_zones_check_ball(WrapZones* zones, Ball* ball) {
    if (!zones || !ball || !ball->active) return 0;

    // Check if ball is within table X bounds
    if (ball->x < zones->table_x ||
        ball->x > zones->table_x + zones->table_width) {
        return 0;  // Ball is outside table, don't wrap
    }

    if (ball->owner == OWNER_PLAYER) {
        // Player ball falling down - check bottom zone
        if (ball->y - ball->radius > zones->bottom_zone_y) {
            // Wrap to top zone
            ball->y = zones->top_zone_y + zones->zone_height - ball->radius;
            return 1;  // Wrapped
        }
    } else if (ball->owner == OWNER_ADVERSARY) {
        // Adversary ball floating up - check top zone
        if (ball->y + ball->radius < zones->top_zone_y + zones->zone_height) {
            // Wrap to bottom zone
            ball->y = zones->bottom_zone_y + ball->radius;
            return 1;  // Wrapped
        }
    }

    return 0;  // No wrap
}
```

### Step 4: Integrate with main loop

```c
// src/001-main.c

// Create wrap zones after world creation
WrapZones* wrap_zones = wrap_zones_create(world, screen_height);

// Update on window resize
if (window_resized) {
    wrap_zones_update(wrap_zones, screen_height);
}

// Update after stage expansion
if (expansion_completed) {
    wrap_zones_update(wrap_zones, screen_height);
}

// Check balls for wrapping (in physics update or after)
for (int i = 0; i < ball_manager->capacity; i++) {
    Ball* ball = &ball_manager->balls_current[i];
    if (ball->active) {
        wrap_zones_check_ball(wrap_zones, ball);
    }
}

// Cleanup
wrap_zones_destroy(wrap_zones);
```

### Step 5: Update after stage additions

```c
// In on_stage_purchased callback
void on_stage_purchased(void* user_data) {
    StagePurchaseContext* ctx = (StagePurchaseContext*)user_data;

    // ... existing stage addition code ...

    // Update wrap zones for new world bounds
    wrap_zones_update(ctx->wrap_zones, ctx->screen_height);
}
```

### Step 6: Remove old ball_check_bounds

```c
// In src/007-ball.c
// Remove or comment out the old ball_check_bounds() function
// Wrapping is now handled by WrapZones system
```

### Step 7: Debug visualization (optional)

```c
void wrap_zones_render_debug(WrapZones* zones) {
    // Draw top zone (blue)
    DrawRectangle(
        (int)zones->table_x,
        (int)zones->top_zone_y,
        (int)zones->table_width,
        (int)zones->zone_height,
        (Color){50, 50, 255, 50}
    );

    // Draw bottom zone (red)
    DrawRectangle(
        (int)zones->table_x,
        (int)zones->bottom_zone_y,
        (int)zones->table_width,
        (int)zones->zone_height,
        (Color){255, 50, 50, 50}
    );
}
```

## Files to Create

- `src/036-wrap-zones.h` - WrapZones structure and API
- `src/037-wrap-zones.c` - WrapZones implementation

## Files to Modify

- `src/001-main.c` - Create/update/destroy wrap zones, integrate checking
- `src/007-ball.c` - Remove old ball_check_bounds() function
- `Makefile` - Add new source files

## Dynamic Update Triggers

| Event | Action |
|-------|--------|
| Window resize | Call `wrap_zones_update(zones, new_screen_height)` |
| Stage purchased | Call `wrap_zones_update(zones, screen_height)` |
| Game reset | Call `wrap_zones_update(zones, screen_height)` |

## Testing

1. **Basic wrapping:**
   - Player ball exits bottom → appears at top
   - Adversary ball exits top → appears at bottom

2. **Window resize:**
   - Resize window while ball is falling
   - Ball should still wrap at correct position

3. **Stage expansion:**
   - Add new stage while balls are active
   - Balls should wrap at new extended bounds

4. **Edge cases:**
   - Ball wraps immediately after stage expansion
   - Multiple balls wrap in same frame
   - Ball at exact boundary position

5. **Debug visualization:**
   - Enable debug render to see zone positions
   - Verify zones update when window/stages change

## Related Issues

- 1009-ball-screen-wrapping.md (original wrapping implementation)
- 1115-fix-player-ball-wrap-position.md (attempted fix)
- 601-add-scrolling-viewport.md (camera scroll bounds)

## Why Zone-Based is Better

| Aspect | Hardcoded Y | Zone-Based |
|--------|-------------|------------|
| Window resize | Breaks | Works |
| Stage addition | Breaks | Works |
| Code clarity | Magic numbers | Clear bounds |
| Debug visibility | None | Can render zones |
| Maintenance | Error-prone | Self-updating |

## Implementation Notes

**Files Created:**
- `src/036-wrap-zones.h` - WrapZones structure and API
- `src/037-wrap-zones.c` - Dynamic zone positioning and ball wrapping

**Files Modified:**
- `src/004-world.h` - Added `WrapZones* wrap_zones` to World struct
- `src/007-ball.c` - Call wrap_zones_check_ball in physics, updated top wall to use zone bounds
- `src/001-main.c` - Create/update/destroy wrap zones, attach to world

**Key Fix:**
The original `ball_collide_with_walls` had a hardcoded top wall at `SPAWN_Y - 20` that clamped wrapped player balls back to the spawn area. Fixed by using wrap zone top position as the top wall boundary.

**Debug Visualization:**
Semi-transparent colored rectangles render at wrap zone positions (blue=top, red=bottom). Kept enabled since zones are offscreen during normal play.

## Status: COMPLETE
