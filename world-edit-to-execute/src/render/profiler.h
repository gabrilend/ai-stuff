/*
 * Render System Profiler
 *
 * Provides timing instrumentation, statistics, and visualization for
 * debugging performance. Uses thread-local storage to avoid lock contention.
 *
 * Usage:
 *   PROFILE_BEGIN(worker);
 *   ... work ...
 *   PROFILE_END(worker);
 *
 * Toggle overlay: F3
 * Dump to file: F4
 */

#ifndef PROFILER_H
#define PROFILER_H

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <pthread.h>

/* {{{ Configuration */
#define PROFILE_MAX_SAMPLES_PER_THREAD 16   /* Max samples per thread per frame */
#define PROFILE_MAX_SAMPLES_PER_FRAME 64    /* Max total samples per frame */
#define PROFILE_HISTORY_SIZE 120            /* 2 seconds at 60 FPS */
#define PROFILE_MAX_THREADS 16              /* Max threads to track */
/* }}} */

/* {{{ ProfileSample
 * One named timing measurement. */
typedef struct profile_sample {
    const char* name;       /* Static string, e.g., "Worker 0" */
    double start_us;        /* Microseconds since epoch */
    double end_us;
    double duration_us;     /* end_us - start_us */
} ProfileSample;
/* }}} */

/* {{{ ProfileFrame
 * All samples for one frame. */
typedef struct profile_frame {
    uint32_t frame_number;
    double frame_start_us;
    double frame_end_us;
    double frame_duration_us;

    ProfileSample samples[PROFILE_MAX_SAMPLES_PER_FRAME];
    int sample_count;
} ProfileFrame;
/* }}} */

/* {{{ ProfileRingBuffer
 * Rolling history of frames. */
typedef struct profile_ring_buffer {
    ProfileFrame frames[PROFILE_HISTORY_SIZE];
    int head;               /* Next write position */
    int count;              /* Number of valid frames */
} ProfileRingBuffer;
/* }}} */

/* {{{ ProfileStatistics
 * Aggregate statistics over the history buffer. */
typedef struct profile_statistics {
    double avg_frame_us;
    double min_frame_us;
    double max_frame_us;
    double fps;
    int spike_count;        /* Frames > 2x average */
} ProfileStatistics;
/* }}} */

/* {{{ ThreadSampleBuffer
 * Thread-local sample collection. */
typedef struct thread_sample_buffer {
    ProfileSample samples[PROFILE_MAX_SAMPLES_PER_THREAD];
    int count;
    pthread_t thread_id;
    bool registered;
} ThreadSampleBuffer;
/* }}} */

/* {{{ ProfileContext
 * Global profiler state. */
typedef struct profile_context {
    ProfileRingBuffer history;

    /* Thread sample buffers (indexed by slot, not thread ID) */
    ThreadSampleBuffer thread_buffers[PROFILE_MAX_THREADS];
    int thread_count;
    pthread_spinlock_t thread_lock;

    /* Current frame being built */
    ProfileFrame current_frame;
    uint32_t frame_counter;

    /* Display state */
    bool visible;
    bool enabled;

    /* Statistics cache */
    ProfileStatistics stats;
    bool stats_dirty;
} ProfileContext;
/* }}} */

/* {{{ Global Profiler Instance */
extern ProfileContext g_profiler;
/* }}} */

/* {{{ Function Declarations - Initialization */

/* Initialize the profiler. Call once at startup. */
void profile_init(void);

/* Shutdown the profiler. Call at program exit. */
void profile_shutdown(void);
/* }}} */

/* {{{ Function Declarations - Thread Registration */

/* Register current thread for profiling. Call from each worker at startup. */
void profile_register_thread(void);

/* Get the thread-local sample buffer. Returns NULL if not registered. */
ThreadSampleBuffer* profile_get_thread_buffer(void);
/* }}} */

/* {{{ Function Declarations - Recording */

/* Get current time in microseconds (monotonic clock). */
double profile_time_us(void);

/* Record a sample in the current thread's buffer.
 * Called by PROFILE_END macro. */
void profile_record(const char* name, double start_us, double end_us);

/* Begin a new frame. Call at the start of each game loop iteration. */
void profile_begin_frame(void);

/* End the current frame. Merges all thread samples and stores in history. */
void profile_end_frame(void);
/* }}} */

/* {{{ Function Declarations - Overlay */

/* Draw the profiler overlay (call after EndDrawing if visible). */
void profile_draw_overlay(void);

/* Toggle overlay visibility. */
void profile_toggle(void);

/* Check if overlay is visible. */
bool profile_is_visible(void);
/* }}} */

/* {{{ Function Declarations - Statistics */

/* Get statistics over the history buffer. */
ProfileStatistics profile_get_stats(void);

/* Get the most recent completed frame. */
ProfileFrame* profile_get_latest_frame(void);
/* }}} */

/* {{{ Function Declarations - Export */

/* Dump history to a file. */
void profile_dump_to_file(const char* filename);
/* }}} */

/* {{{ Convenience Macros */

/* Begin timing a named region.
 * Creates a local variable _prof_start_##name. */
#define PROFILE_BEGIN(name) \
    double _prof_start_##name = profile_time_us()

/* End timing a named region.
 * Requires matching PROFILE_BEGIN(name) in same scope. */
#define PROFILE_END(name) \
    profile_record(#name, _prof_start_##name, profile_time_us())

/* Conditional profiling (for release builds). */
#ifdef PROFILE_ENABLED
    #define PROFILE_BEGIN_IF(name) PROFILE_BEGIN(name)
    #define PROFILE_END_IF(name) PROFILE_END(name)
#else
    #define PROFILE_BEGIN_IF(name) ((void)0)
    #define PROFILE_END_IF(name) ((void)0)
#endif
/* }}} */

#endif /* PROFILER_H */
