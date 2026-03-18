# 1003 - Dynamic World Vertical Expansion

## Current Behavior

The world has fixed vertical bounds set at initialization:

```c
// src/001-main.c - bounds calculated once at startup
world_set_table_bounds(world, table_width, peg_start_y, zone_height);
world_generate_adversary_pegs(world, peg_rows, peg_cols, peg_spacing);
```

The camera uses Camera2D with a fixed target. When new stages are added, the world needs to grow vertically and the camera/viewport needs to accommodate the expanded space.

Current layout (approximate):
```
[Spawn area]          y = 0-100
[Player stage 1]      y = 100-700
[Gates]               y = 700-760
[Adversary stage 1]   y = 760-1360
```

## Intended Behavior

When a new stage is purchased:
1. Calculate total new world height
2. Shift adversary content downward (or player content upward)
3. Insert new stage content in the gap
4. Update all y-coordinates and bounds
5. Adjust camera to show expanded world

After stage 2 purchase:
```
[Spawn area]          y = 0-100
[Player stage 1]      y = 100-700
[Gates row 1]         y = 700-760
[Player stage 2]      y = 760-960      <- NEW (ramps, shorter)
[Gates row 2]         y = 960-1020     <- NEW (2x value)
[Adversary stage 2]   y = 1020-1220    <- NEW (mirrored ramps)
[Gates row 3]         y = 1220-1280    <- NEW
[Adversary stage 1]   y = 1280-1880    <- SHIFTED DOWN
```

## Suggested Implementation Steps

### Step 1: Track total world height dynamically

```c
// In World struct
float total_height;        // Current total world height
float expansion_offset;    // Accumulated vertical shift from expansions
```

### Step 2: World expansion function

```c
// Calculate new positions when adding stages
void world_expand_for_stages(World* world, float player_stage_height,
                             float adversary_stage_height, float gate_height) {
    float expansion = player_stage_height + adversary_stage_height + gate_height * 2;

    // Shift adversary content down
    world_shift_adversary_content(world, expansion);

    // Update bounds
    world->total_height += expansion;
    world->adversary_table_bottom += expansion;
}
```

### Step 3: Content shifting functions

```c
void world_shift_adversary_content(World* world, float offset) {
    // Shift adversary pegs
    for (int i = 0; i < world->adversary_peg_count; i++) {
        world->adversary_pegs[i].y += offset;
    }

    // Shift adversary bumpers
    for (int i = 0; i < world->adversary_bumper_count; i++) {
        world->adversary_bumpers[i].y += offset;
    }

    // Update adversary table bounds
    world->adversary_table_top += offset;
    world->adversary_table_bottom += offset;
}
```

### Step 4: Camera adjustment

The camera should smoothly pan to show the new content or zoom out slightly:

```c
void camera_accommodate_expansion(Camera2D* camera, float new_world_height) {
    // Option A: Zoom out to show more
    // Option B: Keep zoom, adjust offset
    // Option C: Animated transition (see issue 1007)
}
```

### Step 5: Ball position preservation

Active balls need their positions preserved during expansion:
- Player balls: positions unchanged
- Adversary balls: shift y-coordinates by expansion amount
- Balls in transit through gates: handle edge case

```c
void ball_manager_handle_expansion(BallManager* manager, float offset,
                                   float expansion_y_start) {
    for (int i = 0; i < manager->ball_count; i++) {
        if (manager->balls_current[i].y > expansion_y_start) {
            manager->balls_current[i].y += offset;
            manager->balls_next[i].y += offset;
        }
    }
}
```

## Files to Modify

- `src/004-world.h` - Add total_height, expansion tracking
- `src/005-world.c` - Implement expansion and shifting functions
- `src/007-ball.c` - Ball position adjustment during expansion
- `src/001-main.c` - Camera adjustment logic

## Dependencies

- Issue 1002 (Stage system architecture) - Need stage structures defined

## Related Issues

- 1007 - Stage insertion animation (smooth visual transition)

## Testing

1. Verify world dimensions update correctly
2. Verify adversary content shifts to correct positions
3. Verify active balls maintain correct relative positions
4. Verify camera shows expanded world appropriately
5. Verify collision detection works at new positions
