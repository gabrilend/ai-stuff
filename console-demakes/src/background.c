/*
 * GBA Background/Tilemap System
 * Implements scrolling backgrounds with rotation effects for exploration
 */

#include "gba_hardware.h"
#include "background.h"
#include "input.h"

// Scroll position (16-bit for sub-pixel precision)
static int16_t scroll_x = 0;
static int16_t scroll_y = 0;

// Movement speed
static uint8_t move_speed = 2;

// Rotation state (0-7 for 8 rotations: matches cube rotation)
static uint8_t rotation_state = 0;

// Simple tile data for patterns
static const uint32_t checker_tile_data[8] = {
    0xFFFFFFFF, 0x00000000, 0xFFFFFFFF, 0x00000000,
    0xFFFFFFFF, 0x00000000, 0xFFFFFFFF, 0x00000000
};

static const uint32_t solid_tile_data[8] = {
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF,
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF
};

static const uint32_t line_tile_data[8] = {
    0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000,
    0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000
};

void background_init(void) {
    // Initialize scroll positions
    scroll_x = 0;
    scroll_y = 0;
    
    // Set movement speed (pixels per frame when moving)
    move_speed = 2;
    
    // Initialize rotation state (0 = facing north)
    rotation_state = 0;
    
    // Set up background control register for BG0
    // Priority 0, character base 0, 16-color, screen base 8, 256x256 size
    REG_BG0CNT = BGCNT_PRIORITY_0 | BGCNT_CHARBASE(0) | BGCNT_16COLOR | BGCNT_SCREENBASE(8) | BGCNT_SIZE_0;
    
    // Load tile patterns into VRAM
    background_load_tiles();
    
    // Load initial tilemap
    background_load_tilemap();
    
    // Set initial scroll position
    REG_BG0HOFS = scroll_x;
    REG_BG0VOFS = scroll_y;
}

void background_load_tiles(void) {
    // Load tile data into character base 0
    volatile uint32_t* tile_mem = (volatile uint32_t*)CHARBLOCK(0);
    
    // Tile 0: Transparent/empty tile
    for (int i = 0; i < 8; i++) {
        tile_mem[i] = 0x00000000;
    }
    
    // Tile 1: Checker pattern
    for (int i = 0; i < 8; i++) {
        tile_mem[8 + i] = checker_tile_data[i];
    }
    
    // Tile 2: Solid pattern  
    for (int i = 0; i < 8; i++) {
        tile_mem[16 + i] = solid_tile_data[i];
    }
    
    // Tile 3: Line pattern
    for (int i = 0; i < 8; i++) {
        tile_mem[24 + i] = line_tile_data[i];
    }
}

void background_load_tilemap(void) {
    // Load tilemap into screen base 8
    volatile uint16_t* tilemap = SCREENBLOCK(8);
    
    // Fill with a pattern based on rotation state
    for (int y = 0; y < 32; y++) {
        for (int x = 0; x < 32; x++) {
            uint16_t tile_id;
            
            // Create different patterns based on 8-way rotation
            switch (rotation_state) {
                case 0: // North - alternating checker pattern
                    tile_id = ((x + y) & 1) ? 1 : 2;
                    break;
                case 1: // Northeast - diagonal pattern
                    tile_id = ((x - y) & 3) ? 1 : 3;
                    break;
                case 2: // East - horizontal lines
                    tile_id = (y & 1) ? 3 : 1;
                    break;
                case 3: // Southeast - diagonal pattern  
                    tile_id = ((x + y) & 3) ? 2 : 3;
                    break;
                case 4: // South - inverse checker pattern
                    tile_id = ((x + y) & 1) ? 2 : 1;
                    break;
                case 5: // Southwest - diagonal pattern
                    tile_id = ((x - y) & 3) ? 3 : 2;
                    break;
                case 6: // West - vertical lines
                    tile_id = (x & 1) ? 3 : 2;
                    break;
                case 7: // Northwest - diagonal pattern
                    tile_id = ((x + y) & 3) ? 1 : 2;
                    break;
                default:
                    tile_id = 1;
                    break;
            }
            
            tilemap[y * 32 + x] = tile_id;
        }
    }
}

void background_update(void) {
    // Background rotation is now controlled by the cube system
    // No direct input processing here - rotation comes from cube_update()
    
    // Process movement based on current rotation and input
    background_process_movement();
    
    // Update hardware scroll registers
    REG_BG0HOFS = scroll_x;
    REG_BG0VOFS = scroll_y;
}

