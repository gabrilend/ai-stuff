// {{{ bash_bridge.c - C to bash script integration implementation
#define _GNU_SOURCE  // For strdup, setenv, unsetenv, mkstemp
#include "bash_bridge.h"
#include "../common/logging.h"
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <errno.h>

// {{{ BashResult management
void free_bash_result(BashResult* result) {
    if (result) {
        free(result->stdout_data);
        free(result->stderr_data);
        free(result);
    }
}

bool bash_result_success(const BashResult* result) {
    return result && result->exit_code == 0 && !result->timed_out;
}

const char* bash_result_output(const BashResult* result) {
    return result ? result->stdout_data : NULL;
}

const char* bash_result_error(const BashResult* result) {
    return result ? result->stderr_data : NULL;
}
// }}}

// {{{ Core execution functions
BashResult* execute_bash_command(const char* command) {
    if (!command) return NULL;
    
    BashResult* result = calloc(1, sizeof(BashResult));
    if (!result) return NULL;
    
    MLOG_DEBUG("bash_bridge", "Executing command: %s", command);
    
    // Use popen for simple implementation
    FILE* pipe = popen(command, "r");
    if (!pipe) {
        MLOG_ERROR("bash_bridge", "Failed to execute command: %s", strerror(errno));
        free(result);
        return NULL;
    }
    
    // Read output
    char buffer[4096];
    size_t output_size = 0;
    size_t capacity = 4096;
    result->stdout_data = malloc(capacity);
    
    while (fgets(buffer, sizeof(buffer), pipe)) {
        size_t len = strlen(buffer);
        if (output_size + len >= capacity) {
            capacity *= 2;
            result->stdout_data = realloc(result->stdout_data, capacity);
        }
        strcpy(result->stdout_data + output_size, buffer);
        output_size += len;
    }
    
    result->exit_code = pclose(pipe);
    result->stderr_data = strdup(""); // No stderr capture with popen
    result->timed_out = false;
    result->duration = 0.0; // TODO: Implement timing
    
    MLOG_DEBUG("bash_bridge", "Command completed with exit code: %d", result->exit_code);
    return result;
}

BashResult* execute_bash_script(const char* script_path, const char** args) {
    if (!script_path) return NULL;
    
    // Build command string
    char command[2048];
    snprintf(command, sizeof(command), "%s", script_path);
    
    if (args) {
        for (int i = 0; args[i]; i++) {
            strcat(command, " ");
            strcat(command, args[i]);
        }
    }
    
    return execute_bash_command(command);
}

BashResult* execute_bash_with_timeout(const char* script_path, const char** args, double timeout) {
    // TODO: Implement timeout support
    (void)timeout; // Suppress warning
    return execute_bash_script(script_path, args);
}

BashResult* execute_bash_with_input(const char* script_path, const char** args, const char* input_data) {
    // TODO: Implement input support
    (void)input_data; // Suppress warning
    return execute_bash_script(script_path, args);
}
// }}}

// {{{ JSON integration
int execute_bash_json(const char* script_path, const char** args, const char* input_json, char** output_json) {
    if (!script_path || !output_json) return BASH_ERROR_EXECUTION;
    
    BashResult* result = execute_bash_script(script_path, args);
    if (!result) return BASH_ERROR_EXECUTION;
    
    if (bash_result_success(result)) {
        *output_json = strdup(result->stdout_data);
        free_bash_result(result);
        return BASH_SUCCESS;
    } else {
        MLOG_ERROR("bash_bridge", "Script failed: %s", bash_result_error(result));
        free_bash_result(result);
        return BASH_ERROR_EXECUTION;
    }
}

BashResult* execute_bash_structured(const BashCommand* command) {
    if (!command || !command->script) return NULL;
    
    // TODO: Implement full structured command support
    return execute_bash_script(command->script, command->args);
}
// }}}

// {{{ Progress-II specific integration
BashResult* progress_ii_adventure(const char* character_json, const char* scenario) {
    if (!character_json || !scenario) return NULL;
    
    // TODO: Write character_json to temp file and call progress-ii script
    char command[1024];
    snprintf(command, sizeof(command), 
             "/home/ritz/programming/ai-stuff/progress-ii/src/progress-ii.sh --character='%s' --scenario='%s'", 
             character_json, scenario);
    
    return execute_bash_command(command);
}

BashResult* progress_ii_generate_oneliner(const char* task_description) {
    if (!task_description) return NULL;
    
    char command[1024];
    snprintf(command, sizeof(command), 
             "/home/ritz/programming/ai-stuff/progress-ii/src/progress-ii.sh --generate-oneliner='%s'", 
             task_description);
    
    return execute_bash_command(command);
}

BashResult* progress_ii_save_state(const char* state_json) {
    if (!state_json) return NULL;
    
    char command[1024];
    snprintf(command, sizeof(command), 
             "/home/ritz/programming/ai-stuff/progress-ii/src/progress-ii.sh --save-state='%s'", 
             state_json);
    
    return execute_bash_command(command);
}

