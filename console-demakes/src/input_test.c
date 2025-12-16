/*
 * GBA Input Test Scene Implementation
 * Visual button tester for verifying all controls work correctly
 */

#include "gba_hardware.h"
#include "input_test.h"
#include "input.h"
#include "sprite.h"

// Simple button graphics data (8x8 tiles)
static const uint32_t button_graphics_data[] = {
    // Tile 16: D-pad Up (unpressed)
    0x00111100, 0x01111110, 0x11111111, 0x11111111,
    0x01111110, 0x00111100, 0x00111100, 0x00111100,
    
    // Tile 17: D-pad Up (pressed) - brighter
    0x00222200, 0x02222220, 0x22222222, 0x22222222,
    0x02222220, 0x00222200, 0x00222200, 0x00222200,
    
    // Tile 18: D-pad Down (unpressed)
    0x00111100, 0x00111100, 0x00111100, 0x01111110,
    0x11111111, 0x11111111, 0x01111110, 0x00111100,
    
    // Tile 19: D-pad Down (pressed)
    0x00222200, 0x00222200, 0x00222200, 0x02222220,
    0x22222222, 0x22222222, 0x02222220, 0x00222200,
    
    // Tile 20: D-pad Left (unpressed)
    0x01110000, 0x11111000, 0x11111100, 0x11111110,
    0x11111110, 0x11111100, 0x11111000, 0x01110000,
    
    // Tile 21: D-pad Left (pressed)
    0x02220000, 0x22222000, 0x22222200, 0x22222220,
    0x22222220, 0x22222200, 0x22222000, 0x02220000,
    
    // Tile 22: D-pad Right (unpressed)
    0x00001110, 0x00011111, 0x00111111, 0x01111111,
    0x01111111, 0x00111111, 0x00011111, 0x00001110,
    
    // Tile 23: D-pad Right (pressed)
    0x00002220, 0x00022222, 0x00222222, 0x02222222,
    0x02222222, 0x00222222, 0x00022222, 0x00002220,
    
    // Tile 24: A Button (unpressed) - Circle
    0x00111100, 0x01111110, 0x11100111, 0x11101111,
    0x11111011, 0x11100111, 0x01111110, 0x00111100,
    
    // Tile 25: A Button (pressed)
    0x00222200, 0x02222220, 0x22200222, 0x22202222,
    0x22222022, 0x22200222, 0x02222220, 0x00222200,
    
    // Tile 26: B Button (unpressed) - Circle
    0x00111100, 0x01111110, 0x11011011, 0x11111111,
    0x11111111, 0x11011011, 0x01111110, 0x00111100,
    
    // Tile 27: B Button (pressed)
    0x00222200, 0x02222220, 0x22022022, 0x22222222,
    0x22222222, 0x22022022, 0x02222220, 0x00222200,
    
    // Tile 28: L Button (unpressed) - Rectangle
    0x11111111, 0x11111111, 0x11100111, 0x11100111,
    0x11100111, 0x11100111, 0x11111111, 0x11111111,
    
    // Tile 29: L Button (pressed)
    0x22222222, 0x22222222, 0x22200222, 0x22200222,
    0x22200222, 0x22200222, 0x22222222, 0x22222222,
    
    // Tile 30: R Button (unpressed) - Rectangle
    0x11111111, 0x11111111, 0x11101111, 0x11101111,
    0x11101111, 0x11101111, 0x11111111, 0x11111111,
    
    // Tile 31: R Button (pressed)
    0x22222222, 0x22222222, 0x22202222, 0x22202222,
    0x22202222, 0x22202222, 0x22222222, 0x22222222,
    
    // Tile 32: Select (unpressed) - Small rect
    0x00000000, 0x01111110, 0x01111110, 0x01111110,
    0x01111110, 0x01111110, 0x01111110, 0x00000000,
    
    // Tile 33: Select (pressed)
    0x00000000, 0x02222220, 0x02222220, 0x02222220,
    0x02222220, 0x02222220, 0x02222220, 0x00000000,
    
    // Tile 34: Start (unpressed) - Small rect
    0x00000000, 0x01111110, 0x01111110, 0x01111110,
    0x01111110, 0x01111110, 0x01111110, 0x00000000,
    
    // Tile 35: Start (pressed)
    0x00000000, 0x02222220, 0x02222220, 0x02222220,
    0x02222220, 0x02222220, 0x02222220, 0x00000000,
};

void input_test_init(void) {
    // Load button graphics and palette
    input_test_load_button_graphics();
    input_test_load_button_palette();
    
    // Create button sprites
    input_test_create_button_sprites();
}

void input_test_update(void) {
    // Update button visual states based on input
    input_test_update_button_states();
}

void input_test_render(void) {
    // Button rendering is handled by the sprite system
    // This function can be used for additional visual effects
}

void input_test_load_button_graphics(void) {
    // Load button graphics into OBJ VRAM starting at tile 16
    volatile uint32_t* obj_tiles = (volatile uint32_t*)0x06010000;
    
    // Copy all button tile data (20 tiles * 8 words per tile)
    for (int i = 0; i < 20 * 8; i++) {
        obj_tiles[BUTTON_TILE_START * 8 + i] = button_graphics_data[i];
    }
}

