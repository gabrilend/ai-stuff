/*
 * GBA Sprite System Header
 * Handles sprite rendering, animation, and object management
 */

#ifndef SPRITE_H
#define SPRITE_H

#include <stdint.h>

// ============================================================================
// SPRITE CONSTANTS
// ============================================================================

#define MAX_SPRITES         128         // Maximum sprites on screen
#define SPRITE_WIDTH        16          // Sprite width in pixels (can be 8, 16, 32, 64)
#define SPRITE_HEIGHT       16          // Sprite height in pixels (can be 8, 16, 32, 64)

// Sprite size constants for OAM
#define SPRITE_SIZE_8x8     0x0000
#define SPRITE_SIZE_16x16   0x4000
#define SPRITE_SIZE_32x32   0x8000
#define SPRITE_SIZE_64x64   0xC000

// Sprite shape constants for OAM
#define SPRITE_SHAPE_SQUARE 0x0000
#define SPRITE_SHAPE_WIDE   0x8000
#define SPRITE_SHAPE_TALL   0x4000

// Sprite attributes
#define SPRITE_ATTR_COLOR_16    0x0000  // 16 colors (4bpp)
#define SPRITE_ATTR_COLOR_256   0x2000  // 256 colors (8bpp)
#define SPRITE_ATTR_MOSAIC      0x1000  // Mosaic effect
#define SPRITE_ATTR_VISIBLE     0x0000  // Visible
#define SPRITE_ATTR_HIDDEN      0x0200  // Hidden

// ============================================================================
// SPRITE STRUCTURE
// ============================================================================

typedef struct {
    int16_t x, y;               // Screen position
    uint16_t tile_id;           // Starting tile number in VRAM
    uint8_t palette;            // Palette number (0-15)
    uint8_t priority;           // Rendering priority (0-3)
    uint8_t direction;          // Current facing direction (0-7)
    uint8_t animation_frame;    // Current animation frame
    uint8_t animation_timer;    // Animation timing counter
    uint8_t animation_speed;    // Frames per animation frame
    uint8_t is_active;          // 1 if sprite is active, 0 if not
    uint8_t is_visible;         // 1 if visible, 0 if hidden
} Sprite;

// ============================================================================
// LINK CHARACTER CONSTANTS
// ============================================================================

#define LINK_SPRITE_ID      0           // Link uses sprite slot 0
#define LINK_TILE_START     0           // Link's tiles start at tile 0 in OBJ VRAM
#define LINK_PALETTE        0           // Link uses palette 0

// 3-column beachball constants (3 separate 8x8 sprites)
#define BEACHBALL_LEFT_ID   1           // Left column sprite
#define BEACHBALL_CENTER_ID 2           // Center column sprite  
#define BEACHBALL_RIGHT_ID  3           // Right column sprite
#define BEACHBALL_TILE_START 32         // Beachball tiles start at tile 32
#define BEACHBALL_PALETTE   1           // Beachball palette
#define BEACHBALL_CENTER_X  120         // Beachball center X position
#define BEACHBALL_CENTER_Y  80          // Beachball center Y position

// Direction constants (matches input.h directions)
#define LINK_DIR_UP         0
#define LINK_DIR_UP_RIGHT   1
#define LINK_DIR_RIGHT      2
#define LINK_DIR_DOWN_RIGHT 3
#define LINK_DIR_DOWN       4
#define LINK_DIR_DOWN_LEFT  5
#define LINK_DIR_LEFT       6
#define LINK_DIR_UP_LEFT    7

// Animation constants
#define LINK_ANIM_FRAMES    2           // 2 frames per direction (idle, walk)
#define LINK_ANIM_SPEED     8           // 8 game frames per animation frame

// ============================================================================
// FUNCTION PROTOTYPES
// ============================================================================

// System functions
void sprite_init(void);
void sprite_update(void);
void sprite_render(void);

// Sprite management
void sprite_create(uint8_t sprite_id, int16_t x, int16_t y, uint16_t tile_id, uint8_t palette);
void sprite_destroy(uint8_t sprite_id);
void sprite_set_position(uint8_t sprite_id, int16_t x, int16_t y);
void sprite_set_tile(uint8_t sprite_id, uint16_t tile_id);
void sprite_set_palette(uint8_t sprite_id, uint8_t palette);
void sprite_set_visible(uint8_t sprite_id, uint8_t visible);

// Animation functions
void sprite_set_direction(uint8_t sprite_id, uint8_t direction);
void sprite_update_animation(uint8_t sprite_id);

// Link-specific functions
void link_init(void);
void link_update(void);
void link_set_position(int16_t x, int16_t y);
void link_set_direction(uint8_t direction);
void link_start_walking(void);
void link_stop_walking(void);

// 3-column beachball functions
void beachball_init(void);
void beachball_update(void);
void beachball_set_rotation(uint8_t direction);  // 0-7 for 8 viewing angles
void beachball_update_colors(void);

// Sprite data loading
void sprite_load_link_graphics(void);
void sprite_load_link_palette(void);
void sprite_load_beachball_graphics(void);
void sprite_load_beachball_palette(void);

// Helper functions
uint16_t sprite_get_tile_for_direction(uint8_t direction, uint8_t frame);
void sprite_write_oam(uint8_t sprite_id);

#endif // SPRITE_H