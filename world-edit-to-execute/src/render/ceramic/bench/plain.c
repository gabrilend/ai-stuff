/*
 * plain.c - the benchmark's two ways without the engine (issue 515a)
 *
 * What this is: the same pose work (pose-boxes.c, included whole) done
 *   - by one thread in a plain loop: the floor, what the work itself costs;
 *   - by a hand-written parallel loop: persistent threads, one per core,
 *     each posing its own slice of units per frame, meeting at a barrier.
 *     That is the shape of the 512 thread pool, and the thing the ceramic
 *     ways have to match.
 * Same checksum as ceramic-host.c, so the script can check that all four
 * ways computed the same poses.
 *
 * Usage: ./plain plain|parallel UNITS FRAMES
 */
#include <pthread.h>
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
} frame_share;

typedef struct {
    frame_share *share;
    int index;
} slice_arg;

/* {{{ static void pose_slice(frame_share *s, int index) */
static void pose_slice(frame_share *s, int index)
{
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
    if (argc != 4 || (strcmp(argv[1], "plain") != 0 && strcmp(argv[1], "parallel") != 0)) {
        fprintf(stderr, "usage: %s plain|parallel UNITS FRAMES\n", argv[0]);
        return 64;
    }
    int parallel = strcmp(argv[1], "parallel") == 0;
    int units = atoi(argv[2]), frames = atoi(argv[3]);
    pose *poses = malloc((size_t)units * sizeof(pose));
    if (!poses) { fprintf(stderr, "no memory for %d poses\n", units); return 71; }

    long cores = sysconf(_SC_NPROCESSORS_ONLN);
    int threads = parallel ? (cores > 0 ? (int)cores : 1) : 1;
    frame_share share = { .poses = poses, .units = units, .threads = threads, .frames = frames };
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
    double total = 0, best = 1e18;
    for (int f = 0; f < frames; f++) {
        float t = (float)f / 60.0f;
        double start = now_us();
        if (parallel) {
            share.time = t;
            pthread_barrier_wait(&share.start);
            pose_slice(&share, 0);
            pthread_barrier_wait(&share.done);
        } else {
            for (int u = 0; u < units; u++) pose_into(u, t, &poses[u]);
        }
        double took = now_us() - start;
        total += took;
        if (took < best) best = took;
        check ^= fold(poses, (size_t)units * sizeof(pose)) + (uint32_t)f;
    }

    if (parallel) {
        for (int i = 1; i < threads; i++) pthread_join(ids[i], NULL);
        free(ids);
        free(args);
    }
    printf("%s\t%d\t%d\t%d\t%.1f\t%.1f\t%08x\n", parallel ? "parallel-loop" : "plain-loop",
           units, frames, threads, total / frames, best, check);
    free(poses);
    return 0;
}
/* }}} */
