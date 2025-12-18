#!/bin/bash
# run-local-lua.sh
# Wrapper script to run the local Lua interpreter

# -- {{{ run-local-lua
# Set the directory to the script's directory (following user instructions)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Allow override via command line argument
if [ $# -ge 1 ] && [ -d "$1" ]; then
    DIR="$1"
    shift
fi

# Path to local Lua installation
LOCAL_LUA="$DIR/../lua/local/bin/lua"

# Check if local Lua exists
if [ ! -f "$LOCAL_LUA" ]; then
    echo "Error: Local Lua not found at $LOCAL_LUA"
    echo "Run 'bash build-lua.sh' first."
    exit 1
fi

# Set up library paths for local libraries
export LUA_PATH="$DIR/../luasocket/?.lua;$DIR/../luasocket/socket/?.lua;$DIR/../dkjson/?.lua;./?.lua;?.lua"
export LUA_CPATH="$DIR/../luasocket/?.so;$DIR/../luasocket/socket/?.so;$DIR/../luasocket/mime/?.so;./?.so;?.so"

# Run local Lua with all arguments
exec "$LOCAL_LUA" "$@"
# -- }}}