// {{{ Game Boy Color RPG - JS Game Engine (temporary WASM replacement)
// Game Boy Color RPG - JS Game Engine (temporary WASM replacement)
// This will be replaced with actual WASM once proper toolchain is available

class GameEngine {
    // {{{ constructor
    constructor() {
        this.canvas_width = 800;
        this.canvas_height = 720;
        this.gbc_scale = 5; // 160x144 -> 800x720
        this.game_running = false;
        this.frame_count = 0;
        
        // Colors (GBC-style palette)
        this.COLOR_BLACK = 0x000000;
        this.COLOR_DGREEN = 0x306230;
        this.COLOR_LGREEN = 0x8BAC0F;
        this.COLOR_WHITE = 0x9BBD0F;
        
        // Canvas context reference
        this.ctx = null;
    }
    // }}}
    
    // {{{ setCanvasContext
    setCanvasContext(ctx) {
        this.ctx = ctx;
    }
    // }}}
    
    // {{{ init_game
    init_game(width, height) {
        this.canvas_width = width;
        this.canvas_height = height;
        
        // Calculate optimal scaling
        const scale_x = Math.floor(width / 160);
        const scale_y = Math.floor(height / 144);
        this.gbc_scale = Math.min(scale_x, scale_y);
        
        // Ensure minimum 5x scaling
        if (this.gbc_scale < 5) this.gbc_scale = 5;
        
        this.game_running = true;
        this.frame_count = 0;
        
        console.log(`Game initialized: ${width}x${height}, scale: ${this.gbc_scale}x`);
    }
    // }}}
    
    // {{{ get_canvas_width
    get_canvas_width() {
        return this.canvas_width;
    }
    // }}}
    
    // {{{ get_canvas_height
    get_canvas_height() {
        return this.canvas_height;
    }
    // }}}
    
    // {{{ get_gbc_scale
    get_gbc_scale() {
        return this.gbc_scale;
    }
    // }}}
    
    // {{{ update_game
    update_game() {
        this.frame_count++;
    }
    // }}}
    
    // {{{ render_game
    render_game() {
        if (!this.ctx) return;
        
        // Clear canvas with dark green (GBC style)
        this.js_clear_canvas(this.COLOR_DGREEN);
        
        // Draw a simple animated rectangle to test rendering
        const rect_size = 32 * this.gbc_scale; // 32x32 GBC pixels scaled up
        const center_x = (this.canvas_width - rect_size) / 2;
        const center_y = (this.canvas_height - rect_size) / 2;
        
        // Animate position slightly
        const offset = Math.floor(this.frame_count / 60) % 20 - 10; // Move back and forth
        
        this.js_draw_rect(
            center_x + offset * this.gbc_scale,
            center_y + offset * this.gbc_scale,
            rect_size,
            rect_size,
            this.COLOR_WHITE
        );
        
        // Draw frame counter for debugging
        this.ctx.fillStyle = '#9BBD0F';
        this.ctx.font = '12px monospace';
        this.ctx.fillText(`Frame: ${this.frame_count}`, 10, 20);
        this.ctx.fillText(`Scale: ${this.gbc_scale}x`, 10, 35);
    }
    // }}}
    
    // {{{ game_loop
    game_loop() {
        if (!this.game_running) return;
        
        this.update_game();
        this.render_game();
        
        // Request next frame
        this.js_request_frame();
    }
    // }}}
    
    // {{{ is_game_running
    is_game_running() {
        return this.game_running;
    }
    // }}}
    
    // {{{ stop_game
    stop_game() {
        this.game_running = false;
    }
    // }}}
    
    // {{{ js_clear_canvas
    js_clear_canvas(color) {
        if (!this.ctx) return;
        
        const r = (color >>> 16) & 0xFF;
        const g = (color >>> 8) & 0xFF;
        const b = color & 0xFF;
        
        this.ctx.fillStyle = `rgb(${r}, ${g}, ${b})`;
        this.ctx.fillRect(0, 0, this.canvas_width, this.canvas_height);
    }
    // }}}
    
    // {{{ js_draw_rect
    js_draw_rect(x, y, width, height, color) {
        if (!this.ctx) return;
        
        const r = (color >>> 16) & 0xFF;
        const g = (color >>> 8) & 0xFF;
        const b = color & 0xFF;
        
        this.ctx.fillStyle = `rgb(${r}, ${g}, ${b})`;
        this.ctx.fillRect(x, y, width, height);
    }
    // }}}
    
    // {{{ js_request_frame
    js_request_frame() {
        requestAnimationFrame(() => this.game_loop());
    }
    // }}}
}

// Export for use in main.js
window.GameEngine = GameEngine;
// }}}