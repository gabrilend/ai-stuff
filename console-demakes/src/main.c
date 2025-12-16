/*
 * GBA Ocarina of Time Demake - Main Entry Point
 * A Game Boy Advance demake of Ocarina of Time with keyboard-responsive tilemap
 */

#include "gba_hardware.h"
#include "input.h"
#include "background.h"
#include "sprite.h"
#include "input_test.h"

// Function prototypes
void init_system(void);
void init_graphics(void);
void init_palette(void);
void game_loop(void);
void update_game(void);
void render_frame(void);

// Simple VBlank interrupt handler
void vblank_handler(void) {
    // This can be used for timing or sprite updates
    // For now, we'll keep it minimal
}

int main(void) {
    // Initialize all systems
    init_system();
    init_graphics();
    init_palette();
    
    // Initialize game-specific systems
    input_init();
    background_init();
    sprite_init();
    // input_test_init();  // Disabled for cube rotation testing
    
    // Enter main game loop
    game_loop();
    
    return 0;
}

void init_system(void) {
    // Disable interrupts during setup
    REG_IME = 0;
    
    // Set up VBlank interrupt
    REG_IE = INT_VBLANK;
    REG_IF = INT_VBLANK;
    REG_IME = 1;
}

void init_graphics(void) {
    // Wait for VBlank before modifying video settings
    while (REG_VCOUNT < 160);
    
    // Set up display control register
    // Mode 0 (tile mode), enable BG0 and sprites
    REG_DISPCNT = DISPCNT_MODE_0 | DISPCNT_BG0_ON | DISPCNT_OBJ_ON;
}

void init_palette(void) {
    // Set up a simple 16-color palette for backgrounds
    // Palette entry 0 is always transparent
    BG_PALETTE[0] = COLOR_BLACK;      // Transparent/background
    BG_PALETTE[1] = COLOR_WHITE;      // White
    BG_PALETTE[2] = COLOR_RED;        // Red  
    BG_PALETTE[3] = COLOR_GREEN;      // Green
    BG_PALETTE[4] = COLOR_BLUE;       // Blue
    BG_PALETTE[5] = COLOR_YELLOW;     // Yellow
    BG_PALETTE[6] = COLOR_MAGENTA;    // Magenta
    BG_PALETTE[7] = COLOR_CYAN;       // Cyan
    
    // Fill remaining palette entries with grays
    for (int i = 8; i < 16; i++) {
        int gray = (i - 8) * 4;  // 0, 4, 8, 12, 16, 20, 24, 28
        BG_PALETTE[i] = RGB15(gray, gray, gray);
    }
}

void game_loop(void) {
    while (1) {
        // Wait for VBlank to ensure smooth timing
        while (REG_VCOUNT >= 160);
        while (REG_VCOUNT < 160);
        
        // Update game logic
        update_game();
        
        // Render frame (minimal for tilemap demo)
        render_frame();
    }
}

void update_game(void) {
    // Update input state
    input_update();
    
    // Background system disabled - focusing on cube orbital movement
    // background_update();
    
    // Update sprites and cube (Link temporarily disabled)
    sprite_update();
    
    // Future game logic:
    // - Combat system
    // - Companion AI
    // - Scene transitions
}

void render_frame(void) {
    // Render all sprites to OAM
    sprite_render();
    
    // Render input test display
    // input_test_render();  // Disabled for cube rotation testing
    
    // Background is black - all visual feedback comes from cube rotation
}