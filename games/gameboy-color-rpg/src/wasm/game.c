// {{{ Game Boy Color RPG - Main WASM Module
// Game Boy Color RPG - Main WASM Module
#include <stdint.h>
#include <stdbool.h>

// External JS functions we'll import
extern void js_clear_canvas(uint32_t color);
extern void js_draw_rect(int32_t x, int32_t y, int32_t width, int32_t height, uint32_t color);
extern void js_request_frame(void);

// Game state
static int32_t canvas_width = 800;
static int32_t canvas_height = 720;
static int32_t gbc_scale = 5; // 160x144 -> 800x720
static bool game_running = false;
static uint32_t frame_count = 0;

// Colors (GBC-style palette)
#define COLOR_BLACK   0x000000
#define COLOR_DGREEN  0x306230
#define COLOR_LGREEN  0x8BAC0F
#define COLOR_WHITE   0x9BBD0F

// {{{ init_game
// Initialize the game
void init_game(int32_t width, int32_t height) {
    canvas_width = width;
    canvas_height = height;
    
    // Calculate optimal scaling
    int scale_x = width / 160;
    int scale_y = height / 144;
    gbc_scale = (scale_x < scale_y) ? scale_x : scale_y;
    
    // Ensure minimum 5x scaling
    if (gbc_scale < 5) gbc_scale = 5;
    
    game_running = true;
    frame_count = 0;
}
// }}}

// {{{ get_canvas_width
// Get canvas width
int32_t get_canvas_width(void) {
    return canvas_width;
}
// }}}

// {{{ get_canvas_height  
// Get canvas height
int32_t get_canvas_height(void) {
    return canvas_height;
}
// }}}

// {{{ get_gbc_scale
// Get GBC scaling factor
int32_t get_gbc_scale(void) {
    return gbc_scale;
}
// }}}

// {{{ update_game
// Update game logic
void update_game(void) {
    frame_count++;
}
// }}}

// {{{ render_game
// Render game frame
void render_game(void) {
    // Clear canvas with dark green (GBC style)
    js_clear_canvas(COLOR_DGREEN);
    
    // Draw a simple animated rectangle to test rendering
    int32_t rect_size = 32 * gbc_scale; // 32x32 GBC pixels scaled up
    int32_t center_x = (canvas_width - rect_size) / 2;
    int32_t center_y = (canvas_height - rect_size) / 2;
    
    // Animate position slightly
    int32_t offset = (frame_count / 60) % 20 - 10; // Move back and forth
    
    js_draw_rect(
        center_x + offset * gbc_scale,
        center_y + offset * gbc_scale,
        rect_size,
        rect_size,
        COLOR_WHITE
    );
}
// }}}

// {{{ game_loop
// Main game loop called from JS
void game_loop(void) {
    if (!game_running) return;
    
    update_game();
    render_game();
    
    // Request next frame
    js_request_frame();
}
// }}}

// {{{ is_game_running
// Check if game is running
bool is_game_running(void) {
    return game_running;
}
// }}}

// {{{ stop_game
// Stop the game
void stop_game(void) {
    game_running = false;
}
// }}}
// }}}