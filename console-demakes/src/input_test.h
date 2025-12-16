/*
 * GBA Input Test Scene Header
 * Visual representation of GBA buttons for testing input
 */

#ifndef INPUT_TEST_H
#define INPUT_TEST_H

#include <stdint.h>

// ============================================================================
// INPUT TEST CONSTANTS
// ============================================================================

#define BUTTON_TILE_START   16      // Start tiles after Link's sprites
#define BUTTON_PALETTE      1       // Use palette 1 for button sprites

// Button positions on screen (sprite coordinates)
#define DPAD_CENTER_X       60
#define DPAD_CENTER_Y       80

#define FACE_BUTTONS_X      180
#define FACE_BUTTONS_Y      80

#define SHOULDER_BUTTONS_Y  30
#define L_BUTTON_X          40
#define R_BUTTON_X          200

#define SELECT_START_Y      130
#define SELECT_X            100
#define START_X             140

// Sprite IDs for button display
#define SPRITE_DPAD_UP      10
#define SPRITE_DPAD_DOWN    11
#define SPRITE_DPAD_LEFT    12
#define SPRITE_DPAD_RIGHT   13
#define SPRITE_A_BUTTON     14
#define SPRITE_B_BUTTON     15
#define SPRITE_L_BUTTON     16
#define SPRITE_R_BUTTON     17
#define SPRITE_SELECT       18
#define SPRITE_START        19

// Button states
#define BUTTON_UNPRESSED    0
#define BUTTON_PRESSED      1

// ============================================================================
// FUNCTION PROTOTYPES
// ============================================================================

// System functions
void input_test_init(void);
void input_test_update(void);
void input_test_render(void);

// Button sprite management
void input_test_load_button_graphics(void);
void input_test_load_button_palette(void);
void input_test_create_button_sprites(void);
void input_test_update_button_states(void);

// Helper functions
void input_test_set_button_sprite(uint8_t sprite_id, uint16_t x, uint16_t y, uint16_t tile, uint8_t pressed);

#endif // INPUT_TEST_H