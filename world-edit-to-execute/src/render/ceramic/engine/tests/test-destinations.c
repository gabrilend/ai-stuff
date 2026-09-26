/*
 * test-destinations.c - several task queues, and who serves them (issue 515i)
 *
 * What this proves, against the kept copy of the engine:
 *   1. The order is the policy. One worker serving [frame, default], ten
 *      default tasks handed in first and ten frame tasks after, all before
 *      the worker is released: the frame tasks run first, then the
 *      default ones, each in the order handed in.
 *   2. A destination no worker serves is refused when the workers are
 *      released -- its tasks would never run (in a child process, since
 *      refusing ends the program).
 *   3. Exactly once across three destinations: four outside threads and
 *      the workers themselves hand in a million tasks to destinations
 *      chosen at random, while half the workers serve [1, 2, 0] and half
 *      [2, 0] -- so service isn't uniform and every hand-in must wake all
 *      sleepers. Every task runs once, and the pool stops by itself.
 * The no-destination case is test-task-queue.c, unchanged.
 */
#include "cera.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static int failures;

/* {{{ static void check(int ok, const char *what) */
static void check(int ok, const char *what)
{
    printf("  [%s] %s\n", ok ? "PASS" : "FAIL", what);
    if (!ok) failures++;
}
/* }}} */

typedef struct {
    cera_task_t  t;
    int          id;
    cera_pool_t *pool;
} numbered_task;

/* {{{ the order test */
static int order_seen[32];
static _Atomic int order_n;

static void note_order(cera_task_t *t)
{
    order_seen[atomic_fetch_add(&order_n, 1)] = ((numbered_task *)t)->id;
}

static cera_task_t *order_task(int id, int dest)
{
    numbered_task *n = calloc(1, sizeof *n);
    n->t.call = note_order;
    n->t.station = -1;
    n->t.dest = dest;
    n->id = id;
    return &n->t;
}

static void order_is_policy(void)
{
    cera_pool_t *p = cera_pool_create(1, NULL, NULL);
    int frame = cera_pool_add_destination(p);
    int order[] = { frame, 0 };
    cera_pool_set_sources(p, order, 2);
    for (int i = 0; i < 10; i++) cera_pool_push(p, order_task(i, 0));          /* default, first */
    for (int i = 0; i < 10; i++) cera_pool_push(p, order_task(100 + i, frame)); /* frame, after */
    cera_pool_release(p);
    cera_pool_join(p);
    int ok = atomic_load(&order_n) == 20;
    for (int i = 0; i < 10 && ok; i++) ok = order_seen[i] == 100 + i && order_seen[10 + i] == i;
    check(ok, "one worker serving [frame, default]: the frame tasks ran first, then the default ones, each in order");
    cera_pool_destroy(p);
}
/* }}} */

/* {{{ the refusal test */
static void unserved_is_refused(void)
{
    int pipefd[2];
    if (pipe(pipefd) != 0) { perror("pipe"); exit(71); }
    fflush(stdout);   /* or the child repeats what is still buffered */
    pid_t child = fork();
    if (child == 0) {
        dup2(pipefd[1], 2);
        close(pipefd[0]);
        cera_pool_t *p = cera_pool_create(2, NULL, NULL);
        cera_pool_add_destination(p);          /* destination 1: nobody serves it */
        cera_pool_release(p);
        _exit(0);
    }
    close(pipefd[1]);
    char said[512] = { 0 };
    ssize_t got = read(pipefd[0], said, sizeof said - 1);
    (void)got;
    close(pipefd[0]);
    int status = 0;
    waitpid(child, &status, 0);
    check(WIFEXITED(status) && WEXITSTATUS(status) != 0 && strstr(said, "served by no worker"),
          "a destination no worker serves is refused at release");
}
/* }}} */

/* {{{ the exactly-once test */
#define SUBMITTERS 4
#define PER_SUBMITTER 200000
#define ROOTS (SUBMITTERS * PER_SUBMITTER)
#define CHILDREN (ROOTS / 4)
static _Atomic unsigned char *ran;

static void run_spread(cera_task_t *t);

static cera_task_t *spread_task(cera_pool_t *p, int id)
{
    numbered_task *n = calloc(1, sizeof *n);
    if (!n) { fprintf(stderr, "out of memory\n"); exit(71); }
    n->t.call = run_spread;
    n->t.station = -1;
    n->t.dest = (int)((unsigned)id * 2654435761u >> 16) % 3;
    n->id = id;
    n->pool = p;
    return &n->t;
}

static void run_spread(cera_task_t *t)
{
    numbered_task *n = (numbered_task *)t;
    atomic_fetch_add_explicit(&ran[n->id], 1, memory_order_relaxed);
    if (n->id < ROOTS && n->id % 4 == 0)
        cera_pool_push(n->pool, spread_task(n->pool, ROOTS + n->id / 4));
}

typedef struct { cera_pool_t *pool; int first; } submitter_arg;

static void *submit(void *arg)
{
    submitter_arg *a = arg;
    cera_pool_submitter_register(a->pool);
    cera_task_t *batch[32];
    for (int id = a->first; id < a->first + PER_SUBMITTER; ) {
        if (id % 3 == 0) {
            cera_pool_push(a->pool, spread_task(a->pool, id++));
        } else {
            int n = 0;
            while (n < 32 && id < a->first + PER_SUBMITTER) batch[n++] = spread_task(a->pool, id++);
            cera_pool_push_many(a->pool, batch, n);   /* mixed destinations in one batch */
        }
    }
    cera_pool_submitter_unregister(a->pool);
    return NULL;
}

static void exactly_once_across_destinations(void)
{
    ran = calloc(ROOTS + CHILDREN, 1);
    cera_pool_t *p = cera_pool_create(8, NULL, NULL);
    int d1 = cera_pool_add_destination(p), d2 = cera_pool_add_destination(p);
    int first_half[] = { d1, d2, 0 }, second_half[] = { d2, 0 };
    for (int w = 0; w < 8; w++) {
        if (w < 4) cera_pool_set_worker_sources(p, w, first_half, 3);
        else cera_pool_set_worker_sources(p, w, second_half, 2);
    }
    cera_pool_submitter_register(p);
    cera_pool_release(p);
    pthread_t th[SUBMITTERS];
    submitter_arg args[SUBMITTERS];
    for (int i = 0; i < SUBMITTERS; i++) {
        args[i] = (submitter_arg){ p, i * PER_SUBMITTER };
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
    char what[200];
    snprintf(what, sizeof what, "%d tasks over three destinations, workers serving different lists: %d never ran, %d ran twice",
             ROOTS + CHILDREN, missing, twice);
    check(missing == 0 && twice == 0, what);
    check(cera_pool_finished(p) && cera_pool_queued(p) == 0, "the pool stopped by itself, nothing left in any destination");
    cera_pool_destroy(p);
    free((void *)ran);
}
/* }}} */

/* {{{ int main(void) */
int main(void)
{
    order_is_policy();
    unserved_is_refused();
    exactly_once_across_destinations();
    printf("%s\n", failures ? "FAILED" : "all passed");
    return failures ? 1 : 0;
}
/* }}} */
