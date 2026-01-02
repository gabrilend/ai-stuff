/*
 * Threading Architecture Demo Implementation
 *
 * Visualizes v2 threading internals: ring buffers, task execution,
 * load balancing, sync watch list, and updater behavior.
 *
 * Text-based visualization for clarity.
 */

#include "demo_threading.h"
#include "raylib.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

/* {{{ Demo State */
static struct {
    WorkerPool* pool;
    SyncContext* sync;
    UpdaterContext* updater;
    bool active;
    bool initialized;

    /* Timing */
    float update_timer;
    float update_interval;

    /* Auto-injection */
    int injection_rate;
    float injection_timer;

    /* Statistics */
    DemoStats stats;
    uint64_t last_tasks_executed;
    float stats_timer;

    /* Display state */
    int scroll_offset;
    int selected_worker;
} g_demo = {0};

/* Test task state */
static atomic_int g_test_task_counter = 0;
/* }}} */

/* {{{ test_task_execute
 * Simple test task that increments a counter */
static void test_task_execute(void* context) {
    (void)context;
    atomic_fetch_add(&g_test_task_counter, 1);
    /* Brief work simulation */
    for (volatile int i = 0; i < 1000; i++) {}
}
/* }}} */

/* {{{ test_task_on_complete
 * Called when test task finishes all repeats */
static void test_task_on_complete(void* context) {
    (void)context;
    g_demo.stats.tasks_executed++;
}
/* }}} */

/* {{{ heavy_task_execute
 * Heavier task that takes more time */
static void heavy_task_execute(void* context) {
    (void)context;
    /* More work simulation */
    for (volatile int i = 0; i < 10000; i++) {}
}
/* }}} */

/* {{{ demo_threading_init */
void demo_threading_init(WorkerPool* pool, SyncContext* sync) {
    g_demo.pool = pool;
    g_demo.sync = sync;
    g_demo.updater = NULL;
    g_demo.active = false;
    g_demo.initialized = true;

    g_demo.update_interval = 1.0f / DEMO_REFRESH_HZ;
    g_demo.update_timer = 0.0f;

    g_demo.injection_rate = 0;
    g_demo.injection_timer = 0.0f;

    memset(&g_demo.stats, 0, sizeof(DemoStats));
    g_demo.last_tasks_executed = 0;
    g_demo.stats_timer = 0.0f;

    g_demo.scroll_offset = 0;
    g_demo.selected_worker = 0;

    printf("[demo] Threading demo initialized\n");
}
/* }}} */

/* {{{ demo_threading_set_updater */
void demo_threading_set_updater(UpdaterContext* updater) {
    g_demo.updater = updater;
}
/* }}} */

/* {{{ demo_threading_shutdown */
void demo_threading_shutdown(void) {
    g_demo.initialized = false;
    g_demo.active = false;
    printf("[demo] Threading demo shutdown\n");
}
/* }}} */

/* {{{ demo_threading_toggle */
void demo_threading_toggle(void) {
    if (g_demo.initialized) {
        g_demo.active = !g_demo.active;
        printf("[demo] Threading demo %s\n", g_demo.active ? "enabled" : "disabled");
    }
}
/* }}} */

/* {{{ demo_threading_is_active */
bool demo_threading_is_active(void) {
    return g_demo.initialized && g_demo.active;
}
/* }}} */

/* {{{ demo_threading_update */
void demo_threading_update(float dt) {
    if (!g_demo.initialized) return;

    g_demo.update_timer += dt;
    g_demo.stats_timer += dt;

    /* Update statistics every second */
    if (g_demo.stats_timer >= 1.0f) {
        uint64_t current = g_demo.stats.tasks_executed;
        uint64_t delta = current - g_demo.last_tasks_executed;
        g_demo.stats.tasks_per_sec = (float)delta / g_demo.stats_timer;
        g_demo.last_tasks_executed = current;

        /* Update history */
        g_demo.stats.throughput_history[g_demo.stats.history_index] = g_demo.stats.tasks_per_sec;
        g_demo.stats.history_index = (g_demo.stats.history_index + 1) % DEMO_HISTORY_SIZE;

        g_demo.stats_timer = 0.0f;
    }

    /* Auto-injection */
    if (g_demo.active && g_demo.injection_rate > 0) {
        g_demo.injection_timer += dt;
        float interval = 1.0f / g_demo.injection_rate;
        while (g_demo.injection_timer >= interval) {
            demo_inject_test_task();
            g_demo.injection_timer -= interval;
        }
    }
}
/* }}} */

