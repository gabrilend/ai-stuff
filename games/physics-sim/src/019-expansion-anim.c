// src/019-expansion-anim.c
// Implementation of expansion animation system
// Controls camera zoom, content splitting, and fade-in during stage purchases
//
// External functions: expansion_animation_init, expansion_animation_start,
//                     expansion_animation_update, expansion_animation_apply_camera,
//                     expansion_animation_is_active

#include "018-expansion-anim.h"
#include <math.h>

// =============================================================================
// Easing functions
// =============================================================================

// {{{ ease_out_cubic
// Deceleration curve: fast start, slow end
// t should be in range [0, 1]
float ease_out_cubic(float t) {
    if (t < 0.0f) t = 0.0f;
    if (t > 1.0f) t = 1.0f;
    float inv = 1.0f - t;
    return 1.0f - inv * inv * inv;
}
// }}}

// {{{ ease_in_cubic
// Acceleration curve: slow start, fast end
// t should be in range [0, 1]
float ease_in_cubic(float t) {
    if (t < 0.0f) t = 0.0f;
    if (t > 1.0f) t = 1.0f;
    return t * t * t;
}
// }}}

// {{{ ease_in_out_cubic
// S-curve: slow start and end, fast middle
// t should be in range [0, 1]
float ease_in_out_cubic(float t) {
    if (t < 0.0f) t = 0.0f;
    if (t > 1.0f) t = 1.0f;
    if (t < 0.5f) {
        return 4.0f * t * t * t;
    } else {
        float f = 2.0f * t - 2.0f;
        return 0.5f * f * f * f + 1.0f;
    }
}
// }}}

// {{{ lerp
// Linear interpolation between a and b
// t = 0 returns a, t = 1 returns b
float lerp(float a, float b, float t) {
    return a + (b - a) * t;
}
// }}}

// =============================================================================
// ExpansionAnimation functions
// =============================================================================

// {{{ expansion_animation_init
// Initializes an expansion animation structure to idle state.
void expansion_animation_init(ExpansionAnimation* anim) {
    anim->state = EXPANSION_IDLE;
    anim->timer = 0.0f;
    anim->state_duration = 0.0f;

    anim->target_expansion = 0.0f;
    anim->current_expansion = 0.0f;
    anim->expansion_y = 0.0f;

    anim->camera_zoom_start = EXPANSION_CAMERA_ZOOM_NORMAL;
    anim->camera_zoom_target = EXPANSION_CAMERA_ZOOM_OUT;
    anim->camera_y_offset = 0.0f;

    anim->original_zoom = EXPANSION_CAMERA_ZOOM_NORMAL;
    anim->original_target_y = 0.0f;

    anim->physics_paused = 0;
    anim->is_player_stage = 1;
    anim->new_stage_alpha = 0.0f;
}
// }}}

// {{{ expansion_animation_start
// Starts an expansion animation sequence.
void expansion_animation_start(ExpansionAnimation* anim, float target_expansion,
                               float expansion_y, int is_player_stage,
                               float current_camera_zoom,
                               float current_camera_target_y) {
    // Store original camera state for restoration
    anim->original_zoom = current_camera_zoom;
    anim->original_target_y = current_camera_target_y;

    // Set expansion parameters
    anim->target_expansion = target_expansion;
    anim->current_expansion = 0.0f;
    anim->expansion_y = expansion_y;
    anim->is_player_stage = is_player_stage;

    // Set camera animation parameters
    anim->camera_zoom_start = current_camera_zoom;
    anim->camera_zoom_target = EXPANSION_CAMERA_ZOOM_OUT;
    anim->camera_y_offset = 0.0f;

    // Initialize fade-in
    anim->new_stage_alpha = 0.0f;

    // Start animation
    anim->state = EXPANSION_ZOOM_OUT;
    anim->timer = 0.0f;
    anim->state_duration = EXPANSION_ZOOM_OUT_DURATION;

    // Pause physics during animation
    anim->physics_paused = 1;
}
// }}}

