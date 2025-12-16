#!/bin/bash

# {{{ WebAssembly Build Script for Words-PDF Project
set -euo pipefail

DIR="/mnt/mtwo/programming/ai-stuff/words-pdf"
if [ $# -eq 1 ]; then
    DIR="$1"
fi

cd "$DIR"

echo "Building WebAssembly module for secure spacebar handling..."

# Check if emsdk is available
if [ ! -d "/tmp/emsdk" ]; then
    echo "Setting up Emscripten SDK..."
    git clone https://github.com/emscripten-core/emsdk.git /tmp/emsdk
    cd /tmp/emsdk
    ./emsdk install latest
    ./emsdk activate latest
    cd "$DIR"
fi

# Source emscripten environment
echo "Sourcing Emscripten environment..."
source /tmp/emsdk/emsdk_env.sh

# Compile C to WebAssembly
echo "Compiling spacebar-handler.c to WebAssembly..."
emcc src/spacebar-handler.c \
    -o src/spacebar-handler.js \
    -s EXPORTED_FUNCTIONS='["_wasm_init", "_enter_expansion_mode", "_exit_expansion_mode", "_is_expansion_mode", "_update_response_lines"]' \
    -s EXPORTED_RUNTIME_METHODS='["ccall", "cwrap", "UTF8ToString"]' \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s ENVIRONMENT='web' \
    -O2

echo "WebAssembly module compiled successfully!"
echo "Generated files:"
echo "  - src/spacebar-handler.js (JavaScript loader)"
echo "  - src/spacebar-handler.wasm (WebAssembly module)"

# }}}