/*
 * Render System Profiler Implementation
 *
 * Thread-safe profiling with TLS sample buffers.
 * Run with: Add to SOURCES in run script.
 */

#include "profiler.h"
#include "raylib.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* {{{ Global Profiler Instance */
ProfileContext g_profiler = {0};
/* }}} */

/* {{{ Thread-Local Storage
 * Each thread has its own slot in g_profiler.thread_buffers.
 * We use pthread_self() to find our slot after registration. */
static __thread int tls_thread_slot = -1;
/* }}} */

/* {{{ profile_time_us
 * High-resolution timer using CLOCK_MONOTONIC. */
double profile_time_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec * 1000000.0 + (double)ts.tv_nsec / 1000.0;
}
/* }}} */

/* {{{ profile_init
 * Initialize the profiler. Call once at startup. */
void profile_init(void) {
    memset(&g_profiler, 0, sizeof(g_profiler));

    pthread_spin_init(&g_profiler.thread_lock, PTHREAD_PROCESS_PRIVATE);

    g_profiler.enabled = true;
    g_profiler.visible = false;
    g_profiler.stats_dirty = true;

    /* Initialize history ring buffer */
    g_profiler.history.head = 0;
    g_profiler.history.count = 0;

    /* Initialize thread buffers */
    for (int i = 0; i < PROFILE_MAX_THREADS; i++) {
        g_profiler.thread_buffers[i].registered = false;
        g_profiler.thread_buffers[i].count = 0;
    }
    g_profiler.thread_count = 0;

    /* Register main thread */
    profile_register_thread();
}
/* }}} */

/* {{{ profile_shutdown
 * Shutdown the profiler. */
void profile_shutdown(void) {
    pthread_spin_destroy(&g_profiler.thread_lock);
}
/* }}} */

/* {{{ profile_register_thread
 * Register current thread for profiling. */
void profile_register_thread(void) {
    if (tls_thread_slot >= 0) return;  /* Already registered */

    pthread_spin_lock(&g_profiler.thread_lock);

    if (g_profiler.thread_count >= PROFILE_MAX_THREADS) {
        pthread_spin_unlock(&g_profiler.thread_lock);
        fprintf(stderr, "[Profiler] Warning: max threads exceeded\n");
        return;
    }

    int slot = g_profiler.thread_count++;
    tls_thread_slot = slot;

    ThreadSampleBuffer* buf = &g_profiler.thread_buffers[slot];
    buf->thread_id = pthread_self();
    buf->registered = true;
    buf->count = 0;

    pthread_spin_unlock(&g_profiler.thread_lock);
}
/* }}} */

/* {{{ profile_get_thread_buffer
 * Get the thread-local sample buffer. */
ThreadSampleBuffer* profile_get_thread_buffer(void) {
    if (tls_thread_slot < 0) return NULL;
    return &g_profiler.thread_buffers[tls_thread_slot];
}
/* }}} */

/* {{{ profile_record
 * Record a sample in the current thread's buffer. */
void profile_record(const char* name, double start_us, double end_us) {
    if (!g_profiler.enabled) return;

    ThreadSampleBuffer* buf = profile_get_thread_buffer();
    if (!buf) return;  /* Thread not registered */

    if (buf->count >= PROFILE_MAX_SAMPLES_PER_THREAD) return;  /* Buffer full */

    ProfileSample* sample = &buf->samples[buf->count++];
    sample->name = name;
    sample->start_us = start_us;
    sample->end_us = end_us;
    sample->duration_us = end_us - start_us;
}
/* }}} */

/* {{{ profile_begin_frame
 * Begin a new frame. */
void profile_begin_frame(void) {
    if (!g_profiler.enabled) return;

    /* Reset current frame */
    memset(&g_profiler.current_frame, 0, sizeof(ProfileFrame));
    g_profiler.current_frame.frame_number = g_profiler.frame_counter;
    g_profiler.current_frame.frame_start_us = profile_time_us();

    /* Clear all thread sample buffers */
    for (int i = 0; i < g_profiler.thread_count; i++) {
        g_profiler.thread_buffers[i].count = 0;
    }
}
/* }}} */

/* {{{ profile_end_frame
 * End the current frame. Merges all thread samples and stores in history. */
void profile_end_frame(void) {
    if (!g_profiler.enabled) return;

    g_profiler.current_frame.frame_end_us = profile_time_us();
    g_profiler.current_frame.frame_duration_us =
        g_profiler.current_frame.frame_end_us - g_profiler.current_frame.frame_start_us;

    /* Merge samples from all threads */
    int total_samples = 0;
    for (int t = 0; t < g_profiler.thread_count; t++) {
        ThreadSampleBuffer* buf = &g_profiler.thread_buffers[t];
        for (int s = 0; s < buf->count && total_samples < PROFILE_MAX_SAMPLES_PER_FRAME; s++) {
            g_profiler.current_frame.samples[total_samples++] = buf->samples[s];
        }
    }
    g_profiler.current_frame.sample_count = total_samples;

    /* Store in history ring buffer */
    int slot = g_profiler.history.head;
    g_profiler.history.frames[slot] = g_profiler.current_frame;
    g_profiler.history.head = (slot + 1) % PROFILE_HISTORY_SIZE;
    if (g_profiler.history.count < PROFILE_HISTORY_SIZE) {
        g_profiler.history.count++;
    }

    g_profiler.frame_counter++;
    g_profiler.stats_dirty = true;
}
/* }}} */