/* {{{ draw_worker_panel
 * Draw a single worker's ring buffer state */
static void draw_worker_panel(Worker* w, int x, int y, int width, bool selected) {
    int line_height = 14;
    int padding = 4;

    /* Background */
    Color bg = selected ? (Color){40, 50, 60, 255} : (Color){30, 35, 40, 255};
    DrawRectangle(x, y, width, line_height * 6 + padding * 2, bg);

    /* Border */
    Color border = selected ? SKYBLUE : DARKGRAY;
    DrawRectangleLines(x, y, width, line_height * 6 + padding * 2, border);

    int tx = x + padding;
    int ty = y + padding;

    /* Header: Worker ID and load */
    unsigned int load = atomic_load(&w->num_tasks);
    char header[64];
    snprintf(header, sizeof(header), "Worker %d  [load: %u]", w->worker_id, load);
    DrawText(header, tx, ty, 12, WHITE);
    ty += line_height;

    /* Ring buffer visualization */
    int bar_width = width - padding * 2 - 100;
    int bar_x = tx;
    int bar_y = ty;

    /* Draw buffer bar */
    DrawRectangle(bar_x, bar_y, bar_width, 10, DARKGRAY);

    /* Calculate fill */
    size_t used = 0;
    if (w->end_ptr >= w->start_ptr) {
        used = w->end_ptr - w->start_ptr;
    } else {
        used = w->task_list_size - w->start_ptr + w->end_ptr;
    }
    float fill_ratio = (float)used / w->task_list_size;
    int fill_width = (int)(bar_width * fill_ratio);

    /* Color based on load */
    Color fill_color = GREEN;
    if (fill_ratio > 0.7f) fill_color = ORANGE;
    if (fill_ratio > 0.9f) fill_color = RED;
    DrawRectangle(bar_x, bar_y, fill_width, 10, fill_color);

    /* Pointers text */
    char ptrs[48];
    snprintf(ptrs, sizeof(ptrs), "start=%zu end=%zu", w->start_ptr, w->end_ptr);
    DrawText(ptrs, bar_x + bar_width + 8, bar_y - 2, 10, GRAY);

    ty += line_height;

    /* Show tasks in buffer */
    size_t ptr = w->start_ptr;
    int shown = 0;
    while (ptr != w->end_ptr && shown < 4) {
        WorkerTask* task = &w->task_list[ptr];

        char task_str[80];
        const char* name = "unknown";
        if (task->execute == test_task_execute) name = "test_task";
        else if (task->execute == heavy_task_execute) name = "heavy_task";
        else if (task->execute == sleep_task) name = "sleep_task";
        else if (task->execute == relocate_task) name = "relocate";
        else if (task->execute == primary_updater_execute) name = "updater";
        else if (task->execute == helper_updater_execute) name = "helper";

        snprintf(task_str, sizeof(task_str), "[%zu] %s (w=%d, r=%d)%s",
                 ptr, name, task->weight, task->repeat_count,
                 (ptr == w->start_ptr) ? " <--" : "");

        Color task_color = (ptr == w->start_ptr) ? YELLOW : LIGHTGRAY;
        DrawText(task_str, tx + 8, ty, 10, task_color);

        ty += line_height - 2;
        ptr = (ptr + 1) % w->task_list_size;
        shown++;
    }

    if (used > 4) {
        char more[48];
        snprintf(more, sizeof(more), "  ... +%zu more", used - 4);
        DrawText(more, tx + 8, ty, 10, DARKGRAY);
    }
}
/* }}} */

/* {{{ draw_sync_panel
 * Draw sync watch list state */
