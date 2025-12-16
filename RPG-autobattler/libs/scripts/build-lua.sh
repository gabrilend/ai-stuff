#!/bin/bash
# build-lua.sh
# Downloads and compiles Lua locally

# -- {{{ build-lua
# Set the directory to the script's directory (following user instructions)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Allow override via command line argument
if [ $# -eq 1 ]; then
    DIR="$1"
fi

# Navigate to lua directory
cd "$DIR/../lua"

LUA_VERSION="5.2.4"
DOWNLOAD_URL="https://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz"

echo "Building Lua v${LUA_VERSION}..."

# Check if source already exists
if [ ! -f "src/lua.c" ]; then
    echo "Downloading Lua source..."
    wget "$DOWNLOAD_URL" -O "lua-${LUA_VERSION}.tar.gz"
    
    if [ $? -eq 0 ]; then
        echo "Extracting..."
        tar -xzf "lua-${LUA_VERSION}.tar.gz"
        mv "lua-${LUA_VERSION}"/* .
        rm -rf "lua-${LUA_VERSION}" "lua-${LUA_VERSION}.tar.gz"
    else
        echo "Failed to download Lua source"
        exit 1
    fi
fi

# Check for build dependencies
echo "Checking build dependencies..."

if ! command -v gcc &> /dev/null; then
    echo "Error: gcc not found. Please install build-essential or equivalent."
    exit 1
fi

if ! command -v make &> /dev/null; then
    echo "Error: make not found. Please install make."
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

echo "Building for platform: $PLATFORM"

# Clean previous builds
echo "Cleaning previous builds..."
make clean

# Build Lua
echo "Compiling Lua..."
make "$PLATFORM"

if [ $? -eq 0 ]; then
    echo "Compilation successful!"
    
    # Install locally
    echo "Installing locally..."
    LOCAL_PREFIX="$(pwd)/local"
    make install INSTALL_TOP="$LOCAL_PREFIX"
    
    if [ $? -eq 0 ]; then
        echo "Local installation successful!"
        echo "Lua installed in: $LOCAL_PREFIX"
        echo ""
        echo "Lua binary: $LOCAL_PREFIX/bin/lua"
        echo "Lua compiler: $LOCAL_PREFIX/bin/luac"
        echo "Lua headers: $LOCAL_PREFIX/include/"
        echo "Lua library: $LOCAL_PREFIX/lib/liblua.a"
        
        # Test the installation
        echo ""
        echo "Testing installation..."
        if "$LOCAL_PREFIX/bin/lua" -v; then
            echo "✓ Lua installation successful!"
        else
            echo "✗ Lua installation test failed"
            exit 1
        fi
    else
        echo "Local installation failed."
        exit 1
    fi
else
    echo "Compilation failed. Check the error messages above."
    exit 1
fi
# -- }}}