/*
 * 040-threadpool.h -- a range and a function, and nothing else.
 *
 * Every parallel pass in this project is the same shape: walk a contiguous span
 * of records. The world is flat arrays, so splitting work is arithmetic --
 * records 0 to 4999 are yours, 5000 to 9999 are mine -- and this is the whole of
 * what a pool has to offer.
 *
 * It deliberately does not offer task queues, futures, or work stealing. Those
 * are machinery for problems this project does not have, and every one of them
 * would be a place for a bug that only appears under load.
 *
 * There are no locks inside a pass, because no pass writes where another
 * instance of itself reads -- that is buffer-then-resolve, established at the
 * design level rather than defended at the code level.
 *
 * IF A PASS EVER NEEDS A MUTEX, THE PASS IS THE BUG, NOT THE POOL. The first
 * person to hit a race will otherwise reach for a lock, it will work, and the
 * design will quietly be over.
 *
 * See issues/201-the-thread-pool.md.
 */

#ifndef VTT_THREADPOOL_H
#define VTT_THREADPOOL_H

#include <stdint.h>

/*
 * What a parallel pass looks like. Called once per worker with a half-open span
 * of item indices. `context` is whatever the caller needs; the pool never looks
 * inside it.
 */
typedef void (*pool_function)(void *context, uint32_t first, uint32_t last);

struct pool;

/*
 * Start a pool with the given number of workers, or 0 to size it from the
 * machine. Returns NULL if the threads could not be started.
 *
 * Threads are created here and never again. Creating one during a tick is a
 * stall nobody expects and nobody measures.
 */
struct pool *pool_start(uint32_t worker_count);

/* Stop the workers and release everything. */
void pool_stop(struct pool *p);

/*
 * Split [0, item_count) across the workers, run `fn` on each span, and wait
 * until all of them are finished. This call is a barrier: when it returns, every
 * span is complete.
 *
 * An item_count of 0 does nothing. A pool of one worker runs the whole range on
 * the calling thread, which is a real mode rather than a degraded one -- it is
 * how the determinism harness proves that thread count changes nothing.
 */
void pool_run(struct pool *p, pool_function fn, void *context, uint32_t item_count);

/* How many workers this pool has. */
uint32_t pool_worker_count(const struct pool *p);

/*
 * How many workers a pool started with 0 would use. Exposed so a caller can
 * report it without starting one.
 */
uint32_t pool_default_worker_count(void);

#endif
