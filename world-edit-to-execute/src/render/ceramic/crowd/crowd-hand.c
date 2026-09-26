/*
 * crowd-hand.c - the crowd's tick, threaded by hand every usual way (issue 515k)
 *
 * What this is: the opponents the ceramic graph is measured against on the
 * crowd, real game work whose cost nobody chose. A tick is a snapshot (one
 * thread), then every moving unit deciding (the parallel part: most take a
 * cheap step, a few re-plan at about a hundred times the cost, and which
 * ones changes every tick), then settling (one thread). The ways differ in
 * how the deciding is shared out:
 *
 *   serial          one thread does it all
 *   measure         serial, timing each phase and each unit's deciding:
 *                   prints the tick's parts and its floor instead (see
 *                   measure_line; the last column is how many crossings
 *                   ended)
 *   slices-*        each thread owns a fixed slice of the units, always the
 *                   same one (threading by role: a thread per share)
 *   counter-*       threads take chunks of CHUNK units from a shared counter
 *                   until none are left (a self-balancing parallel loop)
 *   jobs            chunks as jobs on per-thread queues, run by their owner
 *                   or stolen by an idle thread (the job system of 515j)
 * and, for the two with a barrier, how threads wait at it:
 *   -sleep          in the system's barrier
 *   -hybrid         spinning for SPIN_US, then sleeping
 *
 * Every way runs the same crowd and must end with the same checksum of
 * every unit's position; it is printed so run-crowd.sh can compare.
 *
 * Usage: crowd-hand WAY SCENE TICKS THREADS
 *   CROWD_CHUNK (default 32): units a chunk; CROWD_SPIN_US (default 50)
 *   CROWD_TIMELINE=PATH: record who ran which chunk when, for four ticks
 *   from CROWD_TIMELINE_AT (default 600)
 *
 * Output: one line, tab-separated: way, threads, units, ticks, mean ms,
 * median ms, 99th percentile ms, worst ms, checksum.
 */
#include "crowd.h"
#include "crowd-common.h"
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int CHUNK = 32;
static double SPIN_US = 50;
static cr_crowd *crowd;
static int units;
static const double DT = 1 / 62.5;

/* {{{ static void decide_range(int first, int last) */
/* Units first .. last-1 decide; timed for the timeline when it's on. */
static void decide_range(int first, int last, int worker)
{
    double t0 = timeline_on() ? now_us() : 0;
    for (int i = first; i < last; i++) cr_decide(crowd, i, DT);
    if (timeline_on()) timeline_add(worker, first / CHUNK, t0, now_us());
}
/* }}} */

/* THREADING { -- the barrier ways: slices and counter */
typedef struct {
    pthread_barrier_t start, done;
    int         threads, hybrid, by_slices;
    _Atomic int next, quit;
    _Atomic int arrived, round, napping;
    pthread_mutex_t nap_lock;
    pthread_cond_t  nap;
} crew;

/* {{{ static void meet(crew *w, pthread_barrier_t *b) */
/* All threads wait here for each other: in the system's barrier, or
 * spinning SPIN_US on a round counter and then sleeping (the last to
 * arrive moves the round and wakes the sleepers; napping is raised before
 * the round is looked at again under the lock, so neither side misses the
 * other). */
static void meet(crew *w, pthread_barrier_t *b)
{
    if (!w->hybrid) { pthread_barrier_wait(b); return; }
    int round = atomic_load(&w->round);
    if (atomic_fetch_add(&w->arrived, 1) + 1 == w->threads) {
        atomic_store(&w->arrived, 0);
        atomic_store(&w->round, round + 1);
        if (atomic_load(&w->napping) > 0) {
            pthread_mutex_lock(&w->nap_lock);
            pthread_cond_broadcast(&w->nap);
            pthread_mutex_unlock(&w->nap_lock);
        }
        return;
    }
    double until = now_us() + SPIN_US;
    while (atomic_load(&w->round) == round) {
        pause_a_moment();
        if (now_us() > until) {
            pthread_mutex_lock(&w->nap_lock);
            atomic_fetch_add(&w->napping, 1);
            while (atomic_load(&w->round) == round) pthread_cond_wait(&w->nap, &w->nap_lock);
            atomic_fetch_sub(&w->napping, 1);
            pthread_mutex_unlock(&w->nap_lock);
        }
    }
}
/* }}} */

