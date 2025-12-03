// {{{ logging.c - Unified logging implementation
#include "logging.h"
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

#ifdef LOGGING_THREAD_SAFE
#include <pthread.h>
static pthread_mutex_t log_mutex = PTHREAD_MUTEX_INITIALIZER;
#endif

// {{{ Global logging state
static LogConfig g_log_config;
static FILE* g_log_file = NULL;
static char g_module_name[64] = "unknown";
static int g_initialized = 0;
// }}}

// {{{ Thread safety
#ifdef LOGGING_THREAD_SAFE
void log_lock(void) { pthread_mutex_lock(&log_mutex); }
void log_unlock(void) { pthread_mutex_unlock(&log_mutex); }
#endif
// }}}

// {{{ log_level_string
const char* log_level_string(LogLevel level) {
    switch (level) {
        case LOG_LEVEL_DEBUG: return "DEBUG";
        case LOG_LEVEL_INFO:  return "INFO";
        case LOG_LEVEL_WARN:  return "WARN";
        case LOG_LEVEL_ERROR: return "ERROR";
        default: return "UNKNOWN";
    }
}
// }}}

// {{{ log_format_timestamp
void log_format_timestamp(char* buffer, size_t size) {
    time_t now = time(NULL);
    struct tm* tm_info = localtime(&now);
    strftime(buffer, size, "%Y-%m-%d %H:%M:%S", tm_info);
}
// }}}

// {{{ log_format_message
void log_format_message(char* buffer, size_t buffer_size, LogLevel level, const char* module, 
                       const char* file, int line, const char* message) {
    char timestamp[32];
    log_format_timestamp(timestamp, sizeof(timestamp));
    
    const char* basename = strrchr(file, '/');
    basename = basename ? basename + 1 : file;
    
    snprintf(buffer, buffer_size, "[%s] %s %s:%d:%s - %s\n", 
             timestamp, log_level_string(level), module, line, basename, message);
}
// }}}

// {{{ log_rotate_file
int log_rotate_file(const char* filename) {
    if (!filename) return -1;
    
    struct stat st;
    if (stat(filename, &st) != 0) return 0; // File doesn't exist
    
    if (st.st_size < g_log_config.max_file_size) return 0; // No rotation needed
    
    // Create backup filename
    char backup_name[512];
    snprintf(backup_name, sizeof(backup_name), "%s.1", filename);
    
    // Rotate existing backups
    for (int i = g_log_config.max_backup_files; i > 1; i--) {
        char old_backup[512], new_backup[512];
        snprintf(old_backup, sizeof(old_backup), "%s.%d", filename, i-1);
        snprintf(new_backup, sizeof(new_backup), "%s.%d", filename, i);
        rename(old_backup, new_backup);
    }
    
    // Move current log to .1
    rename(filename, backup_name);
    
    return 1; // Rotation occurred
}
// }}}

// {{{ log_cleanup_old_files
int log_cleanup_old_files(const char* base_filename, int max_files) {
    for (int i = max_files + 1; i <= max_files + 10; i++) {
        char filename[512];
        snprintf(filename, sizeof(filename), "%s.%d", base_filename, i);
        if (unlink(filename) != 0) break; // File doesn't exist, stop
    }
    return 0;
}
// }}}

// {{{ log_init
int log_init(const LogConfig* config) {
    log_lock();
    
    if (g_initialized) {
        log_cleanup();
    }
    
    g_log_config = *config;
    
    if (config->module_name) {
        strncpy(g_module_name, config->module_name, sizeof(g_module_name) - 1);
        g_module_name[sizeof(g_module_name) - 1] = '\0';
    }
    
    if ((config->destinations & LOG_DEST_FILE) && config->log_file) {
        log_rotate_file(config->log_file);
        g_log_file = fopen(config->log_file, "a");
        if (!g_log_file) {
            log_unlock();
            return -1;
        }
    }
    
    g_initialized = 1;
    log_unlock();
    return 0;
}
// }}}

// {{{ log_cleanup
void log_cleanup(void) {
    log_lock();
    
    if (g_log_file) {
        fclose(g_log_file);
        g_log_file = NULL;
    }
    
    g_initialized = 0;
    log_unlock();
}
// }}}

// {{{ log_set_level and log_get_level
void log_set_level(LogLevel level) {
    log_lock();
    g_log_config.min_level = level;
    log_unlock();
}

LogLevel log_get_level(void) {
    return g_log_config.min_level;
}
// }}}

// {{{ log_set_module and log_get_module
void log_set_module(const char* module_name) {
    log_lock();
    if (module_name) {
        strncpy(g_module_name, module_name, sizeof(g_module_name) - 1);
        g_module_name[sizeof(g_module_name) - 1] = '\0';
    }
    log_unlock();
}

const char* log_get_module(void) {
    return g_module_name;
}
// }}}

// {{{ log_message
void log_message(LogLevel level, const char* module, const char* file, int line, const char* format, ...) {
    if (!g_initialized) {
        // Auto-initialize with defaults
        LogConfig config = log_default_config();
        log_init(&config);
    }
    
    if (level < g_log_config.min_level) return;
    
    log_lock();
    
    // Format the message
    va_list args;
    va_start(args, format);
    char message[1024];
    vsnprintf(message, sizeof(message), format, args);
    va_end(args);
    
    // Format the full log line
    char full_message[1536];
    log_format_message(full_message, sizeof(full_message), level, module, file, line, message);
    
    // Output to destinations
    if (g_log_config.destinations & LOG_DEST_STDERR) {
        fputs(full_message, stderr);
        fflush(stderr);
    }
    
    if ((g_log_config.destinations & LOG_DEST_FILE) && g_log_file) {
        fputs(full_message, g_log_file);
        fflush(g_log_file);
        
        // Check for rotation
        if (ftell(g_log_file) > g_log_config.max_file_size) {
            fclose(g_log_file);
            log_rotate_file(g_log_config.log_file);
            g_log_file = fopen(g_log_config.log_file, "a");
        }
    }
    
    log_unlock();
}
// }}}

// {{{ Default configurations
LogConfig log_default_config(void) {
    LogConfig config = {
        .min_level = LOG_LEVEL_INFO,
        .destinations = LOG_DEST_STDERR,
        .log_file = NULL,
        .module_name = "default",
        .max_file_size = 1024 * 1024, // 1MB
        .max_backup_files = 5
    };
    return config;
}

LogConfig log_config_for_module(const char* module_name) {
    LogConfig config = log_default_config();
    config.module_name = (char*)module_name;
    
    // Module-specific log file
    static char log_filename[256];
    snprintf(log_filename, sizeof(log_filename), "/tmp/%s.log", module_name);
    config.log_file = log_filename;
    config.destinations = LOG_DEST_STDERR | LOG_DEST_FILE;
    
    return config;
}
// }}}