/* {{{ profile_get_latest_frame
 * Get the most recent completed frame. */
ProfileFrame* profile_get_latest_frame(void) {
    if (g_profiler.history.count == 0) return NULL;

    int slot = (g_profiler.history.head - 1 + PROFILE_HISTORY_SIZE) % PROFILE_HISTORY_SIZE;
    return &g_profiler.history.frames[slot];
}
/* }}} */

/* {{{ profile_get_stats
 * Calculate statistics over the history buffer. */
ProfileStatistics profile_get_stats(void) {
    if (!g_profiler.stats_dirty) {
        return g_profiler.stats;
    }

    ProfileStatistics stats = {0};
    if (g_profiler.history.count == 0) {
        g_profiler.stats = stats;
        g_profiler.stats_dirty = false;
        return stats;
    }

    double sum = 0;
    double min_val = 1e9;
    double max_val = 0;

    for (int i = 0; i < g_profiler.history.count; i++) {
        double dur = g_profiler.history.frames[i].frame_duration_us;
        sum += dur;
        if (dur < min_val) min_val = dur;
        if (dur > max_val) max_val = dur;
    }

    stats.avg_frame_us = sum / g_profiler.history.count;
    stats.min_frame_us = min_val;
    stats.max_frame_us = max_val;
    stats.fps = 1000000.0 / stats.avg_frame_us;

    /* Count spikes (frames > 2x average) */
    double spike_threshold = stats.avg_frame_us * 2.0;
    for (int i = 0; i < g_profiler.history.count; i++) {
        if (g_profiler.history.frames[i].frame_duration_us > spike_threshold) {
            stats.spike_count++;
        }
    }

    g_profiler.stats = stats;
    g_profiler.stats_dirty = false;
    return stats;
}
/* }}} */

/* {{{ profile_toggle
 * Toggle overlay visibility. */
void profile_toggle(void) {
    g_profiler.visible = !g_profiler.visible;
}
/* }}} */

/* {{{ profile_is_visible
 * Check if overlay is visible. */
bool profile_is_visible(void) {
    return g_profiler.visible;
}
/* }}} */

/* {{{ draw_bar
 * Draw a timing bar with label. */
static void draw_bar(int x, int y, const char* label, double duration_us, double frame_budget_us) {
    float pct = (float)(duration_us / frame_budget_us);
    if (pct > 1.0f) pct = 1.0f;

    int bar_max_w = 180;
    int bar_w = (int)(pct * bar_max_w);

    /* Choose color based on percentage */
    Color bar_color;
    if (pct < 0.5f) {
        bar_color = GREEN;
    } else if (pct < 0.8f) {
        bar_color = YELLOW;
    } else {
        bar_color = RED;
    }

    /* Label */
    DrawText(label, x, y, 10, LIGHTGRAY);

    /* Bar background */
    DrawRectangle(x + 65, y, bar_max_w, 12, (Color){60, 60, 60, 255});

    /* Bar fill */
    DrawRectangle(x + 65, y, bar_w, 12, bar_color);

    /* Duration text */
    char buf[32];
    snprintf(buf, sizeof(buf), "%.2fms", duration_us / 1000.0);
    DrawText(buf, x + 250, y, 10, WHITE);

    /* Percentage */
    snprintf(buf, sizeof(buf), "%3.0f%%", pct * 100);
    DrawText(buf, x + 305, y, 10, WHITE);
}
/* }}} */

/* {{{ profile_draw_overlay
 * Draw the profiler overlay. */
