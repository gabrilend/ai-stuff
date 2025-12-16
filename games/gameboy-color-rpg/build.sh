#!/bin/bash
# {{{ Build script for Game Boy Color RPG
# Build script for Game Boy Color RPG
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Accept DIR as argument
if [ "$1" != "" ]; then
    DIR="$1"
fi

echo "Building Game Boy Color RPG WASM module..."
echo "Project directory: $DIR"

# {{{ setup_emscripten_environment
setup_emscripten_environment() {
    # Set quiet mode before sourcing
    export EMSDK_QUIET=1
    
    # Save our DIR variable before sourcing emsdk (which overrides DIR)
    PROJECT_DIR="$DIR"
    EMSDK_DIR="$PROJECT_DIR/libs/emsdk"
    
    if [ -d "$EMSDK_DIR" ]; then
        echo "Using local Emscripten SDK..."
        source "$EMSDK_DIR/emsdk_env.sh"
        
        # Restore our DIR variable
        DIR="$PROJECT_DIR"
        
        if command -v emcc &> /dev/null; then
            echo "✓ Local Emscripten activated: $(emcc --version | head -n1)"
            return 0
        else
            echo "✗ Failed to activate local Emscripten"
            return 1
        fi
    fi
    
    # Check if system emcc is available
    if command -v emcc &> /dev/null; then
        echo "Using system Emscripten: $(emcc --version | head -n1)"
        return 0
    fi
    
    # No Emscripten found
    echo "Error: Emscripten (emcc) not found."
    echo ""
    echo "To install local Emscripten SDK:"
    echo "  ./scripts/build-dependencies"
    echo ""
    echo "Or install system-wide:"
    echo "  Visit: https://emscripten.org/docs/getting_started/downloads.html"
    return 1
}
# }}}

# Setup Emscripten environment
if ! setup_emscripten_environment; then
    exit 1
fi

# Create output directory
mkdir -p "$DIR/src/wasm"

# Compile C to WASM
echo "Compiling C to WebAssembly..."
emcc "$DIR/src/wasm/game.c" \
    -o "$DIR/src/wasm/game.wasm" \
    -s WASM=1 \
    -s EXPORTED_FUNCTIONS='["_init_game","_get_canvas_width","_get_canvas_height","_get_gbc_scale","_update_game","_render_game","_game_loop","_is_game_running","_stop_game"]' \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s STANDALONE_WASM=1 \
    -Wl,--allow-undefined \
    -O2 \
    --no-entry

if [ $? -eq 0 ]; then
    echo "✓ WASM compilation successful!"
    echo "✓ Output: $DIR/src/wasm/game.wasm"
    echo ""
    echo "To test the game:"
    echo "1. Start a local web server in the project directory"
    echo "2. Open index.html in a browser"
    echo ""
    echo "Example web server commands:"
    echo "  python3 -m http.server 8000"
    echo "  or"
    echo "  npx serve ."
else
    echo "✗ WASM compilation failed!"
    exit 1
fi
# }}}