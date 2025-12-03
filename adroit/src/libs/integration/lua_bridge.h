// {{{ lua_bridge.h - C to Lua/LuaJIT integration bridge
#ifndef LUA_BRIDGE_H
#define LUA_BRIDGE_H

#include <stdio.h>
#include <stdbool.h>

// Forward declarations
struct Unit;
typedef struct Unit Unit;

// {{{ LuaJIT compatibility and feature detection
#ifdef LUAJIT_VERSION
#define USING_LUAJIT 1
#define LUA_JIT_AVAILABLE 1
#else
#define USING_LUAJIT 0
#define LUA_JIT_AVAILABLE 0
#endif

// LuaJIT-specific features
#if USING_LUAJIT
#define LUA_SUPPORTS_FFI 1
#define LUA_SUPPORTS_JIT_PROFILING 1
#define LUA_SUPPORTS_BYTECODE_CACHE 1
#else
#define LUA_SUPPORTS_FFI 0
#define LUA_SUPPORTS_JIT_PROFILING 0
#define LUA_SUPPORTS_BYTECODE_CACHE 0
#endif
// }}}

// {{{ Lua execution result structure
typedef struct LuaResult {
    int status;             // Lua execution status (0 = success)
    char* output;           // Captured output (allocated)
    char* error_message;    // Error message if any (allocated)
    double duration;        // Execution time in seconds
    bool has_return_value;  // True if script returned a value
    char* return_value;     // String representation of return value
    
    // LuaJIT-specific profiling data
    #if LUA_SUPPORTS_JIT_PROFILING
    double jit_compile_time;    // Time spent JIT compiling
    int traces_compiled;        // Number of traces compiled
    int traces_aborted;         // Number of traces aborted
    char* jit_profile_data;     // JIT profiling information
    #endif
} LuaResult;
// }}}

// {{{ Lua context management
typedef struct LuaContext LuaContext;

// Create/destroy Lua contexts
LuaContext* lua_context_create(void);
void lua_context_destroy(LuaContext* ctx);

// Global context for simple operations
LuaContext* lua_get_global_context(void);
void lua_cleanup_global_context(void);

// LuaJIT-specific context options
#if USING_LUAJIT
int lua_context_set_jit_mode(LuaContext* ctx, bool enable_jit);
int lua_context_set_jit_options(LuaContext* ctx, const char* options);
bool lua_context_is_jit_enabled(LuaContext* ctx);
const char* lua_get_jit_version(void);
#endif
// }}}

// {{{ Script execution
// Execute Lua script from string
LuaResult* lua_execute_string(LuaContext* ctx, const char* lua_code);

// Execute Lua script from file
LuaResult* lua_execute_file(LuaContext* ctx, const char* script_path);

// Execute Lua function with arguments
LuaResult* lua_call_function(LuaContext* ctx, const char* function_name, 
                            const char** args, int arg_count);

// Execute with timeout (in seconds)
LuaResult* lua_execute_with_timeout(LuaContext* ctx, const char* lua_code, double timeout);

// LuaJIT-specific execution options
#if USING_LUAJIT
// Execute with JIT compilation control
LuaResult* lua_execute_with_jit(LuaContext* ctx, const char* lua_code, bool force_jit);

// Precompile and cache bytecode for performance
int lua_precompile_script(LuaContext* ctx, const char* lua_code, char** bytecode, size_t* bytecode_len);
LuaResult* lua_execute_bytecode(LuaContext* ctx, const char* bytecode, size_t bytecode_len);

// FFI integration for direct C struct access
int lua_register_ffi_cdef(LuaContext* ctx, const char* c_definitions);
int lua_register_ffi_clib(LuaContext* ctx, const char* library_name, void* library_handle);
#endif
// }}}

// {{{ Data exchange
// Execute Lua script and parse JSON output
int lua_execute_json(LuaContext* ctx, const char* lua_code, const char* input_json, char** output_json);

// Set variables in Lua context
int lua_set_string(LuaContext* ctx, const char* var_name, const char* value);
int lua_set_number(LuaContext* ctx, const char* var_name, double value);
int lua_set_boolean(LuaContext* ctx, const char* var_name, bool value);
int lua_set_json(LuaContext* ctx, const char* var_name, const char* json_data);

// Get variables from Lua context
const char* lua_get_string(LuaContext* ctx, const char* var_name);
double lua_get_number(LuaContext* ctx, const char* var_name);
bool lua_get_boolean(LuaContext* ctx, const char* var_name);
char* lua_get_json(LuaContext* ctx, const char* var_name);

// LuaJIT FFI direct memory access (zero-copy)
#if LUA_SUPPORTS_FFI
int lua_set_ffi_pointer(LuaContext* ctx, const char* var_name, void* ptr, const char* type_name);
void* lua_get_ffi_pointer(LuaContext* ctx, const char* var_name);
int lua_register_struct_type(LuaContext* ctx, const char* struct_name, const char* struct_def);

// High-performance character data exchange via FFI
int lua_set_character_ffi(LuaContext* ctx, const char* var_name, const Unit* character);
Unit* lua_get_character_ffi(LuaContext* ctx, const char* var_name);
#endif
// }}}

// {{{ Module and package management
// Load Lua module/package
int lua_load_module(LuaContext* ctx, const char* module_name);

// Add search path for Lua modules
int lua_add_path(LuaContext* ctx, const char* path);

