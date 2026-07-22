/* pool-test.c — proves the worker pool: fan-out exactness, self-spawn (the
 * frame-clock / iterator re-arm mechanism), and spawn-from-inside-a-task. All
 * checked by counting completed work against wait_quiescent. Temporary prover;
 * compile and run from the Makefile / a run script.
 */
#include "pool.h"

#include <stdio.h>
#include <stdatomic.h>

static int failures = 0;
/* {{{ check() */
static void check(const char *name, int cond)
{
    if (cond) printf("  ok  %s\n", name);
    else    { printf("  FAIL %s\n", name); failures++; }
}
/* }}} */

/* {{{ fan-out: every spawned task runs exactly once */
static _Atomic long fan_counter;
static void bump(void *arg) { (void)arg; atomic_fetch_add(&fan_counter, 1); }

static void test_fanout(void)
{
    pool_t *p = pool_create(0);
    check("pool created", p != NULL);
    check("has workers", pool_n_workers(p) >= 1);

    atomic_store(&fan_counter, 0);
    const long N = 200000;
    for (long i = 0; i < N; i++) pool_spawn(p, bump, NULL);
    pool_wait_quiescent(p);
    check("fan-out: every task ran exactly once", atomic_load(&fan_counter) == N);

    pool_destroy(p);
}
/* }}} */

/* {{{ self-spawn: a task that re-arms itself (the heartbeat / iterator shape) */
typedef struct { pool_t *p; _Atomic long *count; long target; } rearm_t;

static void rearm(void *arg)
{
    rearm_t *r = arg;
    long now = atomic_fetch_add(r->count, 1) + 1;
    /* Two paths:
     *   not done yet → re-add ourselves to the pool (one successor, so the
     *                  chain stays single-in-flight, exactly like the frame
     *                  clock re-arming after each tick).
     *   done         → stop re-arming; the chain ends and the pool goes quiet. */
    if (now < r->target) pool_spawn(r->p, rearm, r);
}

static void test_self_spawn(void)
{
    pool_t *p = pool_create(0);
    _Atomic long count;
    atomic_store(&count, 0);
    rearm_t r = { p, &count, 100000 };
    pool_spawn(p, rearm, &r);      /* kick off the chain */
    pool_wait_quiescent(p);
    check("self-spawn: re-armed exactly target times", atomic_load(&count) == r.target);
    pool_destroy(p);
}
/* }}} */

/* {{{ nested spawn: a task that spawns children from inside itself */
static _Atomic long nested_counter;
static void child(void *arg) { (void)arg; atomic_fetch_add(&nested_counter, 1); }

typedef struct { pool_t *p; int children; } parent_t;
static void parent(void *arg)
{
    parent_t *pp = arg;
    for (int i = 0; i < pp->children; i++) pool_spawn(pp->p, child, NULL);
}

static void test_nested_spawn(void)
{
    pool_t *p = pool_create(0);
    atomic_store(&nested_counter, 0);
    const int PARENTS = 500, CHILDREN = 400;
    parent_t pp = { p, CHILDREN };
    for (int i = 0; i < PARENTS; i++) pool_spawn(p, parent, &pp);
    pool_wait_quiescent(p);
    check("nested spawn: all children ran",
          atomic_load(&nested_counter) == (long)PARENTS * CHILDREN);
    pool_destroy(p);
}
/* }}} */

/* {{{ main() */
int main(void)
{
    printf("fan-out:\n");      test_fanout();
    printf("self-spawn:\n");   test_self_spawn();
    printf("nested spawn:\n"); test_nested_spawn();
    printf(failures ? "\n%d FAILURE(S)\n" : "\nall checks passed\n", failures);
    return failures ? 1 : 0;
}
/* }}} */
