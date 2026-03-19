# 708 - Ball Screen Wrapping

## Current Behavior

Balls are deactivated when they exit the play area:

```c
// src/007-ball.c:514-527
// Balls despawn one screen height + buffer past the board edges
float screen_height = (float)world->height;

// Player ball moving downward - destroy one screen past adversary board
float bottom_bound = world->adversary_table_bottom + screen_height + DESPAWN_BUFFER;
if (ball->y - ball->radius > bottom_bound) {
    // deactivate
}

// Adversary ball moving upward - destroy one screen above player board
float top_bound = world->table_top - screen_height - DESPAWN_BUFFER;
if (ball->y + ball->radius < top_bound) {
    // deactivate
}
```

Once a ball exits the screen, it is lost permanently. There is no way for balls to return to play after leaving the visible area.

## Intended Behavior

Balls wrap around the screen instead of being destroyed:

**Player balls (falling down):**
- When a ball exits the bottom of the screen, it reappears at the top
- Same x position (horizontal), same velocity, same health
- Appears above the player's spawn area

**Adversary balls (rising up):**
- When a ball exits the top of the screen, it reappears at the bottom
- Same x position, same velocity, same health
- Appears below the adversary's board

**Gameplay implications:**
- Balls can survive indefinitely if they don't die from collisions
- Creates a "loop" effect where balls cycle through both boards
- Encourages more aggressive cross-board play
- Balls accumulate damage over multiple passes

## Suggested Implementation Steps

### Step 1: Define wrap boundaries

```c
// In 006-ball.h or as local constants
#define WRAP_BUFFER 50.0f  // Distance past screen edge before wrap triggers
```

### Step 2: Replace deactivation with wrap logic

```c
// Replace ball_check_offscreen_and_deactivate with:
void ball_check_and_wrap(Ball* ball, World* world) {
    float screen_height = (float)world->height;

    if (ball->owner == OWNER_PLAYER) {
        // Player ball exiting bottom - wrap to top
        float bottom_bound = world->adversary_table_bottom + WRAP_BUFFER;
        if (ball->y - ball->radius > bottom_bound) {
            // Wrap to top of screen
            float wrap_y = world->table_top - WRAP_BUFFER - ball->radius;
            ball->y = wrap_y;
            // x position and velocity unchanged
        }
    } else {
        // Adversary ball exiting top - wrap to bottom
        float top_bound = world->table_top - WRAP_BUFFER;
        if (ball->y + ball->radius < top_bound) {
            // Wrap to bottom of screen
            float wrap_y = world->adversary_table_bottom + WRAP_BUFFER + ball->radius;
            ball->y = wrap_y;
            // x position and velocity unchanged
        }
    }
}
```

### Step 3: Handle double-buffered state

Since ball physics use double-buffering, wrap logic needs to update the next buffer:

```c
void ball_update_task_wrap(BallTaskData* task) {
    Ball* next = &task->write_buffer[task->ball_index];
    World* world = task->world;

    // Only wrap active balls
    if (!next->active) return;

    // Check and apply wrap
    ball_check_and_wrap(next, world);
}
```

### Step 4: Particle effect on wrap (optional)

Spawn a subtle particle effect when balls wrap to indicate the teleport:

```c
// In particle spawn after wrap detection
if (did_wrap) {
    // Spawn particles at exit point
    particle_spawn_burst(ps, ball->x, exit_y, PARTICLE_SIMPLE, 3, 20.0f);
    // Spawn particles at entry point
    particle_spawn_burst(ps, ball->x, ball->y, PARTICLE_SIMPLE, 3, 20.0f);
}
```

### Step 5: Consider stage expansion compatibility

When stages are added (issues 1002-1008), wrap boundaries need to account for expanded world height:

```c
// With stage manager active
float bottom_wrap_point = stage_manager_get_bottom_bound(world->stages);
float top_wrap_point = stage_manager_get_top_bound(world->stages);
```

## Files to Modify

- `src/007-ball.c` - Replace deactivation with wrap logic
- `src/006-ball.h` - Add WRAP_BUFFER constant
- `src/009-particles.c` - Optional wrap particle effect

## Testing

1. Player ball falls past bottom - appears at top with same velocity
2. Adversary ball rises past top - appears at bottom with same velocity
3. Ball health preserved through wrap
4. Ball x position preserved through wrap
5. Wrapped balls continue normal physics after reappearing
6. Multiple balls can wrap simultaneously
7. No visual glitches at wrap point

## Balance Considerations

- Balls now have infinite potential lifespan
- May need to add maximum wrap count or gradual health decay
- Could add "wrap damage" if balls become too persistent
- Monitor average ball lifespan to ensure game pace feels right

## Completion Notes

**Status:** Completed

**Implementation:**
1. Replaced `DESPAWN_BUFFER` with `WRAP_BUFFER` constant (50.0f)
2. Rewrote `ball_check_bounds()` function to wrap instead of deactivate
3. Player balls exiting bottom wrap to `table_top - WRAP_BUFFER`
4. Adversary balls exiting top wrap to `adversary_table_bottom + WRAP_BUFFER`
5. Position, velocity, and health all preserved through wrap

**Files Changed:**
- `src/006-ball.h:50-52` - Replaced DESPAWN_BUFFER with WRAP_BUFFER
- `src/007-ball.c:512-537` - Rewrote ball_check_bounds() for wrapping
