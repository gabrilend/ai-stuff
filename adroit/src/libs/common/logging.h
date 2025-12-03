// {{{ logging.h - Unified logging system for ai-stuff ecosystem
#ifndef LOGGING_H
#define LOGGING_H

#include <stdio.h>
#include <stdarg.h>
#include <time.h>

// {{{ Log levels
typedef enum LogLevel {
    LOG_LEVEL_DEBUG = 0,
    LOG_LEVEL_INFO  = 1,
    LOG_LEVEL_WARN  = 2,
    LOG_LEVEL_ERROR = 3,
    LOG_LEVEL_NONE  = 4
} LogLevel;
// }}}

// {{{ Log destinations
typedef enum LogDestination {
    LOG_DEST_STDERR = 1,
    LOG_DEST_FILE   = 2,
    LOG_DEST_SYSLOG = 4
} LogDestination;
// }}}

// {{{ Configuration
typedef struct LogConfig {
    LogLevel min_level;
    int destinations;           // Bitfield of LogDestination
    char* log_file;            // NULL for no file logging
    char* module_name;         // Module identifier
    int max_file_size;         // Rotate at this size (bytes)
    int max_backup_files;      // Keep this many backup files
} LogConfig;
// }}}

// {{{ Core logging functions
int log_init(const LogConfig* config);
void log_cleanup(void);
void log_set_level(LogLevel level);
LogLevel log_get_level(void);

// Internal logging function
void log_message(LogLevel level, const char* module, const char* file, int line, const char* format, ...);

// Convenience macros
#define LOG_DEBUG(fmt, ...) log_message(LOG_LEVEL_DEBUG, "default", __FILE__, __LINE__, fmt, ##__VA_ARGS__)
#define LOG_INFO(fmt, ...)  log_message(LOG_LEVEL_INFO, "default", __FILE__, __LINE__, fmt, ##__VA_ARGS__)
#define LOG_WARN(fmt, ...)  log_message(LOG_LEVEL_WARN, "default", __FILE__, __LINE__, fmt, ##__VA_ARGS__)
#define LOG_ERROR(fmt, ...) log_message(LOG_LEVEL_ERROR, "default", __FILE__, __LINE__, fmt, ##__VA_ARGS__)
// }}}

// {{{ Module-specific logging
void log_set_module(const char* module_name);
const char* log_get_module(void);

// Module-aware logging macros
#define MLOG_DEBUG(module, fmt, ...) log_message(LOG_LEVEL_DEBUG, module, __FILE__, __LINE__, fmt, ##__VA_ARGS__)
#define MLOG_INFO(module, fmt, ...)  log_message(LOG_LEVEL_INFO, module, __FILE__, __LINE__, fmt, ##__VA_ARGS__)
#define MLOG_WARN(module, fmt, ...)  log_message(LOG_LEVEL_WARN, module, __FILE__, __LINE__, fmt, ##__VA_ARGS__)
#define MLOG_ERROR(module, fmt, ...) log_message(LOG_LEVEL_ERROR, module, __FILE__, __LINE__, fmt, ##__VA_ARGS__)
// }}}

// {{{ Log formatting
const char* log_level_string(LogLevel level);
void log_format_timestamp(char* buffer, size_t size);
void log_format_message(char* buffer, size_t buffer_size, LogLevel level, const char* module, 
                       const char* file, int line, const char* message);
// }}}

// {{{ File management
int log_rotate_file(const char* filename);
int log_cleanup_old_files(const char* base_filename, int max_files);
// }}}

// {{{ Thread safety
#ifdef LOGGING_THREAD_SAFE
#include <pthread.h>
void log_lock(void);
void log_unlock(void);
#else
#define log_lock()
#define log_unlock() 
#endif
// }}}

// {{{ Default configuration helper
LogConfig log_default_config(void);
LogConfig log_config_for_module(const char* module_name);
// }}}

#endif // LOGGING_H
// }}}