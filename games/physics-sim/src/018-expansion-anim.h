// src/018-expansion-anim.h
// Expansion animation system for stage purchases
// Handles camera zoom, content splitting, and fade-in effects
//
// External functions: expansion_animation_init, expansion_animation_start,
//                     expansion_animation_update, expansion_animation_apply_camera,
//                     expansion_animation_is_active

#ifndef EXPANSION_ANIM_H
#define EXPANSION_ANIM_H

#include <raylib.h>

// Animation timing constants (seconds)
#define EXPANSION_ZOOM_OUT_DURATION 0.3f
#define EXPANSION_SPLIT_DURATION 0.4f
#define EXPANSION_INSERT_DURATION 0.6f
#define EXPANSION_SETTLE_DURATION 0.2f
#define EXPANSION_ZOOM_IN_DURATION 0.3f

// Camera zoom levels
#define EXPANSION_CAMERA_ZOOM_NORMAL 1.0f
#define EXPANSION_CAMERA_ZOOM_OUT 0.75f

// {{{ ExpansionAnimState enum
// Animation state machine states
typedef enum ExpansionAnimState {
    EXPANSION_IDLE,       // No animation active
    EXPANSION_ZOOM_OUT,   // Camera pulling back to show expansion area
    EXPANSION_SPLIT,      // Gap opening between stages
    EXPANSION_INSERT,     // New content sliding/fading in
    EXPANSION_SETTLE,     // Brief pause at full expansion
    EXPANSION_ZOOM_IN     // Camera returning to normal view
} ExpansionAnimState;
// }}}

// {{{ typedef struct ExpansionAnimation
// Tracks state and progress of stage expansion animation.
// Created once in main, reused for each stage purchase.
typedef struct ExpansionAnimation {
    ExpansionAnimState state;   // Current animation phase
    float timer;                // Time elapsed in current state
    float state_duration;       // Duration of current state

    // Expansion parameters
    float target_expansion;     // Total vertical expansion in pixels
    float current_expansion;    // Animated expansion value (0 to target)
    float expansion_y;          // Y position where expansion occurs

    // Camera parameters
    float camera_zoom_start;    // Zoom level at animation start
    float camera_zoom_target;   // Target zoom level during animation
    float camera_y_offset;      // Vertical camera offset during animation

    // Original camera state (for restoration)
    float original_zoom;
    float original_target_y;

    // Physics pause flag
    int physics_paused;

    // Stage info for spawning content
    int is_player_stage;        // 1 = player expansion, 0 = adversary
    float new_stage_alpha;      // Fade-in alpha for new content (0-1)
} ExpansionAnimation;
// }}}

// =============================================================================
// ExpansionAnimation functions
// =============================================================================

// {{{ expansion_animation_init
// Initializes an expansion animation structure to idle state.
void expansion_animation_init(ExpansionAnimation* anim);
// }}}

// {{{ expansion_animation_start
// Starts an expansion animation sequence.
// Parameters:
//   anim: Animation structure to start
//   target_expansion: Total vertical expansion in pixels
//   expansion_y: Y position where the split occurs
//   is_player_stage: 1 if expanding player area, 0 for adversary
//   current_camera_zoom: Current camera zoom level
//   current_camera_target_y: Current camera target Y position
void expansion_animation_start(ExpansionAnimation* anim, float target_expansion,
                               float expansion_y, int is_player_stage,
                               float current_camera_zoom,
                               float current_camera_target_y);
// }}}

// {{{ expansion_animation_update
// Updates the animation state machine.
// Returns 1 when animation just completed (signals world update needed).
int expansion_animation_update(ExpansionAnimation* anim, float dt);
// }}}

// {{{ expansion_animation_apply_camera
// Applies animated camera zoom and offset.
// Call this to get the animated camera zoom value.
void expansion_animation_apply_camera(ExpansionAnimation* anim, Camera2D* camera);
// }}}

// {{{ expansion_animation_is_active
// Returns 1 if animation is currently playing.
int expansion_animation_is_active(ExpansionAnimation* anim);
// }}}

// {{{ expansion_animation_get_offset
// Returns the current expansion offset for rendering.
// Use this to offset content positions during animation.
float expansion_animation_get_offset(ExpansionAnimation* anim);
// }}}

// {{{ expansion_animation_get_new_stage_alpha
// Returns the alpha value for rendering new stage content.
// 0.0 = invisible, 1.0 = fully visible
float expansion_animation_get_new_stage_alpha(ExpansionAnimation* anim);
// }}}

// =============================================================================
// Easing functions
// =============================================================================

// {{{ ease_out_cubic
// Deceleration curve: fast start, slow end
float ease_out_cubic(float t);
// }}}

// {{{ ease_in_cubic
// Acceleration curve: slow start, fast end
float ease_in_cubic(float t);
// }}}

// {{{ ease_in_out_cubic
// S-curve: slow start and end, fast middle
float ease_in_out_cubic(float t);
// }}}

// {{{ lerp
// Linear interpolation between a and b
float lerp(float a, float b, float t);
// }}}

#endif // EXPANSION_ANIM_H
