/*
 * plain.c - the benchmark's two ways without the engine (issue 515a)
 *
 * What this is: the same pose work (pose-boxes.c, included whole) done
 *   - by one thread in a plain loop: the floor, what the work itself costs;
 *   - by a hand-written parallel loop: persistent threads, one per core,
 *     each posing its own fixed slice of units per frame, meeting at a
 *     barrier. That is the shape of the 512 thread pool. Equal slices
 *     don't finish at equal times (two threads share each physical core,
 *     and the system interrupts threads), so the frame waits for the
 *     slowest;
 *   - by the same threads sharing one counter instead of fixed slices:
 *     each takes the next PER units by adding PER to the counter, until
 *     the units run out, so a slowed thread simply takes fewer. The
 *     owner's fairness question (2026-09-25); the hand-written equal of
 *     the ceramic engine's chunked tasks.
 * Same checksum as ceramic-host.c, so the script can check that all four
 * ways computed the same poses.
 *
 * Output: the analysis host's columns (analysis-host.c), so the two sides
 * line up: way, units, 0, threads, frames, mean / 50th / 95th / 99th
 * percentile / worst frame in microseconds, 0, 0, checksum. (The zeros are
 * the host's delivery and landing times, which a plain loop doesn't have.)
 *
 * Usage: ./plain plain|parallel|counter UNITS FRAMES [THREADS] [PER]
 *   THREADS: the thread count, default one per online core
 *   PER: units taken from the shared counter at a time (counter), default 32
 */
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include "pose-boxes.c"

/* {{{ static double now_us(void) */
static double now_us(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1e6 + ts.tv_nsec / 1e3;
}
/* }}} */

/* {{{ static int by_value(const void *a, const void *b) */
static int by_value(const void *a, const void *b)
{
    double x = *(const double *)a, y = *(const double *)b;
    return (x > y) - (x < y);
}
/* }}} */

/* {{{ static uint32_t fold(const void *data, size_t bytes) */
static uint32_t fold(const void *data, size_t bytes)
{
    const uint32_t *w = data;
    uint32_t x = 0;
    for (size_t i = 0; i < bytes / 4; i++) x ^= w[i];
    return x;
}
/* }}} */

/* The parallel loop's shared frame: every thread reads these after the
 * start barrier and writes only its own slice of `poses`. */
typedef struct {
    pthread_barrier_t start, done;
    pose *poses;
    int units, threads, frames;
    float time;
    int counter, per;              /* counter mode: units taken PER at a time */
    _Atomic int next;              /* counter mode: the next unit nobody has taken */
} frame_share;

typedef struct {
    frame_share *share;
    int index;
} slice_arg;

/* {{{ static void pose_slice(frame_share *s, int index) */
static void pose_slice(frame_share *s, int index)
{
    /* Two paths: the shared counter hands out the next PER units until
     * none are left; fixed slices give thread i the i-th share. */
    if (s->counter) {
        for (;;) {
            int from = atomic_fetch_add(&s->next, s->per);
            if (from >= s->units) return;
            int to = from + s->per < s->units ? from + s->per : s->units;
            for (int u = from; u < to; u++) pose_into(u, s->time, &s->poses[u]);
        }
    }
    int per = (s->units + s->threads - 1) / s->threads;
    int from = index * per, to = from + per < s->units ? from + per : s->units;
    for (int u = from; u < to; u++) pose_into(u, s->time, &s->poses[u]);
}
/* }}} */

/* {{{ static void *slice_thread(void *arg) */
static void *slice_thread(void *arg)
{
    slice_arg *a = arg;
    for (int f = 0; f < a->share->frames; f++) {
        pthread_barrier_wait(&a->share->start);
        pose_slice(a->share, a->index);
        pthread_barrier_wait(&a->share->done);
    }
    return NULL;
}
/* }}} */

/* {{{ int main(int argc, char **argv) */
int main(int argc, char **argv)
{
    if (argc < 4 || argc > 6 || (strcmp(argv[1], "plain") != 0 && strcmp(argv[1], "parallel") != 0 && strcmp(argv[1], "counter") != 0)) {
        fprintf(stderr, "usage: %s plain|parallel|counter UNITS FRAMES [THREADS] [PER]\n", argv[0]);
        return 64;
    }
    int counter = strcmp(argv[1], "counter") == 0;
    int parallel = counter || strcmp(argv[1], "parallel") == 0;
    int per_take = argc == 6 ? atoi(argv[5]) : 32;
    if (per_take < 1) { fprintf(stderr, "PER must be at least 1\n"); return 64; }
    int units = atoi(argv[2]), frames = atoi(argv[3]);
    pose *poses = malloc((size_t)units * sizeof(pose));
    double *took = malloc(sizeof *took * (size_t)frames);
    if (!poses || !took) { fprintf(stderr, "no memory for %d poses\n", units); return 71; }

    long cores = sysconf(_SC_NPROCESSORS_ONLN);
    int threads = parallel ? (argc >= 5 ? atoi(argv[4]) : (cores > 0 ? (int)cores : 1)) : 1;
    if (threads < 1) { fprintf(stderr, "threads must be at least 1\n"); return 64; }
    frame_share share = { .poses = poses, .units = units, .threads = threads, .frames = frames,
                          .counter = counter, .per = per_take };
    pthread_t *ids = NULL;
    slice_arg *args = NULL;
    if (parallel) {
        /* the main thread is slice 0; threads-1 helpers take the rest */
        pthread_barrier_init(&share.start, NULL, (unsigned)threads);
        pthread_barrier_init(&share.done, NULL, (unsigned)threads);
        ids = malloc(sizeof *ids * (size_t)threads);
        args = malloc(sizeof *args * (size_t)threads);
        for (int i = 1; i < threads; i++) {
            args[i] = (slice_arg){ &share, i };
            pthread_create(&ids[i], NULL, slice_thread, &args[i]);
        }
    }

    uint32_t check = 0;
    double total = 0;
    for (int f = 0; f < frames; f++) {
        float t = (float)f / 60.0f;
        double start = now_us();
        if (parallel) {
            share.time = t;
            atomic_store(&share.next, 0);       /* a fresh count every frame */
            pthread_barrier_wait(&share.start);
            pose_slice(&share, 0);
            pthread_barrier_wait(&share.done);
        } else {
            for (int u = 0; u < units; u++) pose_into(u, t, &poses[u]);
        }
        took[f] = now_us() - start;
        total += took[f];
        check ^= fold(poses, (size_t)units * sizeof(pose)) + (uint32_t)f;
    }

    if (parallel) {
        for (int i = 1; i < threads; i++) pthread_join(ids[i], NULL);
        free(ids);
        free(args);
    }
    qsort(took, (size_t)frames, sizeof *took, by_value);
#define PCT(q) took[(int)((frames - 1) * (q))]
    printf("%s\t%d\t%d\t%d\t%d\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t0\t0\t%08x\n",
           counter ? "counter-loop" : parallel ? "parallel-loop" : "plain-loop", units, counter ? per_take : 0, threads, frames, total / frames, PCT(0.50), PCT(0.95), PCT(0.99), took[frames - 1], check);
    free(poses);
    free(took);
    return 0;
}
/* }}} */
