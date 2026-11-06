/*
 * Threadpool Platform Layer
 *
 * Every operating-system call the threadpool makes goes through this header:
 * threads, mutexes, condition variables, spinlocks, the monotonic clock,
 * sleeping and counting CPUs. The rest of the library and its tests use only
 * these names, so supporting another platform means adding one more section
 * here and nothing anywhere else (`make check-portable` in tests/ verifies
 * that no POSIX call has leaked out of this file).
 *
 * The layer is header-only (static inline), so projects that copy or compile
 * the library's .c files keep the same build lines.
 *
 * Backends:
 *   POSIX (Linux, the BSDs, macOS) - implemented here.
 *   Win32 - planned, see issues/800i-win32-backend.md. Until then a Windows
 *           build stops at the #error below rather than failing obscurely.
 *
 * Conventions:
 *   - Functions return 0 on success where they can fail (as pthreads do).
 *   - Timed waits take a RELATIVE timeout in microseconds, which every
 *     platform supports; callers that need a deadline loop and recompute.
 *   - The spinlock is built on C11 atomic_flag, so it needs nothing from the
 *     OS (macOS has no pthread_spinlock_t).
 */

#ifndef THREADPOOL_PLATFORM_H
#define THREADPOOL_PLATFORM_H

#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>

#if defined(_WIN32)
#error "threadpool: the Win32 backend is not written yet (issues/800i-win32-backend.md)"
#endif

/* {{{ POSIX backend */
#include <errno.h>
#include <pthread.h>
#include <sched.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

/* {{{ Condition variable clock
 * Timed waits measure their timeout on the monotonic clock where the platform
 * lets a condition variable use it (pthread_condattr_setclock). macOS has no
 * pthread_condattr_setclock, so there the wait falls back to the wall clock:
 * a wall-clock jump can then lengthen or shorten one wait, never break it.
 * Define TP_COND_REALTIME to force the fallback (the tests build it both ways). */
#if defined(__APPLE__) && !defined(TP_COND_REALTIME)
#define TP_COND_REALTIME 1
#endif
/* }}} */

typedef pthread_t tp_thread_t;
typedef pthread_mutex_t tp_mutex_t;
typedef pthread_cond_t tp_cond_t;
typedef void* (*tp_thread_fn)(void* arg);

/* {{{ tp_spinlock_t
 * Busy-waiting lock for very short critical sections. */
typedef struct tp_spinlock {
    atomic_flag flag;
} tp_spinlock_t;
/* }}} */

/* {{{ tp_thread_create
 * Starts fn(arg) on a new thread. Returns 0 on success. */
static inline int tp_thread_create(tp_thread_t* thread, tp_thread_fn fn, void* arg) {
    return pthread_create(thread, NULL, fn, arg);
}
/* }}} */

/* {{{ tp_thread_join
 * Waits for a thread to finish. Returns 0 on success. */
static inline int tp_thread_join(tp_thread_t thread) {
    return pthread_join(thread, NULL);
}
/* }}} */

/* {{{ tp_mutex_init / destroy / lock / unlock */
static inline int tp_mutex_init(tp_mutex_t* m) { return pthread_mutex_init(m, NULL); }
static inline void tp_mutex_destroy(tp_mutex_t* m) { pthread_mutex_destroy(m); }
static inline void tp_mutex_lock(tp_mutex_t* m) { pthread_mutex_lock(m); }
static inline void tp_mutex_unlock(tp_mutex_t* m) { pthread_mutex_unlock(m); }
/* }}} */

/* {{{ tp_cond_init
 * A condition variable whose timed waits use the monotonic clock (see
 * TP_COND_REALTIME above). Returns 0 on success. */
static inline int tp_cond_init(tp_cond_t* c) {
#ifdef TP_COND_REALTIME
    return pthread_cond_init(c, NULL);
#else
    pthread_condattr_t attr;
    int rc = pthread_condattr_init(&attr);
    if (rc != 0) return rc;
    rc = pthread_condattr_setclock(&attr, CLOCK_MONOTONIC);
    if (rc == 0) rc = pthread_cond_init(c, &attr);
    pthread_condattr_destroy(&attr);
    return rc;
#endif
}
/* }}} */

/* {{{ tp_cond_destroy / wait / signal / broadcast */
static inline void tp_cond_destroy(tp_cond_t* c) { pthread_cond_destroy(c); }
static inline void tp_cond_wait(tp_cond_t* c, tp_mutex_t* m) { pthread_cond_wait(c, m); }
static inline void tp_cond_signal(tp_cond_t* c) { pthread_cond_signal(c); }
static inline void tp_cond_broadcast(tp_cond_t* c) { pthread_cond_broadcast(c); }
/* }}} */

/* {{{ tp_cond_timedwait_us
 * Waits on c (m held) for at most timeout_us microseconds.
 * Returns true if woken (possibly spuriously), false on timeout. */
static inline bool tp_cond_timedwait_us(tp_cond_t* c, tp_mutex_t* m, uint64_t timeout_us) {
    struct timespec deadline;
#ifdef TP_COND_REALTIME
    struct timeval now;
    gettimeofday(&now, NULL);
    deadline.tv_sec = now.tv_sec;
    deadline.tv_nsec = (long)now.tv_usec * 1000L;
#else
    clock_gettime(CLOCK_MONOTONIC, &deadline);
#endif
    uint64_t total_ns = (uint64_t)deadline.tv_nsec + (timeout_us % 1000000ULL) * 1000ULL;
    deadline.tv_sec += (time_t)(timeout_us / 1000000ULL + total_ns / 1000000000ULL);
    deadline.tv_nsec = (long)(total_ns % 1000000000ULL);

    return pthread_cond_timedwait(c, m, &deadline) != ETIMEDOUT;
}
/* }}} */

/* {{{ tp_spin_init / destroy / lock / unlock */
static inline void tp_spin_init(tp_spinlock_t* s) { atomic_flag_clear(&s->flag); }
static inline void tp_spin_destroy(tp_spinlock_t* s) { (void)s; }
static inline void tp_spin_lock(tp_spinlock_t* s) {
    while (atomic_flag_test_and_set_explicit(&s->flag, memory_order_acquire)) {
        sched_yield();
    }
}
static inline void tp_spin_unlock(tp_spinlock_t* s) {
    atomic_flag_clear_explicit(&s->flag, memory_order_release);
}
/* }}} */

/* {{{ tp_time_us
 * Microseconds on a monotonic clock (only differences are meaningful). */
static inline uint64_t tp_time_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000ULL + (uint64_t)ts.tv_nsec / 1000ULL;
}
/* }}} */

/* {{{ tp_sleep_us
 * Sleeps the calling thread for about us microseconds. */
static inline void tp_sleep_us(uint64_t us) {
    struct timespec ts = {
        .tv_sec = (time_t)(us / 1000000ULL),
        .tv_nsec = (long)(us % 1000000ULL) * 1000L
    };
    while (nanosleep(&ts, &ts) != 0 && errno == EINTR) {
        /* Interrupted by a signal: sleep the remainder */
    }
}
/* }}} */

/* {{{ tp_cpu_count
 * Number of online CPUs, or 0 if it cannot be found. */
static inline int tp_cpu_count(void) {
    long n = sysconf(_SC_NPROCESSORS_ONLN);
    return n > 0 ? (int)n : 0;
}
/* }}} */

/* }}} */

#endif /* THREADPOOL_PLATFORM_H */
