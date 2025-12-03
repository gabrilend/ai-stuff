// {{{ module_template.h - Template for creating new modules
// Copy this file and replace TEMPLATE with your module name
// Replace template_* functions with your module's functionality

#ifndef TEMPLATE_MODULE_H
#define TEMPLATE_MODULE_H

#include "../common/module.h"
#include "../common/logging.h"
#include "../integration/bash_bridge.h"

// {{{ Module API definition
typedef struct TemplateAPI {
    // Core functionality - replace with your module's functions
    int (*start)(const char* config);
    int (*stop)(void);
    
    // Data management
    char* (*export_state)(void);
    int (*import_state)(const char* data);
    
    // Integration points
    void (*on_data_update)(const char* event_type, const char* data);
    int (*process_command)(const char* command, void* args);
    
    // Module-specific functions
    // Add your module's unique functionality here
    void (*custom_function)(void);
} TemplateAPI;
// }}}

// {{{ Module registration (required)
Module* register_module(void);
// }}}

// {{{ Internal module state
typedef struct TemplateState {
    bool initialized;
    char* config_file;
    char* data_directory;
    void* module_data;  // Module-specific data
} TemplateState;

extern TemplateState g_template_state;
// }}}

// {{{ Lifecycle functions
int template_init(ModuleConfig* config);
int template_cleanup(void);
// }}}

// {{{ API implementation
void* template_get_api(const char* api_name);
TemplateAPI* template_get_main_api(void);
// }}}

// {{{ Core functionality
int template_start(const char* config);
int template_stop(void);
char* template_export_state(void);
int template_import_state(const char* data);
// }}}

// {{{ Event handling
void template_on_data_update(const char* event_type, const char* data);
int template_process_command(const char* command, void* args);

// Register for events this module cares about
int template_register_events(void);
// }}}

// {{{ Configuration management
typedef struct TemplateConfig {
    // Module-specific configuration
    char* setting_1;
    int setting_2;
    bool setting_3;
} TemplateConfig;

int template_load_config(const char* config_file, TemplateConfig* config);
void template_free_config(TemplateConfig* config);
// }}}

// {{{ Data structures
// Define your module's data structures here
typedef struct TemplateData {
    char* name;
    int value;
    // Add your data fields
} TemplateData;

// Data management functions
TemplateData* template_create_data(void);
void template_free_data(TemplateData* data);
char* template_serialize_data(const TemplateData* data);
TemplateData* template_deserialize_data(const char* json);
// }}}

// {{{ Integration with other modules
// If integrating with bash scripts (like progress-ii)
int template_execute_script(const char* script_name, const char* args);
int template_parse_script_output(const char* output, TemplateData* result);

// If integrating with Lua scripts
#include "../integration/lua_bridge.h"
int template_execute_lua(LuaContext* ctx, const char* lua_code, TemplateData* result);
int template_call_lua_function(LuaContext* ctx, const char* function_name, TemplateData* input);

// If providing services to other modules
int template_provide_service(const char* service_name, void* params);
// }}}

// {{{ Utility functions specific to your module
// Add helper functions your module needs
void template_utility_function(void);
int template_validate_data(const TemplateData* data);
// }}}

// {{{ Error codes specific to your module
#define TEMPLATE_SUCCESS           0
#define TEMPLATE_ERROR_CONFIG     -100
#define TEMPLATE_ERROR_DATA       -101
#define TEMPLATE_ERROR_SCRIPT     -102
// Add module-specific error codes starting from -100

const char* template_error_string(int error_code);
// }}}

#endif // TEMPLATE_MODULE_H
// }}}


/* {{{ Usage Instructions:

1. Copy this file to your project's integration directory
2. Replace all instances of "TEMPLATE"/"template" with your module name
3. Implement the required functions:
   - register_module() - Module registration
   - template_init() - Module initialization
   - template_cleanup() - Module cleanup
   - template_get_api() - API access

4. Define your module's API structure with relevant functions
5. Implement configuration loading/saving
6. Add event handlers for inter-module communication
7. Implement data serialization for state management

Example implementation in module.c:

```c
#include "template_module.h"

TemplateState g_template_state = {0};

Module* register_module(void) {
    static Module module = {
        .name = "template",
        .version = "1.0.0", 
        .dependencies = {"common", "logging", NULL},
        .init = template_init,
        .cleanup = template_cleanup,
        .get_api = template_get_api,
        .description = "Template module for integration",
        .author = "Your Name",
        .license = "MIT"
    };
    return &module;
}

int template_init(ModuleConfig* config) {
    LOG_INFO("Initializing template module");
    g_template_state.initialized = true;
    template_register_events();
    return MODULE_SUCCESS;
}

// ... implement other functions
```

5. Integration checklist:
   [ ] Module registration implemented
   [ ] Lifecycle functions working
   [ ] Configuration loading/saving
   [ ] State serialization/deserialization
   [ ] Event handling for inter-module communication
   [ ] API implementation
   [ ] Documentation updated
   [ ] Tests written

6. Test your module:
   - Standalone: Module works independently
   - Integration: Module works with other modules
   - Lifecycle: Module loads/unloads cleanly
   - Data: Serialization round-trips correctly
   - Events: Inter-module communication works

}}} */