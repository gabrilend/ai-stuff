/*
 * GBA Background/Tilemap System Header
 * Implements scrolling backgrounds with rotation effects for exploration
 */

#ifndef BACKGROUND_H
#define BACKGROUND_H

#include <stdint.h>

// ============================================================================
// INITIALIZATION AND SETUP
// ============================================================================

void background_init(void);
void background_load_tiles(void);
void background_load_tilemap(void);

// ============================================================================
// MAIN UPDATE FUNCTION
// ============================================================================

void background_update(void);

// ============================================================================
// MOVEMENT PROCESSING
// ============================================================================

void background_process_movement(void);

// ============================================================================
// ROTATION SYSTEM
// ============================================================================

void background_rotate_left(void);
void background_rotate_right(void);
void background_visual_rotate(void);
void background_set_rotation(uint8_t rotation);  // Set rotation to match cube

// ============================================================================
// STATE GETTERS
// ============================================================================

int16_t background_get_scroll_x(void);
int16_t background_get_scroll_y(void);
uint8_t background_get_rotation(void);

// ============================================================================
// CONFIGURATION
// ============================================================================

void background_set_move_speed(uint8_t speed);
uint8_t background_get_move_speed(void);

// ============================================================================
// ROTATION CONSTANTS (8-way rotation to match cube)
// ============================================================================

#define ROTATION_NORTH      0
#define ROTATION_NORTHEAST  1
#define ROTATION_EAST       2
#define ROTATION_SOUTHEAST  3
#define ROTATION_SOUTH      4
#define ROTATION_SOUTHWEST  5
#define ROTATION_WEST       6
#define ROTATION_NORTHWEST  7

#endif // BACKGROUND_H