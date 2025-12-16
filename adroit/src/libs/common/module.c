// {{{ module.c - Core module system implementation
#define _GNU_SOURCE  // For strdup
#include "module.h"
#include "logging.h"
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>

// {{{ Module registry
#define MAX_MODULES 64
static Module* g_modules[MAX_MODULES];
static int g_module_count = 0;
static bool g_initialized = false;

// Event system
#define MAX_EVENT_HANDLERS 128
typedef struct EventHandler {
    char event_type[64];
    EventCallback callback;
    void* user_data;
    bool active;
} EventHandler;

static EventHandler g_event_handlers[MAX_EVENT_HANDLERS];
static int g_event_handler_count = 0;

// Global state store
#define MAX_STATE_ENTRIES 256
typedef struct StateEntry {
    char key[64];
    char* value;
    bool active;
} StateEntry;

static StateEntry g_state_store[MAX_STATE_ENTRIES];
static int g_state_count = 0;
// }}}

// {{{ Error handling
static char g_last_error[256] = "";

const char* module_error_string(int error_code) {
    switch (error_code) {
        case MODULE_SUCCESS: return "Success";
        case MODULE_ERROR_GENERAL: return "General error";
        case MODULE_ERROR_NOT_FOUND: return "Module not found";
        case MODULE_ERROR_DEPENDENCY: return "Dependency error";
        case MODULE_ERROR_CONFIG: return "Configuration error";
        case MODULE_ERROR_VERSION: return "Version incompatible";
        case MODULE_ERROR_INIT: return "Initialization failed";
        default: return "Unknown error";
    }
}
// }}}

// {{{ Module management
int load_module(const char* module_path) {
    if (g_module_count >= MAX_MODULES) {
        snprintf(g_last_error, sizeof(g_last_error), "Maximum modules exceeded");
        return MODULE_ERROR_GENERAL;
    }
    
    // For now, just simulate loading - in real implementation would use dlopen
    MLOG_INFO("module_loader", "Loading module from %s", module_path);
    
    // This would be: dlopen(module_path, RTLD_LAZY);
    // And then: dlsym to get the register_module function
    
    return MODULE_SUCCESS;
}

int unload_module(const char* module_name) {
    for (int i = 0; i < g_module_count; i++) {
        if (g_modules[i] && strcmp(g_modules[i]->name, module_name) == 0) {
            if (g_modules[i]->cleanup) {
                g_modules[i]->cleanup();
            }
            g_modules[i] = NULL;
            MLOG_INFO("module_loader", "Unloaded module %s", module_name);
            return MODULE_SUCCESS;
        }
    }
    return MODULE_ERROR_NOT_FOUND;
}

Module* get_module(const char* module_name) {
    for (int i = 0; i < g_module_count; i++) {
        if (g_modules[i] && strcmp(g_modules[i]->name, module_name) == 0) {
            return g_modules[i];
        }
    }
    return NULL;
}

int get_loaded_modules(Module*** modules, int* count) {
    *modules = g_modules;
    *count = g_module_count;
    return MODULE_SUCCESS;
}
// }}}

// {{{ Event system
int register_event_handler(const char* event_type, EventCallback callback, void* user_data) {
    if (g_event_handler_count >= MAX_EVENT_HANDLERS) {
        return MODULE_ERROR_GENERAL;
    }
    
    EventHandler* handler = &g_event_handlers[g_event_handler_count++];
    strncpy(handler->event_type, event_type, sizeof(handler->event_type) - 1);
    handler->callback = callback;
    handler->user_data = user_data;
    handler->active = true;
    
    MLOG_DEBUG("events", "Registered handler for event type: %s", event_type);
    return MODULE_SUCCESS;
}

int unregister_event_handler(const char* event_type, EventCallback callback) {
    for (int i = 0; i < g_event_handler_count; i++) {
        if (g_event_handlers[i].active && 
            strcmp(g_event_handlers[i].event_type, event_type) == 0 &&
            g_event_handlers[i].callback == callback) {
            g_event_handlers[i].active = false;
            MLOG_DEBUG("events", "Unregistered handler for event type: %s", event_type);
            return MODULE_SUCCESS;
        }
    }
    return MODULE_ERROR_NOT_FOUND;
}