/* {{{ static void share_out(crew *w, int self) */
/* This thread's part of the deciding. Two ways: its own fixed slice, or
 * chunks from the shared counter until none are left. */
static void share_out(crew *w, int self)
{
    if (w->by_slices) {
        decide_range(units * self / w->threads, units * (self + 1) / w->threads, self);
        return;
    }
    for (;;) {
        int k = atomic_fetch_add(&w->next, 1);
        int first = k * CHUNK;
        if (first >= units) return;
        int last = first + CHUNK < units ? first + CHUNK : units;
        decide_range(first, last, self);
    }
}
/* }}} */

typedef struct { crew *w; int self; } crew_arg;

/* {{{ static void *crew_member(void *arg) */
static void *crew_member(void *arg)
{
    crew_arg *a = arg;
    for (;;) {
        meet(a->w, &a->w->start);
        if (atomic_load(&a->w->quit)) return NULL;
        share_out(a->w, a->self);
        meet(a->w, &a->w->done);
    }
}
/* }}} */

/* {{{ static void crew_decide(crew *w) */
/* One tick's deciding, this thread working too. */
static void crew_decide(crew *w)
{
    atomic_store(&w->next, 0);
    meet(w, &w->start);
    share_out(w, 0);
    meet(w, &w->done);
}
/* }}} */

/* The job system: a job is a chunk of units; each thread's queue is its
 * own jobs, popped newest first by the owner, taken oldest first by
 * thieves; a spin lock each. */
typedef struct {
    atomic_flag lock;
    int *jobs;
    int  head, tail;
    char pad[64];
} job_queue;

typedef struct {
    job_queue *queues;
    int        threads, n_jobs;
    _Atomic int outstanding, quit, napping;
    pthread_mutex_t nap_lock;
    pthread_cond_t  nap;
} job_share;

static void queue_lock(job_queue *q) { while (atomic_flag_test_and_set_explicit(&q->lock, memory_order_acquire)) {} }
static void queue_unlock(job_queue *q) { atomic_flag_clear_explicit(&q->lock, memory_order_release); }

/* {{{ static int job_take(job_share *js, int self) */
static int job_take(job_share *js, int self)
{
    job_queue *q = &js->queues[self];
    int j = -1;
    queue_lock(q);
    if (q->tail > q->head) j = q->jobs[--q->tail];
    queue_unlock(q);
    for (int k = 1; j < 0 && k < js->threads; k++) {
        job_queue *v = &js->queues[(self + k) % js->threads];
        queue_lock(v);
        if (v->tail > v->head) j = v->jobs[v->head++];
        queue_unlock(v);
    }
    return j;
}
/* }}} */

/* {{{ static void job_run(job_share *js, int self, int j) */
static void job_run(job_share *js, int self, int j)
{
    int first = j * CHUNK, last = first + CHUNK < units ? first + CHUNK : units;
    decide_range(first, last, self);
    atomic_fetch_sub(&js->outstanding, 1);
}
/* }}} */

/* {{{ static void *job_worker(void *arg) */
/* Take, steal, run; with nothing to take, spin SPIN_US, then sleep until
 * the next tick's jobs wake it. */
