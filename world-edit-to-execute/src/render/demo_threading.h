/*
 * Threading Architecture Demo
 *
 * Visualizes v2 threading internals in real-time.
 * Shows ring buffers, task flow, load balancing, and sync operations.
 *
 * Usage:
 *   demo_threading_init(pool, sync);  // Attach to existing pool
 *   demo_threading_update();          // Call each frame
 *   demo_threading_draw();            // Render visualization
 *   demo_threading_handle_input();    // Process keyboard controls
 *   demo_threading_shutdown();        // Cleanup
 */

#ifndef DEMO_THREADING_H
#define DEMO_THREADING_H

#include "threading.h"
#include <stdbool.h>

/* {{{ Configuration */
#define DEMO_REFRESH_HZ 10          /* Visualization refresh rate */
#define DEMO_HISTORY_SIZE 60        /* Samples for throughput graph */
#define DEMO_MAX_VISIBLE_TASKS 8    /* Tasks shown per worker */
/* }}} */

/* {{{ DemoStats - aggregate statistics */
typedef struct demo_stats {
    uint64_t tasks_executed;
    uint64_t tasks_injected;
    uint64_t swaps_performed;
    uint64_t relocates_triggered;
    uint64_t helpers_spawned;

    /* Throughput tracking */
    float tasks_per_sec;
    float avg_task_duration_us;

    /* History for mini-graph */
    float throughput_history[DEMO_HISTORY_SIZE];
    int history_index;
} DemoStats;
/* }}} */

/* {{{ Public API */

/* Initialize demo with existing pool and sync context */
void demo_threading_init(WorkerPool* pool, SyncContext* sync);

/* Set the updater context for timing visualization */
void demo_threading_set_updater(UpdaterContext* updater);

/* Update demo state (call each frame or at DEMO_REFRESH_HZ) */
void demo_threading_update(float dt);

/* Render visualization (raylib drawing context must be active) */
void demo_threading_draw(int x, int y, int width, int height);

/* Handle keyboard input for controls */
void demo_threading_handle_input(void);

/* Shutdown and cleanup */
void demo_threading_shutdown(void);

/* Check if demo is active */
bool demo_threading_is_active(void);

/* Toggle demo visibility */
void demo_threading_toggle(void);

/* }}} */

/* {{{ Task injection API (for interactive demo) */

/* Inject a test task to least-busy worker */
void demo_inject_test_task(void);

/* Inject a heavy task (high weight, multiple repeats) */
void demo_inject_heavy_task(void);

/* Inject a sleep task */
void demo_inject_sleep_task(void);

/* Set automatic injection rate (tasks per second, 0 = disabled) */
void demo_set_injection_rate(int tasks_per_sec);

/* }}} */

/* {{{ Statistics access */

/* Get current statistics (read-only) */
const DemoStats* demo_get_stats(void);

/* Reset all statistics */
void demo_reset_stats(void);

/* }}} */

#endif /* DEMO_THREADING_H */
