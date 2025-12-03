// {{{ config.h - Configuration management for ai-stuff ecosystem
#ifndef CONFIG_H
#define CONFIG_H

#include <stdbool.h>

// {{{ Configuration value types
typedef enum ConfigValueType {
    CONFIG_TYPE_STRING,
    CONFIG_TYPE_INT,
    CONFIG_TYPE_BOOL,
    CONFIG_TYPE_FLOAT
} ConfigValueType;

typedef struct ConfigValue {
    ConfigValueType type;
    union {
        char* string_value;
        int int_value;
        bool bool_value;
        float float_value;
    } data;
} ConfigValue;
// }}}

// {{{ Configuration context
typedef struct Config Config;

// Create/destroy configuration contexts
Config* config_create(void);
void config_destroy(Config* config);
// }}}

// {{{ File operations
int config_load_file(Config* config, const char* filename);
int config_save_file(Config* config, const char* filename);
int config_load_string(Config* config, const char* config_string);
char* config_to_string(Config* config);
// }}}

// {{{ Value operations
// Set values
int config_set_string(Config* config, const char* key, const char* value);
int config_set_int(Config* config, const char* key, int value);
int config_set_bool(Config* config, const char* key, bool value);
int config_set_float(Config* config, const char* key, float value);

// Get values with defaults
const char* config_get_string(Config* config, const char* key, const char* default_value);
int config_get_int(Config* config, const char* key, int default_value);
bool config_get_bool(Config* config, const char* key, bool default_value);
float config_get_float(Config* config, const char* key, float default_value);

// Check if key exists
bool config_has_key(Config* config, const char* key);

// Remove keys
int config_remove_key(Config* config, const char* key);
// }}}

// {{{ Section operations
int config_set_section(Config* config, const char* section);
int config_get_section_keys(Config* config, const char* section, char*** keys, int* count);
void config_free_keys(char** keys, int count);
// }}}

// {{{ Hierarchical configuration
// Load multiple config files with inheritance
// Later files override earlier ones
Config* config_load_hierarchy(const char** filenames, int count);

// Environment variable support
int config_load_env_vars(Config* config, const char* prefix);
const char* config_expand_env(Config* config, const char* value);
// }}}

// {{{ Validation and constraints
typedef struct ConfigConstraint {
    const char* key;
    ConfigValueType expected_type;
    bool required;
    void* min_value;  // Type-specific minimum
    void* max_value;  // Type-specific maximum
    const char** allowed_strings; // NULL-terminated array for string validation
} ConfigConstraint;

int config_validate(Config* config, const ConfigConstraint* constraints, int constraint_count);
char* config_validation_errors(Config* config, const ConfigConstraint* constraints, int constraint_count);
// }}}

// {{{ Watch for changes
typedef void (*ConfigChangeCallback)(const char* key, const ConfigValue* old_value, const ConfigValue* new_value, void* user_data);

int config_watch_file(Config* config, const char* filename, ConfigChangeCallback callback, void* user_data);
int config_stop_watching(Config* config, const char* filename);
// }}}

// {{{ Default configurations
// Create config with common ai-stuff defaults
Config* config_create_default(const char* module_name);

// Add default values for a module
int config_add_module_defaults(Config* config, const char* module_name);
// }}}

// {{{ Error handling
#define CONFIG_SUCCESS           0
#define CONFIG_ERROR_FILE       -1
#define CONFIG_ERROR_PARSE      -2
#define CONFIG_ERROR_TYPE       -3
#define CONFIG_ERROR_NOT_FOUND  -4
#define CONFIG_ERROR_VALIDATION -5

const char* config_error_string(int error_code);
const char* config_get_last_error(void);
// }}}

// {{{ Convenience macros
#define CONFIG_GET_STRING(config, key, default) config_get_string(config, key, default)
#define CONFIG_GET_INT(config, key, default)    config_get_int(config, key, default)  
#define CONFIG_GET_BOOL(config, key, default)   config_get_bool(config, key, default)
#define CONFIG_GET_FLOAT(config, key, default)  config_get_float(config, key, default)

#define CONFIG_SET_STRING(config, key, value) config_set_string(config, key, value)
#define CONFIG_SET_INT(config, key, value)    config_set_int(config, key, value)
#define CONFIG_SET_BOOL(config, key, value)   config_set_bool(config, key, value)
#define CONFIG_SET_FLOAT(config, key, value)  config_set_float(config, key, value)
// }}}

#endif // CONFIG_H
// }}}