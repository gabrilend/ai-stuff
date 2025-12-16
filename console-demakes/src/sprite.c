/*
 * GBA Sprite System Implementation
 * Handles sprite rendering, animation, and Link character
 */

#include "gba_hardware.h"
#include "sprite.h"
#include "input.h"
#include "background.h"

// ============================================================================
// SPRITE SYSTEM STATE
// ============================================================================

static Sprite sprites[MAX_SPRITES];
static uint8_t sprite_count = 0;

// Link character state
static int16_t link_x = 120;        // Center of screen
static int16_t link_y = 80;         // Center of screen
static uint8_t link_is_walking = 0;

// 3-column beachball orbital system state
static uint16_t orbital_angle = 0;       // Current orbital angle (0-2047, 256 steps per sprite)
static uint8_t beachball_rotation = 0;   // Current rotation index (0-7)
static uint8_t beachball_is_active = 0;  // Whether beachball is visible

#define ORBITAL_SPEED 8                  // Degrees per frame when orbiting
#define ANGLE_PER_SPRITE 256             // Orbital angle units per sprite (2048/8)

// Color sequence for 8 orbital positions
static const uint8_t color_sequence[8] = {2, 3, 4, 5, 6, 7, 1, 1}; // Red, Orange, Yellow, Green, Blue, Purple, White, White

// ============================================================================
// SIMPLE LINK SPRITE DATA (8x8 tiles)
// ============================================================================

// Simple Link sprite data - 8 directions, 2 frames each
// This is placeholder data - in a full implementation, you'd convert from actual sprites
static const uint32_t link_sprite_data[] = {
    // Direction 0: UP - Frame 0 (idle)
    0x00111100, 0x01122110, 0x12233221, 0x12333321,
    0x12233221, 0x01222210, 0x01133110, 0x00111100,
    
    // Direction 0: UP - Frame 1 (walk)
    0x00111100, 0x01122110, 0x12233221, 0x12333321,
    0x12233221, 0x01222210, 0x01133110, 0x00111100,
    
    // Direction 1: UP-RIGHT - Frame 0
    0x00111100, 0x01122110, 0x12233221, 0x12333321,
    0x12233221, 0x01222210, 0x01133110, 0x00111100,
    
    // Direction 1: UP-RIGHT - Frame 1
    0x00111100, 0x01122110, 0x12233221, 0x12333321,
    0x12233221, 0x01222210, 0x01133110, 0x00111100,
    
    // Direction 2: RIGHT - Frame 0
    0x00111100, 0x01122110, 0x12233221, 0x12333321,
    0x12233221, 0x01222210, 0x01133110, 0x00111100,
    
    // Direction 2: RIGHT - Frame 1
    0x00111100, 0x01122110, 0x12233221, 0x12333321,
    0x12233221, 0x01222210, 0x01133110, 0x00111100,
    
    // Direction 3: DOWN-RIGHT - Frame 0
    0x00111100, 0x01122110, 0x12233221, 0x12333321,
    0x12233221, 0x01222210, 0x01133110, 0x00111100,
    
    // Direction 3: DOWN-RIGHT - Frame 1
    0x00111100, 0x01122110, 0x12233221, 0x12333321,
    0x12233221, 0x01222210, 0x01133110, 0x00111100,
    
    // Direction 4: DOWN - Frame 0
    0x00111100, 0x01122110, 0x12233221, 0x12333321,
    0x12233221, 0x01222210, 0x01133110, 0x00111100,
    
    // Direction 4: DOWN - Frame 1
    0x00111100, 0x01122110, 0x12233221, 0x12333321,
    0x12233221, 0x01222210, 0x01133110, 0x00111100,
    
    // Direction 5: DOWN-LEFT - Frame 0
    0x00111100, 0x01122110, 0x12233221, 0x12333321,
    0x12233221, 0x01222210, 0x01133110, 0x00111100,
    
    // Direction 5: DOWN-LEFT - Frame 1
    0x00111100, 0x01122110, 0x12233221, 0x12333321,
    0x12233221, 0x01222210, 0x01133110, 0x00111100,
    
    // Direction 6: LEFT - Frame 0
    0x00111100, 0x01122110, 0x12233221, 0x12333321,
    0x12233221, 0x01222210, 0x01133110, 0x00111100,
    
    // Direction 6: LEFT - Frame 1
    0x00111100, 0x01122110, 0x12233221, 0x12333321,
    0x12233221, 0x01222210, 0x01133110, 0x00111100,
    
    // Direction 7: UP-LEFT - Frame 0
    0x00111100, 0x01122110, 0x12233221, 0x12333321,
    0x12233221, 0x01222210, 0x01133110, 0x00111100,
    
    // Direction 7: UP-LEFT - Frame 1
    0x00111100, 0x01122110, 0x12233221, 0x12333321,
    0x12233221, 0x01222210, 0x01133110, 0x00111100,
};

