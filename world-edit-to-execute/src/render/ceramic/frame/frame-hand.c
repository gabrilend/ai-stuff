/*
 * frame-hand.c - the fabricated frame, by hand (issue 515h)
 *
 * What this is: the same frame as frame.map, running the very same box
 * functions (frame-boxes.c, included whole), three ways:
 *   serial    one thread, every task in order. Its frame time is the
 *             frame's total work, the yardstick for how full the cores are.
 *   systems   the usual engine shape: one parallel loop per system, in
 *             order -- simulation, fog, poses, pathfinding, culling -- with
 *             every thread meeting at a barrier after each.
 *   levels    the best a barrier design can do: everything that could run
 *             together shares one loop -- simulation; then fog, poses and
 *             pathfinding; then culling -- three barriers.
 * Within a loop, threads take the next task from a shared counter (the
 * self-balancing kind, not fixed slices).
 *
 * Between stages, threads either sleep at a barrier (systems, levels) or
 * spin at one (systems-spin, levels-spin). It matters more than it looks:
 * on a machine that lowers an idle core's clock (this one's governor idles
 * cores at 1.2 GHz), threads that sleep between stages wake on cold,
 * slow cores, and every stage's tasks run slower; spinning keeps the cores
 * busy and their clocks up, at the price of burning them while waiting. With BACKGROUND, two decodes a
 * frame go to one dedicated thread of their own, as engines usually run
 * background work; it is never waited for within a frame.
 *
 * Output: the same columns as frame-host.c.
 *
 * Usage: ./frame-hand serial|systems|levels|systems-spin|levels-spin FRAMES THREADS BACKGROUND
 */
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "frame-boxes.c"   /* the combined box file run-frame.sh builds: pose math + frame boxes */

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

/* One frame's state: every stage writes only its own slots. */
typedef struct {
    int       frame, npaths;
    sim_state sim;
    lane_out  lanes[FRAME_LANES];
    done      fogs[FRAME_PLAYERS], culls[FRAME_LANES], paths[FRAME_PATHS_MAX];
    job       path_jobs[FRAME_PATHS_MAX];
} frame_state;

/* A task in a stage's list: which kind, which one. */
enum { T_SIM, T_FOG, T_POSE, T_PATH, T_CULL };
typedef struct { int kind, index; } item;

/* {{{ static void run_item(frame_state *s, item it) */
/* One task: dispatched by kind to the same boxes the map places. */
static void run_item(frame_state *s, item it)
{
    switch (it.kind) {
    case T_SIM:  s->sim = simulate((tick){ s->frame, 12345 }); break;
    case T_FOG:  s->fogs[it.index] = fog(s->sim, it.index); break;
    case T_POSE: s->lanes[it.index] = pose_lane((lane_req){ s->frame, it.index }, s->sim); break;
    case T_PATH: s->paths[it.index] = pathfind(s->path_jobs[it.index]); break;
    case T_CULL: s->culls[it.index] = cull(s->lanes[it.index]); break;
    }
}
/* }}} */

/* THREADING { -- the parallel loop, the barrier, the background thread */
/* A stage's shared list and counter; all threads meet at `start` and
 * `done` around each stage. */
typedef struct {
    pthread_barrier_t start, done;
    frame_state *s;
    item        *items;
    int          n;
    _Atomic int  next;
    _Atomic int  quit;
    /* the spinning barrier: how many have arrived, and which round it is */
    int          spin, threads;
    _Atomic int  arrived;
    _Atomic int  round;
} stage_share;

/* {{{ static void meet(stage_share *st, pthread_barrier_t *b) */
/* Every thread waits here until all have arrived. Two ways: sleep in the
 * system's barrier, or spin on a round counter (the last to arrive starts
 * the next round), pausing between looks. */
static void meet(stage_share *st, pthread_barrier_t *b)
{
    if (!st->spin) {
        pthread_barrier_wait(b);
        return;
    }
    int round = atomic_load(&st->round);
    if (atomic_fetch_add(&st->arrived, 1) + 1 == st->threads) {
        atomic_store(&st->arrived, 0);
        atomic_store(&st->round, round + 1);
    } else {
        while (atomic_load(&st->round) == round) {
#if defined(__x86_64__) || defined(__i386__)
            __builtin_ia32_pause();
#endif
        }
    }
}
/* }}} */

