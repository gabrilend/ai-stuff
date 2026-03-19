# 1007 - Stage Insertion Animation

## Current Behavior

When upgrades are purchased, effects are applied immediately with no visual feedback beyond the menu closing. The world state changes instantaneously.

## Intended Behavior

When a new stage is purchased, play a brief animation showing the world expanding:

**Animation sequence:**
1. Pause ball physics temporarily
2. Camera zooms out slightly to show full expansion area
3. Visual "split" effect as gate row separates
4. New stage content slides/fades into the gap
5. Gate rows settle into final positions
6. Camera returns to normal view
7. Resume ball physics

**Duration:** ~1.5-2 seconds total

**Visual elements:**
- Smooth easing on all movements
- Particle effects at expansion seam
- Flash/glow on new gates highlighting multiplier
- Optional: "STAGE 2 UNLOCKED" text overlay

## Suggested Implementation Steps

### Step 1: Define animation state

```c
typedef enum ExpansionAnimState {
    EXPANSION_IDLE,
    EXPANSION_ZOOM_OUT,
    EXPANSION_SPLIT,
    EXPANSION_INSERT,
    EXPANSION_SETTLE,
    EXPANSION_ZOOM_IN
} ExpansionAnimState;

typedef struct ExpansionAnimation {
    ExpansionAnimState state;
    float timer;              // Time in current state
    float state_duration;     // Duration of current state

    float target_expansion;   // Total vertical expansion
    float current_expansion;  // Animated expansion value

    float camera_zoom_start;
    float camera_zoom_target;

    int paused_physics;       // Flag to pause ball updates
} ExpansionAnimation;
```

### Step 2: Animation state machine

```c
void expansion_animation_update(ExpansionAnimation* anim, float dt) {
    if (anim->state == EXPANSION_IDLE) return;

    anim->timer += dt;

    switch (anim->state) {
        case EXPANSION_ZOOM_OUT:
            if (anim->timer >= 0.3f) {
                anim->state = EXPANSION_SPLIT;
                anim->timer = 0.0f;
            }
            break;

        case EXPANSION_SPLIT:
            // Animate gap opening
            float t = anim->timer / 0.4f;  // 0.4s duration
            t = ease_out_cubic(t);
            anim->current_expansion = t * anim->target_expansion * 0.3f;

            if (anim->timer >= 0.4f) {
                anim->state = EXPANSION_INSERT;
                anim->timer = 0.0f;
            }
            break;

        case EXPANSION_INSERT:
            // Animate stage content appearing
            float t = anim->timer / 0.6f;  // 0.6s duration
            t = ease_out_cubic(t);
            anim->current_expansion = anim->target_expansion * (0.3f + 0.7f * t);

            if (anim->timer >= 0.6f) {
                anim->state = EXPANSION_SETTLE;
                anim->timer = 0.0f;
            }
            break;

        case EXPANSION_SETTLE:
            // Brief pause at full expansion
            if (anim->timer >= 0.2f) {
                anim->state = EXPANSION_ZOOM_IN;
                anim->timer = 0.0f;
            }
            break;

        case EXPANSION_ZOOM_IN:
            if (anim->timer >= 0.3f) {
                anim->state = EXPANSION_IDLE;
                anim->paused_physics = 0;
            }
            break;
    }
}
```

### Step 3: Camera animation

```c
void expansion_animation_apply_camera(ExpansionAnimation* anim,
                                      Camera2D* camera) {
    if (anim->state == EXPANSION_IDLE) return;

    float zoom_t = 0.0f;

    if (anim->state == EXPANSION_ZOOM_OUT) {
        zoom_t = anim->timer / 0.3f;
        zoom_t = ease_out_cubic(zoom_t);
        camera->zoom = lerp(anim->camera_zoom_start,
                           anim->camera_zoom_target, zoom_t);
    }
    else if (anim->state == EXPANSION_ZOOM_IN) {
        zoom_t = anim->timer / 0.3f;
        zoom_t = ease_in_cubic(zoom_t);
        camera->zoom = lerp(anim->camera_zoom_target,
                           anim->camera_zoom_start, zoom_t);
    }
    else {
        camera->zoom = anim->camera_zoom_target;
    }
}
```

### Step 4: Render animated expansion

During animation, render world elements at interpolated positions:

```c
void world_render_with_expansion(World* world, ExpansionAnimation* anim) {
    float offset = anim->current_expansion;

    // Render player content at normal positions
    world_render_player_stages(world);

    // Render gates with animated split
    world_render_gates_with_offset(world, offset / 2.0f);

    // Render adversary content shifted down
    world_render_adversary_stages_with_offset(world, offset);

    // Render new stage content fading in
    if (anim->state >= EXPANSION_INSERT) {
        float alpha = (anim->state == EXPANSION_INSERT)
            ? anim->timer / 0.6f
            : 1.0f;
        world_render_new_stage(world, alpha);
    }
}
```

### Step 5: Particle effects at seam

```c
void expansion_spawn_seam_particles(ParticleSystem* ps, float y,
                                    float table_x, float table_width) {
    // Spawn sparkle particles along the expansion seam
    for (float x = table_x; x < table_x + table_width; x += 20.0f) {
        particle_spawn_burst(ps, x, y,
                            PARTICLE_SPARKLE,
                            /* count */ 2,
                            /* spread */ 10.0f);
    }
}
```

### Step 6: Trigger animation on purchase

```c
void stage_manager_purchase_stage(StageManager* manager,
                                  ExpansionAnimation* anim) {
    // Calculate expansion size
    float player_stage_height = STAGE_2_HEIGHT;
    float adversary_stage_height = STAGE_2_HEIGHT;
    float gate_height = ZONE_HEIGHT * 2;  // Two new gate rows

    float total_expansion = player_stage_height + adversary_stage_height
                          + gate_height;

    // Start animation
    anim->state = EXPANSION_ZOOM_OUT;
    anim->timer = 0.0f;
    anim->target_expansion = total_expansion;
    anim->current_expansion = 0.0f;
    anim->camera_zoom_start = 1.0f;
    anim->camera_zoom_target = 0.7f;  // Zoom out to see more
    anim->paused_physics = 1;
}
```

## Files to Create

- `src/018-expansion-anim.h` - Animation state structures
- `src/019-expansion-anim.c` - Animation state machine and rendering

## Files to Modify

- `src/001-main.c` - Check animation state, pause physics during animation
- `src/005-world.c` - Offset rendering functions
- `src/009-particles.c` - Seam particle effects

## Dependencies

- Issue 1002 (Stage system architecture)
- Issue 1003 (Dynamic world expansion)

## Testing

1. Animation plays smoothly without hitches
2. Physics paused during animation (balls frozen)
3. Camera zooms out and back smoothly
4. New content fades in at correct position
5. After animation, world state is correct
6. No visual glitches at animation boundaries
