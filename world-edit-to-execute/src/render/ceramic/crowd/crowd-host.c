/*
 * crowd-host.c - the crowd's tick on the ceramic engine, driven by its host (issue 515k)
 *
 * What this is: the main loop for crowd.map, on the kept engine copy. serac
 * compiles it after the engine and the map's construction code (with
 * crowd-boxes.c). Each tick the host takes the snapshot, re-arms the
 * landing for every chunk's answer, hands every chunk of units in to the
 * task queue as one batch, waits until all have landed, then settles the
 * tick and moves the armies on. The engine's workers do the deciding; the
 * host thread only waits for it, as a renderer's main thread would.
 *
 * Output: the same line as crowd-hand.c, the way named "ceramic" (or
 * "ceramic-spin" with CERAMIC_SPIN set: the engine's idle workers look at
 * the queue that many times before sleeping).
 *
 * Usage: ./crowd-ceramic SCENE TICKS WORKERS
 *   CROWD_CHUNK (default 32): units a chunk; CROWD_TIMELINE=PATH as in
 *   crowd-hand.c.
 */
#include <sched.h>

/* {{{ static void must(const char *refusal, const char *what) */
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
    if (argc != 4) { fprintf(stderr, "usage: %s SCENE TICKS WORKERS\n", argv[0]); return 64; }
    long ticks = atol(argv[2]);
    int workers = atoi(argv[3]);
    int chunk = getenv("CROWD_CHUNK") ? atoi(getenv("CROWD_CHUNK")) : 32;
    scene sc;
    crowd_now = scene_load(argv[1], &sc);
    crowd_dt = 1 / 62.5;
    int units = cr_count(crowd_now);
    int chunks = (units + chunk - 1) / chunk;
    timeline_open(getenv("CROWD_TIMELINE"), workers + 1);

    /* THREADING { -- start the engine, find its doors */
    const cera_map_build_t *program = cera_map_build_find("crowd.map");
    if (!program) { fprintf(stderr, "built without crowd.map\n"); return 70; }
    cera_map_t *m = cera_map_create_empty();
    program->build(m, 0, 0);
    cera_map_start(m, workers);
    cera_pool_submitter_register(m->pool);
    must(cera_map_bring_up(m), "the program");
    int in_at, in_p, out_at, out_p;
    if (!cera_map_argument_at(m, 0, &in_at, &in_p) || !cera_map_result_at(m, 0, &out_at, &out_p)) {
        fprintf(stderr, "crowd.map lacks its doors\n"); return 70;
    }
    cera_pool_release(m->pool);
    chunk_req *reqs = malloc((size_t)chunks * sizeof(chunk_req));
    chunk_done *dones = malloc((size_t)chunks * sizeof(chunk_done));
    for (int k = 0; k < chunks; k++) reqs[k] = (chunk_req){ k, k * chunk, (k + 1) * chunk < units ? (k + 1) * chunk : units };
    /* } THREADING */

    double *times = malloc((size_t)ticks * sizeof(double));
    crossing cross;
    crossing_start(&cross, crowd_now, &sc);
    for (long t = 1; t <= ticks; t++) {
        timeline_tick(t);
        double t0 = now_us();
        cr_tick_begin(crowd_now);
        /* THREADING { -- the tick's chunks in as one batch, then wait */
        must(cera_map_collect(m, out_at, out_p, dones, chunks, (int)sizeof(chunk_done)), "the chunks' landing");
        /* (handing in an array is one batch already) */
        must(cera_map_deliver_arguments(m, in_at, in_p, reqs, chunks, (int)sizeof(chunk_req)), "the chunks");
        while (cera_map_collected(m, out_at, out_p) < chunks) sched_yield();
        /* } THREADING */
        cr_tick_end(crowd_now, crowd_dt);
        crossing_step(&cross, crowd_now, &sc);
        times[t - 1] = (now_us() - t0) / 1000;
    }

    /* THREADING { -- stop the engine */
    cera_pool_submitter_unregister(m->pool);
    cera_pool_join(m->pool);
    cera_map_destroy(m);
    /* } THREADING */
    report(getenv("CERAMIC_SPIN") ? "ceramic-spin" : "ceramic", workers, units, ticks, times, crowd_now);
    timeline_close();
    return 0;
}
/* }}} */
