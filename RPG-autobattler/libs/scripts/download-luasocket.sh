#!/bin/bash
# download-luasocket.sh
# Downloads and extracts LuaSocket source code

# -- {{{ download-luasocket
# Set the directory to the script's directory (following user instructions)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Allow override via command line argument
if [ $# -eq 1 ]; then
    DIR="$1"
fi

# Navigate to luasocket directory
cd "$DIR/../luasocket"

LUASOCKET_VERSION="3.1.0"
DOWNLOAD_URL="https://github.com/lunarmodules/luasocket/archive/refs/tags/v${LUASOCKET_VERSION}.tar.gz"

echo "Downloading LuaSocket v${LUASOCKET_VERSION}..."
echo "URL: $DOWNLOAD_URL"

# Download source
wget "$DOWNLOAD_URL" -O "luasocket-${LUASOCKET_VERSION}.tar.gz"

if [ $? -eq 0 ]; then
    echo "Download successful, extracting..."
    
    # Extract and move files
    tar -xzf "luasocket-${LUASOCKET_VERSION}.tar.gz"
    
    # Move contents to current directory
    mv "luasocket-${LUASOCKET_VERSION}"/* .
    
    # Clean up
    rm -rf "luasocket-${LUASOCKET_VERSION}"
    rm "luasocket-${LUASOCKET_VERSION}.tar.gz"
    
    echo "LuaSocket source downloaded and extracted successfully!"
    echo "To compile, run: bash build-luasocket.sh"
else
    echo "Failed to download LuaSocket source."
    exit 1
fi
# -- }}}