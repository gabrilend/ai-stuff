/*
 * test-task-queue.c - the fork's lock-free task queue, under load (issue 515g)
 *
 * What this proves, against the kept copy of the engine
 * (src/render/ceramic/engine/cera.c):
 *   1. Every task handed in runs exactly once. Four outside threads hand
 *      in 800,000 tasks between them -- single hand-ins, batches of
 *      random size (cera_pool_push_many), and pushes gathered by an open
 *      batch (cera_pool_batch_begin / end) -- while a quarter of the
 *      tasks, running on workers, hand in a child task of their own. Then
 *      the pool must notice by itself that the work ran out, and stop.
 *   2. Tasks seeded before the workers are released all run, and the
 *      pool stops with no outside submitter (how a map starts).
 *   3. The same load on a ring of only 16 slots, so it is full nearly
 *      all the time: outside threads must wait for room, and workers
 *      handing in children must run them themselves (a box never waits)
 *      -- and still every task runs exactly once and the pool stops.
 *
 * Built by run-engine-tests.sh with the fork and a stub construction
 * file; exits 0 when every check passes.
 */
#include "cera.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define SUBMITTERS 4
#define PER_SUBMITTER 200000
#define ROOTS (SUBMITTERS * PER_SUBMITTER)
#define CHILD_EVERY 4               /* every fourth root hands in a child */
#define CHILDREN (ROOTS / CHILD_EVERY)

/* A task with its number: the engine frees the task pointer, which is
 * the start of this struct, so one free takes it all. */
typedef struct {
    cera_task_t t;
    int         id;
    cera_pool_t *pool;
} numbered_task;

static _Atomic unsigned char *ran;   /* how many times each id ran */
static int spawn_children;           /* only the first check hands in children */
static int failures;

/* {{{ static void check(int ok, const char *what) */
static void check(int ok, const char *what)
{
    printf("  [%s] %s\n", ok ? "PASS" : "FAIL", what);
    if (!ok) failures++;
}
/* }}} */

static void run_numbered(cera_task_t *t);

/* {{{ static cera_task_t *make_task(cera_pool_t *p, int id) */
static cera_task_t *make_task(cera_pool_t *p, int id)
{
    numbered_task *n = calloc(1, sizeof *n);
    if (!n) { fprintf(stderr, "out of memory\n"); exit(71); }
    n->t.call = run_numbered;
    n->t.station = -1;
    n->id = id;
    n->pool = p;
    return &n->t;
}
/* }}} */

/* {{{ static void run_numbered(cera_task_t *t) */
/* Count the run; a root whose number divides by CHILD_EVERY hands in a
 * child, numbered after all the roots, from inside the worker. */
static void run_numbered(cera_task_t *t)
{
    numbered_task *n = (numbered_task *)t;
    atomic_fetch_add_explicit(&ran[n->id], 1, memory_order_relaxed);
    if (spawn_children && n->id < ROOTS && n->id % CHILD_EVERY == 0)
        cera_pool_push(n->pool, make_task(n->pool, ROOTS + n->id / CHILD_EVERY));
}
/* }}} */

typedef struct { cera_pool_t *pool; int first; unsigned seed; } submitter_arg;

/* {{{ static void *submit(void *arg) */
/* One outside thread: its share of the roots, in three shapes chosen
 * at random -- one at a time, a batch array, or an open batch. */
static void *submit(void *arg)
{
    submitter_arg *a = arg;
    cera_pool_submitter_register(a->pool);
    cera_task_t *batch[64];
    int id = a->first, end = a->first + PER_SUBMITTER;
    while (id < end) {
        int shape = rand_r(&a->seed) % 3;
        int n = 1 + rand_r(&a->seed) % 64;
        if (n > end - id) n = end - id;
        if (shape == 0) {
            cera_pool_push(a->pool, make_task(a->pool, id++));
        } else if (shape == 1) {
            for (int i = 0; i < n; i++) batch[i] = make_task(a->pool, id++);
            cera_pool_push_many(a->pool, batch, n);
        } else {
            cera_pool_batch_begin(a->pool);
            for (int i = 0; i < n; i++) cera_pool_push(a->pool, make_task(a->pool, id++));
            cera_pool_batch_end(a->pool);
        }
    }
    cera_pool_submitter_unregister(a->pool);
    return NULL;
}
/* }}} */

/* {{{ static void exactly_once(const char *slots) */
/* `slots`: the ring's size for this run (CERAMIC_QUEUE_SLOTS), or NULL
 * for the default. */
static void exactly_once(const char *slots)
{
    if (slots) setenv("CERAMIC_QUEUE_SLOTS", slots, 1);
    else unsetenv("CERAMIC_QUEUE_SLOTS");
    ran = calloc(ROOTS + CHILDREN, 1);
    spawn_children = 1;
    cera_pool_t *p = cera_pool_create(8, NULL, NULL);
    /* One outside registration held across starting the submitters, so
     * the pool can't decide it is finished before any of them arrive. */
    cera_pool_submitter_register(p);
    cera_pool_release(p);
    pthread_t th[SUBMITTERS];
    submitter_arg args[SUBMITTERS];
    for (int i = 0; i < SUBMITTERS; i++) {
        args[i] = (submitter_arg){ p, i * PER_SUBMITTER, 12345u + (unsigned)i };
        pthread_create(&th[i], NULL, submit, &args[i]);
    }
    for (int i = 0; i < SUBMITTERS; i++) pthread_join(th[i], NULL);
    cera_pool_submitter_unregister(p);
    cera_pool_join(p);

    int missing = 0, twice = 0;
    for (int i = 0; i < ROOTS + CHILDREN; i++) {
        if (ran[i] == 0) missing++;
        if (ran[i] > 1) twice++;
    }
    char what[160];
    snprintf(what, sizeof what, "%s ring: %d tasks from %d threads and inside workers: %d never ran, %d ran twice",
             slots ? slots : "default", ROOTS + CHILDREN, SUBMITTERS, missing, twice);
    check(missing == 0 && twice == 0, what);
    check(cera_pool_finished(p), "the pool stopped by itself when the work ran out");
    check(cera_pool_queued(p) == 0, "nothing left in the queue");
    cera_pool_destroy(p);
    free((void *)ran);
    spawn_children = 0;
    unsetenv("CERAMIC_QUEUE_SLOTS");
}
/* }}} */

/* {{{ static void seeded_before_release(void) */
static void seeded_before_release(void)
{
    ran = calloc(1000, 1);
    cera_pool_t *p = cera_pool_create(4, NULL, NULL);
    for (int i = 0; i < 1000; i++) cera_pool_push(p, make_task(p, i));
    cera_pool_release(p);
    cera_pool_join(p);
    int all = 1;
    for (int i = 0; i < 1000; i++) if (ran[i] != 1) all = 0;
    check(all, "1000 tasks seeded before release all ran once, and the pool stopped with no outside submitter");
    cera_pool_destroy(p);
    free((void *)ran);
}
/* }}} */

/* {{{ int main(void) */
int main(void)
{
    exactly_once(NULL);
    seeded_before_release();
    exactly_once("16");
    printf("%s\n", failures ? "FAILED" : "all passed");
    return failures ? 1 : 0;
}
/* }}} */