// Preload common ai-stuff Lua utilities
int lua_load_ai_stuff_libs(LuaContext* ctx);
// }}}

// {{{ Character and game data integration
// Character data serialization to/from Lua
int lua_set_character(LuaContext* ctx, const char* var_name, const Unit* character);
int lua_get_character(LuaContext* ctx, const char* var_name, Unit* character);

// Execute character-aware Lua scripts
LuaResult* lua_process_character(LuaContext* ctx, const char* lua_code, const Unit* character);

// Adventure and quest scripting
LuaResult* lua_run_adventure(LuaContext* ctx, const char* adventure_script, 
                           const Unit* character, const char* scenario_data);
LuaResult* lua_generate_content(LuaContext* ctx, const char* generator_script, 
                              const char* content_type, const char* parameters);
// }}}

// {{{ AI and procedural generation integration
// Execute Lua scripts for procedural generation
LuaResult* lua_generate_equipment(LuaContext* ctx, const Unit* character, const char* equipment_type);
LuaResult* lua_generate_name(LuaContext* ctx, const char* name_type, const char* parameters);
LuaResult* lua_generate_story(LuaContext* ctx, const char* story_type, const Unit* character);

// AI-assisted Lua generation (bridge to LLMs)
LuaResult* lua_ai_generate_script(LuaContext* ctx, const char* task_description);
LuaResult* lua_ai_optimize_script(LuaContext* ctx, const char* existing_script);
// }}}

// {{{ Performance and debugging
// Lua performance monitoring
typedef struct LuaProfileData {
    double total_time;
    int call_count;
    double avg_time;
    double max_time;
    char* function_name;
    
    // LuaJIT-specific metrics
    #if LUA_SUPPORTS_JIT_PROFILING
    int times_compiled;         // How many times JIT compiled this function
    int times_deoptimized;      // How many times JIT had to fall back
    double jit_compile_time;    // Time spent compiling
    double interpreted_time;    // Time spent in interpreter
    double native_time;         // Time spent in compiled code
    int trace_aborts;           // Number of trace compilation aborts
    char* trace_abort_reasons;  // Reasons for trace aborts
    #endif
} LuaProfileData;

int lua_enable_profiling(LuaContext* ctx, bool enable);
LuaProfileData* lua_get_profile_data(LuaContext* ctx, int* count);
void lua_clear_profile_data(LuaContext* ctx);

// LuaJIT-specific profiling
#if LUA_SUPPORTS_JIT_PROFILING
int lua_enable_jit_profiling(LuaContext* ctx, bool enable);
int lua_dump_jit_traces(LuaContext* ctx, const char* output_file);
char* lua_get_jit_status(LuaContext* ctx);
int lua_optimize_hot_paths(LuaContext* ctx); // Force JIT compilation of hot paths
#endif

// Debugging support
int lua_set_debug_mode(LuaContext* ctx, bool enable);
int lua_add_breakpoint(LuaContext* ctx, const char* file, int line);
int lua_step_debugger(LuaContext* ctx);
// }}}

// {{{ Error handling and validation
#define LUA_SUCCESS              0
#define LUA_ERROR_SYNTAX        -1
#define LUA_ERROR_RUNTIME       -2
#define LUA_ERROR_MEMORY        -3
#define LUA_ERROR_FILE          -4
#define LUA_ERROR_TIMEOUT       -5
#define LUA_ERROR_TYPE          -6

const char* lua_error_string(int error_code);

// Lua script validation
bool lua_validate_syntax(const char* lua_code, char** error_message);
bool lua_validate_file(const char* script_path, char** error_message);
// }}}

// {{{ Result management
// Free LuaResult structure
void free_lua_result(LuaResult* result);

// Helper functions for result processing
bool lua_result_success(const LuaResult* result);
const char* lua_result_output(const LuaResult* result);
const char* lua_result_error(const LuaResult* result);
const char* lua_result_return_value(const LuaResult* result);

// Result caching
int cache_lua_result(LuaContext* ctx, const char* key, const LuaResult* result);
LuaResult* get_cached_lua_result(LuaContext* ctx, const char* key);
void clear_lua_cache(LuaContext* ctx);
// }}}

// {{{ Standard Lua libraries and utilities
// Preload specific Lua libraries
int lua_load_string_lib(LuaContext* ctx);
int lua_load_table_lib(LuaContext* ctx);
int lua_load_math_lib(LuaContext* ctx);
int lua_load_io_lib(LuaContext* ctx);
int lua_load_json_lib(LuaContext* ctx);

// Register C functions in Lua
typedef int (*LuaCFunction)(LuaContext* ctx);
int lua_register_function(LuaContext* ctx, const char* name, LuaCFunction func);

// Utility functions available to Lua scripts
int lua_util_log(LuaContext* ctx);          // Logging from Lua
int lua_util_execute_bash(LuaContext* ctx); // Execute bash from Lua
int lua_util_get_character_data(LuaContext* ctx); // Access character data
int lua_util_emit_event(LuaContext* ctx);   // Emit module events
// }}}

// {{{ Integration with module system
// Register Lua context as a module
typedef struct LuaModule {
    LuaContext* context;
    char* script_file;
    char* module_name;
} LuaModule;

LuaModule* lua_module_create(const char* module_name, const char* script_file);
void lua_module_destroy(LuaModule* module);
int lua_module_register(LuaModule* module);
// }}}

#endif // LUA_BRIDGE_H
// }}}