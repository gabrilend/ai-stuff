/*
 * 029-blocks.h — small pieces of memory, by size class, per owner
 * (the memory half of issue 210).
 *
 * General description: pages are 4 KB and most things the engine makes —
 * a task, a list of wire destinations, a station's port records — are a
 * few dozen bytes. So each owner cuts pages into blocks of one size (16,
 * 32, 64 ... 2048 bytes) and keeps a free list per size. Taking a block
 * is popping the head of your own list; freeing your own is pushing it
 * back. A block freed by another owner goes onto its owner's returns list,
 * which the owner empties the next time it allocates — so a block never
 * sits on two owners' lists, and memory does not drift toward whichever
 * core frees more than it builds.
 *
 * Anything larger than the largest class is given its own run of whole
 * pages.
 */
#ifndef SOREN_BLOCKS_H
#define SOREN_BLOCKS_H

#include <stdint.h>
#include <stddef.h>

#define BLOCK_CLASSES 8               /* 16, 32, 64, 128, 256, 512, 1024, 2048 */
#define BLOCK_SMALLEST 16
#define BLOCK_LARGEST 2048

/* Per owner, per class. Written only by the owner. */
struct block_stats {
    uint64_t taken[BLOCK_CLASSES];    /* blocks handed out */
    uint64_t pages_cut[BLOCK_CLASSES];/* pages cut into blocks of this class */
    uint64_t returned;                /* blocks other owners handed back */
    uint64_t large_runs;              /* allocations too big for any class */
};

/* Answers NULL only when the page allocator is exhausted (which has
 * already been reported by then). */
void *block_alloc(int owner, size_t bytes);
void *block_alloc_zero(int owner, size_t bytes);
void  block_free(int owner, void *block);

/* Which class a request of `bytes` falls in, or -1 if it needs a run. */
int   block_class(size_t bytes);
size_t block_class_bytes(int cls);

void  blocks_stats(int owner, struct block_stats *out);

#endif
