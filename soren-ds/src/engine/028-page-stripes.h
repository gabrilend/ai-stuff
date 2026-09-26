/*
 * 028-page-stripes.h — pages of memory, handed out by the core that owns
 * them, with no lock (issue 203).
 *
 * General description: the memory pool is tracked by a bitmap, one bit per
 * 4 KB page. The bitmap is cut into stripes of one cache line each — 64
 * bytes of bitmap, 512 pages, 2 MB of memory — and every stripe belongs to
 * exactly one owner. An owner allocates only from its own stripes, so two
 * cores never write the same line of the bitmap and never wait for each
 * other. A core that runs out takes a stripe nobody owns yet, with one
 * compare-and-swap. A page freed by a core that does not own it is handed
 * back to its owner through a returns list the owner empties later.
 *
 * Owners are the cores (0 .. core count - 1) plus one more, the "outside"
 * owner, which stands for any caller that is not a core: the boot code
 * before the cores exist, and on the laptop twin the test program that
 * builds maps from its own thread.
 */
#ifndef SOREN_PAGE_STRIPES_H
#define SOREN_PAGE_STRIPES_H

#include <stdint.h>
#include <stddef.h>

#define STRIPE_PAGES 512
#define STRIPE_BYTES_TOTAL ((size_t)STRIPE_PAGES * 4096)

/* The owner number used by callers that are not a core. It is one past
 * the largest possible core number so it never collides with one. */
#define OWNER_OUTSIDE 16

/* How the allocator is doing, per owner. Counters only; nothing reads
 * them to decide anything. */
struct stripe_stats {
    uint64_t pages_allocated;   /* pages handed out, ever */
    uint64_t pages_freed;       /* pages returned by this owner itself */
    uint64_t pages_returned;    /* pages another owner freed and handed back to us */
    uint64_t stripes_taken;     /* stripes claimed from the unowned pool after startup */
    uint64_t scan_steps;        /* bitmap words examined while searching */
};

/* Set up the bitmap over the platform's pool and give each of `cores`
 * cores, and the outside owner, `initial_stripes` stripes each. The rest
 * stay unowned until somebody runs out. Called once, before any core
 * starts. */
void stripes_init(int cores, int initial_stripes);

/* One page, from the calling owner's stripes. Answers NULL only when the
 * whole pool is genuinely exhausted — no owned page free and no unowned
 * stripe left — and says so on the developer's line first. */
void *page_alloc(int owner);

/* `count` contiguous pages (1 .. STRIPE_PAGES) from one of the caller's
 * stripes. For the few things that must be one unbroken span. */
void *pages_alloc_run(int owner, int count);

/* Give one page back. The caller need not be its owner. */
void  page_free(int owner, void *page);
void  pages_free_run(int owner, void *first, int count);

/* Parking support (issue 213). Is this page currently marked free in the
 * bitmap? Is it reclaimable — and if so, mark it allocated again, taking
 * it back without asking its owner? Both are safe from any core because
 * every bitmap write is one atomic word operation. */
int   page_is_free(void *page);
int   page_reclaim(void *page);
/* Mark a page free directly, whoever owns its stripe. Only parking uses
 * this: routing a parked page through its owner's returns list would
 * leave its bit set until the owner next allocated, and the restart would
 * then find it "taken" and rebuild for nothing. Rare, and atomic, so the
 * only cost is one cache line visiting another core. */
void  page_release_direct(void *page);

/* Which owner a page's stripe belongs to, or -1 for unowned. */
int   page_owner(void *page);

/* Totals, for reports and the metrics pages. */
void   stripes_stats(int owner, struct stripe_stats *out);
size_t stripes_total_pages(void);
size_t stripes_free_pages(void);
int    stripes_total(void);
int    stripes_unowned(void);

#endif
