// {{{ bash_bridge.h - C to bash script integration
#ifndef BASH_BRIDGE_H
#define BASH_BRIDGE_H

#include <stdio.h>
#include <stdbool.h>

// {{{ Execution result structure
typedef struct BashResult {
    int exit_code;      // Script exit code
    char* stdout_data;  // Standard output (allocated)
    char* stderr_data;  // Standard error (allocated)
    double duration;    // Execution time in seconds
    bool timed_out;     // True if execution timed out
} BashResult;
// }}}

// {{{ Script execution functions
// Execute bash script with arguments
BashResult* execute_bash_script(const char* script_path, const char** args);

// Execute bash command line
BashResult* execute_bash_command(const char* command);

// Execute with timeout (in seconds)
BashResult* execute_bash_with_timeout(const char* script_path, const char** args, double timeout);

// Execute with input data (stdin)
BashResult* execute_bash_with_input(const char* script_path, const char** args, const char* input_data);
// }}}

// {{{ JSON data exchange
// Execute script and parse JSON output
int execute_bash_json(const char* script_path, const char** args, const char* input_json, char** output_json);

// Execute with structured data
typedef struct BashCommand {
    const char* script;
    const char** args;
    const char* working_dir;
    const char* input_data;
    double timeout;
    bool capture_stderr;
} BashCommand;

BashResult* execute_bash_structured(const BashCommand* command);
// }}}

// {{{ Progress-II specific integration
// Execute progress-ii adventure with character data
BashResult* progress_ii_adventure(const char* character_json, const char* scenario);

// Execute progress-ii bash oneliner generation
BashResult* progress_ii_generate_oneliner(const char* task_description);

// Execute progress-ii state management
BashResult* progress_ii_save_state(const char* state_json);
BashResult* progress_ii_load_state(void);
BashResult* progress_ii_rollback_state(int commits_back);
// }}}

// {{{ File-based communication
// Write JSON to temporary file and execute script
BashResult* execute_with_json_file(const char* script_path, const char* json_data);

// Execute script and read JSON from output file
int execute_and_read_json_file(const char* script_path, const char** args, char** json_output);

// Set up file watchers for script output
typedef void (*FileChangeCallback)(const char* filepath, const char* content);
int setup_file_watcher(const char* filepath, FileChangeCallback callback);
int remove_file_watcher(const char* filepath);
// }}}

// {{{ Environment management
// Set environment variables for script execution
int set_bash_env(const char* name, const char* value);
int unset_bash_env(const char* name);

// Set working directory for script execution
int set_bash_working_dir(const char* directory);
const char* get_bash_working_dir(void);

// Script discovery and validation
bool validate_bash_script(const char* script_path);
int discover_bash_modules(const char* search_path, char*** script_paths, int* count);
// }}}

// {{{ Result management
// Free BashResult structure
void free_bash_result(BashResult* result);

// Helper functions for result processing
bool bash_result_success(const BashResult* result);
const char* bash_result_output(const BashResult* result);
const char* bash_result_error(const BashResult* result);

// Result caching
int cache_bash_result(const char* key, const BashResult* result);
BashResult* get_cached_result(const char* key);
void clear_bash_cache(void);
// }}}

// {{{ Error handling
#define BASH_SUCCESS            0
#define BASH_ERROR_NOT_FOUND   -1
#define BASH_ERROR_PERMISSION  -2
#define BASH_ERROR_TIMEOUT     -3
#define BASH_ERROR_EXECUTION   -4
#define BASH_ERROR_JSON        -5
#define BASH_ERROR_FILE_IO     -6

const char* bash_error_string(int error_code);
// }}}

// {{{ Async execution (for long-running scripts)
typedef struct BashAsync BashAsync;

// Start asynchronous execution
BashAsync* execute_bash_async(const char* script_path, const char** args);

// Check if execution is complete
bool bash_async_is_complete(const BashAsync* async);

// Get partial output (non-blocking)
const char* bash_async_get_output(const BashAsync* async);

// Wait for completion and get result
BashResult* bash_async_wait(BashAsync* async);

// Cancel execution
int bash_async_cancel(BashAsync* async);

// Free async handle
void free_bash_async(BashAsync* async);
// }}}

#endif // BASH_BRIDGE_H
// }}}