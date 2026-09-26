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
 * Two stronger ways (issue 515j):
 *   jobs      a hand-written job system, the design shipping engines use:
 *             every task is a job with a count of unfinished inputs;
 *             finishing one releases its dependents onto the finishing
 *             thread's own queue; idle threads steal from the others, then
 *             spin, then sleep; the frame ends when nothing is outstanding.
 *             It does what the ceramic graph does, by hand, for this frame.
 *   systems-hybrid, levels-hybrid   the barrier ways, with threads that spin
 *             for SPIN_US at a barrier and then sleep.
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
 * Usage: ./frame-hand serial|systems|levels|systems-spin|levels-spin|systems-hybrid|levels-hybrid|jobs FRAMES THREADS BACKGROUND
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
    /* the spinning barrier: how many have arrived, and which round it is;
     * spin is 0 (sleep), 1 (spin) or 2 (spin, then sleep) */
    int          spin, threads;
    _Atomic int  arrived;
    _Atomic int  round;
    /* the hybrid barrier's sleepers */
    pthread_mutex_t nap_lock;
    pthread_cond_t  nap;
    _Atomic int     napping;
} stage_share;

/* How long a hybrid wait spins before it sleeps, in microseconds: long
 * enough to cover the short gaps inside a frame, short enough not to burn a
 * core through the long ones. FRAME_SPIN_US overrides the default, so the
 * opponents can be given their best setting rather than a guess. */
