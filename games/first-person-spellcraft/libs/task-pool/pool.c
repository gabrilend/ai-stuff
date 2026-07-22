/* pool.c — the lean worker pool.
 *
 * How it works, for a general reader: a handful of worker threads share one
 * to-do list (a FIFO queue). Each worker loops: take the next task off the list
 * (waiting quietly if the list is empty), run it, repeat. Anyone — including a
 * running task — can add to the list, and adding wakes a sleeping worker. A
 * separate tally of "tasks still in flight" lets a caller wait for the whole
 * list to go quiet, which is used for setup/teardown and tests but never by the
 * running game (its clock keeps the list full forever).
 *
 * Two locks that never nest, so there's no lock-ordering to worry about:
 *   q_mtx    guards the task queue + the shutdown flag.
 *   act_mtx  guards the in-flight-task tally + the quiescence wait.
 */
#include "pool.h"

#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>

/* {{{ struct task / struct pool */
struct task {
    pool_task_t  fn;
    void        *arg;
    struct task *next;
};

struct pool {
    pthread_t      *workers;
    int             n_workers;

    /* the FIFO queue + its lock/cv, plus the shutdown flag */
    struct task    *head, *tail;
    pthread_mutex_t q_mtx;
    pthread_cond_t  q_cv;
    int             shutdown;

    /* in-flight tally + its lock/cv for pool_wait_quiescent */
    long            active;
    pthread_mutex_t act_mtx;
    pthread_cond_t  act_cv;
};
/* }}} */

/* {{{ local dequeue() — pop the head task, or NULL. Caller holds q_mtx. */
static struct task *dequeue(struct pool *p)
{
    struct task *t = p->head;
    if (t) {
        p->head = t->next;
        if (!p->head) p->tail = NULL;
    }
    return t;
}
/* }}} */

/* {{{ local worker_main() */
/* One worker's whole life: wait for work, run it, account for it, repeat until
 * shutdown drains the queue. The two-path wait is the crux —
 *   - queue non-empty: take a task and run it.
 *   - queue empty & not shutting down: sleep on q_cv until spawn or destroy
 *     wakes us.
 *   - queue empty & shutting down: nothing left ever comes, so exit. */
static void *worker_main(void *arg)
{
    struct pool *p = arg;
    for (;;) {
        pthread_mutex_lock(&p->q_mtx);
        while (!p->shutdown && p->head == NULL)
            pthread_cond_wait(&p->q_cv, &p->q_mtx);
        if (p->shutdown && p->head == NULL) {
            pthread_mutex_unlock(&p->q_mtx);
            break;
        }
        struct task *t = dequeue(p);
        pthread_mutex_unlock(&p->q_mtx);

        if (t) {
            t->fn(t->arg);
            free(t);
            /* Account for completion. If we just emptied the world, wake any
             * quiescence waiter. active is guarded by act_mtx throughout so the
             * waiter never misses the drop to zero. */
            pthread_mutex_lock(&p->act_mtx);
            if (--p->active == 0)
                pthread_cond_broadcast(&p->act_cv);
            pthread_mutex_unlock(&p->act_mtx);
        }
    }
    return NULL;
}
/* }}} */

/* {{{ pool_create() */
pool_t *pool_create(int n_workers)
{
    if (n_workers <= 0) {
        long cpus = sysconf(_SC_NPROCESSORS_ONLN);
        n_workers = (cpus > 0) ? (int)cpus : 1;
    }
    if (n_workers > POOL_MAX_WORKERS) n_workers = POOL_MAX_WORKERS;

    struct pool *p = calloc(1, sizeof *p);
    if (!p) return NULL;
    p->n_workers = n_workers;
    pthread_mutex_init(&p->q_mtx, NULL);
    pthread_cond_init(&p->q_cv, NULL);
    pthread_mutex_init(&p->act_mtx, NULL);
    pthread_cond_init(&p->act_cv, NULL);

    p->workers = calloc((size_t)n_workers, sizeof *p->workers);
    if (!p->workers) { free(p); return NULL; }

    for (int i = 0; i < n_workers; i++) {
        if (pthread_create(&p->workers[i], NULL, worker_main, p) != 0) {
            /* Partial spawn: shut down what we started and bail, so we never
             * leak live threads on a half-built pool. */
            pthread_mutex_lock(&p->q_mtx);
            p->shutdown = 1;
            pthread_cond_broadcast(&p->q_cv);
            pthread_mutex_unlock(&p->q_mtx);
            for (int j = 0; j < i; j++) pthread_join(p->workers[j], NULL);
            free(p->workers);
            free(p);
            return NULL;
        }
    }
    return p;
}
/* }}} */

/* {{{ pool_spawn() */
void pool_spawn(pool_t *p, pool_task_t fn, void *arg)
{
    if (!p || !fn) return;
    struct task *t = malloc(sizeof *t);
    if (!t) return; /* out of memory: the task is simply not scheduled */
    t->fn = fn;
    t->arg = arg;
    t->next = NULL;

    /* Count it in-flight BEFORE it can be run, so a quiescence waiter can never
     * observe a false zero between enqueue and execution. */
    pthread_mutex_lock(&p->act_mtx);
    p->active++;
    pthread_mutex_unlock(&p->act_mtx);

    pthread_mutex_lock(&p->q_mtx);
    if (p->tail) p->tail->next = t; else p->head = t;
    p->tail = t;
    pthread_cond_signal(&p->q_cv);   /* wake one idle worker */
    pthread_mutex_unlock(&p->q_mtx);
}
/* }}} */

/* {{{ pool_wait_quiescent() */
void pool_wait_quiescent(pool_t *p)
{
    if (!p) return;
    pthread_mutex_lock(&p->act_mtx);
    while (p->active > 0)
        pthread_cond_wait(&p->act_cv, &p->act_mtx);
    pthread_mutex_unlock(&p->act_mtx);
}
/* }}} */

/* {{{ pool_destroy() */
void pool_destroy(pool_t *p)
{
    if (!p) return;
    pthread_mutex_lock(&p->q_mtx);
    p->shutdown = 1;
    pthread_cond_broadcast(&p->q_cv);  /* wake every idle worker to exit */
    pthread_mutex_unlock(&p->q_mtx);

    for (int i = 0; i < p->n_workers; i++)
        pthread_join(p->workers[i], NULL);

    /* Free any tasks that were queued but never run (shutdown mid-backlog). */
    for (struct task *t = p->head; t; ) {
        struct task *next = t->next;
        free(t);
        t = next;
    }
    pthread_mutex_destroy(&p->q_mtx);
    pthread_cond_destroy(&p->q_cv);
    pthread_mutex_destroy(&p->act_mtx);
    pthread_cond_destroy(&p->act_cv);
    free(p->workers);
    free(p);
}
/* }}} */

/* {{{ pool_n_workers() */
int pool_n_workers(const pool_t *p) { return p ? p->n_workers : 0; }
/* }}} */
