// {{{ module.h - Core module interface for ai-stuff ecosystem
#ifndef MODULE_H
#define MODULE_H

#include <stdbool.h>

// Forward declarations
typedef struct Module Module;
typedef struct ModuleConfig ModuleConfig;
typedef struct ModuleAPI ModuleAPI;

// {{{ Module interface structure
typedef struct Module {
    const char* name;           // Module name (must be unique)
    const char* version;        // Semantic version string
    const char** dependencies; // NULL-terminated array of dependency names
    
    // Lifecycle functions
    int (*init)(ModuleConfig* config);
    int (*cleanup)(void);
    
    // API access
    void* (*get_api)(const char* api_name);
    
    // Optional metadata
    const char* description;
    const char* author;
    const char* license;
} Module;
// }}}

// {{{ Configuration structure
typedef struct ModuleConfig {
    const char* config_file;    // Path to module config file
    const char* data_dir;       // Module data directory
    const char* state_dir;      // Module state directory
    void* custom_config;        // Module-specific configuration
} ModuleConfig;
// }}}

// {{{ Module registration and management
// Each module must implement this function
Module* register_module(void);

// Module loader functions
int load_module(const char* module_path);
int unload_module(const char* module_name);
Module* get_module(const char* module_name);
int get_loaded_modules(Module*** modules, int* count);

// Dependency resolution
int resolve_dependencies(void);
int check_dependency(const char* module_name, const char* dependency);
// }}}

// {{{ Inter-module communication
// Event system
typedef void (*EventCallback)(const char* event_type, const char* data, void* user_data);

int register_event_handler(const char* event_type, EventCallback callback, void* user_data);
int unregister_event_handler(const char* event_type, EventCallback callback);
int emit_event(const char* event_type, const char* data);

// Direct API access
void* get_module_api(const char* module_name, const char* api_name);
// }}}

// {{{ State management
// Global state store (key-value)
int set_global_state(const char* key, const char* value);
const char* get_global_state(const char* key);
int remove_global_state(const char* key);

// State synchronization
typedef void (*StateChangeCallback)(const char* key, const char* old_value, const char* new_value);
int register_state_change_handler(const char* key_pattern, StateChangeCallback callback);
// }}}

// {{{ Utility functions
// Configuration helpers
int load_module_config(const char* config_path, ModuleConfig* config);
void free_module_config(ModuleConfig* config);

// Module discovery
int discover_modules(const char* search_path, char*** module_paths, int* count);
void free_module_paths(char** module_paths, int count);

// Version checking
bool is_version_compatible(const char* required, const char* available);
int compare_versions(const char* version1, const char* version2);
// }}}

// {{{ Error handling
#define MODULE_SUCCESS          0
#define MODULE_ERROR_GENERAL   -1
#define MODULE_ERROR_NOT_FOUND -2
#define MODULE_ERROR_DEPENDENCY -3
#define MODULE_ERROR_CONFIG    -4
#define MODULE_ERROR_VERSION   -5
#define MODULE_ERROR_INIT      -6

const char* module_error_string(int error_code);
// }}}

#endif // MODULE_H
// }}}