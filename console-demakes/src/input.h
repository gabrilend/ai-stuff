/*
 * GBA Input Handling System Header
 * 8-directional movement with button state tracking
 */

#ifndef INPUT_H
#define INPUT_H

#include <stdint.h>

// ============================================================================
// INITIALIZATION
// ============================================================================

void input_init(void);
void input_update(void);

// ============================================================================
// INTERNAL PROCESSING (called by input_update)
// ============================================================================

void input_process_movement(void);
void input_process_buttons(void);

// ============================================================================
// MOVEMENT STATE QUERIES
// ============================================================================

uint8_t input_is_up(void);
uint8_t input_is_down(void);
uint8_t input_is_left(void);
uint8_t input_is_right(void);

// ============================================================================
// BUTTON STATE QUERIES (held down)
// ============================================================================

uint8_t input_is_a(void);
uint8_t input_is_b(void);
uint8_t input_is_select(void);
uint8_t input_is_start(void);
uint8_t input_is_l(void);
uint8_t input_is_r(void);

// ============================================================================
// BUTTON PRESS DETECTION (just pressed this frame)
// ============================================================================

uint8_t input_pressed_a(void);
uint8_t input_pressed_b(void);
uint8_t input_pressed_select(void);
uint8_t input_pressed_start(void);
uint8_t input_pressed_l(void);
uint8_t input_pressed_r(void);

// ============================================================================
// BUTTON RELEASE DETECTION (just released this frame)
// ============================================================================

uint8_t input_released_a(void);
uint8_t input_released_b(void);
uint8_t input_released_select(void);
uint8_t input_released_start(void);
uint8_t input_released_l(void);
uint8_t input_released_r(void);

// ============================================================================
// RAW INPUT ACCESS
// ============================================================================

uint16_t input_get_keys_held(void);
uint16_t input_get_keys_pressed(void);
uint16_t input_get_keys_released(void);

// ============================================================================
// 8-DIRECTIONAL MOVEMENT HELPERS
// ============================================================================

uint8_t input_is_diagonal(void);
int8_t input_get_direction_x(void);      // -1, 0, or 1
int8_t input_get_direction_y(void);      // -1, 0, or 1
int8_t input_get_direction_8way(void);   // 0-7 for 8 directions, -1 for none

// ============================================================================
// DIRECTION CONSTANTS (for input_get_direction_8way)
// ============================================================================

#define DIR_UP          0
#define DIR_UP_RIGHT    1
#define DIR_RIGHT       2
#define DIR_DOWN_RIGHT  3
#define DIR_DOWN        4
#define DIR_DOWN_LEFT   5
#define DIR_LEFT        6
#define DIR_UP_LEFT     7
#define DIR_NONE        -1

#endif // INPUT_H