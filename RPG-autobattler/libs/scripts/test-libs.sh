#!/bin/bash
# test-libs.sh
# Tests all installed libraries

# -- {{{ test-libs
# Set the directory to the script's directory (following user instructions)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Allow override via command line argument
if [ $# -eq 1 ]; then
    DIR="$1"
fi

cd "$DIR/.."

echo "Testing library installations..."
echo "======================================="

# Test local Lua
echo "Testing local Lua:"
LOCAL_LUA="$DIR/../lua/local/bin/lua"
if [ -f "$LOCAL_LUA" ]; then
    lua_version=$("$LOCAL_LUA" -v 2>/dev/null | head -1 || echo "Unknown version")
    echo "  ✓ Local Lua found: $lua_version"
else
    echo "  ✗ Local Lua not found at $LOCAL_LUA"
fi

# Test Love2D
echo ""
echo "Testing Love2D:"
LOCAL_LOVE="$DIR/../love2d/love-11.5-x86_64.AppImage"
if [ -f "$LOCAL_LOVE" ]; then
    love_version=$("$LOCAL_LOVE" --version 2>/dev/null || echo "Unknown version")
    echo "  ✓ Local Love2D found: $love_version"
else
    echo "  ✗ Local Love2D not found at $LOCAL_LOVE"
fi

# Test LuaSocket
echo ""
echo "Testing LuaSocket:"
cd luasocket

# Create a temporary test script
cat > test_luasocket.lua << 'EOF'
-- Test LuaSocket
local success, socket = pcall(require, 'socket')
if success then
    print("  ✓ LuaSocket loaded successfully")
    print("    Version:", socket._VERSION or "Unknown")
    
    -- Test TCP socket creation
    local tcp_success, tcp_socket = pcall(socket.tcp)
    if tcp_success then
        print("  ✓ TCP socket creation works")
        tcp_socket:close()
    else
        print("  ✗ TCP socket creation failed:", tcp_socket)
    end
    
    -- Test UDP socket creation
    local udp_success, udp_socket = pcall(socket.udp)
    if udp_success then
        print("  ✓ UDP socket creation works")
        udp_socket:close()
    else
        print("  ✗ UDP socket creation failed:", udp_socket)
    end
else
    print("  ✗ Failed to load LuaSocket:", socket)
end
EOF

# Run the test with local Lua and proper paths
LUA_PATH="./?.lua;./socket/?.lua;$LUA_PATH" LUA_CPATH="./?.so;./socket/?.so;./mime/?.so;$LUA_CPATH" "$LOCAL_LUA" test_luasocket.lua

# Clean up
rm test_luasocket.lua

cd ../dkjson

# Test dkjson
echo ""
echo "Testing dkjson:"

# Create a temporary test script
cat > test_dkjson.lua << 'EOF'
-- Test dkjson
local success, json = pcall(require, 'dkjson')
if success then
    print("  ✓ dkjson loaded successfully")
    
    -- Test encoding
    local test_table = {name = "test", value = 42, list = {1, 2, 3}}
    local encode_success, json_string = pcall(json.encode, test_table)
    if encode_success then
        print("  ✓ JSON encoding works")
        print("    Encoded:", json_string)
        
        -- Test decoding
        local decode_success, decoded_table = pcall(json.decode, json_string)
        if decode_success then
            print("  ✓ JSON decoding works")
            print("    Decoded name:", decoded_table.name)
        else
            print("  ✗ JSON decoding failed:", decoded_table)
        end
    else
        print("  ✗ JSON encoding failed:", json_string)
    end
else
    print("  ✗ Failed to load dkjson:", json)
end
EOF

# Run the test with local Lua
LUA_PATH="./?.lua;$LUA_PATH" "$LOCAL_LUA" test_dkjson.lua

# Clean up
rm test_dkjson.lua

cd "$DIR/.."

echo ""
echo "======================================="
echo "Library testing completed!"

# Create a summary
echo ""
echo "Library Status Summary:"
echo "----------------------"

# Local Lua status
if [ -f "$LOCAL_LUA" ]; then
    echo "Local Lua: ✓ Installed ($("$LOCAL_LUA" -v 2>/dev/null | head -1))"
else
    echo "Local Lua: ✗ Not found"
fi

# Love2D status
if [ -f "$LOCAL_LOVE" ]; then
    echo "Love2D: ✓ Installed ($("$LOCAL_LOVE" --version 2>/dev/null | head -1))"
else
    echo "Love2D: ✗ Not found"
fi

# LuaSocket status
cd luasocket
if [ -f "socket.lua" ] && [ -f "socket/core.so" ]; then
    echo "LuaSocket: ✓ Installed and compiled"
else
    echo "LuaSocket: ✗ Missing files"
fi

cd ../dkjson
# dkjson status
if [ -f "dkjson.lua" ]; then
    echo "dkjson: ✓ Installed"
else
    echo "dkjson: ✗ Missing"
fi

echo ""
echo "To use these libraries in your project:"
echo "1. Use the wrapper scripts: run-local-lua.sh or run-local-love.sh"
echo "2. Or manually set LUA_PATH and LUA_CPATH environment variables"
echo "3. See the example code in the test scripts above"
echo ""
echo "Example usage:"
echo "  bash scripts/run-local-lua.sh myscript.lua"
echo "  bash scripts/run-local-love.sh ../example"
# -- }}}