static void *job_worker(void *arg)
{
    crew_arg *a = arg;
    job_share *js = (job_share *)a->w;
    for (;;) {
        if (atomic_load(&js->quit)) return NULL;
        int j = job_take(js, a->self);
        if (j >= 0) { job_run(js, a->self, j); continue; }
        double until = now_us() + SPIN_US;
        while (j < 0 && now_us() < until && !atomic_load(&js->quit)) { pause_a_moment(); j = job_take(js, a->self); }
        if (j >= 0) { job_run(js, a->self, j); continue; }
        pthread_mutex_lock(&js->nap_lock);
        atomic_fetch_add(&js->napping, 1);
        if (atomic_load(&js->outstanding) == 0 && !atomic_load(&js->quit)) pthread_cond_wait(&js->nap, &js->nap_lock);
        atomic_fetch_sub(&js->napping, 1);
        pthread_mutex_unlock(&js->nap_lock);
    }
}
/* }}} */

/* {{{ static void jobs_decide(job_share *js) */
/* One tick's deciding: the chunks dealt round the threads' queues, then
 * sleepers woken, and the main thread working until none are outstanding. */
static void jobs_decide(job_share *js)
{
    js->n_jobs = (units + CHUNK - 1) / CHUNK;
    atomic_store(&js->outstanding, js->n_jobs);
    /* emptied under each lock: a thief may still be looking at a queue */
    for (int t = 0; t < js->threads; t++) {
        queue_lock(&js->queues[t]);
        js->queues[t].head = js->queues[t].tail = 0;
        queue_unlock(&js->queues[t]);
    }
    for (int j = 0; j < js->n_jobs; j++) {
        job_queue *q = &js->queues[j % js->threads];
        queue_lock(q);
        q->jobs[q->tail++] = j;
        queue_unlock(q);
    }
    atomic_thread_fence(memory_order_seq_cst);
    if (atomic_load(&js->napping) > 0) {
        pthread_mutex_lock(&js->nap_lock);
        pthread_cond_broadcast(&js->nap);
        pthread_mutex_unlock(&js->nap_lock);
    }
    while (atomic_load(&js->outstanding) > 0) {
        int j = job_take(js, 0);
        if (j >= 0) job_run(js, 0, j); else pause_a_moment();
    }
}
/* }}} */
/* } THREADING */