int emit_event(const char* event_type, const char* data) {
    MLOG_DEBUG("events", "Emitting event: %s", event_type);
    
    for (int i = 0; i < g_event_handler_count; i++) {
        if (g_event_handlers[i].active && 
            strcmp(g_event_handlers[i].event_type, event_type) == 0) {
            g_event_handlers[i].callback(event_type, data, g_event_handlers[i].user_data);
        }
    }
    return MODULE_SUCCESS;
}
// }}}

// {{{ API access
void* get_module_api(const char* module_name, const char* api_name) {
    Module* module = get_module(module_name);
    if (!module || !module->get_api) {
        return NULL;
    }
    return module->get_api(api_name);
}
// }}}

// {{{ Global state management
int set_global_state(const char* key, const char* value) {
    // Look for existing key
    for (int i = 0; i < g_state_count; i++) {
        if (g_state_store[i].active && strcmp(g_state_store[i].key, key) == 0) {
            free(g_state_store[i].value);
            g_state_store[i].value = strdup(value);
            return MODULE_SUCCESS;
        }
    }
    
    // Add new key
    if (g_state_count >= MAX_STATE_ENTRIES) {
        return MODULE_ERROR_GENERAL;
    }
    
    StateEntry* entry = &g_state_store[g_state_count++];
    strncpy(entry->key, key, sizeof(entry->key) - 1);
    entry->value = strdup(value);
    entry->active = true;
    
    return MODULE_SUCCESS;
}

const char* get_global_state(const char* key) {
    for (int i = 0; i < g_state_count; i++) {
        if (g_state_store[i].active && strcmp(g_state_store[i].key, key) == 0) {
            return g_state_store[i].value;
        }
    }
    return NULL;
}

int remove_global_state(const char* key) {
    for (int i = 0; i < g_state_count; i++) {
        if (g_state_store[i].active && strcmp(g_state_store[i].key, key) == 0) {
            free(g_state_store[i].value);
            g_state_store[i].active = false;
            return MODULE_SUCCESS;
        }
    }
    return MODULE_ERROR_NOT_FOUND;
}
// }}}

// {{{ Dependency resolution
int resolve_dependencies(void) {
    // Simple dependency resolution - in real implementation would be more sophisticated
    MLOG_INFO("module_loader", "Resolving module dependencies");
    
    for (int i = 0; i < g_module_count; i++) {
        if (!g_modules[i]) continue;
        
        if (g_modules[i]->dependencies) {
            for (int j = 0; g_modules[i]->dependencies[j]; j++) {
                if (!get_module(g_modules[i]->dependencies[j])) {
                    MLOG_WARN("module_loader", "Module %s missing dependency: %s", 
                             g_modules[i]->name, g_modules[i]->dependencies[j]);
                    return MODULE_ERROR_DEPENDENCY;
                }
            }
        }
    }
    
    return MODULE_SUCCESS;
}

int check_dependency(const char* module_name, const char* dependency) {
    Module* module = get_module(module_name);
    if (!module || !module->dependencies) return 0;
    
    for (int i = 0; module->dependencies[i]; i++) {
        if (strcmp(module->dependencies[i], dependency) == 0) {
            return 1;
        }
    }
    return 0;
}
// }}}

// {{{ Version checking
bool is_version_compatible(const char* required, const char* available) {
    // Simple version checking - just string comparison for now
    // Real implementation would parse semantic versions
    return strcmp(required, available) <= 0;
}

int compare_versions(const char* version1, const char* version2) {
    return strcmp(version1, version2);
}
// }}}

// {{{ Utility functions
int load_module_config(const char* config_path, ModuleConfig* config) {
    // Simplified implementation
    config->config_file = strdup(config_path);
    config->data_dir = strdup("/tmp/module_data");
    config->state_dir = strdup("/tmp/module_state");
    config->custom_config = NULL;
    
    return MODULE_SUCCESS;
}

void free_module_config(ModuleConfig* config) {
    if (config) {
        free((void*)config->config_file);
        free((void*)config->data_dir);
        free((void*)config->state_dir);
        free(config->custom_config);
    }
}

int discover_modules(const char* search_path, char*** module_paths, int* count) {
    // Simplified - would scan directory for .so files
    *module_paths = NULL;
    *count = 0;
    MLOG_INFO("module_loader", "Module discovery in %s not yet implemented", search_path);
    return MODULE_SUCCESS;
}

void free_module_paths(char** module_paths, int count) {
    if (module_paths) {
        for (int i = 0; i < count; i++) {
            free(module_paths[i]);
        }
        free(module_paths);
    }
}
// }}}