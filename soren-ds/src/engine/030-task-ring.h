/*
 * 030-task-ring.h — the one channel between the core that finds work and
 * the core that does it (issue 204).
 *
 * General description: a first-in-first-out ring of pointers to tasks.
 * A delivery that makes a station ready pushes the task it built; an idle
 * worker pops the oldest. The ring holds pointers *out* to tasks, never
 * the tasks themselves, and nothing anywhere points *into* the ring — so
 * when it fills it can simply be replaced by one twice the size, contents
 * unwrapped into order, without leaving a dangling reference anywhere.
 */
#ifndef SOREN_TASK_RING_H
#define SOREN_TASK_RING_H

#include <stdint.h>
#include "027-primitives.h"

struct task_ring {
    spin_lock_t lock;         /* guards every field below */
    void      **slots;        /* the ring itself: `capacity` task pointers */
    int32_t     capacity;
    int32_t     read;         /* where the oldest waiting task sits */
    int32_t     write;        /* where the next one goes */
    int32_t     count;        /* how many are waiting */
    int32_t     high_water;   /* the most ever waiting at once */
    int32_t     growths;      /* how many times it doubled */
    uint64_t    pushed;       /* total pushes, ever */
} LINE_ALIGNED;

/* Allocates `capacity` slots (rounded up to a power of two) from `owner`'s
 * memory. */
void  ring_init(struct task_ring *ring, int owner, int capacity);

/* Add a task. Grows the ring if it is full — never refuses and never
 * waits for room. Answers 0 only if growing needed memory the allocator
 * no longer has. Does not wake anybody: the caller decides that. */
int   ring_push(struct task_ring *ring, int owner, void *task);

/* Take the oldest task, or NULL if there is none. Never waits: what to do
 * about an empty ring is the worker's decision (issue 206). */
void *ring_pop(struct task_ring *ring);

/* A snapshot of the counters, taken under the lock. */
void  ring_stats(struct task_ring *ring, int *count, int *capacity,
                 int *high_water, int *growths, uint64_t *pushed);

#endif
