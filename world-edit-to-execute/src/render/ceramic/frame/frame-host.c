/*
 * frame-host.c - the fabricated frame as a ceramic map, driven by its host (issue 515h)
 *
 * What this is: the renderer's main loop for frame.map, on the kept engine
 * copy (issue 515g). serac compiles it after the engine and the map's
 * construction code. Each frame the host opens one batch and hands the
 * whole frame in to the task queue at once -- the tick, the eight lanes'
 * requests, the frame's pathfinding requests and (when asked) two
 * background decodes -- then waits until fog, culling and pathfinding have
 * all landed. The map decides everything else: the simulation's answer
 * fans out to fog and poses, each lane's culling starts when its poses
 * land. Background decodes are never waited for within a frame.
 *
 * The count of landed answers is trusted as it is (the kept copy counts
 * after the copy). Every answer's frame number is checked against the
 * frame being waited for, so an answer from the wrong frame stops the run.
 *
 * Output (one tab-separated line): way, background (0/1), frames, workers,
 * mean / 50th / 95th / 99th percentile / worst frame in microseconds, the
 * checksum, background decodes finished by the end.
 *
 * Usage: ./frame-ceramic FRAMES WORKERS BACKGROUND
 *   With CERAMIC_SPIN set, the engine's idle workers look at the task queue
 *   that many times before sleeping, and the way is reported as
 *   "ceramic-graph-spin" (see frame-hand.c on why spinning matters here).
 */
#include <sched.h>
#include <stdint.h>
#include <time.h>