static void draw_sync_panel(int x, int y, int width) {
    int line_height = 14;
    int padding = 4;

    /* Background */
    DrawRectangle(x, y, width, line_height * 6 + padding * 2, (Color){35, 30, 40, 255});
    DrawRectangleLines(x, y, width, line_height * 6 + padding * 2, PURPLE);

    int tx = x + padding;
    int ty = y + padding;

    /* Header */
    if (g_demo.sync) {
        size_t count = atomic_load(&g_demo.sync->watch_count);
        char header[64];
        snprintf(header, sizeof(header), "Sync Watch List (%zu entries, %lu swaps)",
                 count, g_demo.sync->swaps_performed);
        DrawText(header, tx, ty, 12, WHITE);
        ty += line_height;

        /* Show entries - snapshot count to avoid race conditions */
        size_t shown = 0;
        for (size_t i = 0; i < count && shown < 4; i++) {
            WatchEntry* entry = &g_demo.sync->watch_list[i];

            /* Safety check: ready_flag may be NULL if entry was just compacted */
            if (!entry->ready_flag) continue;

            bool ready = atomic_load(entry->ready_flag);

            char entry_str[80];
            snprintf(entry_str, sizeof(entry_str), "[%zu] ready=%s target=%p",
                     i, ready ? "TRUE " : "false", (void*)entry->target_ptr);

            Color entry_color = ready ? GREEN : GRAY;
            DrawText(entry_str, tx + 8, ty, 10, entry_color);

            ty += line_height - 2;
            shown++;
        }

        if (count > 4) {
            char more[48];
            snprintf(more, sizeof(more), "  ... +%zu more", count - 4);
            DrawText(more, tx + 8, ty, 10, DARKGRAY);
        }

        if (count == 0) {
            DrawText("  (empty - no pending swaps)", tx + 8, ty, 10, DARKGRAY);
        }
    } else {
        DrawText("Sync context not available", tx, ty, 12, RED);
    }
}
/* }}} */

/* {{{ draw_updater_panel
 * Draw updater state and timing */
static void draw_updater_panel(int x, int y, int width) {
    int line_height = 14;
    int padding = 4;

    /* Background */
    DrawRectangle(x, y, width, line_height * 5 + padding * 2, (Color){40, 35, 30, 255});
    DrawRectangleLines(x, y, width, line_height * 5 + padding * 2, ORANGE);

    int tx = x + padding;
    int ty = y + padding;

    DrawText("Updater (Self-Hosted v2)", tx, ty, 12, WHITE);
    ty += line_height;

    if (g_demo.updater) {
        char buf[64];

        /* Type indicator */
        const char* type_str = g_demo.updater->is_primary ? "PRIMARY" : "HELPER";
        Color type_color = g_demo.updater->is_primary ? GREEN : YELLOW;
        snprintf(buf, sizeof(buf), "Type: %s", type_str);
        DrawText(buf, tx + 8, ty, 10, type_color);
        ty += line_height - 2;

        /* Last tick duration */
        uint64_t duration = g_demo.updater->last_tick_duration_us;
        snprintf(buf, sizeof(buf), "Last tick: %lu us", (unsigned long)duration);
        DrawText(buf, tx + 8, ty, 10, LIGHTGRAY);
        ty += line_height - 2;

        /* Target and threshold */
        snprintf(buf, sizeof(buf), "Target: %d us (spawn > %d us)",
                 TARGET_TICK_US, CONTINUATION_THRESHOLD_US);
        DrawText(buf, tx + 8, ty, 10, GRAY);
        ty += line_height - 2;

        /* Overload indicator */
        if (duration > CONTINUATION_THRESHOLD_US) {
            DrawText("OVERLOAD - spawning helper", tx + 8, ty, 10, RED);
        } else if (duration > TARGET_TICK_US / 2) {
            DrawText("Elevated load", tx + 8, ty, 10, ORANGE);
        } else {
            DrawText("Normal operation", tx + 8, ty, 10, GREEN);
        }
    } else {
        DrawText("  (updater not connected)", tx + 8, ty, 10, DARKGRAY);
    }
}
/* }}} */

/* {{{ draw_throughput_graph
 * Draw mini throughput history graph */
static void draw_throughput_graph(int x, int y, int width, int height) {
    /* Background */
    DrawRectangle(x, y, width, height, (Color){25, 25, 30, 255});
    DrawRectangleLines(x, y, width, height, DARKGRAY);

    /* Find max for scaling */
    float max_val = 1.0f;
    for (int i = 0; i < DEMO_HISTORY_SIZE; i++) {
        if (g_demo.stats.throughput_history[i] > max_val) {
            max_val = g_demo.stats.throughput_history[i];
        }
    }

    /* Draw bars */
    int bar_width = width / DEMO_HISTORY_SIZE;
    if (bar_width < 1) bar_width = 1;

    for (int i = 0; i < DEMO_HISTORY_SIZE; i++) {
        int idx = (g_demo.stats.history_index + i) % DEMO_HISTORY_SIZE;
        float val = g_demo.stats.throughput_history[idx];
        float ratio = val / max_val;
        int bar_height = (int)(ratio * (height - 4));

        int bx = x + i * bar_width;
        int by = y + height - 2 - bar_height;

        /* Color gradient */
        Color bar_color = GREEN;
        if (ratio > 0.8f) bar_color = LIME;
        else if (ratio > 0.5f) bar_color = GREEN;
        else if (ratio > 0.2f) bar_color = YELLOW;
        else bar_color = RED;

        DrawRectangle(bx, by, bar_width - 1, bar_height, bar_color);
    }

    /* Label */
    char label[32];
    snprintf(label, sizeof(label), "%.0f/s", g_demo.stats.tasks_per_sec);
    DrawText(label, x + 4, y + 2, 10, WHITE);
}
/* }}} */

