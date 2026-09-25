/*
 * analysis-host.c - the performance analysis's host (issue 515a)
 *
 * What this is: a renderer's main loop doing only the measured work, for any
 * one variant of the analysis map (analysis-gen.lua writes both). Each
 * frame: point collection at the frame's landing array, deliver the frame's
 * requests, wait until every result has fully landed, fold the results into
 * a checksum. Every frame is timed, and so is the part of it the host spends
 * delivering requests, since the host is one thread and delivery is serial.
 *
 * "Fully landed", correctly: the engine's count of collected results rises
 * when a result's slot is reserved, before its bytes are copied in (a bug,
 * recorded in issue 515a for soramech). So after the count is reached, the
 * host waits out every worker that was mid-task at that moment. A worker's
 * epoch is odd while it is inside a task, and the task includes the result
 * copy; once each odd epoch has moved on, every result counted has been
 * copied in. It waits only on tasks actually running, so it costs about
 * the length of the last copy.
 *
 * Output (one tab-separated line): variant, units, units per task, workers,
 * frames, then per-frame microseconds (mean, 50th / 95th / 99th percentile,
 * worst), the mean time delivering, the mean landing wait, the checksum.
 *
 * Usage: ./analysis VARIANT UNITS FRAMES WORKERS
 */
#include <sched.h>
#include <stdint.h>
#include <time.h>
#include <unistd.h>

enum { REQ_UNIT, REQ_CHUNK };
enum { RES_NONE, RES_FOLD, RES_POSE };

/* One variant: its box's name, what it takes, what it gives back, how many
 * units one task covers, and its result's size in bytes. */
typedef struct {
    const char *name;
    int request, result, per;
    size_t size;
} variant;

/* @@VARIANT-TABLE@@ */

/* {{{ static double now_us(void) */
static double now_us(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1e6 + ts.tv_nsec / 1e3;
}
/* }}} */

/* {{{ static uint32_t fold_bytes(const void *data, size_t bytes) */
static uint32_t fold_bytes(const void *data, size_t bytes)
{
    const uint32_t *w = data;
    uint32_t x = 0;
    for (size_t i = 0; i < bytes / 4; i++) x ^= w[i];
    return x;
}
/* }}} */

/* {{{ static void must(const char *refusal, const char *what) */
static void must(const char *refusal, const char *what)
{
    if (refusal) {
        fprintf(stderr, "refused %s: %s\n", what, refusal);
        exit(1);
    }
}
/* }}} */

/* {{{ static int by_value(const void *a, const void *b) */
static int by_value(const void *a, const void *b)
{
    double x = *(const double *)a, y = *(const double *)b;
    return (x > y) - (x < y);
}
/* }}} */

/* {{{ static void wait_until_landed(cera_pool_t *pool, int workers) */
/* Waits out every worker that is inside a task now (see the header). */
static void wait_until_landed(cera_pool_t *pool, int workers)
{
    uint64_t seen[256];
    for (int w = 0; w < workers; w++) seen[w] = cera_pool_worker_epoch(pool, w);
    for (int w = 0; w < workers; w++)
        if (seen[w] & 1)
            while (cera_pool_worker_epoch(pool, w) == seen[w]) sched_yield();
}
/* }}} */

/* {{{ int main(int argc, char **argv) */
int main(int argc, char **argv)
{
    if (argc != 5) {
        fprintf(stderr, "usage: %s VARIANT UNITS FRAMES WORKERS\n", argv[0]);
        return 64;
    }
    int units = atoi(argv[2]), frames = atoi(argv[3]), workers = atoi(argv[4]);
    int vi = -1;
    for (int i = 0; i < N_VARIANTS; i++)
        if (strcmp(VARIANTS[i].name, argv[1]) == 0) vi = i;
    if (vi < 0) { fprintf(stderr, "no variant named %s\n", argv[1]); return 64; }
    const variant *v = &VARIANTS[vi];
    if (units % v->per != 0) { fprintf(stderr, "units must be a multiple of %d\n", v->per); return 64; }
    if (workers < 1 || workers > 256) { fprintf(stderr, "workers must be 1..256\n"); return 64; }

    const cera_map_build_t *program = cera_map_build_find("analysis.map");
    if (!program) { fprintf(stderr, "built without analysis.map\n"); return 70; }
    cera_map_t *m = cera_map_create_empty();
    program->build(m, 0, 0);
    cera_map_start(m, workers);
    cera_pool_submitter_register(m->pool);
    must(cera_map_bring_up(m), "the program");

    int in_at, in_port, out_at, out_port;
    if (!cera_map_argument_at(m, vi, &in_at, &in_port) || !cera_map_result_at(m, vi, &out_at, &out_port)) {
        fprintf(stderr, "the map has no argument or result %d\n", vi);
        return 70;
    }
    int per_frame = units / v->per;
    char *landing = malloc((size_t)per_frame * v->size);
    double *took = malloc(sizeof *took * (size_t)frames);
    if (!landing || !took) { fprintf(stderr, "no memory\n"); return 71; }
    must(cera_map_collect(m, out_at, out_port, landing, per_frame, (int)v->size), "the landing");
    cera_pool_release(m->pool);

    uint32_t check = 0;
    double delivering = 0, landing_wait = 0;
    for (int f = 0; f < frames; f++) {
        float t = (float)f / 60.0f;
        double start = now_us();
        /* re-armed only now: the whole previous frame has landed */
        if (f > 0) must(cera_map_collect(m, out_at, out_port, landing, per_frame, (int)v->size), "a frame's landing");
        for (int i = 0; i < per_frame; i++) {
            if (v->request == REQ_UNIT) {
                pose_request r = { i, t };
                must(cera_map_deliver_argument(m, in_at, in_port, &r, sizeof r), "a request");
            } else {
                chunk_request r = { i * v->per, t };
                must(cera_map_deliver_argument(m, in_at, in_port, &r, sizeof r), "a request");
            }
        }
        double delivered = now_us();
        while (cera_map_collected(m, out_at, out_port) < per_frame) sched_yield();
        double counted = now_us();
        wait_until_landed(m->pool, workers);
        double end = now_us();
        took[f] = end - start;
        delivering += delivered - start;
        landing_wait += end - counted;

        uint32_t frame_check = 0;
        if (v->result == RES_FOLD)
            for (int i = 0; i < per_frame; i++) frame_check ^= ((uint32_t *)landing)[i];
        else if (v->result == RES_POSE)
            frame_check = fold_bytes(landing, (size_t)per_frame * v->size);
        check ^= frame_check + (uint32_t)f;
    }

    double total = 0;
    for (int f = 0; f < frames; f++) total += took[f];
    qsort(took, (size_t)frames, sizeof *took, by_value);
#define PCT(q) took[(int)((frames - 1) * (q))]
    printf("%s\t%d\t%d\t%d\t%d\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%08x\n", v->name, units, v->per, workers, frames,
           total / frames, PCT(0.50), PCT(0.95), PCT(0.99), took[frames - 1], delivering / frames, landing_wait / frames,
           v->result == RES_NONE ? 0u : check);
    cera_pool_submitter_unregister(m->pool);
    cera_pool_join(m->pool);
    free(landing);
    free(took);
    cera_map_destroy(m);
    return 0;
}
/* }}} */
