#!/bin/bash
# build-luasocket.sh
# Compiles LuaSocket from source

# -- {{{ build-luasocket
# Set the directory to the script's directory (following user instructions)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Allow override via command line argument
if [ $# -eq 1 ]; then
    DIR="$1"
fi

# Navigate to luasocket directory
cd "$DIR/../luasocket"

echo "Building LuaSocket..."
echo "Working directory: $(pwd)"

# Check if source files exist
if [ ! -f "makefile" ]; then
    echo "Error: LuaSocket source not found. Run download-luasocket.sh first."
    exit 1
fi

# Detect platform
PLATFORM="linux"
case "$(uname)" in
    Darwin)
        PLATFORM="macosx"
        ;;
    Linux)
        PLATFORM="linux"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        PLATFORM="mingw"
        ;;
    FreeBSD)
        PLATFORM="freebsd"
        ;;
    SunOS)
        PLATFORM="solaris"
        ;;
esac

echo "Detected platform: $PLATFORM"

# Check for required build tools
echo "Checking build dependencies..."

if ! command -v gcc &> /dev/null; then
    echo "Error: gcc not found. Please install build-essential or equivalent."
    exit 1
fi

if ! command -v make &> /dev/null; then
    echo "Error: make not found. Please install make."
    exit 1
fi

# Check for Lua development headers
LUA_INCLUDE_FOUND=false
for lua_include in "/usr/include/lua5.1" "/usr/include/lua/5.1" "/usr/include/lua5.2" "/usr/include/lua/5.2" "/usr/include/lua5.3" "/usr/include/lua/5.3" "/usr/include/lua5.4" "/usr/include/lua/5.4"; do
    if [ -d "$lua_include" ]; then
        echo "Found Lua headers at: $lua_include"
        LUA_INCLUDE_FOUND=true
        break
    fi
done

if [ "$LUA_INCLUDE_FOUND" = false ]; then
    echo "Warning: Lua development headers not found."
    echo "On Ubuntu/Debian, install with: sudo apt-get install liblua5.1-dev"
    echo "On CentOS/RHEL, install with: sudo yum install lua-devel"
    echo "Continuing anyway..."
fi

# Clean previous builds
echo "Cleaning previous builds..."
make clean

# Use local Lua installation
LOCAL_LUA_DIR="$DIR/../lua/local"
LOCAL_LUA_BIN="$LOCAL_LUA_DIR/bin/lua"
LOCAL_LUA_INCLUDE="$LOCAL_LUA_DIR/include"

if [ ! -f "$LOCAL_LUA_BIN" ]; then
    echo "Error: Local Lua not found at $LOCAL_LUA_BIN"
    echo "Run 'bash build-lua.sh' first."
    exit 1
fi

# Detect Lua version from local installation
LUA_VERSION=$("$LOCAL_LUA_BIN" -v 2>&1 | grep -o 'Lua [0-9]\.[0-9]' | grep -o '[0-9]\.[0-9]')
echo "Using local Lua version: $LUA_VERSION"
echo "Lua binary: $LOCAL_LUA_BIN"
echo "Lua headers: $LOCAL_LUA_INCLUDE"

# Build for detected platform with local Lua
echo "Compiling LuaSocket for $PLATFORM with local Lua $LUA_VERSION..."
LUAINC_linux="$LOCAL_LUA_INCLUDE" LUAV="$LUA_VERSION" make "$PLATFORM"

if [ $? -eq 0 ]; then
    echo "Compilation successful!"
    
    # Install locally
    echo "Installing locally..."
    LUAV="$LUA_VERSION" make local
    
    if [ $? -eq 0 ]; then
        echo "Local installation successful!"
        echo "LuaSocket modules installed in: $(pwd)"
        echo ""
        echo "Files created:"
        find . -name "*.so" -o -name "*.lua" | grep -v src/ | sort
    else
        echo "Local installation failed."
        exit 1
    fi
else
    echo "Compilation failed. Check the error messages above."
    exit 1
fi
# -- }}}