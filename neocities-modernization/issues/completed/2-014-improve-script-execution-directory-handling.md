# Issue 014: Improve Script Execution Directory Handling

## Current Behavior
- Scripts fail when executed from wrong directory (e.g., running from `src/` instead of project root)
- Error messages unclear about directory requirements
- Module loading depends on current working directory
- No graceful handling of relative path issues

## Intended Behavior
- Scripts work regardless of execution directory
- Clear error messages when dependencies cannot be found
- Robust path resolution for all module dependencies
- Consistent behavior across different execution contexts

## Root Cause Analysis

### **Directory Dependency Issue**
Scripts currently expect to be run from project root:
- **Working**: `lua src/similarity-engine-parallel.lua -I` (from project root)
- **Failing**: `lua similarity-engine-parallel.lua -I` (from src/ directory)

### **Module Loading Path Issues**
Current package.path configuration:
```lua
package.path = package.path .. ';./libs/?.lua;./src/?.lua;../libs/?.lua;../src/?.lua'
```

Problems:
1. **Relative path dependency**: Assumes specific current directory
2. **Limited fallbacks**: Not all possible execution scenarios covered
3. **Library path hardcoding**: Effil path hardcoded to specific location

## Suggested Implementation Steps
1. **Dynamic Path Detection**: Detect script location and adjust paths accordingly
2. **Enhanced Error Messages**: Provide clear guidance when modules not found
3. **Robust Path Resolution**: Support execution from multiple directory levels
4. **Library Path Discovery**: Automatically find effil library location
5. **Testing**: Verify scripts work from various execution directories

## Technical Requirements

### **Enhanced Path Resolution**
```lua
-- {{{ function get_script_directory
local function get_script_directory()
    local info = debug.getinfo(1, "S")
    local script_path = info.source:match("@?(.*)")
    return script_path:match("(.*[/\\])")
end
-- }}}

-- {{{ function setup_package_paths
local function setup_package_paths()
    local script_dir = get_script_directory()
    local project_root = script_dir:match("(.*/)[^/]+/$") or script_dir .. "../"
    
    -- Add multiple path possibilities
    local paths = {
        project_root .. "libs/?.lua",
        project_root .. "src/?.lua",
        "./libs/?.lua",
        "./src/?.lua",
        "../libs/?.lua",
        "../src/?.lua"
    }
    
    package.path = package.path .. ";" .. table.concat(paths, ";")
end
-- }}}
```

### **Library Discovery Function**
```lua
-- {{{ function find_effil_library
local function find_effil_library()
    local possible_locations = {
        "/home/ritz/programming/ai-stuff/libs/lua/effil-jit/build/effil.so",
        "/home/ritz/programming/ai-stuff/libs/lua/effil/build/effil.so",
        "/usr/local/lib/lua/5.1/effil.so",
        "/usr/lib/lua/5.1/effil.so"
    }
    
    for _, path in ipairs(possible_locations) do
        local file = io.open(path, "r")
        if file then
            file:close()
            return path
        end
    end
    
    return nil
end
-- }}}
```

### **Enhanced Error Messages**
```lua
-- {{{ function show_execution_help
local function show_execution_help()
    print("ERROR: Required modules not found")
    print("")
    print("This script must be executed with proper module access.")
    print("Try one of these approaches:")
    print("")
    print("1. Run from project root:")
    print("   cd /mnt/mtwo/programming/ai-stuff/neocities-modernization/")
    print("   lua src/similarity-engine-parallel.lua -I")
    print("")
    print("2. Run with absolute path:")
    print("   lua /full/path/to/src/similarity-engine-parallel.lua -I")
    print("")
    print("3. Ensure libs/ directory is accessible from current location")
    print("")
    print("Current working directory: " .. (io.popen("pwd"):read("*l") or "unknown"))
    print("Script location: " .. (debug.getinfo(1, "S").source:match("@?(.*)")))
end
-- }}}
```

## Implementation Enhancements

### **Cross-Platform Compatibility**
```lua
-- Handle both Unix and Windows path separators
local path_sep = package.config:sub(1,1)  -- Gets system path separator

-- Normalize paths for current system
local function normalize_path(path)
    return path:gsub("[/\\]", path_sep)
end
```

### **Module Verification**
```lua
-- {{{ function verify_required_modules
local function verify_required_modules()
    local required_modules = {
        {name = "utils", description = "Utility functions"},
        {name = "dkjson", description = "JSON encoding/decoding"},
        {name = "effil", description = "Threading library", optional = true}
    }
    
    local missing = {}
    
    for _, module in ipairs(required_modules) do
        local success, _ = pcall(require, module.name)
        if not success and not module.optional then
            table.insert(missing, module)
        end
    end
    
    return missing
end
-- }}}
```

## User Experience Improvements

### **Flexible Execution**
Users can run scripts from:
- Project root directory
- src/ subdirectory  
- Any directory with proper path setup
- Via absolute paths

### **Clear Error Guidance**
When modules missing:
```
ERROR: Required modules not found

This script must be executed with proper module access.
Try one of these approaches:

1. Run from project root:
   cd /mnt/mtwo/programming/ai-stuff/neocities-modernization/
   lua src/similarity-engine-parallel.lua -I

2. Run with absolute path:
   lua /full/path/to/src/similarity-engine-parallel.lua -I

3. Ensure libs/ directory is accessible from current location

Current working directory: /home/ritz/somewhere
Script location: /mnt/mtwo/programming/ai-stuff/neocities-modernization/src/similarity-engine-parallel.lua
```

## Quality Assurance Criteria
- Scripts execute successfully from project root
- Scripts execute successfully from src/ directory
- Scripts execute successfully from arbitrary directories (with proper setup)
- Clear error messages when dependencies unavailable
- Automatic path discovery for common library locations

## Success Metrics
- **Execution Flexibility**: Scripts work from multiple directory contexts
- **Error Clarity**: 100% of path errors provide actionable guidance
- **User Experience**: No confusion about how to run scripts
- **Maintenance**: Path configurations easy to update for new environments

## Implementation Validation
1. Test execution from project root directory
2. Test execution from src/ subdirectory
3. Test execution from arbitrary directory
4. Verify error messages are helpful and accurate
5. Test path resolution on different systems
6. Confirm library discovery works for various installation locations

**USER REQUEST FULFILLMENT:**
This ticket addresses:
1. ✅ Script execution directory confusion
2. ✅ Module loading path issues  
3. ✅ Error message clarity
4. ✅ User experience improvement

**ISSUE STATUS: READY FOR IMPLEMENTATION** 🚀

**PRIORITY**: Medium - Improves developer experience

**DEPENDENCIES:**
- Lua debug library for script location detection
- File system access for path verification

**RELATED ISSUES:**
- Issue 013: Effil Threading Library Compatibility
- All script execution and module loading issues