// ============================================================================
// 3D CUBE PROJECTION DATA
// ============================================================================

// Simple 8x8 solid color sprites for beachball columns
// Each color gets one 8x8 sprite (8 words each)
static const uint32_t beachball_sprite_data[] = {
    // Color 1: White column
    0x00000000, 0x00111100, 0x01111110, 0x11111111,
    0x11111111, 0x11111111, 0x01111110, 0x00111100,
    
    // Color 2: Red column
    0x00000000, 0x00222200, 0x02222220, 0x22222222,
    0x22222222, 0x22222222, 0x02222220, 0x00222200,
    
    // Color 3: Orange column
    0x00000000, 0x00333300, 0x03333330, 0x33333333,
    0x33333333, 0x33333333, 0x03333330, 0x00333300,
    
    // Color 4: Yellow column
    0x00000000, 0x00444400, 0x04444440, 0x44444444,
    0x44444444, 0x44444444, 0x04444440, 0x00444400,
    
    // Color 5: Green column
    0x00000000, 0x00555500, 0x05555550, 0x55555555,
    0x55555555, 0x55555555, 0x05555550, 0x00555500,
    
    // Color 6: Blue column
    0x00000000, 0x00666600, 0x06666660, 0x66666666,
    0x66666666, 0x66666666, 0x06666660, 0x00666600,
    
    // Color 7: Purple column
    0x00000000, 0x00777700, 0x07777770, 0x77777777,
    0x77777777, 0x77777777, 0x07777770, 0x00777700,
    
    // Color 8: Pink column (using palette index 1 again for now)
    0x00000000, 0x00111100, 0x01111110, 0x11111111,
    0x11111111, 0x11111111, 0x01111110, 0x00111100,
};

// ============================================================================
// SYSTEM INITIALIZATION
// ============================================================================

void sprite_init(void) {
    // Clear all sprites
    for (int i = 0; i < MAX_SPRITES; i++) {
        sprites[i].is_active = 0;
        sprites[i].is_visible = 0;
    }
    
    sprite_count = 0;
    
    // Load Link's graphics and palette
    sprite_load_link_graphics();
    sprite_load_link_palette();
    
    // Load beachball graphics and palette
    sprite_load_beachball_graphics();
    sprite_load_beachball_palette();
    
    // Initialize Link (temporarily disabled for cube testing)
    // link_init();
    
    // Initialize 3-column beachball
    beachball_init();
    
    // Clear OAM (Object Attribute Memory)
    for (int i = 0; i < 128; i++) {
        ((volatile uint16_t*)OAM)[i * 4 + 0] = SPRITE_ATTR_HIDDEN;  // Hide all sprites initially
        ((volatile uint16_t*)OAM)[i * 4 + 1] = 0;
        ((volatile uint16_t*)OAM)[i * 4 + 2] = 0;
        ((volatile uint16_t*)OAM)[i * 4 + 3] = 0;
    }
}

void sprite_update(void) {
    // Update all active sprites
    for (int i = 0; i < MAX_SPRITES; i++) {
        if (sprites[i].is_active) {
            sprite_update_animation(i);
        }
    }
    
    // Update Link (temporarily disabled for cube testing)
    // link_update();
    
    // Update 3-column beachball
    beachball_update();
}

void sprite_render(void) {
    // Write all active sprites to OAM
    for (int i = 0; i < MAX_SPRITES; i++) {
        if (sprites[i].is_active) {
            sprite_write_oam(i);
        }
    }
}