/* {{{ static double now_us(void) */
static double now_us(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1e6 + ts.tv_nsec / 1e3;
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

/* {{{ static void port(cera_map_t *m, int nth, int result, int *at, int *p) */
/* Where the nth marked argument or result is; the map's doors are fixed
 * (frame-gen.lua), so a missing one is a build that doesn't match. */
static void port(cera_map_t *m, int nth, int result, int *at, int *p)
{
    int found = result ? cera_map_result_at(m, nth, at, p) : cera_map_argument_at(m, nth, at, p);
    if (!found) {
        fprintf(stderr, "frame.map has no %s %d\n", result ? "result" : "argument", nth);
        exit(70);
    }
}
/* }}} */

/* {{{ static void check_frame(const done *d, int frame, const char *what) */
static void check_frame(const done *d, int frame, const char *what)
{
    if (d->frame != frame) {
        fprintf(stderr, "a %s answer for frame %d arrived while frame %d was being waited for\n", what, d->frame, frame);
        exit(1);
    }
}
/* }}} */

/* {{{ int main(int argc, char **argv) */
int main(int argc, char **argv)
{
    if (argc != 4) {
        fprintf(stderr, "usage: %s FRAMES WORKERS BACKGROUND\n", argv[0]);
        return 64;
    }
    int frames = atoi(argv[1]), workers = atoi(argv[2]), background = atoi(argv[3]);

    /* THREADING { -- everything from here to the frame loop is the engine's setup */
    const cera_map_build_t *program = cera_map_build_find("frame.map");
    if (!program) { fprintf(stderr, "built without frame.map\n"); return 70; }
    cera_map_t *m = cera_map_create_empty();
    program->build(m, 0, 0);
    cera_map_start(m, workers);
    cera_pool_submitter_register(m->pool);
    must(cera_map_bring_up(m), "the program");

    int tick_at, tick_p, lane_at[FRAME_LANES], lane_p[FRAME_LANES], path_at, path_p, dec_at, dec_p;
    int fog_at[FRAME_PLAYERS], fog_p[FRAME_PLAYERS], cull_at[FRAME_LANES], cull_p[FRAME_LANES];
    int pathr_at, pathr_p, decr_at, decr_p;
    port(m, 0, 0, &tick_at, &tick_p);
    for (int l = 0; l < FRAME_LANES; l++) port(m, 1 + l, 0, &lane_at[l], &lane_p[l]);
    port(m, 1 + FRAME_LANES, 0, &path_at, &path_p);
    port(m, 2 + FRAME_LANES, 0, &dec_at, &dec_p);
    for (int p = 0; p < FRAME_PLAYERS; p++) port(m, p, 1, &fog_at[p], &fog_p[p]);
    for (int l = 0; l < FRAME_LANES; l++) port(m, FRAME_PLAYERS + l, 1, &cull_at[l], &cull_p[l]);
    port(m, FRAME_PLAYERS + FRAME_LANES, 1, &pathr_at, &pathr_p);
    port(m, FRAME_PLAYERS + FRAME_LANES + 1, 1, &decr_at, &decr_p);

    static done fog_in[FRAME_PLAYERS], cull_in[FRAME_LANES], path_in[FRAME_PATHS_MAX];
    done *dec_in = malloc(sizeof *dec_in * (size_t)(frames * FRAME_DECODES + 1));
    double *took = malloc(sizeof *took * (size_t)frames);
    if (!dec_in || !took) { fprintf(stderr, "no memory\n"); return 71; }
    /* decodes land across frames: one array for the whole run, never re-armed */
    must(cera_map_collect(m, decr_at, decr_p, dec_in, frames * FRAME_DECODES + 1, (int)sizeof(done)), "the decodes' landing");
    for (int p = 0; p < FRAME_PLAYERS; p++) must(cera_map_collect(m, fog_at[p], fog_p[p], &fog_in[p], 1, (int)sizeof(done)), "fog's landing");
    for (int l = 0; l < FRAME_LANES; l++) must(cera_map_collect(m, cull_at[l], cull_p[l], &cull_in[l], 1, (int)sizeof(done)), "culling's landing");
    must(cera_map_collect(m, pathr_at, pathr_p, path_in, FRAME_PATHS_MAX, (int)sizeof(done)), "pathfinding's landing");
    cera_pool_release(m->pool);
    /* } THREADING */

    uint32_t check = 0;
    double total = 0;
    job paths[FRAME_PATHS_MAX], decodes[FRAME_DECODES];
    for (int f = 0; f < frames; f++) {
        int np = path_count(f);
        for (int i = 0; i < np; i++) paths[i] = (job){ f, i, us_rounds(path_us(f, i)) };
        for (int i = 0; i < FRAME_DECODES; i++) decodes[i] = (job){ f, i, us_rounds(DECODE_US) };
        double start = now_us();

        /* THREADING { -- a frame: re-arm, hand it all in as one batch, wait */
        if (f > 0) {
            /* re-armed only now: the whole previous frame has landed */
            for (int p = 0; p < FRAME_PLAYERS; p++) must(cera_map_collect(m, fog_at[p], fog_p[p], &fog_in[p], 1, (int)sizeof(done)), "fog's landing");
            for (int l = 0; l < FRAME_LANES; l++) must(cera_map_collect(m, cull_at[l], cull_p[l], &cull_in[l], 1, (int)sizeof(done)), "culling's landing");
            must(cera_map_collect(m, pathr_at, pathr_p, path_in, FRAME_PATHS_MAX, (int)sizeof(done)), "pathfinding's landing");
        }
        cera_pool_batch_begin(m->pool);
        tick tk = { f, 12345 };
        must(cera_map_deliver_argument(m, tick_at, tick_p, &tk, sizeof tk), "the tick");
        for (int l = 0; l < FRAME_LANES; l++) {
            lane_req r = { f, l };
            must(cera_map_deliver_argument(m, lane_at[l], lane_p[l], &r, sizeof r), "a lane's request");
        }
        for (int i = 0; i < np; i++) must(cera_map_deliver_argument(m, path_at, path_p, &paths[i], sizeof paths[i]), "a pathfinding request");
        if (background)
            for (int i = 0; i < FRAME_DECODES; i++) must(cera_map_deliver_argument(m, dec_at, dec_p, &decodes[i], sizeof decodes[i]), "a decode");
        cera_pool_batch_end(m->pool);

        for (;;) {
            int all_in = cera_map_collected(m, pathr_at, pathr_p) >= np;
            for (int p = 0; p < FRAME_PLAYERS && all_in; p++) all_in = cera_map_collected(m, fog_at[p], fog_p[p]) >= 1;
            for (int l = 0; l < FRAME_LANES && all_in; l++) all_in = cera_map_collected(m, cull_at[l], cull_p[l]) >= 1;
            if (all_in) break;
            sched_yield();
        }
        /* } THREADING */

        took[f] = now_us() - start;
        total += took[f];
        uint32_t fc = 0;
        for (int p = 0; p < FRAME_PLAYERS; p++) { check_frame(&fog_in[p], f, "fog"); fc ^= fog_in[p].hash; }
        for (int l = 0; l < FRAME_LANES; l++) { check_frame(&cull_in[l], f, "culling"); fc ^= cull_in[l].hash; }
        for (int i = 0; i < np; i++) { check_frame(&path_in[i], f, "pathfinding"); fc ^= path_in[i].hash; }
        check ^= fc + (uint32_t)f;
    }

    /* The background's tail: wait for the last decodes, so the count is final. */
    if (background)
        while (cera_map_collected(m, decr_at, decr_p) < frames * FRAME_DECODES) sched_yield();
    int decoded = cera_map_collected(m, decr_at, decr_p);

    qsort(took, (size_t)frames, sizeof *took, by_value);
#define PCT(q) took[(int)((frames - 1) * (q))]
    const char *spin = getenv("CERAMIC_SPIN");
    printf("%s\t%d\t%d\t%d\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%08x\t%d\n",
           spin && atoi(spin) > 0 ? "ceramic-graph-spin" : "ceramic-graph", background, frames, workers,
           total / frames, PCT(0.50), PCT(0.95), PCT(0.99), took[frames - 1], check, decoded);
    cera_pool_submitter_unregister(m->pool);
    cera_pool_join(m->pool);
    free(dec_in);
    free(took);
    cera_map_destroy(m);
    return 0;
}
/* }}} */