void profile_draw_overlay(void) {
    if (!g_profiler.visible) return;

    ProfileFrame* frame = profile_get_latest_frame();
    if (!frame) return;

    ProfileStatistics stats = profile_get_stats();

    int x = 10;
    int y = GetScreenHeight() - 260;
    int w = 350;
    int h = 250;

    /* Background */
    DrawRectangle(x, y, w, h, (Color){0, 0, 0, 200});
    DrawRectangleLines(x, y, w, h, (Color){80, 80, 80, 255});

    /* Title */
    DrawText("Render Profiler (F3 toggle, F4 dump)", x + 5, y + 5, 10, LIGHTGRAY);

    /* Header line */
    char header[128];
    snprintf(header, sizeof(header), "Frame: %u  FPS: %.1f  dt: %.2fms",
             frame->frame_number, stats.fps, frame->frame_duration_us / 1000.0);
    DrawText(header, x + 5, y + 20, 12, WHITE);

    /* Separator */
    DrawLine(x + 5, y + 36, x + w - 5, y + 36, (Color){80, 80, 80, 255});

    /* Per-sample bars */
    double frame_budget_us = 16666.0;  /* 60 FPS */
    int bar_y = y + 42;

    for (int i = 0; i < frame->sample_count && bar_y < y + h - 60; i++) {
        ProfileSample* s = &frame->samples[i];
        draw_bar(x + 5, bar_y, s->name, s->duration_us, frame_budget_us);
        bar_y += 16;
    }

    /* Separator */
    DrawLine(x + 5, y + h - 55, x + w - 5, y + h - 55, (Color){80, 80, 80, 255});

    /* Statistics */
    char stat_line[128];
    snprintf(stat_line, sizeof(stat_line), "Avg: %.2fms  Min: %.2fms  Max: %.2fms",
             stats.avg_frame_us / 1000.0, stats.min_frame_us / 1000.0, stats.max_frame_us / 1000.0);
    DrawText(stat_line, x + 5, y + h - 50, 10, LIGHTGRAY);

    snprintf(stat_line, sizeof(stat_line), "History: %d frames  Spikes: %d",
             g_profiler.history.count, stats.spike_count);
    DrawText(stat_line, x + 5, y + h - 35, 10, LIGHTGRAY);

    /* Timeline graph (bottom section) */
    int graph_x = x + 5;
    int graph_y = y + h - 20;
    int graph_w = w - 10;
    int graph_h = 15;

    /* Graph background */
    DrawRectangle(graph_x, graph_y, graph_w, graph_h, (Color){40, 40, 40, 255});

    /* Draw one line per frame in history */
    if (g_profiler.history.count > 0) {
        float pixel_width = (float)graph_w / (float)g_profiler.history.count;
        if (pixel_width < 1.0f) pixel_width = 1.0f;

        for (int i = 0; i < g_profiler.history.count; i++) {
            int slot = (g_profiler.history.head - g_profiler.history.count + i + PROFILE_HISTORY_SIZE) % PROFILE_HISTORY_SIZE;
            double dur = g_profiler.history.frames[slot].frame_duration_us;

            /* Normalize to graph height (0-33ms mapped to 0-graph_h) */
            float norm = (float)(dur / 33333.0);  /* 30 FPS = 33ms */
            if (norm > 1.0f) norm = 1.0f;
            int bar_h = (int)(norm * graph_h);
            if (bar_h < 1) bar_h = 1;

            /* Color based on frame time */
            Color col;
            if (dur < 16666) {
                col = GREEN;
            } else if (dur < 20000) {
                col = YELLOW;
            } else {
                col = RED;
            }

            int px = graph_x + (int)(i * pixel_width);
            DrawRectangle(px, graph_y + graph_h - bar_h, (int)pixel_width + 1, bar_h, col);
        }
    }
}
/* }}} */

/* {{{ profile_dump_to_file
 * Dump history to a file. */
void profile_dump_to_file(const char* filename) {
    FILE* f = fopen(filename, "w");
    if (!f) {
        fprintf(stderr, "[Profiler] Failed to open %s for writing\n", filename);
        return;
    }

    /* Header */
    time_t now = time(NULL);
    struct tm* t = localtime(&now);
    fprintf(f, "# Profile Dump - %04d-%02d-%02d %02d:%02d:%02d\n",
            t->tm_year + 1900, t->tm_mon + 1, t->tm_mday,
            t->tm_hour, t->tm_min, t->tm_sec);

    ProfileStatistics stats = profile_get_stats();
    fprintf(f, "# Frames: %d, Avg: %.2fms, Min: %.2fms, Max: %.2fms, Spikes: %d\n\n",
            g_profiler.history.count,
            stats.avg_frame_us / 1000.0,
            stats.min_frame_us / 1000.0,
            stats.max_frame_us / 1000.0,
            stats.spike_count);

    /* Dump each frame */
    for (int i = 0; i < g_profiler.history.count; i++) {
        int slot = (g_profiler.history.head - g_profiler.history.count + i + PROFILE_HISTORY_SIZE) % PROFILE_HISTORY_SIZE;
        ProfileFrame* frame = &g_profiler.history.frames[slot];

        fprintf(f, "FRAME %u (%.2fms)\n", frame->frame_number, frame->frame_duration_us / 1000.0);

        for (int s = 0; s < frame->sample_count; s++) {
            ProfileSample* sample = &frame->samples[s];
            /* Offset times relative to frame start */
            double rel_start = sample->start_us - frame->frame_start_us;
            double rel_end = sample->end_us - frame->frame_start_us;
            fprintf(f, "  %-12s  %8.2f  %8.2f  %6.2fms\n",
                    sample->name, rel_start / 1000.0, rel_end / 1000.0, sample->duration_us / 1000.0);
        }
        fprintf(f, "\n");
    }

    fclose(f);
    printf("[Profiler] Dumped %d frames to %s\n", g_profiler.history.count, filename);
}
/* }}} */