// ============================================================================
// SPRITE MANAGEMENT
// ============================================================================

void sprite_create(uint8_t sprite_id, int16_t x, int16_t y, uint16_t tile_id, uint8_t palette) {
    if (sprite_id >= MAX_SPRITES) return;
    
    sprites[sprite_id].x = x;
    sprites[sprite_id].y = y;
    sprites[sprite_id].tile_id = tile_id;
    sprites[sprite_id].palette = palette;
    sprites[sprite_id].priority = 0;
    sprites[sprite_id].direction = 0;
    sprites[sprite_id].animation_frame = 0;
    sprites[sprite_id].animation_timer = 0;
    sprites[sprite_id].animation_speed = 8;
    sprites[sprite_id].is_active = 1;
    sprites[sprite_id].is_visible = 1;
    
    if (sprite_id >= sprite_count) {
        sprite_count = sprite_id + 1;
    }
}

void sprite_destroy(uint8_t sprite_id) {
    if (sprite_id >= MAX_SPRITES) return;
    
    sprites[sprite_id].is_active = 0;
    sprites[sprite_id].is_visible = 0;
    
    // Hide in OAM
    ((volatile uint16_t*)OAM)[sprite_id * 4] = SPRITE_ATTR_HIDDEN;
}

void sprite_set_position(uint8_t sprite_id, int16_t x, int16_t y) {
    if (sprite_id >= MAX_SPRITES || !sprites[sprite_id].is_active) return;
    
    sprites[sprite_id].x = x;
    sprites[sprite_id].y = y;
}

void sprite_set_tile(uint8_t sprite_id, uint16_t tile_id) {
    if (sprite_id >= MAX_SPRITES || !sprites[sprite_id].is_active) return;
    
    sprites[sprite_id].tile_id = tile_id;
}

void sprite_set_palette(uint8_t sprite_id, uint8_t palette) {
    if (sprite_id >= MAX_SPRITES || !sprites[sprite_id].is_active) return;
    
    sprites[sprite_id].palette = palette;
}

void sprite_set_visible(uint8_t sprite_id, uint8_t visible) {
    if (sprite_id >= MAX_SPRITES || !sprites[sprite_id].is_active) return;
    
    sprites[sprite_id].is_visible = visible;
}

void sprite_set_direction(uint8_t sprite_id, uint8_t direction) {
    if (sprite_id >= MAX_SPRITES || !sprites[sprite_id].is_active) return;
    
    sprites[sprite_id].direction = direction & 7;  // Keep in range 0-7
}

void sprite_update_animation(uint8_t sprite_id) {
    if (sprite_id >= MAX_SPRITES || !sprites[sprite_id].is_active) return;
    
    sprites[sprite_id].animation_timer++;
    
    if (sprites[sprite_id].animation_timer >= sprites[sprite_id].animation_speed) {
        sprites[sprite_id].animation_timer = 0;
        sprites[sprite_id].animation_frame = (sprites[sprite_id].animation_frame + 1) % LINK_ANIM_FRAMES;
    }
}

// ============================================================================
// LINK CHARACTER FUNCTIONS
// ============================================================================

void link_init(void) {
    // Create Link sprite
    sprite_create(LINK_SPRITE_ID, link_x, link_y, LINK_TILE_START, LINK_PALETTE);
    
    // Set Link's initial direction (facing down)
    sprites[LINK_SPRITE_ID].direction = LINK_DIR_DOWN;
    sprites[LINK_SPRITE_ID].animation_speed = LINK_ANIM_SPEED;
    
    link_is_walking = 0;
}

void link_update(void) {
    // Get input direction
    int8_t dir_x = input_get_direction_x();
    int8_t dir_y = input_get_direction_y();
    
    // Check if Link is moving
    uint8_t is_moving = (dir_x != 0 || dir_y != 0);
    
    if (is_moving) {
        // Update Link's direction based on input
        int8_t input_dir = input_get_direction_8way();
        if (input_dir >= 0) {
            link_set_direction(input_dir);
        }
        
        // Start walking animation if not already walking
        if (!link_is_walking) {
            link_start_walking();
        }
        
        // Move Link (we'll keep Link centered and move the world around him for now)
        // In future, this will be more sophisticated with screen boundaries
        
    } else {
        // Stop walking animation
        if (link_is_walking) {
            link_stop_walking();
        }
    }
    
    // Keep Link centered on screen for now
    link_x = 120;
    link_y = 80;
    sprites[LINK_SPRITE_ID].x = link_x;
    sprites[LINK_SPRITE_ID].y = link_y;
}