static double SPIN_US = 50;

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
        /* hybrid: wake whoever gave up spinning and went to sleep */
        if (st->spin == 2 && atomic_load(&st->napping) > 0) {
            pthread_mutex_lock(&st->nap_lock);
            pthread_cond_broadcast(&st->nap);
            pthread_mutex_unlock(&st->nap_lock);
        }
    } else {
        double until = st->spin == 2 ? now_us() + SPIN_US : 1e300;
        while (atomic_load(&st->round) == round) {
#if defined(__x86_64__) || defined(__i386__)
            __builtin_ia32_pause();
#endif
            if (now_us() > until) {
                /* hybrid: spun long enough; sleep until the round moves.
                 * napping is raised before the round is checked again under
                 * the lock, and the last to arrive moves the round before it
                 * reads napping, so one of the two always sees the other. */
                pthread_mutex_lock(&st->nap_lock);
                atomic_fetch_add(&st->napping, 1);
                while (atomic_load(&st->round) == round) pthread_cond_wait(&st->nap, &st->nap_lock);
                atomic_fetch_sub(&st->napping, 1);
                pthread_mutex_unlock(&st->nap_lock);
            }
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

/* The job system (issue 515j). Job numbers: the simulation 0, fog 1..4,
 * pose lanes 5..12, culling 13..20, pathfinding 21 onward. */
#define J_SIM 0
#define J_FOG (J_SIM + 1)
#define J_POSE (J_FOG + FRAME_PLAYERS)
#define J_CULL (J_POSE + FRAME_LANES)
#define J_PATH (J_CULL + FRAME_LANES)
#define JOBS_MAX (J_PATH + FRAME_PATHS_MAX)

typedef struct {
    item        what;
    _Atomic int waiting;                            /* unfinished inputs */
    int         n_next, next[FRAME_PLAYERS + FRAME_LANES];   /* who it releases */
} frame_job;

/* One thread's queue: its own jobs pop from the back, thieves take from
 * the front. A spin lock each; the lists are a few dozen jobs long. */
typedef struct {
    atomic_flag lock;
    int         jobs[JOBS_MAX], head, tail;
    char        pad[64];
} job_queue;

typedef struct {
    frame_state *s;
    frame_job    job[JOBS_MAX];
    int          n_jobs;
    job_queue   *queues;
    int          threads;
    _Atomic int  outstanding;
    _Atomic int  quit;
    pthread_mutex_t nap_lock;
    pthread_cond_t  nap;
    _Atomic int     napping;
} job_share;

static void queue_lock(job_queue *q) { while (atomic_flag_test_and_set_explicit(&q->lock, memory_order_acquire)) {} }
static void queue_unlock(job_queue *q) { atomic_flag_clear_explicit(&q->lock, memory_order_release); }

/* {{{ static void job_push(job_share *js, int self, int j) */
/* A job ready to run: onto this thread's own queue, and wake a sleeper if
 * there is one (the push is published before napping is read). */
static void job_push(job_share *js, int self, int j)
{
    job_queue *q = &js->queues[self];
    queue_lock(q);
    q->jobs[q->tail++] = j;
    queue_unlock(q);
    atomic_thread_fence(memory_order_seq_cst);
    if (atomic_load(&js->napping) > 0) {
        pthread_mutex_lock(&js->nap_lock);
        pthread_cond_signal(&js->nap);
        pthread_mutex_unlock(&js->nap_lock);
    }
}
/* }}} */

/* {{{ static int job_take(job_share *js, int self) */
/* The newest job on this thread's own queue, else the oldest on another's
 * (stealing, starting from the next thread along), else -1. */
static int job_take(job_share *js, int self)
{
    job_queue *q = &js->queues[self];
    int j = -1;
    queue_lock(q);
    if (q->tail > q->head) j = q->jobs[--q->tail];
    queue_unlock(q);
    for (int k = 1; j < 0 && k < js->threads; k++) {
        job_queue *v = &js->queues[(self + k) % js->threads];
        /* Always under the lock: an unlocked glance at head and tail first
         * would be cheaper, and is a data race. */
        queue_lock(v);
        if (v->tail > v->head) j = v->jobs[v->head++];
        queue_unlock(v);
    }
    return j;
}
/* }}} */

/* {{{ static void job_run(job_share *js, int self, int j) */
/* Run one job, release the jobs waiting on it, and count it done. */
static void job_run(job_share *js, int self, int j)
{
    frame_job *fj = &js->job[j];
    run_item(js->s, fj->what);
    for (int i = 0; i < fj->n_next; i++)
        if (atomic_fetch_sub(&js->job[fj->next[i]].waiting, 1) == 1) job_push(js, self, fj->next[i]);
    atomic_fetch_sub(&js->outstanding, 1);
}
/* }}} */

/* {{{ static int anything_queued(job_share *js) */
static int anything_queued(job_share *js)
{
    for (int t = 0; t < js->threads; t++) {
        job_queue *q = &js->queues[t];
        queue_lock(q);
        int some = q->tail > q->head;
        queue_unlock(q);
        if (some) return 1;
    }
    return 0;
}
/* }}} */

typedef struct { job_share *js; int self; } job_worker_arg;

/* {{{ static void *job_worker(void *arg) */
/* A helper: take, steal, run; with nothing to take, spin SPIN_US, then
 * sleep until a push wakes it. */
static void *job_worker(void *arg)
{
    job_worker_arg *a = arg;
    job_share *js = a->js;
    for (;;) {
        if (atomic_load(&js->quit)) return NULL;
        int j = job_take(js, a->self);
        if (j >= 0) { job_run(js, a->self, j); continue; }
        double until = now_us() + SPIN_US;
        while (j < 0 && now_us() < until && !atomic_load(&js->quit)) {
#if defined(__x86_64__) || defined(__i386__)
            __builtin_ia32_pause();
#endif
            j = job_take(js, a->self);
        }
        if (j >= 0) { job_run(js, a->self, j); continue; }
        pthread_mutex_lock(&js->nap_lock);
        atomic_fetch_add(&js->napping, 1);
        if (!anything_queued(js) && !atomic_load(&js->quit)) pthread_cond_wait(&js->nap, &js->nap_lock);
        atomic_fetch_sub(&js->napping, 1);
        pthread_mutex_unlock(&js->nap_lock);
    }
}
/* }}} */

/* {{{ static void jobs_frame(job_share *js) */
/* One frame: reset every job's count and links, hand the simulation and
 * the pathfinding to the main thread's own queue, and work alongside the
 * helpers until nothing is outstanding. */
static void jobs_frame(job_share *js)
{
    frame_state *s = js->s;
    js->n_jobs = J_PATH + s->npaths;
    js->job[J_SIM] = (frame_job){ { T_SIM, 0 }, 0, 0, { 0 } };
    for (int p = 0; p < FRAME_PLAYERS; p++) {
        js->job[J_FOG + p] = (frame_job){ { T_FOG, p }, 1, 0, { 0 } };
        js->job[J_SIM].next[js->job[J_SIM].n_next++] = J_FOG + p;
    }
    for (int l = 0; l < FRAME_LANES; l++) {
        js->job[J_POSE + l] = (frame_job){ { T_POSE, l }, 1, 1, { J_CULL + l } };
        js->job[J_CULL + l] = (frame_job){ { T_CULL, l }, 1, 0, { 0 } };
        js->job[J_SIM].next[js->job[J_SIM].n_next++] = J_POSE + l;
    }
    for (int i = 0; i < s->npaths; i++) js->job[J_PATH + i] = (frame_job){ { T_PATH, i }, 0, 0, { 0 } };
    atomic_store(&js->outstanding, js->n_jobs);
    job_push(js, 0, J_SIM);
    for (int i = 0; i < s->npaths; i++) job_push(js, 0, J_PATH + i);
    /* the main thread works too, and never sleeps: it spins until the
     * frame is done, so a helper that sleeps a moment too long costs time
     * and never the frame */
    while (atomic_load(&js->outstanding) > 0) {
        int j = job_take(js, 0);
        if (j >= 0) job_run(js, 0, j);
#if defined(__x86_64__) || defined(__i386__)
        else __builtin_ia32_pause();
#endif
    }
}
/* }}} */
/* } THREADING */

/* {{{ int main(int argc, char **argv) */
int main(int argc, char **argv)
{
    const char *ways[] = { "serial", "systems", "levels", "systems-spin", "levels-spin", "systems-hybrid", "levels-hybrid", "jobs" };
    int known = 0;
    for (int i = 0; argc == 5 && i < 8; i++) if (strcmp(argv[1], ways[i]) == 0) known = 1;
    if (!known) {
        fprintf(stderr, "usage: %s serial|systems|levels|systems-spin|levels-spin|systems-hybrid|levels-hybrid|jobs FRAMES THREADS BACKGROUND\n", argv[0]);
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
    const char *spin_env = getenv("FRAME_SPIN_US");
    if (spin_env && *spin_env) SPIN_US = atof(spin_env);
    int jobs = strcmp(way, "jobs") == 0;
    stage_share st = { .s = s, .spin = strstr(way, "-spin") ? 1 : strstr(way, "-hybrid") ? 2 : 0, .threads = threads };
    pthread_mutex_init(&st.nap_lock, NULL);
    pthread_cond_init(&st.nap, NULL);
    pthread_t *ids = malloc(sizeof *ids * (size_t)threads);
    pthread_barrier_init(&st.start, NULL, (unsigned)threads);
    pthread_barrier_init(&st.done, NULL, (unsigned)threads);
    /* the job system's helpers, or the barrier ways' */
    job_share js = { .s = s, .threads = threads };
    job_worker_arg *jargs = malloc(sizeof *jargs * (size_t)threads);
    if (jobs) {
        js.queues = calloc((size_t)threads, sizeof *js.queues);
        for (int i = 0; i < threads; i++) atomic_flag_clear(&js.queues[i].lock);
        pthread_mutex_init(&js.nap_lock, NULL);
        pthread_cond_init(&js.nap, NULL);
        for (int i = 1; i < threads; i++) {
            jargs[i] = (job_worker_arg){ &js, i };
            pthread_create(&ids[i], NULL, job_worker, &jargs[i]);
        }
    } else {
        for (int i = 1; i < threads; i++) pthread_create(&ids[i], NULL, helper, &st);
    }
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
        } else if (jobs) {
            /* Every queue starts the frame empty, reset under its own lock:
             * a helper still looking for work reads head and tail under
             * that lock, and a reset outside it once let a helper see the
             * new head with the old tail and "steal" a job number from the
             * last frame, which then ran twice (every frame's checksum
             * caught it). */
            for (int t = 0; t < threads; t++) {
                queue_lock(&js.queues[t]);
                js.queues[t].head = 0;
                js.queues[t].tail = 0;
                queue_unlock(&js.queues[t]);
            }
            jobs_frame(&js);
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
    if (jobs) {
        atomic_store(&js.quit, 1);
        pthread_mutex_lock(&js.nap_lock);
        pthread_cond_broadcast(&js.nap);
        pthread_mutex_unlock(&js.nap_lock);
    } else {
        atomic_store(&st.quit, 1);
        meet(&st, &st.start);
    }
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
    free(jargs);
    free(js.queues);
    free(bq.jobs);
    return 0;
}
/* }}} */
