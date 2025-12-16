// {{{ Game Boy Color RPG - Main JS Module
// Game Boy Color RPG - Main JS Module

// Canvas and context
let canvas;
let ctx;
let wasmModule;
let statusElement;

// WASM import object
const wasmImports = {
    env: {
        // {{{ js_clear_canvas
        js_clear_canvas: function(color) {
            const r = (color >>> 16) & 0xFF;
            const g = (color >>> 8) & 0xFF;
            const b = color & 0xFF;
            
            ctx.fillStyle = `rgb(${r}, ${g}, ${b})`;
            ctx.fillRect(0, 0, canvas.width, canvas.height);
        },
        // }}}
        
        // {{{ js_draw_rect
        js_draw_rect: function(x, y, width, height, color) {
            const r = (color >>> 16) & 0xFF;
            const g = (color >>> 8) & 0xFF;
            const b = color & 0xFF;
            
            ctx.fillStyle = `rgb(${r}, ${g}, ${b})`;
            ctx.fillRect(x, y, width, height);
        },
        // }}}
        
        // {{{ js_request_frame
        js_request_frame: function() {
            requestAnimationFrame(gameLoop);
        }
        // }}}
    }
};

// {{{ gameLoop
// Main game loop
function gameLoop() {
    if (wasmModule && wasmModule.exports.is_game_running()) {
        wasmModule.exports.game_loop();
    }
}
// }}}

// {{{ initCanvas
// Initialize canvas
function initCanvas() {
    canvas = document.getElementById('gameCanvas');
    ctx = canvas.getContext('2d');
    
    // Disable image smoothing for pixel-perfect rendering
    ctx.imageSmoothingEnabled = false;
    
    // Set canvas size based on window
    const maxWidth = Math.min(window.innerWidth - 40, 1280);
    const maxHeight = Math.min(window.innerHeight - 120, 720);
    
    // Calculate optimal size maintaining GBC aspect ratio (160:144)
    const aspectRatio = 160 / 144;
    let canvasWidth = maxWidth;
    let canvasHeight = maxWidth / aspectRatio;
    
    if (canvasHeight > maxHeight) {
        canvasHeight = maxHeight;
        canvasWidth = maxHeight * aspectRatio;
    }
    
    // Ensure dimensions are multiples of GBC resolution for clean scaling
    const scaleX = Math.floor(canvasWidth / 160);
    const scaleY = Math.floor(canvasHeight / 144);
    const scale = Math.max(Math.min(scaleX, scaleY), 5); // Minimum 5x scale
    
    canvas.width = 160 * scale;
    canvas.height = 144 * scale;
    
    updateStatus(`Canvas: ${canvas.width}x${canvas.height} (${scale}x scale)`);
    
    return { width: canvas.width, height: canvas.height };
}
// }}}

// {{{ updateStatus
// Update status message
function updateStatus(message) {
    if (statusElement) {
        statusElement.textContent = message;
    }
}
// }}}

// {{{ loadWasm
// Load and initialize WebAssembly
async function loadWasm() {
    try {
        updateStatus('Compiling WebAssembly...');
        
        // Fetch and compile WASM
        const wasmResponse = await fetch('src/wasm/game.wasm');
        const wasmBytes = await wasmResponse.arrayBuffer();
        const wasmModule = await WebAssembly.instantiate(wasmBytes, wasmImports);
        
        updateStatus('WebAssembly loaded successfully');
        return wasmModule;
        
    } catch (error) {
        updateStatus(`WASM Error: ${error.message}`);
        console.error('Failed to load WASM:', error);
        return null;
    }
}
// }}}

// {{{ startGame
// Start the game
async function startGame() {
    updateStatus('Initializing game...');
    
    // Initialize canvas
    const canvasDimensions = initCanvas();
    
    // Load WASM module
    wasmModule = await loadWasm();
    if (!wasmModule) {
        updateStatus('Failed to load game engine');
        return;
    }
    
    // Initialize game
    wasmModule.exports.init_game(canvasDimensions.width, canvasDimensions.height);
    
    // Start game loop
    updateStatus(`Game running at ${wasmModule.exports.get_gbc_scale()}x scale`);
    gameLoop();
}
// }}}

// {{{ Window event handlers
// Handle window resize
window.addEventListener('resize', () => {
    if (wasmModule && wasmModule.exports.is_game_running()) {
        const canvasDimensions = initCanvas();
        wasmModule.exports.init_game(canvasDimensions.width, canvasDimensions.height);
    }
});

// Handle page visibility changes
document.addEventListener('visibilitychange', () => {
    if (wasmModule) {
        if (document.hidden) {
            wasmModule.exports.stop_game();
            updateStatus('Game paused (tab hidden)');
        } else {
            wasmModule.exports.init_game(canvas.width, canvas.height);
            updateStatus(`Game resumed at ${wasmModule.exports.get_gbc_scale()}x scale`);
            gameLoop();
        }
    }
});
// }}}

// {{{ Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    statusElement = document.getElementById('status');
    startGame();
});
// }}}
// }}}