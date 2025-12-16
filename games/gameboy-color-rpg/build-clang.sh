#!/bin/bash
# {{{ Build script for Game Boy Color RPG using clang
# Build script for Game Boy Color RPG using clang
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Accept DIR as argument
if [ "$1" != "" ]; then
    DIR="$1"
fi

echo "Building Game Boy Color RPG WASM module with clang..."
echo "Project directory: $DIR"

# Check if clang is available
if ! command -v clang &> /dev/null; then
    echo "Error: clang not found."
    exit 1
fi

# Create output directory
mkdir -p "$DIR/src/wasm"

# Compile C to WASM using clang
echo "Compiling C to WebAssembly..."
clang --target=wasm32 \
    -nostdlib \
    -Wl,--no-entry \
    -Wl,--export-all \
    -Wl,--allow-undefined \
    -O2 \
    "$DIR/src/wasm/game.c" \
    -o "$DIR/src/wasm/game.wasm"

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