/* {{{ draw_stats_panel
 * Draw aggregate statistics */
static void draw_stats_panel(int x, int y, int width) {
    int line_height = 14;
    int padding = 4;

    /* Background */
    DrawRectangle(x, y, width, line_height * 8 + padding * 2, (Color){30, 40, 35, 255});
    DrawRectangleLines(x, y, width, line_height * 8 + padding * 2, GREEN);

    int tx = x + padding;
    int ty = y + padding;

    DrawText("Statistics", tx, ty, 12, WHITE);
    ty += line_height;

    char buf[64];

    if (g_demo.pool) {
        snprintf(buf, sizeof(buf), "Workers: %d", g_demo.pool->count);
        DrawText(buf, tx + 8, ty, 10, LIGHTGRAY);
        ty += line_height - 2;

        unsigned int total_load = pool_get_total_load(g_demo.pool);
        snprintf(buf, sizeof(buf), "Total load: %u", total_load);
        DrawText(buf, tx + 8, ty, 10, LIGHTGRAY);
        ty += line_height - 2;
    }

    snprintf(buf, sizeof(buf), "Tasks executed: %lu", g_demo.stats.tasks_executed);
    DrawText(buf, tx + 8, ty, 10, LIGHTGRAY);
    ty += line_height - 2;

    snprintf(buf, sizeof(buf), "Tasks injected: %lu", g_demo.stats.tasks_injected);
    DrawText(buf, tx + 8, ty, 10, LIGHTGRAY);
    ty += line_height - 2;

    snprintf(buf, sizeof(buf), "Throughput: %.1f tasks/sec", g_demo.stats.tasks_per_sec);
    DrawText(buf, tx + 8, ty, 10, LIGHTGRAY);
    ty += line_height - 2;

    snprintf(buf, sizeof(buf), "Injection rate: %d/sec", g_demo.injection_rate);
    DrawText(buf, tx + 8, ty, 10, LIGHTGRAY);
}
/* }}} */

/* {{{ draw_controls_panel
 * Draw control hints */
static void draw_controls_panel(int x, int y, int width) {
    int line_height = 12;
    int padding = 4;

    DrawRectangle(x, y, width, line_height * 6 + padding * 2, (Color){40, 40, 40, 255});
    DrawRectangleLines(x, y, width, line_height * 6 + padding * 2, GRAY);

    int tx = x + padding;
    int ty = y + padding;

    DrawText("Controls", tx, ty, 10, WHITE);
    ty += line_height;

    DrawText("T: Test task  H: Heavy task  S: Sleep", tx, ty, 9, GRAY);
    ty += line_height;
    DrawText("1-9: Set injection rate (0=off)", tx, ty, 9, GRAY);
    ty += line_height;
    DrawText("R: Reset stats  F5: Toggle demo", tx, ty, 9, GRAY);
    ty += line_height;
    DrawText("Up/Down: Select worker", tx, ty, 9, GRAY);
}
/* }}} */

/* {{{ demo_threading_draw */
void demo_threading_draw(int x, int y, int width, int height) {
    if (!g_demo.initialized || !g_demo.active) return;

    /* Semi-transparent background */
    DrawRectangle(x, y, width, height, (Color){20, 20, 25, 230});
    DrawRectangleLines(x, y, width, height, DARKGRAY);

    /* Title */
    DrawText("Threading Architecture Demo (v2)", x + 10, y + 5, 14, WHITE);

    int panel_y = y + 25;
    int panel_width = width - 20;
    int panel_height = 95;
    int small_panel_height = 78;
    int panel_spacing = 5;

    /* Draw worker panels (left column) */
    if (g_demo.pool) {
        for (int i = 0; i < g_demo.pool->count && i < 4; i++) {
            Worker* w = &g_demo.pool->workers[i];
            bool selected = (i == g_demo.selected_worker);
            draw_worker_panel(w, x + 10, panel_y, panel_width / 2 - 5, selected);
            panel_y += panel_height + panel_spacing;
        }
    }

    /* Right column */
    int right_x = x + width / 2 + 5;
    int right_y = y + 25;
    int right_width = panel_width / 2 - 5;

    /* Updater panel (v2 feature: self-hosted updater) */
    draw_updater_panel(right_x, right_y, right_width);
    right_y += small_panel_height + panel_spacing;

    /* Sync panel */
    draw_sync_panel(right_x, right_y, right_width);
    right_y += panel_height + panel_spacing;

    /* Stats panel */
    draw_stats_panel(right_x, right_y, right_width);
    right_y += panel_height + 30 + panel_spacing;

    /* Throughput graph */
    draw_throughput_graph(right_x, right_y, right_width, 50);
    right_y += 50 + panel_spacing;

    /* Controls panel */
    draw_controls_panel(right_x, right_y, right_width);
}
/* }}} */

