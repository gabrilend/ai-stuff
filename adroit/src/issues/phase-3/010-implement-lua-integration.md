# Issue 010 - Implement Real Lua/LuaJIT Integration

## Current Behavior
The project currently has comprehensive Lua/LuaJIT integration framework with full API definitions in `libs/integration/lua_bridge.h` and `libs/integration/lua_bridge.c`, but all functions are stub implementations that return placeholder values. The framework supports:
- Context management (stub)
- Script execution (stub)
- Data exchange (stub)
- FFI integration for LuaJIT (stub)
- Performance profiling (stub)
- AI-assisted generation (stub)

## Intended Behavior
Replace all stub implementations with real Lua/LuaJIT library calls to enable:
- Actual Lua script execution for procedural generation
- High-performance LuaJIT compilation with FFI for zero-copy data access
- Character data processing and modification via Lua scripts
- Adventure generation and rule processing
- AI-powered content generation through Lua scripting
- Real-time performance profiling and optimization

## Suggested Implementation Steps

### Phase 3A: Core Lua Integration
1. **Install and Link Lua Libraries**
   - Add lua5.4-dev or luajit-dev dependency detection to Makefile
   - Update compilation flags to link against Lua libraries
   - Add conditional compilation based on available Lua version

2. **Implement Basic Context Management**
   - Replace stub `lua_context_create()` with real `luaL_newstate()`
   - Implement proper Lua state initialization and cleanup
   - Add error handling for context creation failures

3. **Implement Script Execution Functions**
   - Replace `lua_execute_string()` stub with real `luaL_dostring()`
   - Implement `lua_execute_file()` using `luaL_dofile()`
   - Add proper error capture and return value handling

### Phase 3B: Data Exchange Implementation
4. **Implement Variable Exchange**
   - Replace `lua_set_string/number/boolean()` stubs with real stack operations
   - Implement `lua_get_*()` functions using Lua stack manipulation
   - Add JSON parsing/generation for `lua_set_json()` and `lua_get_json()`

5. **Implement Character Data Integration**
   - Create Lua userdata type for Unit structures
   - Implement `lua_set_character()` and `lua_get_character()`
   - Add character stat modification functions callable from Lua

### Phase 3C: LuaJIT-Specific Features
6. **Implement FFI Integration (LuaJIT only)**
   - Replace FFI stub functions with real LuaJIT FFI calls
   - Implement zero-copy character data access via FFI
   - Add C struct definitions for direct Lua access

7. **Implement JIT Profiling and Optimization**
   - Replace JIT profiling stubs with real LuaJIT profiling API
   - Implement trace compilation monitoring
   - Add performance optimization hints

### Phase 3D: Advanced Features
8. **Implement Procedural Generation Functions**
   - Create Lua scripts for equipment generation
   - Implement name generation using Lua pattern libraries
   - Add story generation capabilities

9. **Add Module System Integration**
   - Implement `lua_module_create()` and registration
   - Add Lua module auto-discovery and loading
   - Create standard ai-stuff Lua utility libraries

10. **Implement Performance and Debugging**
    - Add real profiling data collection
    - Implement breakpoint and debugging support
    - Add script validation and error reporting

## Dependencies
- lua5.4-dev or luajit-dev system packages
- JSON parsing library (consider cjson or similar)
- Updated Makefile with conditional compilation
- Test Lua scripts for validation

## Verification Criteria
- All lua_test.c assertions pass with real implementations
- Character data can be modified via Lua scripts
- FFI integration provides 10x+ performance improvement for data access
- JIT profiling shows compilation traces and performance metrics
- Procedural generation functions create valid game content

## Estimated Complexity
**High** - This involves deep integration with external Lua libraries and requires expertise in:
- Lua C API programming
- LuaJIT FFI interface
- Performance optimization and profiling
- Error handling and memory management
- Cross-language data serialization

## Related Issues
- Issue 007: Modular architecture framework (enables Lua modules)
- Issue 009: Shared library system (provides infrastructure)
- Future: AI-assisted content generation
- Future: Real-time adventure scripting
- Future: Community Lua module ecosystem

## Notes
This is the largest single implementation task as it converts ~90 stub functions into real implementations. Consider breaking into sub-issues if needed. LuaJIT features should gracefully degrade to standard Lua if LuaJIT is not available.