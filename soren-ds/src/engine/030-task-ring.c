/*
 * 030-task-ring.c — push, pop, and doubling (issue 204).
 *
 * General description: two indices chase each other round an array of
 * task pointers. Pushing writes at `write` and moves it on; popping reads
 * at `read` and moves it on; both wrap at the end. When a push would fill
 * the last free slot the array is replaced by one twice as large, with the
 * wrapped-around part copied so the contents read in order from slot 0.
 * One spin lock covers the lot. It is the only lock anywhere on the path
 * a value travels, and it is held for a handful of instructions.
 */
#include "025-platform.h"
#include "027-primitives.h"
#include "029-blocks.h"
#include "030-task-ring.h"

/* {{{ ring_init */
void ring_init(struct task_ring *ring, int owner, int capacity)
{
    int cap = 8;
    while (cap < capacity) {
        cap <<= 1;
    }
    bytes_zero(ring, sizeof *ring);
    ring->slots = block_alloc(owner, (size_t)cap * sizeof(void *));
    if (!ring->slots) {
        platform_halt("task ring: no memory for the ring itself");
    }
    ring->capacity = cap;
}
/* }}} */

/* {{{ ring_grow */
/* Replace the array with one twice the size, oldest task first. Called
 * holding the lock, so nothing else is inside. */
static int ring_grow(struct task_ring *ring, int owner)
{
    int32_t cap = ring->capacity;
    void **bigger = block_alloc(owner, (size_t)cap * 2 * sizeof(void *));
    if (!bigger) {
        return 0;
    }
    for (int32_t i = 0; i < ring->count; i++) {
        bigger[i] = ring->slots[(ring->read + i) & (cap - 1)];
    }
    block_free(owner, ring->slots);
    ring->slots    = bigger;
    ring->capacity = cap * 2;
    ring->read     = 0;
    ring->write    = ring->count;
    ring->growths++;
    return 1;
}
/* }}} */

/* {{{ ring_push */
int ring_push(struct task_ring *ring, int owner, void *task)
{
    spin_lock(&ring->lock);
    /* Full is exactly "one more would make write land on read"; keeping
     * one slot empty is what lets read == write mean empty. */
    if (ring->count + 1 >= ring->capacity && !ring_grow(ring, owner)) {
        spin_unlock(&ring->lock);
        return 0;
    }
    ring->slots[ring->write] = task;
    ring->write = (ring->write + 1) & (ring->capacity - 1);
    ring->count++;
    ring->pushed++;
    if (ring->count > ring->high_water) {
        ring->high_water = ring->count;
    }
    spin_unlock(&ring->lock);
    /* Waking parked cores is the caller's job (engine_wake_sleepers in
     * 032-workers.c), because only the engine knows whether any are
     * parked — and sending a wake nobody needs costs every core a cache
     * line on every single push. */
    return 1;
}
/* }}} */

/* {{{ ring_pop */
void *ring_pop(struct task_ring *ring)
{
    /* A peek without the lock first: an empty ring is the common case for
     * an idle core and costs nobody a lock hand-over. A stale "empty" is
     * harmless because the pusher's event wakes us to look again. */
    if (atomic_load_relaxed(&ring->count) == 0) {
        return (void *)0;
    }
    spin_lock(&ring->lock);
    void *task = (void *)0;
    if (ring->count > 0) {
        task = ring->slots[ring->read];
        ring->read = (ring->read + 1) & (ring->capacity - 1);
        ring->count--;
    }
    spin_unlock(&ring->lock);
    return task;
}
/* }}} */

/* {{{ ring_stats */
void ring_stats(struct task_ring *ring, int *count, int *capacity,
                int *high_water, int *growths, uint64_t *pushed)
{
    spin_lock(&ring->lock);
    *count      = ring->count;
    *capacity   = ring->capacity;
    *high_water = ring->high_water;
    *growths    = ring->growths;
    *pushed     = ring->pushed;
    spin_unlock(&ring->lock);
}
/* }}} */