/* {{{ demo_threading_handle_input */
void demo_threading_handle_input(void) {
    if (!g_demo.initialized) return;

    /* F5: Toggle demo */
    if (IsKeyPressed(KEY_F5)) {
        demo_threading_toggle();
    }

    if (!g_demo.active) return;

    /* Task injection */
    if (IsKeyPressed(KEY_T)) {
        demo_inject_test_task();
    }
    if (IsKeyPressed(KEY_H)) {
        demo_inject_heavy_task();
    }
    if (IsKeyPressed(KEY_S)) {
        demo_inject_sleep_task();
    }

    /* Injection rate */
    for (int i = 0; i <= 9; i++) {
        if (IsKeyPressed(KEY_ZERO + i)) {
            demo_set_injection_rate(i * 10);  /* 0, 10, 20, ..., 90 */
        }
    }

    /* Reset stats */
    if (IsKeyPressed(KEY_R)) {
        demo_reset_stats();
    }

    /* Worker selection */
    if (IsKeyPressed(KEY_UP) && g_demo.selected_worker > 0) {
        g_demo.selected_worker--;
    }
    if (IsKeyPressed(KEY_DOWN) && g_demo.pool &&
        g_demo.selected_worker < g_demo.pool->count - 1) {
        g_demo.selected_worker++;
    }
}
/* }}} */

/* {{{ demo_inject_test_task */
void demo_inject_test_task(void) {
    if (!g_demo.pool) return;

    Worker* target = find_least_busy_worker(g_demo.pool);
    if (!target) return;

    WorkerTask task = {
        .execute = test_task_execute,
        .on_complete = test_task_on_complete,
        .context = NULL,
        .weight = WEIGHT_LIGHT,
        .repeat_count = 1
    };

    if (task_append(target, &task)) {
        g_demo.stats.tasks_injected++;
    }
}
/* }}} */

/* {{{ demo_inject_heavy_task */
void demo_inject_heavy_task(void) {
    if (!g_demo.pool) return;

    Worker* target = find_least_busy_worker(g_demo.pool);
    if (!target) return;

    WorkerTask task = {
        .execute = heavy_task_execute,
        .on_complete = test_task_on_complete,
        .context = NULL,
        .weight = WEIGHT_HEAVY,
        .repeat_count = 5
    };

    if (task_append(target, &task)) {
        g_demo.stats.tasks_injected++;
    }
}
/* }}} */

/* {{{ demo_inject_sleep_task */
void demo_inject_sleep_task(void) {
    if (!g_demo.pool) return;

    Worker* target = find_least_busy_worker(g_demo.pool);
    if (!target) return;

    WorkerTask task = {
        .execute = sleep_task,
        .on_complete = NULL,
        .context = NULL,
        .weight = WEIGHT_SLEEP,
        .repeat_count = 1
    };

    if (task_append(target, &task)) {
        g_demo.stats.tasks_injected++;
    }
}
/* }}} */

/* {{{ demo_set_injection_rate */
void demo_set_injection_rate(int tasks_per_sec) {
    g_demo.injection_rate = tasks_per_sec;
    g_demo.injection_timer = 0.0f;
    printf("[demo] Injection rate set to %d/sec\n", tasks_per_sec);
}
/* }}} */

/* {{{ demo_get_stats */
const DemoStats* demo_get_stats(void) {
    return &g_demo.stats;
}
/* }}} */

/* {{{ demo_reset_stats */
void demo_reset_stats(void) {
    memset(&g_demo.stats, 0, sizeof(DemoStats));
    g_demo.last_tasks_executed = 0;
    atomic_store(&g_test_task_counter, 0);
    printf("[demo] Statistics reset\n");
}
/* }}} */