BashResult* progress_ii_load_state(void) {
    return execute_bash_command("/home/ritz/programming/ai-stuff/progress-ii/src/progress-ii.sh --load-state");
}

BashResult* progress_ii_rollback_state(int commits_back) {
    char command[256];
    snprintf(command, sizeof(command), 
             "/home/ritz/programming/ai-stuff/progress-ii/src/progress-ii.sh --rollback=%d", 
             commits_back);
    
    return execute_bash_command(command);
}
// }}}

// {{{ File operations
BashResult* execute_with_json_file(const char* script_path, const char* json_data) {
    if (!script_path || !json_data) return NULL;
    
    // Write JSON to temporary file
    char temp_file[] = "/tmp/adroit_json_XXXXXX";
    int fd = mkstemp(temp_file);
    if (fd == -1) return NULL;
    
    write(fd, json_data, strlen(json_data));
    close(fd);
    
    // Execute script with temp file as argument
    const char* args[] = {temp_file, NULL};
    BashResult* result = execute_bash_script(script_path, args);
    
    // Clean up temp file
    unlink(temp_file);
    
    return result;
}

int execute_and_read_json_file(const char* script_path, const char** args, char** json_output) {
    if (!script_path || !json_output) return BASH_ERROR_EXECUTION;
    
    BashResult* result = execute_bash_script(script_path, args);
    if (!result) return BASH_ERROR_EXECUTION;
    
    if (bash_result_success(result)) {
        *json_output = strdup(result->stdout_data);
        free_bash_result(result);
        return BASH_SUCCESS;
    } else {
        free_bash_result(result);
        return BASH_ERROR_EXECUTION;
    }
}

// File watching not implemented yet
int setup_file_watcher(const char* filepath, FileChangeCallback callback) {
    (void)filepath; (void)callback;
    return BASH_SUCCESS; // TODO: Implement inotify-based watching
}

int remove_file_watcher(const char* filepath) {
    (void)filepath;
    return BASH_SUCCESS;
}
// }}}

// {{{ Environment and validation
int set_bash_env(const char* name, const char* value) {
    if (!name || !value) return BASH_ERROR_EXECUTION;
    return setenv(name, value, 1) == 0 ? BASH_SUCCESS : BASH_ERROR_EXECUTION;
}

int unset_bash_env(const char* name) {
    if (!name) return BASH_ERROR_EXECUTION;
    return unsetenv(name) == 0 ? BASH_SUCCESS : BASH_ERROR_EXECUTION;
}

int set_bash_working_dir(const char* directory) {
    if (!directory) return BASH_ERROR_EXECUTION;
    return chdir(directory) == 0 ? BASH_SUCCESS : BASH_ERROR_EXECUTION;
}

const char* get_bash_working_dir(void) {
    static char cwd[1024];
    return getcwd(cwd, sizeof(cwd));
}

bool validate_bash_script(const char* script_path) {
    if (!script_path) return false;
    return access(script_path, R_OK | X_OK) == 0;
}

int discover_bash_modules(const char* search_path, char*** script_paths, int* count) {
    (void)search_path;
    *script_paths = NULL;
    *count = 0;
    return BASH_SUCCESS; // TODO: Implement directory scanning
}
// }}}

// {{{ Error handling
const char* bash_error_string(int error_code) {
    switch (error_code) {
        case BASH_SUCCESS: return "Success";
        case BASH_ERROR_NOT_FOUND: return "Script not found";
        case BASH_ERROR_PERMISSION: return "Permission denied";
        case BASH_ERROR_TIMEOUT: return "Execution timeout";
        case BASH_ERROR_EXECUTION: return "Execution failed";
        case BASH_ERROR_JSON: return "JSON processing error";
        case BASH_ERROR_FILE_IO: return "File I/O error";
        default: return "Unknown error";
    }
}
// }}}

// {{{ Async execution (stubs)
// TODO: Implement proper async execution
BashAsync* execute_bash_async(const char* script_path, const char** args) {
    (void)script_path; (void)args;
    return NULL; // Not implemented yet
}

bool bash_async_is_complete(const BashAsync* async) {
    (void)async;
    return true;
}

const char* bash_async_get_output(const BashAsync* async) {
    (void)async;
    return "";
}

BashResult* bash_async_wait(BashAsync* async) {
    (void)async;
    return NULL;
}

int bash_async_cancel(BashAsync* async) {
    (void)async;
    return BASH_SUCCESS;
}

void free_bash_async(BashAsync* async) {
    (void)async;
}
// }}}

// {{{ Result caching (stubs)
int cache_bash_result(const char* key, const BashResult* result) {
    (void)key; (void)result;
    return BASH_SUCCESS; // TODO: Implement caching
}

BashResult* get_cached_result(const char* key) {
    (void)key;
    return NULL; // TODO: Implement caching
}

void clear_bash_cache(void) {
    // TODO: Implement cache clearing
}
// }}}