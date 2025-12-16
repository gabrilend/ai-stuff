#!/bin/bash
# download-dkjson.sh
# Downloads dkjson.lua library

# -- {{{ download-dkjson
# Set the directory to the script's directory (following user instructions)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Allow override via command line argument
if [ $# -eq 1 ]; then
    DIR="$1"
fi

# Navigate to dkjson directory
cd "$DIR/../dkjson"

DKJSON_URL="https://raw.githubusercontent.com/LuaDist/dkjson/master/dkjson.lua"

echo "Downloading dkjson.lua..."
echo "URL: $DKJSON_URL"

# Download the library
wget "$DKJSON_URL" -O "dkjson.lua"

if [ $? -eq 0 ]; then
    echo "dkjson.lua downloaded successfully!"
    echo "File saved to: $(pwd)/dkjson.lua"
    
    # Verify the file
    if [ -f "dkjson.lua" ] && [ -s "dkjson.lua" ]; then
        file_size=$(wc -c < "dkjson.lua")
        echo "File size: $file_size bytes"
        
        # Check if it's a valid Lua file
        if head -1 "dkjson.lua" | grep -q "^--"; then
            echo "File appears to be a valid Lua script."
        else
            echo "Warning: File may not be a valid Lua script."
        fi
    else
        echo "Error: Downloaded file is empty or missing."
        exit 1
    fi
else
    echo "Failed to download dkjson.lua"
    exit 1
fi
# -- }}}