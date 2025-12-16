#!/bin/bash
# run-local-love.sh
# Wrapper script to run Love2D with local libraries

# -- {{{ run-local-love
# Set the directory to the script's directory (following user instructions)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Allow override via command line argument for directory
if [ $# -ge 1 ] && [ -d "$1" ] && [ ! -f "$1" ]; then
    DIR="$1"
    shift
fi

# Path to local Love2D AppImage
LOCAL_LOVE="$DIR/../love2d/love-11.5-x86_64.AppImage"

# Check if local Love2D exists
if [ ! -f "$LOCAL_LOVE" ]; then
    echo "Error: Local Love2D not found at $LOCAL_LOVE"
    echo "Run 'bash download-love2d.sh' first."
    exit 1
fi

# Make sure it's executable
chmod +x "$LOCAL_LOVE"

# Set up library paths for local libraries
export LUA_PATH="$DIR/../luasocket/?.lua;$DIR/../luasocket/socket/?.lua;$DIR/../dkjson/?.lua;./?.lua;?.lua"
export LUA_CPATH="$DIR/../luasocket/?.so;$DIR/../luasocket/socket/?.so;$DIR/../luasocket/mime/?.so;./?.so;?.so"

# If no arguments provided, show usage
if [ $# -eq 0 ]; then
    echo "Usage: $0 [game_directory|game.love]"
    echo "Examples:"
    echo "  $0 .                    # Run current directory as Love2D game"
    echo "  $0 ../example           # Run example directory"
    echo "  $0 mygame.love          # Run packaged Love2D game"
    exit 1
fi

# Run local Love2D with all arguments
exec "$LOCAL_LOVE" "$@"
# -- }}}