void input_test_load_button_palette(void) {
    // Set up button palette (palette 1)
    OBJ_PALETTE[16 + 0] = COLOR_BLACK;       // Transparent
    OBJ_PALETTE[16 + 1] = RGB15(10, 10, 10); // Dark gray (unpressed)
    OBJ_PALETTE[16 + 2] = RGB15(25, 25, 0);  // Yellow (pressed)
    OBJ_PALETTE[16 + 3] = RGB15(31, 31, 31); // White (highlight)
    OBJ_PALETTE[16 + 4] = RGB15(31, 0, 0);   // Red
    OBJ_PALETTE[16 + 5] = RGB15(0, 31, 0);   // Green
    OBJ_PALETTE[16 + 6] = RGB15(0, 0, 31);   // Blue
    OBJ_PALETTE[16 + 7] = RGB15(31, 15, 0);  // Orange
}

void input_test_create_button_sprites(void) {
    // Create all button sprites in unpressed state
    
    // D-pad
    sprite_create(SPRITE_DPAD_UP, DPAD_CENTER_X, DPAD_CENTER_Y - 12, BUTTON_TILE_START + 0, BUTTON_PALETTE);
    sprite_create(SPRITE_DPAD_DOWN, DPAD_CENTER_X, DPAD_CENTER_Y + 12, BUTTON_TILE_START + 2, BUTTON_PALETTE);
    sprite_create(SPRITE_DPAD_LEFT, DPAD_CENTER_X - 12, DPAD_CENTER_Y, BUTTON_TILE_START + 4, BUTTON_PALETTE);
    sprite_create(SPRITE_DPAD_RIGHT, DPAD_CENTER_X + 12, DPAD_CENTER_Y, BUTTON_TILE_START + 6, BUTTON_PALETTE);
    
    // Face buttons
    sprite_create(SPRITE_A_BUTTON, FACE_BUTTONS_X + 12, FACE_BUTTONS_Y, BUTTON_TILE_START + 8, BUTTON_PALETTE);
    sprite_create(SPRITE_B_BUTTON, FACE_BUTTONS_X - 12, FACE_BUTTONS_Y, BUTTON_TILE_START + 10, BUTTON_PALETTE);
    
    // Shoulder buttons
    sprite_create(SPRITE_L_BUTTON, L_BUTTON_X, SHOULDER_BUTTONS_Y, BUTTON_TILE_START + 12, BUTTON_PALETTE);
    sprite_create(SPRITE_R_BUTTON, R_BUTTON_X, SHOULDER_BUTTONS_Y, BUTTON_TILE_START + 14, BUTTON_PALETTE);
    
    // Select/Start
    sprite_create(SPRITE_SELECT, SELECT_X, SELECT_START_Y, BUTTON_TILE_START + 16, BUTTON_PALETTE);
    sprite_create(SPRITE_START, START_X, SELECT_START_Y, BUTTON_TILE_START + 18, BUTTON_PALETTE);
}

void input_test_update_button_states(void) {
    // Update D-pad sprites
    sprite_set_tile(SPRITE_DPAD_UP, BUTTON_TILE_START + (input_is_up() ? 1 : 0));
    sprite_set_tile(SPRITE_DPAD_DOWN, BUTTON_TILE_START + 2 + (input_is_down() ? 1 : 0));
    sprite_set_tile(SPRITE_DPAD_LEFT, BUTTON_TILE_START + 4 + (input_is_left() ? 1 : 0));
    sprite_set_tile(SPRITE_DPAD_RIGHT, BUTTON_TILE_START + 6 + (input_is_right() ? 1 : 0));
    
    // Update face buttons
    sprite_set_tile(SPRITE_A_BUTTON, BUTTON_TILE_START + 8 + (input_is_a() ? 1 : 0));
    sprite_set_tile(SPRITE_B_BUTTON, BUTTON_TILE_START + 10 + (input_is_b() ? 1 : 0));
    
    // Update shoulder buttons
    sprite_set_tile(SPRITE_L_BUTTON, BUTTON_TILE_START + 12 + (input_is_l() ? 1 : 0));
    sprite_set_tile(SPRITE_R_BUTTON, BUTTON_TILE_START + 14 + (input_is_r() ? 1 : 0));
    
    // Update select/start buttons
    sprite_set_tile(SPRITE_SELECT, BUTTON_TILE_START + 16 + (input_is_select() ? 1 : 0));
    sprite_set_tile(SPRITE_START, BUTTON_TILE_START + 18 + (input_is_start() ? 1 : 0));
}

void input_test_set_button_sprite(uint8_t sprite_id, uint16_t x, uint16_t y, uint16_t tile, uint8_t pressed) {
    sprite_set_position(sprite_id, x, y);
    sprite_set_tile(sprite_id, tile + (pressed ? 1 : 0));
}