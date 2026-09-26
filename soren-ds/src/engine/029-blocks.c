/*
 * 029-blocks.c — size-class blocks on per-owner free lists (issue 210).
 *
 * General description: every page this file cuts begins with a small
 * header naming its owner and its size class, so any block can be freed
 * by anyone — the address rounded down to its page finds the header, and
 * the header says whose list the block goes back to. The first 64 bytes of
 * every such page are that header; the rest is blocks.
 *
 *   one page, class 64:
 *   ┌────────┬──────┬──────┬──────┬─────────────┬──────┐
 *   │ header │  64  │  64  │  64  │    ...      │  64  │
 *   └────────┴──────┴──────┴──────┴─────────────┴──────┘
 *     owner, class
 *
 * A request too large for any class gets a run of whole pages whose first
 * 64 bytes are the same header with the class set to "large".
 */
#include "025-platform.h"
#include "027-primitives.h"
#include "028-page-stripes.h"
#include "029-blocks.h"

#define HEADER_BYTES 64
#define CLASS_LARGE 0xFF
/* Debug builds mark every free block's second word with this, and check
 * it on the way in and out: a block freed twice, or written to after
 * being freed, is caught at the moment it happens rather than as a
 * corrupted list somewhere else later. Every block is at least 16 bytes,
 * so the second word always exists. */
#define FREED_MARK 0xf7eeb10cf7eeb10cull
#define PAGE_MAGIC 0x6b6f6c62u        /* "blok" */
#define OWNER_SLOTS (OWNER_OUTSIDE + 1)

struct page_header {
    uint32_t magic;
    uint8_t  owner;
    uint8_t  cls;                     /* size class, or CLASS_LARGE */
    uint16_t unused;
    uint32_t pages;                   /* large runs: how many pages */
};

struct owner_blocks {
    void *free[BLOCK_CLASSES];        /* free list heads; next pointer in each block's first word */
    void *returns;                    /* blocks handed back by other owners */
    struct block_stats stats;
} LINE_ALIGNED;

static struct owner_blocks owners[OWNER_SLOTS] __attribute__((unused));

#ifdef SOREN_BLOCKS_FROM_HOST
/* The twin's "asan" build: every block comes from the host's allocator,
 * so the host's address checker can see each one and name the exact line
 * that writes to a block after it was freed. Never used on the device. */
void *malloc(size_t n);
void  free(void *p);

/* {{{ block_class */
int block_class(size_t bytes)
{
    size_t size = BLOCK_SMALLEST;
    for (int c = 0; c < BLOCK_CLASSES; c++, size <<= 1) {
        if (bytes <= size) {
            return c;
        }
    }
    return -1;
}
/* }}} */

/* {{{ block_class_bytes */
size_t block_class_bytes(int cls)
{
    return (size_t)BLOCK_SMALLEST << cls;
}
/* }}} */

/* {{{ block_alloc */
void *block_alloc(int owner, size_t bytes)
{
    (void)owner;
    return malloc(bytes ? bytes : 1);
}
/* }}} */

/* {{{ block_alloc_zero */
void *block_alloc_zero(int owner, size_t bytes)
{
    void *b = block_alloc(owner, bytes);
    bytes_zero(b, bytes);
    return b;
}
/* }}} */

/* {{{ block_free */
void block_free(int owner, void *block)
{
    (void)owner;
    free(block);
}
/* }}} */

/* {{{ blocks_stats */
void blocks_stats(int owner, struct block_stats *out)
{
    (void)owner;
    bytes_zero(out, sizeof *out);
}
/* }}} */
#else

/* {{{ block_class */
int block_class(size_t bytes)
{
    size_t size = BLOCK_SMALLEST;
    for (int c = 0; c < BLOCK_CLASSES; c++, size <<= 1) {
        if (bytes <= size) {
            return c;
        }
    }
    return -1;
}
/* }}} */

/* {{{ block_class_bytes */
size_t block_class_bytes(int cls)
{
    return (size_t)BLOCK_SMALLEST << cls;
}
/* }}} */

/* {{{ header_of */
static struct page_header *header_of(void *block)
{
    struct page_header *h = (struct page_header *)((uintptr_t)block & ~(uintptr_t)(PAGE_BYTES - 1));
    if (h->magic != PAGE_MAGIC) {
        platform_halt("blocks: freeing something that did not come from a block page");
    }
    return h;
}
/* }}} */

