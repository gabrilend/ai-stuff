/*
 * 040-threadpool.c -- persistent workers, one barrier, no locks in the pass.
 *
 * Interface and reasoning are in 040-threadpool.h.
 *
 * The shape: workers are started once and then sleep on a condition variable.
 * A call to pool_run publishes the function and the range, bumps a generation
 * counter, wakes everybody, and waits until each worker has reported its span
 * finished.
 *
 * The generation counter is what distinguishes real work from a spurious wakeup.
 * A condition variable is allowed to wake a thread for no reason at all, so a
 * worker that trusted the wake alone would run somebody else's span twice.
 */

#include "040-threadpool.h"

#include <pthread.h>
#include <stdlib.h>
#include <unistd.h>

struct pool;

/*
 * What each thread is handed. It holds a pointer back to the pool and its own
 * index, because those are the only two things a worker needs and putting them
 * in one record is clearer than any arithmetic that would recover one from the
 * other.
 */
struct worker_slot {
    struct pool *pool;
    uint32_t     index;
};

struct pool {
    pthread_t          *threads;
    struct worker_slot *slots;

    uint32_t            worker_count;

    pthread_mutex_t     mutex;
    pthread_cond_t      work_ready;
    pthread_cond_t      work_done;

    /* Published under the mutex before the workers are woken. */
    pool_function       fn;
    void               *context;
    uint32_t            item_count;

    uint64_t            generation;   /* Bumped once per pool_run. */
    uint32_t            spans_done;
    int                 shutting_down;
};

/* {{{ static void span_for_worker */
static void span_for_worker(uint32_t item_count, uint32_t worker_count,
                            uint32_t worker, uint32_t *first, uint32_t *last)
{
    uint32_t base      = item_count / worker_count;
    uint32_t remainder = item_count % worker_count;

    /*
     * The remainder is spread across the first few workers rather than piled on
     * the last one. A barrier waits for its slowest member, so a last worker
     * carrying an extra thousand records makes every other thread idle for as
     * long as those thousand take.
     */
    if (worker < remainder) {
        *first = worker * (base + 1);
        *last  = *first + base + 1;
    } else {
        *first = (remainder * (base + 1)) + ((worker - remainder) * base);
        *last  = *first + base;
    }
}
/* }}} */

/* {{{ static void *worker_loop */
static void *worker_loop(void *argument)
{
    struct worker_slot *slot = argument;
    struct pool *p = slot->pool;
    uint32_t worker = slot->index;

    uint64_t seen = 0;

    for (;;) {
        pool_function fn;
        void *context;
        uint32_t item_count;
        uint32_t worker_count;
        uint32_t first;
        uint32_t last;

        pthread_mutex_lock(&p->mutex);

        /*
         * Wait until the generation moves. A condition variable may wake a
         * thread for no reason, so the generation -- not the wake -- is what says
         * there is work to do.
         */
        while (p->generation == seen && !p->shutting_down) {
            pthread_cond_wait(&p->work_ready, &p->mutex);
        }

        if (p->shutting_down) {
            pthread_mutex_unlock(&p->mutex);
            break;
        }

        seen         = p->generation;
        fn           = p->fn;
        context      = p->context;
        item_count   = p->item_count;
        worker_count = p->worker_count;

        pthread_mutex_unlock(&p->mutex);

        /*
         * The work runs with no lock held. That is the whole point: no pass
         * writes where another instance of itself reads, so there is nothing to
         * protect.
         */
        span_for_worker(item_count, worker_count, worker, &first, &last);
        if (last > first) {
            fn(context, first, last);
        }

        pthread_mutex_lock(&p->mutex);
        p->spans_done++;
        pthread_cond_signal(&p->work_done);
        pthread_mutex_unlock(&p->mutex);
    }

    return NULL;
}
/* }}} */