// {{{ expansion_animation_update
// Updates the animation state machine.
// Returns 1 when animation just completed.
int expansion_animation_update(ExpansionAnimation* anim, float dt) {
    if (anim->state == EXPANSION_IDLE) {
        return 0;
    }

    anim->timer += dt;
    float t;  // Normalized progress [0, 1]

    switch (anim->state) {
        case EXPANSION_ZOOM_OUT:
            // Camera zooms out to show expansion area
            // No expansion movement yet, just camera
            t = anim->timer / EXPANSION_ZOOM_OUT_DURATION;
            if (t > 1.0f) t = 1.0f;

            // Camera Y offset: shift down slightly to center on expansion point
            anim->camera_y_offset = ease_out_cubic(t) * (anim->target_expansion * 0.3f);

            if (anim->timer >= EXPANSION_ZOOM_OUT_DURATION) {
                anim->state = EXPANSION_SPLIT;
                anim->timer = 0.0f;
                anim->state_duration = EXPANSION_SPLIT_DURATION;
            }
            break;

        case EXPANSION_SPLIT:
            // Gap opens between stages (first 30% of expansion)
            t = anim->timer / EXPANSION_SPLIT_DURATION;
            if (t > 1.0f) t = 1.0f;
            t = ease_out_cubic(t);

            // Animate gap opening
            anim->current_expansion = t * anim->target_expansion * 0.3f;

            // Camera continues to track expansion
            anim->camera_y_offset = anim->target_expansion * 0.3f +
                                   t * anim->target_expansion * 0.2f;

            if (anim->timer >= EXPANSION_SPLIT_DURATION) {
                anim->state = EXPANSION_INSERT;
                anim->timer = 0.0f;
                anim->state_duration = EXPANSION_INSERT_DURATION;
            }
            break;

        case EXPANSION_INSERT:
            // New content slides in and fades to visible (remaining 70% of expansion)
            t = anim->timer / EXPANSION_INSERT_DURATION;
            if (t > 1.0f) t = 1.0f;
            t = ease_out_cubic(t);

            // Animate remaining expansion
            anim->current_expansion = anim->target_expansion * (0.3f + 0.7f * t);

            // Fade in new content
            anim->new_stage_alpha = t;

            // Camera tracks to final position
            anim->camera_y_offset = anim->target_expansion * 0.5f +
                                   t * anim->target_expansion * 0.1f;

            if (anim->timer >= EXPANSION_INSERT_DURATION) {
                anim->state = EXPANSION_SETTLE;
                anim->timer = 0.0f;
                anim->state_duration = EXPANSION_SETTLE_DURATION;
                // Ensure full expansion reached
                anim->current_expansion = anim->target_expansion;
                anim->new_stage_alpha = 1.0f;
            }
            break;

        case EXPANSION_SETTLE:
            // Brief pause at full expansion before zoom returns
            if (anim->timer >= EXPANSION_SETTLE_DURATION) {
                anim->state = EXPANSION_ZOOM_IN;
                anim->timer = 0.0f;
                anim->state_duration = EXPANSION_ZOOM_IN_DURATION;
            }
            break;

        case EXPANSION_ZOOM_IN:
            // Camera returns to normal view
            t = anim->timer / EXPANSION_ZOOM_IN_DURATION;
            if (t > 1.0f) t = 1.0f;
            t = ease_in_cubic(t);

            // Camera Y offset returns toward center
            // (will be reset when animation completes)
            float settle_offset = anim->target_expansion * 0.6f;
            anim->camera_y_offset = settle_offset * (1.0f - t);

            if (anim->timer >= EXPANSION_ZOOM_IN_DURATION) {
                // Animation complete
                anim->state = EXPANSION_IDLE;
                anim->physics_paused = 0;
                anim->camera_y_offset = 0.0f;
                return 1;  // Signal completion
            }
            break;

        case EXPANSION_IDLE:
            // Should not reach here due to early return above
            break;
    }

    return 0;
}
// }}}

// {{{ expansion_animation_apply_camera
// Applies animated camera zoom and offset.
void expansion_animation_apply_camera(ExpansionAnimation* anim, Camera2D* camera) {
    if (anim->state == EXPANSION_IDLE) {
        return;
    }

    float t;
    float zoom;

    switch (anim->state) {
        case EXPANSION_ZOOM_OUT:
            // Zoom out progressively
            t = anim->timer / EXPANSION_ZOOM_OUT_DURATION;
            if (t > 1.0f) t = 1.0f;
            t = ease_out_cubic(t);
            zoom = lerp(anim->camera_zoom_start, anim->camera_zoom_target, t);
            break;

        case EXPANSION_ZOOM_IN:
            // Zoom back in progressively
            t = anim->timer / EXPANSION_ZOOM_IN_DURATION;
            if (t > 1.0f) t = 1.0f;
            t = ease_in_cubic(t);
            zoom = lerp(anim->camera_zoom_target, anim->original_zoom, t);
            break;

        default:
            // Hold at zoomed out level during split/insert/settle
            zoom = anim->camera_zoom_target;
            break;
    }

    camera->zoom = zoom;

    // Apply vertical offset to track expansion
    camera->target.y = anim->original_target_y + anim->camera_y_offset;
}
// }}}

// {{{ expansion_animation_is_active
// Returns 1 if animation is currently playing.
int expansion_animation_is_active(ExpansionAnimation* anim) {
    return anim->state != EXPANSION_IDLE;
}
// }}}

// {{{ expansion_animation_get_offset
// Returns the current expansion offset for rendering.
float expansion_animation_get_offset(ExpansionAnimation* anim) {
    return anim->current_expansion;
}
// }}}

// {{{ expansion_animation_get_new_stage_alpha
// Returns the alpha value for rendering new stage content.
float expansion_animation_get_new_stage_alpha(ExpansionAnimation* anim) {
    return anim->new_stage_alpha;
}
// }}}
