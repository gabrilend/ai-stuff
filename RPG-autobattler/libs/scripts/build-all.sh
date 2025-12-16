#!/bin/bash
# build-all.sh
# Master build script for all RPG-autobattler dependencies

# -- {{{ build-all
# Set the directory to the script's directory (following user instructions)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Allow override via command line argument
if [ $# -eq 1 ]; then
    DIR="$1"
fi

# Make sure we're in the right directory
cd "$DIR/.."

echo "Building all libraries locally in $DIR/.."
echo "======================================="

# Build Lua first
echo "Building Lua..."
if [ -f "lua/src/lua.c" ] || bash "$DIR/build-lua.sh"; then
    echo "Lua build completed."
else
    echo "Lua build failed."
    exit 1
fi

# Download Love2D AppImage
echo "Downloading Love2D..."
if [ -f "love2d/love-11.5-x86_64.AppImage" ] || bash "$DIR/download-love2d.sh"; then
    echo "Love2D download completed."
else
    echo "Love2D download failed."
fi

# Build LuaSocket
echo "Building LuaSocket..."
if [ -f "luasocket/makefile" ]; then
    bash "$DIR/build-luasocket.sh"
    if [ $? -eq 0 ]; then
        echo "LuaSocket build completed."
    else
        echo "LuaSocket build failed."
        exit 1
    fi
else
    echo "LuaSocket source not found. Run download-luasocket.sh first."
fi

# Check dkjson (pure Lua, no compilation needed)
echo "Checking dkjson..."
if [ -f "dkjson/dkjson.lua" ]; then
    echo "dkjson.lua found."
else
    echo "dkjson.lua not found. Run download-dkjson.sh first."
fi

# Check Love2D
echo "Checking Love2D..."
if [ -f "love2d/love-11.5-x86_64.AppImage" ]; then
    love_version=$(./love2d/love-11.5-x86_64.AppImage --version 2>/dev/null || echo "Unknown")
    echo "Local Love2D found: $love_version"
else
    echo "Local Love2D not found."
fi

echo "======================================="
echo "Build process completed!"
echo "To test the installations, run: bash test-libs.sh"
# -- }}}