/* {{{ mark_freed */
static inline void mark_freed(void *block)
{
#ifdef SOREN_DEBUG
    uint64_t *w = block;
    if (w[1] == FREED_MARK) {
        platform_halt("blocks: a block was freed twice");
    }
    w[1] = FREED_MARK;
#else
    (void)block;
#endif
}
/* }}} */

/* {{{ mark_taken */
static inline void mark_taken(void *block)
{
#ifdef SOREN_DEBUG
    uint64_t *w = block;
    if (w[1] != FREED_MARK) {
        platform_halt("blocks: a free block was written to after it was freed, or handed out twice");
    }
    w[1] = 0;
#else
    (void)block;
#endif
}
/* }}} */

/* {{{ drain_returns */
static void drain_returns(int owner)
{
    struct owner_blocks *o = &owners[owner];
    void *block = atomic_swap(&o->returns, (void *)0);
    while (block) {
        void *next = *(void **)block;
        struct page_header *h = header_of(block);
        *(void **)block = o->free[h->cls];
        o->free[h->cls] = block;
        o->stats.returned++;
        block = next;
    }
}
/* }}} */

/* {{{ cut_page */
/* Take a fresh page and thread every block in it onto the class's list. */
static int cut_page(int owner, int cls)
{
    uint8_t *page = page_alloc(owner);
    if (!page) {
        return 0;
    }
    struct page_header *h = (struct page_header *)page;
    h->magic = PAGE_MAGIC;
    h->owner = (uint8_t)owner;
    h->cls   = (uint8_t)cls;
    h->pages = 1;
    size_t size = block_class_bytes(cls);
    struct owner_blocks *o = &owners[owner];
    for (size_t at = HEADER_BYTES; at + size <= PAGE_BYTES; at += size) {
        void *block = page + at;
        *(void **)block = o->free[cls];
#ifdef SOREN_DEBUG
        ((uint64_t *)block)[1] = FREED_MARK;
#endif
        o->free[cls] = block;
    }
    o->stats.pages_cut[cls]++;
    return 1;
}
/* }}} */

/* {{{ block_alloc */
void *block_alloc(int owner, size_t bytes)
{
    int cls = block_class(bytes);
    struct owner_blocks *o = &owners[owner];

    /* Two paths: a size some class holds (pop our own list, cutting a page
     * if it is empty), or a size no class holds (a run of whole pages). */
    if (cls < 0) {
        int pages = (int)((bytes + HEADER_BYTES + PAGE_BYTES - 1) / PAGE_BYTES);
        uint8_t *run = pages_alloc_run(owner, pages);
        if (!run) {
            return (void *)0;
        }
        struct page_header *h = (struct page_header *)run;
        h->magic = PAGE_MAGIC;
        h->owner = (uint8_t)owner;
        h->cls   = CLASS_LARGE;
        h->pages = (uint32_t)pages;
        o->stats.large_runs++;
        return run + HEADER_BYTES;
    }
    if (!o->free[cls]) {
        drain_returns(owner);
    }
    if (!o->free[cls] && !cut_page(owner, cls)) {
        return (void *)0;
    }
    void *block = o->free[cls];
    o->free[cls] = *(void **)block;
    mark_taken(block);
    o->stats.taken[cls]++;
    return block;
}
/* }}} */

/* {{{ block_alloc_zero */
void *block_alloc_zero(int owner, size_t bytes)
{
    void *block = block_alloc(owner, bytes);
    if (block) {
        bytes_zero(block, bytes);
    }
    return block;
}
/* }}} */

/* {{{ block_free */
void block_free(int owner, void *block)
{
    if (!block) {
        platform_halt("blocks: freeing nothing — a caller lost track of what it owned");
    }
    struct page_header *h = header_of(block);
    /* Three paths: a large run (its pages go straight back to the page
     * allocator, which knows how to route a foreign free), one of our own
     * blocks (push onto our list), or another owner's block (push onto
     * their returns list; only they touch their free lists). */
    if (h->cls == CLASS_LARGE) {
        pages_free_run(owner, h, (int)h->pages);
        return;
    }
    mark_freed(block);
    if (h->owner == owner) {
        struct owner_blocks *o = &owners[owner];
        *(void **)block = o->free[h->cls];
        o->free[h->cls] = block;
        return;
    }
    struct owner_blocks *o = &owners[h->owner];
    void *head = atomic_load_relaxed(&o->returns);
    do {
        *(void **)block = head;
    } while (!atomic_cas(&o->returns, &head, block));
}
/* }}} */

/* {{{ blocks_stats */
void blocks_stats(int owner, struct block_stats *out)
{
    *out = owners[owner].stats;
}
/* }}} */
#endif
