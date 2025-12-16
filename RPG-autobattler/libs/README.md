# RPG-Autobattler Libraries

This directory contains all the external libraries required for the RPG-autobattler project. **Everything is bundled locally** - no system-wide dependencies required!

## Bundled Libraries

### Lua
- **Purpose**: Core scripting language
- **Version**: 5.2.4
- **Status**: Compiled locally
- **Location**: `./lua/local/`

### Love2D
- **Purpose**: Game engine framework
- **Version**: 11.5
- **Status**: AppImage (portable)
- **Location**: `./love2d/love-11.5-x86_64.AppImage`

### LuaSocket
- **Purpose**: Network communication
- **Version**: 3.1.0
- **Status**: Compiled locally against local Lua
- **Location**: `./luasocket/`

### dkjson
- **Purpose**: JSON parsing and encoding
- **Version**: Latest from master
- **Status**: Pure Lua library
- **Location**: `./dkjson/dkjson.lua`

## Quick Setup

To set up all libraries:

```bash
cd libs/scripts
bash build-all.sh
```

## Individual Library Setup

### Building Lua Locally
```bash
cd libs/scripts
bash build-lua.sh
```

### Downloading Love2D AppImage
```bash
cd libs/scripts
bash download-love2d.sh
```

### Building LuaSocket
```bash
cd libs/scripts
bash download-luasocket.sh  # Only if not already downloaded
bash build-luasocket.sh
```

### Downloading dkjson
```bash
cd libs/scripts
bash download-dkjson.sh
```

## Testing Libraries

To test all library installations:

```bash
cd libs/scripts
bash test-libs.sh
```

## Using Libraries in Your Project

### Method 1: Using Wrapper Scripts (Recommended)

```bash
# Run Lua scripts
bash libs/scripts/run-local-lua.sh myscript.lua

# Run Love2D games  
bash libs/scripts/run-local-love.sh mygame/
```

### Method 2: Manual Environment Setup

```bash
# Set environment variables
export LUA_PATH="libs/luasocket/?.lua;libs/luasocket/socket/?.lua;libs/dkjson/?.lua;./?.lua;?.lua"
export LUA_CPATH="libs/luasocket/?.so;libs/luasocket/socket/?.so;libs/luasocket/mime/?.so;./?.so;?.so"

# Then run with local binaries
libs/lua/local/bin/lua myscript.lua
libs/love2d/love-11.5-x86_64.AppImage mygame/
```

### Method 3: Manual Path Setup in Code

```lua
-- Only needed if not using wrapper scripts
local libs_path = "libs"
package.path = libs_path .. "/luasocket/?.lua;" .. 
               libs_path .. "/luasocket/socket/?.lua;" .. 
               libs_path .. "/dkjson/?.lua;" .. 
               package.path

package.cpath = libs_path .. "/luasocket/?.so;" .. 
                libs_path .. "/luasocket/socket/?.so;" .. 
                libs_path .. "/luasocket/mime/?.so;" .. 
                package.cpath

-- Load libraries
local socket = require("socket")
local json = require("dkjson")
```

## Directory Structure

```
libs/
├── README.md                 # This file
├── lua/                      # Local Lua installation
│   ├── local/               # Compiled Lua binaries and headers
│   │   ├── bin/            # lua, luac executables
│   │   ├── include/        # Lua headers for compilation
│   │   └── lib/            # Lua static library
│   └── src/                 # Lua source code
├── love2d/                   # Love2D AppImage
│   └── love-11.5-x86_64.AppImage
├── luasocket/                # LuaSocket source and compiled modules
│   ├── socket.lua           # Main socket module
│   ├── socket/              # Socket submodules
│   │   ├── core.so         # Compiled socket core
│   │   ├── http.lua        # HTTP client
│   │   ├── smtp.lua        # SMTP client
│   │   └── ...             # Other socket modules
│   ├── mime/                # MIME modules
│   │   └── core.so         # Compiled MIME core
│   └── src/                 # Source code (for rebuilding)
├── dkjson/                   # JSON library
│   └── dkjson.lua           # Pure Lua JSON implementation
├── example/                  # Example Love2D project
│   ├── main.lua             # Demo application
│   └── README.md            # Usage instructions
└── scripts/                  # Build and setup scripts
    ├── build-all.sh         # Build all libraries
    ├── build-lua.sh         # Build Lua only
    ├── build-luasocket.sh   # Build LuaSocket only
    ├── download-love2d.sh   # Download Love2D AppImage
    ├── download-luasocket.sh # Download LuaSocket source
    ├── download-dkjson.sh   # Download dkjson
    ├── run-local-lua.sh     # Run local Lua with proper paths
    ├── run-local-love.sh    # Run local Love2D with proper paths
    └── test-libs.sh         # Test all installations
```

## Build Requirements

- **GCC**: C compiler for Lua and LuaSocket
- **Make**: Build system
- **wget**: For downloading libraries
- **tar**: For extracting source archives

**Note**: No Lua development headers needed since we compile Lua locally!

## Platform Support

- **Linux x86_64**: Fully supported and tested
- **macOS**: Should work with minor adjustments to build scripts
- **Windows**: Requires WSL or similar environment

## Advantages of Local Installation

✅ **Self-contained**: No system dependencies
✅ **Version-locked**: Consistent behavior across environments  
✅ **Portable**: Can be moved between machines
✅ **Isolated**: Won't conflict with system installations
✅ **Reproducible**: Same setup everywhere

## Troubleshooting

### LuaSocket Compilation Issues

If LuaSocket fails to compile:

1. Ensure build tools are installed:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install build-essential
   
   # CentOS/RHEL
   sudo yum install gcc make
   ```

2. Rebuild from clean state:
   ```bash
   cd libs/scripts
   bash build-lua.sh      # Rebuild Lua first
   bash build-luasocket.sh # Then rebuild LuaSocket
   ```

### Love2D AppImage Issues

If Love2D AppImage won't run:

1. Make sure it's executable:
   ```bash
   chmod +x libs/love2d/love-11.5-x86_64.AppImage
   ```

2. Check if FUSE is available:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install fuse
   ```

### Path Issues

If libraries can't be found at runtime:

1. Use the wrapper scripts instead of direct execution
2. Verify environment variables are set correctly
3. Check that compiled .so files exist in the correct locations

## Self-Contained Execution

Once built, the entire libs directory can be copied to any compatible Linux system and will work without additional installation. This makes deployment and distribution much simpler!