void link_set_direction(uint8_t direction) {
    sprite_set_direction(LINK_SPRITE_ID, direction);
}

void link_start_walking(void) {
    link_is_walking = 1;
    sprites[LINK_SPRITE_ID].animation_speed = LINK_ANIM_SPEED;
}

void link_stop_walking(void) {
    link_is_walking = 0;
    sprites[LINK_SPRITE_ID].animation_frame = 0;  // Reset to idle frame
    sprites[LINK_SPRITE_ID].animation_timer = 0;
}

// ============================================================================
// GRAPHICS LOADING
// ============================================================================

void sprite_load_link_graphics(void) {
    // Load Link sprite data into OBJ VRAM
    volatile uint32_t* obj_tiles = (volatile uint32_t*)0x06010000;  // OBJ tile data starts here
    
    // Copy all Link sprite frames (8 directions * 2 frames * 8 words per tile)
    for (int i = 0; i < 16 * 8; i++) {
        obj_tiles[i] = link_sprite_data[i];
    }
}

void sprite_load_link_palette(void) {
    // Set up Link's palette (palette 0)
    OBJ_PALETTE[0] = COLOR_BLACK;       // Transparent
    OBJ_PALETTE[1] = RGB15(31, 31, 31); // White/light
    OBJ_PALETTE[2] = RGB15(0, 15, 0);   // Green (tunic)
    OBJ_PALETTE[3] = RGB15(25, 20, 10); // Brown/tan (skin)
    OBJ_PALETTE[4] = RGB15(31, 31, 0);  // Yellow (hair)
    OBJ_PALETTE[5] = RGB15(15, 10, 5);  // Dark brown
    OBJ_PALETTE[6] = RGB15(20, 20, 31); // Blue
    OBJ_PALETTE[7] = RGB15(31, 0, 0);   // Red
}

void sprite_load_beachball_graphics(void) {
    // Load beachball color sprites into OBJ VRAM (starting at tile 32)
    volatile uint32_t* obj_tiles = (volatile uint32_t*)0x06010000;
    
    // Copy all color sprites (8 colors * 8 words per 8x8 sprite)
    for (int i = 0; i < 8 * 8; i++) {
        obj_tiles[BEACHBALL_TILE_START * 8 + i] = beachball_sprite_data[i];
    }
}