/* {{{ static void take_items(stage_share *st) */
static void take_items(stage_share *st)
{
    for (;;) {
        int i = atomic_fetch_add(&st->next, 1);
        if (i >= st->n) return;
        run_item(st->s, st->items[i]);
    }
}
/* }}} */

/* {{{ static void *helper(void *arg) */
static void *helper(void *arg)
{
    stage_share *st = arg;
    for (;;) {
        meet(st, &st->start);
        if (atomic_load(&st->quit)) return NULL;
        take_items(st);
        meet(st, &st->done);
    }
}
/* }}} */

/* {{{ static void run_stage(stage_share *st, item *items, int n) */
/* One parallel loop over `items`, with every thread (this one included). */
static void run_stage(stage_share *st, item *items, int n)
{
    st->items = items;
    st->n = n;
    atomic_store(&st->next, 0);
    meet(st, &st->start);
    take_items(st);
    meet(st, &st->done);
}
/* }}} */

/* The background thread's queue of decodes: a mutex, a condition, a list. */
typedef struct {
    pthread_mutex_t lock;
    pthread_cond_t  more;
    job            *jobs;
    int             head, tail, closing;
    _Atomic int     finished;
} background_queue;

/* {{{ static void *background(void *arg) */
static void *background(void *arg)
{
    background_queue *q = arg;
    for (;;) {
        pthread_mutex_lock(&q->lock);
        while (q->head == q->tail && !q->closing) pthread_cond_wait(&q->more, &q->lock);
        if (q->head == q->tail) { pthread_mutex_unlock(&q->lock); return NULL; }
        job j = q->jobs[q->head++];
        pthread_mutex_unlock(&q->lock);
        (void)decode(j);
        atomic_fetch_add(&q->finished, 1);
    }
}
/* }}} */
/* } THREADING */