/* {{{ uint32_t pool_default_worker_count */
uint32_t pool_default_worker_count(void)
{
    long online = sysconf(_SC_NPROCESSORS_ONLN);

    /*
     * One fewer than the machine has, so that the operating system and -- later
     * -- the socket thread are not fighting the pool for the last core. A host
     * running this alongside something else can override the number from input/.
     */
    if (online < 2) {
        return 1;
    }

    return (uint32_t)(online - 1);
}
/* }}} */

/* {{{ struct pool *pool_start */
struct pool *pool_start(uint32_t worker_count)
{
    struct pool *p;
    uint32_t i;

    if (worker_count == 0) {
        worker_count = pool_default_worker_count();
    }

    p = calloc(1, sizeof(struct pool));
    if (p == NULL) {
        return NULL;
    }

    p->worker_count = worker_count;
    p->generation   = 0;
    p->spans_done   = 0;

    pthread_mutex_init(&p->mutex, NULL);
    pthread_cond_init(&p->work_ready, NULL);
    pthread_cond_init(&p->work_done, NULL);

    /*
     * A pool of one runs everything on the calling thread. That is a real mode,
     * not a degraded one -- it is how the determinism harness proves that thread
     * count changes nothing -- so no thread is started for it at all.
     */
    if (worker_count == 1) {
        return p;
    }

    p->slots   = calloc((size_t)worker_count, sizeof(struct worker_slot));
    p->threads = calloc((size_t)worker_count, sizeof(pthread_t));

    if (p->slots == NULL || p->threads == NULL) {
        p->worker_count = 1;
        pool_stop(p);
        return NULL;
    }

    for (i = 0; i < worker_count; i++) {
        p->slots[i].pool  = p;
        p->slots[i].index = i;

        if (pthread_create(&p->threads[i], NULL, worker_loop, &p->slots[i]) != 0) {
            /*
             * Some threads may already be running. Shut those down properly
             * rather than leaking them, then report failure -- a half-started
             * pool is worse than none, because it would silently do a fraction
             * of every pass.
             */
            p->worker_count = i;
            pool_stop(p);
            return NULL;
        }
    }

    return p;
}
/* }}} */

/* {{{ void pool_stop */
void pool_stop(struct pool *p)
{
    uint32_t i;

    if (p == NULL) {
        return;
    }

    if (p->threads != NULL) {
        pthread_mutex_lock(&p->mutex);
        p->shutting_down = 1;
        pthread_cond_broadcast(&p->work_ready);
        pthread_mutex_unlock(&p->mutex);

        for (i = 0; i < p->worker_count; i++) {
            pthread_join(p->threads[i], NULL);
        }
    }

    free(p->threads);
    free(p->slots);

    pthread_cond_destroy(&p->work_done);
    pthread_cond_destroy(&p->work_ready);
    pthread_mutex_destroy(&p->mutex);

    free(p);
}
/* }}} */

/* {{{ void pool_run */
void pool_run(struct pool *p, pool_function fn, void *context, uint32_t item_count)
{
    if (item_count == 0) {
        return;
    }

    /* A pool of one is the calling thread, with no signalling at all. */
    if (p->worker_count == 1 || p->threads == NULL) {
        fn(context, 0, item_count);
        return;
    }

    pthread_mutex_lock(&p->mutex);

    p->fn         = fn;
    p->context    = context;
    p->item_count = item_count;
    p->spans_done = 0;
    p->generation++;

    pthread_cond_broadcast(&p->work_ready);

    /*
     * The barrier. When this returns every span is complete, which is what lets
     * the next pass in the tick assume the previous one finished everywhere
     * rather than mostly.
     */
    while (p->spans_done < p->worker_count) {
        pthread_cond_wait(&p->work_done, &p->mutex);
    }

    pthread_mutex_unlock(&p->mutex);
}
/* }}} */

/* {{{ uint32_t pool_worker_count */
uint32_t pool_worker_count(const struct pool *p)
{
    return p->worker_count;
}
/* }}} */