void background_process_movement(void) {
    int8_t move_x = 0;
    int8_t move_y = 0;
    
    // Get movement input
    uint8_t up = input_is_up();
    uint8_t down = input_is_down();
    uint8_t left = input_is_left();
    uint8_t right = input_is_right();
    
    // Calculate movement based on 8-way rotation
    // Movement creates the pseudo-3D camera effect
    
    if (up) {   // Move forward in current facing direction
        switch (rotation_state) {
            case 0: move_y = -move_speed; break;                    // North
            case 1: move_x = move_speed; move_y = -move_speed; break; // Northeast
            case 2: move_x = move_speed; break;                     // East
            case 3: move_x = move_speed; move_y = move_speed; break;  // Southeast
            case 4: move_y = move_speed; break;                     // South
            case 5: move_x = -move_speed; move_y = move_speed; break; // Southwest
            case 6: move_x = -move_speed; break;                    // West
            case 7: move_x = -move_speed; move_y = -move_speed; break; // Northwest
        }
    }
    
    if (down) { // Move backward from current facing direction
        switch (rotation_state) {
            case 0: move_y = move_speed; break;                     // North
            case 1: move_x = -move_speed; move_y = move_speed; break; // Northeast
            case 2: move_x = -move_speed; break;                    // East
            case 3: move_x = -move_speed; move_y = -move_speed; break; // Southeast
            case 4: move_y = -move_speed; break;                    // South
            case 5: move_x = move_speed; move_y = -move_speed; break; // Southwest
            case 6: move_x = move_speed; break;                     // West
            case 7: move_x = move_speed; move_y = move_speed; break;  // Northwest
        }
    }
    
    // Left/right strafe perpendicular to facing direction
    if (left && !input_pressed_l()) {   // Don't move if we just rotated
        switch (rotation_state) {
            case 0: move_x = -move_speed; break;                    // North: strafe left
            case 1: move_x = -move_speed; move_y = move_speed; break; // Northeast
            case 2: move_y = -move_speed; break;                    // East: strafe up
            case 3: move_x = -move_speed; move_y = -move_speed; break; // Southeast  
            case 4: move_x = move_speed; break;                     // South: strafe right
            case 5: move_x = move_speed; move_y = -move_speed; break; // Southwest
            case 6: move_y = move_speed; break;                     // West: strafe down
            case 7: move_x = move_speed; move_y = move_speed; break;  // Northwest
        }
    }
    
    if (right && !input_pressed_r()) {  // Don't move if we just rotated
        switch (rotation_state) {
            case 0: move_x = move_speed; break;                     // North: strafe right
            case 1: move_x = move_speed; move_y = -move_speed; break; // Northeast
            case 2: move_y = move_speed; break;                     // East: strafe down
            case 3: move_x = move_speed; move_y = move_speed; break;  // Southeast
            case 4: move_x = -move_speed; break;                    // South: strafe left  
            case 5: move_x = -move_speed; move_y = move_speed; break; // Southwest
            case 6: move_y = -move_speed; break;                    // West: strafe up
            case 7: move_x = -move_speed; move_y = -move_speed; break; // Northwest
        }
    }
    
    // Apply movement
    scroll_x += move_x;
    scroll_y += move_y;
    
    // Keep scroll values in reasonable bounds (wrap around)
    scroll_x &= 0x1FF;  // 512 pixel wrap (32 tiles * 16 pixels - but we use 256x256 maps)
    scroll_y &= 0x1FF;
}

void background_rotate_left(void) {
    rotation_state = (rotation_state + 7) & 7;  // Wrap 0-7 (counter-clockwise)
    background_visual_rotate();
}

void background_rotate_right(void) {
    rotation_state = (rotation_state + 1) & 7;  // Wrap 0-7 (clockwise)
    background_visual_rotate();
}

void background_set_rotation(uint8_t rotation) {
    rotation_state = rotation & 7;
    background_visual_rotate();
}

void background_visual_rotate(void) {
    // Reload the tilemap with new pattern to show rotation
    background_load_tilemap();
}

// Getters for external systems
int16_t background_get_scroll_x(void) {
    return scroll_x;
}

int16_t background_get_scroll_y(void) {
    return scroll_y;
}

uint8_t background_get_rotation(void) {
    return rotation_state;
}

void background_set_move_speed(uint8_t speed) {
    move_speed = speed;
}

uint8_t background_get_move_speed(void) {
    return move_speed;
}