/* {{{ int main(int argc, char **argv) */
int main(int argc, char **argv)
{
    if (argc != 5 || (strcmp(argv[1], "serial") && strcmp(argv[1], "systems") && strcmp(argv[1], "levels")
                      && strcmp(argv[1], "systems-spin") && strcmp(argv[1], "levels-spin"))) {
        fprintf(stderr, "usage: %s serial|systems|levels|systems-spin|levels-spin FRAMES THREADS BACKGROUND\n", argv[0]);
        return 64;
    }
    const char *way = argv[1];
    int frames = atoi(argv[2]), threads = atoi(argv[3]), with_background = atoi(argv[4]);
    int serial = strcmp(way, "serial") == 0;
    if (serial) threads = 1;
    double *took = malloc(sizeof *took * (size_t)frames);
    frame_state *s = calloc(1, sizeof *s);
    if (!took || !s) { fprintf(stderr, "no memory\n"); return 71; }

    /* THREADING { -- start the helpers and the background thread */
    stage_share st = { .s = s, .spin = strstr(way, "-spin") != NULL, .threads = threads };
    pthread_t *ids = malloc(sizeof *ids * (size_t)threads);
    pthread_barrier_init(&st.start, NULL, (unsigned)threads);
    pthread_barrier_init(&st.done, NULL, (unsigned)threads);
    for (int i = 1; i < threads; i++) pthread_create(&ids[i], NULL, helper, &st);
    background_queue bq = { .jobs = malloc(sizeof(job) * (size_t)(frames * FRAME_DECODES + 1)) };
    pthread_mutex_init(&bq.lock, NULL);
    pthread_cond_init(&bq.more, NULL);
    pthread_t bg_id;
    if (with_background && !serial) pthread_create(&bg_id, NULL, background, &bq);
    /* } THREADING */

    item list[1 + FRAME_PLAYERS + FRAME_LANES + FRAME_PATHS_MAX];
    uint32_t check = 0;
    double total = 0;
    for (int f = 0; f < frames; f++) {
        s->frame = f;
        s->npaths = path_count(f);
        for (int i = 0; i < s->npaths; i++) s->path_jobs[i] = (job){ f, i, us_rounds(path_us(f, i)) };
        double start = now_us();

        if (with_background && !serial) {
            /* THREADING { -- two decodes to the background thread */
            pthread_mutex_lock(&bq.lock);
            for (int i = 0; i < FRAME_DECODES; i++) bq.jobs[bq.tail++] = (job){ f, i, us_rounds(DECODE_US) };
            pthread_cond_signal(&bq.more);
            pthread_mutex_unlock(&bq.lock);
            /* } THREADING */
        }

        /* Three shapes: serial runs every task here; systems runs one
         * parallel loop per system; levels one loop per dependency level. */
        int n;
        if (serial) {
            run_item(s, (item){ T_SIM, 0 });
            for (int p = 0; p < FRAME_PLAYERS; p++) run_item(s, (item){ T_FOG, p });
            for (int l = 0; l < FRAME_LANES; l++) run_item(s, (item){ T_POSE, l });
            for (int i = 0; i < s->npaths; i++) run_item(s, (item){ T_PATH, i });
            for (int l = 0; l < FRAME_LANES; l++) run_item(s, (item){ T_CULL, l });
        } else if (strncmp(way, "systems", 7) == 0) {
            list[0] = (item){ T_SIM, 0 };
            run_stage(&st, list, 1);
            for (n = 0; n < FRAME_PLAYERS; n++) list[n] = (item){ T_FOG, n };
            run_stage(&st, list, n);
            for (n = 0; n < FRAME_LANES; n++) list[n] = (item){ T_POSE, n };
            run_stage(&st, list, n);
            for (n = 0; n < s->npaths; n++) list[n] = (item){ T_PATH, n };
            run_stage(&st, list, n);
            for (n = 0; n < FRAME_LANES; n++) list[n] = (item){ T_CULL, n };
            run_stage(&st, list, n);
        } else {
            list[0] = (item){ T_SIM, 0 };
            run_stage(&st, list, 1);
            /* the level's tasks in a fixed order -- pose lanes, fog,
             * pathfinding -- with pathfinding's costs unsorted, since a
             * real engine doesn't know how long a search will take */
            n = 0;
            for (int l = 0; l < FRAME_LANES; l++) list[n++] = (item){ T_POSE, l };
            for (int p = 0; p < FRAME_PLAYERS; p++) list[n++] = (item){ T_FOG, p };
            for (int i = 0; i < s->npaths; i++) list[n++] = (item){ T_PATH, i };
            run_stage(&st, list, n);
            for (n = 0; n < FRAME_LANES; n++) list[n] = (item){ T_CULL, n };
            run_stage(&st, list, n);
        }

        took[f] = now_us() - start;
        total += took[f];
        uint32_t fc = 0;
        for (int p = 0; p < FRAME_PLAYERS; p++) fc ^= s->fogs[p].hash;
        for (int l = 0; l < FRAME_LANES; l++) fc ^= s->culls[l].hash;
        for (int i = 0; i < s->npaths; i++) fc ^= s->paths[i].hash;
        check ^= fc + (uint32_t)f;
    }

    /* THREADING { -- stop the helpers and let the background finish */
    atomic_store(&st.quit, 1);
    meet(&st, &st.start);
    for (int i = 1; i < threads; i++) pthread_join(ids[i], NULL);
    if (with_background && !serial) {
        pthread_mutex_lock(&bq.lock);
        bq.closing = 1;
        pthread_cond_signal(&bq.more);
        pthread_mutex_unlock(&bq.lock);
        pthread_join(bg_id, NULL);
    }
    /* } THREADING */

    qsort(took, (size_t)frames, sizeof *took, by_value);
#define PCT(q) took[(int)((frames - 1) * (q))]
    printf("hand-%s\t%d\t%d\t%d\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%08x\t%d\n", way, with_background && !serial, frames, threads,
           total / frames, PCT(0.50), PCT(0.95), PCT(0.99), took[frames - 1], check, atomic_load(&bq.finished));
    free(took);
    free(s);
    free(ids);
    free(bq.jobs);
    return 0;
}
/* }}} */
