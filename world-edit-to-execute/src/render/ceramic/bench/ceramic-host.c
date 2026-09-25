/*
 * ceramic-host.c - the benchmark's host, for the two ceramic ways (issue 515a)
 *
 * What this is: the main loop a renderer's host would run, doing only the
 * pose work, so the engine's cost can be timed. serac compiles it after the
 * engine and the construction code of one map (per-unit.map or
 * per-chunk.map), and it finds out which one it was built with.
 *
 * Each frame, like the renderer will: point collection at the frame's
 * landing array, deliver the frame's requests (one per unit, or one per 64
 * units), wait until every result has landed, fold the results into a
 * checksum. One frame in flight: collection is re-armed only after the
 * whole previous frame has landed, which is the one moment no task can
 * still be writing into the old array.
 *
 * Output (one line): way, units, frames, workers, mean and best frame time
 * in microseconds, the checksum. The script compares checksums across ways.
 *
 * Usage: ./per-unit UNITS FRAMES   (./per-chunk the same)
 */
#include <sched.h>
#include <stdint.h>
#include <time.h>
#include <unistd.h>

/* {{{ static double now_us(void) */
static double now_us(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1e6 + ts.tv_nsec / 1e3;
}
/* }}} */

/* {{{ static uint32_t fold(const void *data, size_t bytes) */
/* Every 32-bit word XORed together: exact, and blind to the order results
 * arrive in (they arrive in whatever order workers finish). */
static uint32_t fold(const void *data, size_t bytes)
{
    const uint32_t *w = data;
    uint32_t x = 0;
    for (size_t i = 0; i < bytes / 4; i++) x ^= w[i];
    return x;
}
/* }}} */

/* {{{ static void must(const char *refusal, const char *what) */
/* The engine answers NULL when it takes something, or a sentence saying why
 * not; a refusal ends the benchmark (no fallbacks). */
static void must(const char *refusal, const char *what)
{
    if (refusal) {
        fprintf(stderr, "refused %s: %s\n", what, refusal);
        exit(1);
    }
}
/* }}} */

/* {{{ int main(int argc, char **argv) */
int main(int argc, char **argv)
{
    if (argc != 3) {
        fprintf(stderr, "usage: %s UNITS FRAMES\n", argv[0]);
        return 64;
    }
    int units = atoi(argv[1]), frames = atoi(argv[2]);

    /* Which map this program carries decides the way. */
    const cera_map_build_t *program = cera_map_build_find("per-unit.map");
    int per_chunk = 0;
    if (!program) {
        program = cera_map_build_find("per-chunk.map");
        per_chunk = 1;
    }
    if (!program) {
        fprintf(stderr, "built with neither per-unit.map nor per-chunk.map\n");
        return 70;
    }
    if (per_chunk && units % CHUNK_UNITS != 0) {
        fprintf(stderr, "units must be a multiple of %d for chunks\n", CHUNK_UNITS);
        return 64;
    }

    cera_map_t *m = cera_map_create_empty();
    program->build(m, 0, 0);

    /* One worker per core but one: the host thread is the last core, as the
     * raylib main thread will be. */
    long cores = sysconf(_SC_NPROCESSORS_ONLN);
    int workers = cores > 1 ? (int)cores - 1 : 1;
    cera_map_start(m, workers);
    cera_pool_submitter_register(m->pool);
    must(cera_map_bring_up(m), "the program");

    int in_at, in_port, out_at, out_port;
    if (!cera_map_argument_at(m, 0, &in_at, &in_port) || !cera_map_result_at(m, 0, &out_at, &out_port)) {
        fprintf(stderr, "the map has no argument 0 or no result 0\n");
        return 70;
    }

    /* The landing array for one frame: a pose per unit either way. */
    int per_frame = per_chunk ? units / CHUNK_UNITS : units;
    size_t elem = per_chunk ? sizeof(chunk_pose) : sizeof(pose);
    char *landing = malloc((size_t)per_frame * elem);
    if (!landing) { fprintf(stderr, "no memory for %d results\n", per_frame); return 71; }

    must(cera_map_collect(m, out_at, out_port, landing, per_frame, (int)elem), "the first frame's landing");
    cera_pool_release(m->pool);

    uint32_t check = 0;
    double total = 0, best = 1e18;
    for (int f = 0; f < frames; f++) {
        float t = (float)f / 60.0f;
        double start = now_us();
        /* re-armed only now: the whole previous frame has landed */
        if (f > 0) must(cera_map_collect(m, out_at, out_port, landing, per_frame, (int)elem), "a frame's landing");
        if (per_chunk) {
            for (int c = 0; c < per_frame; c++) {
                chunk_request r = { c * CHUNK_UNITS, t };
                must(cera_map_deliver_argument(m, in_at, in_port, &r, sizeof r), "a chunk request");
            }
        } else {
            for (int u = 0; u < units; u++) {
                pose_request r = { u, t };
                must(cera_map_deliver_argument(m, in_at, in_port, &r, sizeof r), "a unit request");
            }
        }
        /* The host has nothing else to do in a benchmark, so it waits by
         * yielding; the renderer's host would be drawing the last frame. */
        while (cera_map_collected(m, out_at, out_port) < per_frame) sched_yield();
        double took = now_us() - start;
        total += took;
        if (took < best) best = took;
        check ^= fold(landing, (size_t)per_frame * elem) + (uint32_t)f;
    }

    cera_pool_submitter_unregister(m->pool);
    cera_pool_join(m->pool);
    printf("%s\t%d\t%d\t%d\t%.1f\t%.1f\t%08x\n", per_chunk ? "ceramic-per-chunk" : "ceramic-per-unit",
           units, frames, workers, total / frames, best, check);
    free(landing);
    cera_map_destroy(m);
    return 0;
}
/* }}} */
