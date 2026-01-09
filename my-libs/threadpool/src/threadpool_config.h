/*
 * Threadpool Configuration
 *
 * Configurable constants and settings for the threadpool library.
 * Users can override defaults by defining values before including this header.
 */

#ifndef THREADPOOL_CONFIG_H
#define THREADPOOL_CONFIG_H

#include <stddef.h>
#include <stdint.h>

/* {{{ Default Constants
 * Override these by defining before including this header */

#ifndef TP_DEFAULT_TASK_LIST_SIZE
#define TP_DEFAULT_TASK_LIST_SIZE 1024
#endif

#ifndef TP_DEFAULT_TARGET_TICK_US
#define TP_DEFAULT_TARGET_TICK_US 10000  /* 10ms = 100Hz */
#endif

/* }}} */

/* {{{ Weight Constants
 * Used for load balancing. Higher weight = more expensive task. */
#ifndef TP_WEIGHT_SLEEP
#define TP_WEIGHT_SLEEP   0
#endif

#ifndef TP_WEIGHT_LIGHT
#define TP_WEIGHT_LIGHT   1
#endif

#ifndef TP_WEIGHT_MEDIUM
#define TP_WEIGHT_MEDIUM  5
#endif

#ifndef TP_WEIGHT_HEAVY
#define TP_WEIGHT_HEAVY   20
#endif

#ifndef TP_WEIGHT_UPDATER
#define TP_WEIGHT_UPDATER 10
#endif
/* }}} */

/* {{{ Log Callback Type
 * Signature for optional logging function.
 * If NULL, no logging occurs (minimal overhead - single pointer check). */
typedef void (*tp_log_fn)(const char* fmt, ...);
/* }}} */

/* {{{ TpConfig
 * Configuration structure for threadpool creation.
 * Pass NULL to tp_pool_create() to use defaults. */
typedef struct tp_config {
    size_t task_list_size;      /* Ring buffer capacity per worker */
    tp_log_fn log_fn;           /* Optional logging callback (NULL = silent) */
} TpConfig;
/* }}} */

/* {{{ tp_config_default
 * Returns configuration with sensible defaults. */
static inline TpConfig tp_config_default(void) {
    TpConfig cfg = {
        .task_list_size = TP_DEFAULT_TASK_LIST_SIZE,
        .log_fn = NULL
    };
    return cfg;
}
/* }}} */

/* {{{ TP_LOG Macro
 * Conditional logging - only calls log_fn if it's set.
 * Usage: TP_LOG(&config, "Worker %d started", id); */
#define TP_LOG(cfg_ptr, fmt, ...) \
    do { \
        if ((cfg_ptr)->log_fn) { \
            (cfg_ptr)->log_fn(fmt, ##__VA_ARGS__); \
        } \
    } while(0)
/* }}} */

#endif /* THREADPOOL_CONFIG_H */
