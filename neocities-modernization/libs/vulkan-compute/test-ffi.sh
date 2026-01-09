#!/bin/bash
# test-ffi.sh - Runner script for Lua FFI tests
#
# This script tests the Lua FFI bindings for the Vulkan compute library.
# It can be run from any directory and will handle paths correctly.
#
# Usage: ./test-ffi.sh [DIR]
#   DIR - Path to vulkan-compute root directory (optional)

# {{{ Set DIR variable
DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# }}}

# {{{ Verify directory structure
if [ ! -d "$DIR/lua" ] || [ ! -d "$DIR/build" ]; then
    echo "ERROR: Invalid vulkan-compute directory: $DIR"
    echo "Expected directories: lua/, build/"
    exit 1
fi

if [ ! -f "$DIR/build/libvkcompute.so" ]; then
    echo "ERROR: Shared library not found: $DIR/build/libvkcompute.so"
    echo "Run 'make' in $DIR first"
    exit 1
fi
# }}}

# {{{ Change to DIR and run test
cd "$DIR" || exit 1
echo "Running FFI test from: $(pwd)"
luajit lua/test_ffi.lua "$DIR"
# }}}
