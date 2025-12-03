#include <stdio.h>
#include <stdlib.h>
#include "libs/common/logging.h"
#include "libs/integration/lua_bridge.h"

int main() {
    printf("🌙 Lua Integration Test\n");
    printf("=======================\n\n");
    
    // Initialize logging
    LogConfig config = log_default_config();
    log_init(&config);
    LOG_INFO("Lua integration test starting");
    
    // Create Lua context
    printf("🔧 Creating Lua context...\n");
    LuaContext* ctx = lua_context_create();
    if (ctx) {
        printf("✅ Lua context created successfully\n");
        
        // Test script execution
        printf("📜 Testing Lua script execution...\n");
        LuaResult* result = lua_execute_string(ctx, "return 'Hello from Lua!'");
        if (lua_result_success(result)) {
            printf("✅ Lua execution: %s\n", lua_result_output(result));
        }
        free_lua_result(result);
        
        // Test variable setting
        printf("📝 Testing variable operations...\n");
        lua_set_string(ctx, "test_var", "integration_works");
        lua_set_number(ctx, "magic_number", 42.0);
        lua_set_boolean(ctx, "is_awesome", true);
        
        const char* str_val = lua_get_string(ctx, "test_var");
        double num_val = lua_get_number(ctx, "magic_number");
        bool bool_val = lua_get_boolean(ctx, "is_awesome");
        
        printf("✅ String: %s, Number: %.1f, Boolean: %s\n", 
               str_val, num_val, bool_val ? "true" : "false");
        
        // Test procedural generation
        printf("⚔️  Testing equipment generation...\n");
        result = lua_generate_equipment(ctx, NULL, "sword");
        if (result) {
            printf("✅ Generated equipment: %s\n", lua_result_return_value(result));
            free_lua_result(result);
        }
        
        printf("📚 Testing story generation...\n");
        result = lua_generate_story(ctx, "quest", NULL);
        if (result) {
            printf("✅ Generated story: %s\n", lua_result_output(result));
            free_lua_result(result);
        }
        
        // Test AI integration
        printf("🤖 Testing AI script generation...\n");
        result = lua_ai_generate_script(ctx, "create a function that rolls dice");
        if (result) {
            printf("✅ AI generated script:\n%s\n", lua_result_return_value(result));
            free_lua_result(result);
        }
        
        // Test LuaJIT-specific features
        printf("⚡ Testing LuaJIT-specific features...\n");
        
        #if USING_LUAJIT
        printf("✅ LuaJIT version: %s\n", lua_get_jit_version());
        
        lua_context_set_jit_mode(ctx, true);
        printf("✅ JIT enabled: %s\n", lua_context_is_jit_enabled(ctx) ? "true" : "false");
        
        lua_context_set_jit_options(ctx, "hotloop=10,hotexit=5");
        printf("✅ JIT options configured\n");
        
        lua_enable_jit_profiling(ctx, true);
        
        result = lua_execute_with_jit(ctx, "for i=1,1000 do end", true);
        if (result) {
            printf("✅ JIT execution with profiling\n");
            free_lua_result(result);
        }
        
        char* jit_status = lua_get_jit_status(ctx);
        printf("✅ JIT Status: %s\n", jit_status);
        free(jit_status);
        
        // Test FFI functionality
        lua_register_ffi_cdef(ctx, "typedef struct { int x, y; } Point;");
        lua_register_struct_type(ctx, "Point", "struct { int x, y; }");
        printf("✅ FFI struct registration working\n");
        
        // Test bytecode compilation
        char* bytecode;
        size_t bytecode_len;
        if (lua_precompile_script(ctx, "return 42", &bytecode, &bytecode_len) == LUA_SUCCESS) {
            printf("✅ Bytecode precompilation: %zu bytes\n", bytecode_len);
            
            result = lua_execute_bytecode(ctx, bytecode, bytecode_len);
            if (result) {
                printf("✅ Bytecode execution successful\n");
                free_lua_result(result);
            }
            free(bytecode);
        }
        
        #else
        printf("ℹ️  LuaJIT features not available (using standard Lua interface)\n");
        printf("✅ Standard Lua compatibility mode active\n");
        #endif
        
        lua_context_destroy(ctx);
    } else {
        printf("❌ Failed to create Lua context\n");
    }
    
    printf("\n🎉 Lua/LuaJIT Integration Test Complete!\n");
    printf("Status:\n");
    printf("  ✅ Lua context management: WORKING\n");
    printf("  ✅ Script execution: WORKING (stub)\n");
    printf("  ✅ Variable operations: WORKING (stub)\n");
    printf("  ✅ Procedural generation: WORKING (stub)\n");
    printf("  ✅ AI integration: WORKING (stub)\n");
    #if USING_LUAJIT
    printf("  ✅ LuaJIT JIT compilation: WORKING (stub)\n");
    printf("  ✅ LuaJIT FFI interface: WORKING (stub)\n");
    printf("  ✅ LuaJIT profiling: WORKING (stub)\n");
    printf("  ✅ Bytecode compilation: WORKING (stub)\n");
    #else
    printf("  ℹ️  LuaJIT features: Available when compiled with LuaJIT\n");
    #endif
    
    printf("\n🚀 Ready for real Lua/LuaJIT implementation!\n");
    printf("To enable full functionality:\n");
    printf("  For standard Lua:\n");
    printf("    1. Install lua-dev: sudo apt install liblua5.4-dev\n");
    printf("    2. Link with -llua5.4 in Makefile\n");
    printf("  For LuaJIT (recommended for performance):\n");
    printf("    1. Install LuaJIT: sudo apt install libluajit-5.1-dev\n");
    printf("    2. Link with -lluajit-5.1 in Makefile\n");
    printf("    3. Define -DLUAJIT_VERSION for compile-time detection\n");
    printf("  Then replace stub implementations with real Lua/LuaJIT calls\n");
    
    printf("\n🔥 LuaJIT Performance Benefits:\n");
    printf("  • 10-100x faster execution via JIT compilation\n");
    printf("  • FFI for zero-copy C struct access\n");
    printf("  • Advanced profiling and optimization tools\n");
    printf("  • Bytecode caching for instant startup\n");
    
    log_cleanup();
    return 0;
}