void sprite_load_beachball_palette(void) {
    // Set up beachball palette (palette 1) - 8 distinct colors
    // Offset by 16 colors for palette 1
    OBJ_PALETTE[16 + 0] = COLOR_BLACK;       // Transparent
    OBJ_PALETTE[16 + 1] = RGB15(31, 31, 31); // White
    OBJ_PALETTE[16 + 2] = RGB15(31, 0, 0);   // Red
    OBJ_PALETTE[16 + 3] = RGB15(31, 15, 0);  // Orange
    OBJ_PALETTE[16 + 4] = RGB15(31, 31, 0);  // Yellow
    OBJ_PALETTE[16 + 5] = RGB15(0, 31, 0);   // Green
    OBJ_PALETTE[16 + 6] = RGB15(0, 0, 31);   // Blue
    OBJ_PALETTE[16 + 7] = RGB15(20, 0, 31);  // Purple
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

uint16_t sprite_get_tile_for_direction(uint8_t direction, uint8_t frame) {
    // Calculate tile ID based on direction and frame
    return LINK_TILE_START + (direction * LINK_ANIM_FRAMES) + frame;
}

void sprite_write_oam(uint8_t sprite_id) {
    if (sprite_id >= MAX_SPRITES || !sprites[sprite_id].is_active) return;
    
    Sprite* spr = &sprites[sprite_id];
    volatile uint16_t* oam = (volatile uint16_t*)OAM;
    
    if (!spr->is_visible) {
        // Hide sprite
        oam[sprite_id * 4] = SPRITE_ATTR_HIDDEN;
        return;
    }
    
    uint16_t tile_id;
    
    // For Link (sprite 0), calculate tile based on direction and animation
    if (sprite_id == LINK_SPRITE_ID) {
        tile_id = sprite_get_tile_for_direction(spr->direction, spr->animation_frame);
    } else {
        // For other sprites (buttons), use the stored tile_id directly
        tile_id = spr->tile_id;
    }
    
    // Attribute 0: Y position, shape, color mode
    oam[sprite_id * 4 + 0] = (spr->y & 0xFF) | SPRITE_SHAPE_SQUARE | SPRITE_ATTR_COLOR_16;
    
    // Attribute 1: X position, size (all sprites are 8x8 now)
    oam[sprite_id * 4 + 1] = (spr->x & 0x1FF) | SPRITE_SIZE_8x8;
    
    // Attribute 2: Tile ID, palette, priority
    oam[sprite_id * 4 + 2] = tile_id | (spr->palette << 12) | (spr->priority << 10);
    
    // Attribute 3: Unused for basic sprites
    oam[sprite_id * 4 + 3] = 0;
}

// ============================================================================
// 3D CUBE FUNCTIONS
// ============================================================================

void beachball_init(void) {
    // Create 3 sprites side by side (8x8 each)
    sprite_create(BEACHBALL_LEFT_ID, BEACHBALL_CENTER_X - 8, BEACHBALL_CENTER_Y, BEACHBALL_TILE_START, BEACHBALL_PALETTE);
    sprite_create(BEACHBALL_CENTER_ID, BEACHBALL_CENTER_X, BEACHBALL_CENTER_Y, BEACHBALL_TILE_START, BEACHBALL_PALETTE);
    sprite_create(BEACHBALL_RIGHT_ID, BEACHBALL_CENTER_X + 8, BEACHBALL_CENTER_Y, BEACHBALL_TILE_START, BEACHBALL_PALETTE);
    
    // Initialize orbital system
    orbital_angle = 0;              // Start at position 0
    beachball_rotation = 0;         // Start at rotation 0
    beachball_is_active = 1;
    
    // Set initial colors
    beachball_set_rotation(0);
}

void beachball_update(void) {
    if (!beachball_is_active) return;
    
    // Get directional input for smooth orbital rotation
    uint8_t left = input_is_left();
    uint8_t right = input_is_right();
    
    // Smooth orbital rotation
    if (left) {
        orbital_angle = (orbital_angle - ORBITAL_SPEED + 2048) & 2047;  // Orbit counter-clockwise
    }
    if (right) {
        orbital_angle = (orbital_angle + ORBITAL_SPEED) & 2047;        // Orbit clockwise  
    }
    
    // Calculate which rotation to show based on orbital angle
    uint8_t new_rotation = (orbital_angle / ANGLE_PER_SPRITE) & 7;
    
    // Update colors if we've crossed into a new viewing angle
    if (new_rotation != beachball_rotation) {
        beachball_rotation = new_rotation;
        beachball_set_rotation(beachball_rotation);
    }
}

void beachball_set_rotation(uint8_t direction) {
    beachball_rotation = direction & 7;
    
    // Set colors for the 3 columns based on rotation
    // Each position shows 3 consecutive colors from the sequence
    uint8_t left_color = (beachball_rotation + 0) & 7;
    uint8_t center_color = (beachball_rotation + 1) & 7;
    uint8_t right_color = (beachball_rotation + 2) & 7;
    
    // Update tile IDs to show correct colors (each color sprite is 8 words)
    sprites[BEACHBALL_LEFT_ID].tile_id = BEACHBALL_TILE_START + left_color;
    sprites[BEACHBALL_CENTER_ID].tile_id = BEACHBALL_TILE_START + center_color;
    sprites[BEACHBALL_RIGHT_ID].tile_id = BEACHBALL_TILE_START + right_color;
    
    // Background rotation disabled for now - focus on beachball orbital movement
    // background_set_rotation(beachball_rotation);
}

void beachball_update_colors(void) {
    // This function updates the beachball colors based on current rotation
    if (beachball_is_active) {
        beachball_set_rotation(beachball_rotation);
    }
}