/* {{{ int main(int argc, char **argv) */
int main(int argc, char **argv)
{
    if (argc != 5) {
        fprintf(stderr, "usage: %s serial|slices-sleep|slices-hybrid|counter-sleep|counter-hybrid|jobs SCENE TICKS THREADS\n", argv[0]);
        return 64;
    }
    const char *way = argv[1];
    long ticks = atol(argv[3]);
    int threads = atoi(argv[4]);
    if (getenv("CROWD_CHUNK")) CHUNK = atoi(getenv("CROWD_CHUNK"));
    if (getenv("CROWD_SPIN_US")) SPIN_US = atof(getenv("CROWD_SPIN_US"));
    scene sc;
    crowd = scene_load(argv[2], &sc);
    units = cr_count(crowd);
    timeline_open(getenv("CROWD_TIMELINE"), threads);

    int measure = strcmp(way, "measure") == 0;
    int serial = strcmp(way, "serial") == 0 || measure;
    int jobs = strcmp(way, "jobs") == 0;
    int slices = strncmp(way, "slices-", 7) == 0, counter = strncmp(way, "counter-", 8) == 0;
    if (!serial && !jobs && !slices && !counter) { fprintf(stderr, "no way called %s\n", way); return 64; }
    const char *wait = slices ? way + 7 : counter ? way + 8 : "";
    if ((slices || counter) && strcmp(wait, "sleep") != 0 && strcmp(wait, "hybrid") != 0) { fprintf(stderr, "wait %s: sleep or hybrid\n", wait); return 64; }

    /* THREADING { -- start the helpers */
    crew w = { .threads = threads, .hybrid = strcmp(wait, "hybrid") == 0, .by_slices = slices };
    job_share js = { .threads = threads };
    pthread_t *helpers = calloc((size_t)threads, sizeof(pthread_t));
    crew_arg *args = calloc((size_t)threads, sizeof(crew_arg));
    if (slices || counter) {
        pthread_barrier_init(&w.start, NULL, (unsigned)threads);
        pthread_barrier_init(&w.done, NULL, (unsigned)threads);
        pthread_mutex_init(&w.nap_lock, NULL);
        pthread_cond_init(&w.nap, NULL);
        for (int t = 1; t < threads; t++) { args[t] = (crew_arg){ &w, t }; pthread_create(&helpers[t], NULL, crew_member, &args[t]); }
    }
    if (jobs) {
        js.queues = calloc((size_t)threads, sizeof(job_queue));
        for (int t = 0; t < threads; t++) js.queues[t].jobs = malloc(((size_t)units / (size_t)CHUNK + 2) * sizeof(int));
        pthread_mutex_init(&js.nap_lock, NULL);
        pthread_cond_init(&js.nap, NULL);
        for (int t = 1; t < threads; t++) { args[t] = (crew_arg){ (crew *)&js, t }; pthread_create(&helpers[t], NULL, job_worker, &args[t]); }
    }
    /* } THREADING */

    double *times = malloc((size_t)ticks * sizeof(double));
    /* measure: each phase's total, and each tick's floor summed */
    double m_begin = 0, m_decide = 0, m_end = 0, m_cross = 0, m_floor = 0, m_longest = 0;
    long hw = sysconf(_SC_NPROCESSORS_ONLN);
    crossing cross;
    crossing_start(&cross, crowd, &sc);
    for (long t = 1; t <= ticks; t++) {
        timeline_tick(t);
        double t0 = now_us();
        cr_tick_begin(crowd);
        double t1 = now_us(), longest = 0;
        /* Five paths: the way's deciding (measure: serial, each unit timed) */
        if (measure) for (int i = 0; i < units; i++) {
            double a = now_us();
            cr_decide(crowd, i, DT);
            double d = now_us() - a;
            if (d > longest) longest = d;
        }
        else if (serial) for (int i = 0; i < units; i++) cr_decide(crowd, i, DT);
        else if (jobs) jobs_decide(&js);
        else crew_decide(&w);
        double t2 = now_us();
        cr_tick_end(crowd, DT);
        double t3 = now_us();
        crossing_step(&cross, crowd, &sc);
        double t4 = now_us();
        times[t - 1] = (t4 - t0) / 1000;
        if (measure) {
            m_begin += t1 - t0; m_decide += t2 - t1; m_end += t3 - t2; m_cross += t4 - t3;
            if (longest > m_longest) m_longest = longest;
            /* the floor: the serial parts, plus the deciding shared perfectly
             * over the hardware threads but no shorter than its longest unit */
            double shared = (t2 - t1) / hw;
            m_floor += (t1 - t0) + (t3 - t2) + (t4 - t3) + (longest > shared ? longest : shared);
        }
    }

    /* THREADING { -- stop the helpers */
    if (slices || counter) {
        atomic_store(&w.quit, 1);
        meet(&w, &w.start);
        for (int t = 1; t < threads; t++) pthread_join(helpers[t], NULL);
    }
    if (jobs) {
        atomic_store(&js.quit, 1);
        pthread_mutex_lock(&js.nap_lock);
        pthread_cond_broadcast(&js.nap);
        pthread_mutex_unlock(&js.nap_lock);
        for (int t = 1; t < threads; t++) pthread_join(helpers[t], NULL);
    }
    /* } THREADING */

    /* Two paths: measure -> the tick's parts (mean ms a tick: snapshot,
     * deciding, settling, orders, the floor on this machine's hardware
     * threads, the longest single unit's deciding); otherwise the report */
    if (measure) {
        printf("measure\t%d\t%ld\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f\t%ld\t%ld\n", units, ticks,
               m_begin / ticks / 1000, m_decide / ticks / 1000, m_end / ticks / 1000, m_cross / ticks / 1000,
               m_floor / ticks / 1000, m_longest / 1000, hw, cross.crossings);
        return 0;
    }
    report(way, serial ? 1 : threads, units, ticks, times, crowd);
    timeline_close();
    return 0;
}
/* }}} */
