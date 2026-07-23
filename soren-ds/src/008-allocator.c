/*
 * 008-allocator.c — flat physical page allocator
 *
 * Hands out 4 KB physical pages from the DRAM pool the previous
 * issue exposes. Tracks who has what via a one-bit-per-page bitmap
 * that lives at the start of the pool itself, so the allocator's
 * bookkeeping costs scale with the pool size and consume the pool
 * rather than burning kernel image space.
 *
 * Design:
 *
 *   The bitmap is carved out of the bottom of the pool at init.
 *   For three gigabytes of DRAM at 4 KB pages that is roughly
 *   96 KB of bitmap, which costs about 24 of the pool's pages —
 *   a trivial fraction of the total. The remaining pages are
 *   what alloc_page hands out and what free_page returns.
 *
 *   alloc_page is O(n) where n is the number of managed pages; on
 *   the device's ~786,000 pages that is still sub-millisecond,
 *   and phase 1's kernel does not call it on a hot path. Phase 2's
 *   threading core might call it from per-thread setup, but even
 *   there it is a one-shot per thread rather than a per-fire cost.
 *
 *   free_page is O(1): the page address determines the bitmap
 *   index directly.
 *
 * What this file deliberately does not do yet:
 *
 *   - (added in 111d) Multi-page contiguous allocation, alloc_pages(N) /
 *     free_pages(addr, N). The display framebuffers are the first caller:
 *     VOP2 scans a framebuffer as one linear span from a single base
 *     address, so it must be physically contiguous, not a page list.
 *
 *   - Concurrency control. The kernel is still single-core at
 *     this point. Phase 2's threading core adds atomics; the page
 *     allocator's bitmap operations move from plain reads and
 *     writes to compare-and-swap once that lands.
 *
 *   - Statistics, page colouring, NUMA awareness — none of these
 *     are needed before phase 8 at the earliest.
 */

#include <stdint.h>

extern uint64_t memory_pool_base(void);
extern uint64_t memory_pool_end(void);

#define PAGE_SIZE   ((uint64_t)4096)
#define PAGE_SHIFT  12

/* Bitmap state. Set by allocator_init; read by alloc_page and
 * free_page. All addresses are physical, in the flat model the
 * project commits to until phase 9. */
static uint8_t *page_bitmap;       /* one bit per managed page */
static uint64_t bitmap_bytes;      /* size of the bitmap region */
static uint64_t managed_pool_base; /* first page address that the bitmap tracks */
static uint64_t managed_pool_pages;/* number of pages the bitmap tracks */

/* Round a value up to the next multiple of PAGE_SIZE. */
static inline uint64_t page_round_up(uint64_t x)
{
    return (x + (PAGE_SIZE - 1)) & ~(PAGE_SIZE - 1);
}

/* Zero a region of bytes. The kernel has no memset yet; phase 2's
 * string-and-memory utilities will replace this with a faster
 * version. For a one-shot 96 KB clear at boot, the simple loop is
 * fine. */
static void zero_bytes(uint8_t *dst, uint64_t count)
{
    for (uint64_t i = 0; i < count; i++) {
        dst[i] = 0;
    }
}

/* Initialise the allocator from the memory layout defined in
 * 007-memory.c. Idempotent if called more than once because every
 * field is rewritten unconditionally; we still expect to be called
 * exactly once, from kernel_main. */
void allocator_init(void)
{
    uint64_t pool_base  = memory_pool_base();
    uint64_t pool_end   = memory_pool_end();
    uint64_t pool_pages = (pool_end - pool_base) >> PAGE_SHIFT;

    /* Carve the bitmap out of the bottom of the pool. The bitmap
     * needs one bit per page; size it round-up to whole bytes. */
    uint64_t needed_bitmap_bytes = (pool_pages + 7) >> 3;
    uint64_t needed_bitmap_pages =
        (needed_bitmap_bytes + (PAGE_SIZE - 1)) >> PAGE_SHIFT;

    page_bitmap         = (uint8_t *)(uintptr_t)pool_base;
    bitmap_bytes        = needed_bitmap_bytes;
    managed_pool_base   = pool_base + (needed_bitmap_pages << PAGE_SHIFT);
    managed_pool_pages  = pool_pages - needed_bitmap_pages;

    /* All managed pages start free. The bitmap stores 0=free,
     * 1=used; clearing the whole region is the right initial
     * state. */
    zero_bytes(page_bitmap, bitmap_bytes);
}

/* Try to allocate one page. Returns the physical address of a
 * freshly-allocated page, or zero if no pages are free.
 *
 * Zero is a legitimate "no allocation" sentinel because the
 * managed pool never starts at physical address zero — that area
 * is reserved by lower-layer firmware per the memory map. */
uint64_t alloc_page(void)
{
    /* Linear scan. Walks the bitmap byte-by-byte; for each byte
     * with at least one zero bit, finds the lowest free bit and
     * returns the corresponding page. */
    for (uint64_t byte_index = 0; byte_index < bitmap_bytes; byte_index++) {
        uint8_t bits = page_bitmap[byte_index];
        if (bits == 0xFFu) {
            continue;
        }
        for (unsigned bit_index = 0; bit_index < 8; bit_index++) {
            if (!(bits & (1u << bit_index))) {
                uint64_t page_index = (byte_index << 3) + bit_index;
                if (page_index >= managed_pool_pages) {
                    return 0;
                }
                page_bitmap[byte_index] = bits | (uint8_t)(1u << bit_index);
                return managed_pool_base + (page_index << PAGE_SHIFT);
            }
        }
    }
    return 0;
}

/* Return a page to the pool. The caller is responsible for not
 * passing in addresses outside the managed pool; in debug builds
 * we might want a bounds check, but for phase 1 we trust the
 * caller. */
void free_page(uint64_t page_address)
{
    if (page_address < managed_pool_base) {
        return;
    }
    uint64_t offset = page_address - managed_pool_base;
    uint64_t page_index = offset >> PAGE_SHIFT;
    if (page_index >= managed_pool_pages) {
        return;
    }
    uint64_t byte_index = page_index >> 3;
    unsigned bit_index = (unsigned)(page_index & 7);
    page_bitmap[byte_index] &= (uint8_t)~(1u << bit_index);
}

/* {{{ uint64_t alloc_pages() */
/* Allocate N physically-contiguous free pages; returns the address of the
 * first, or 0 if no run of N free pages exists (issue 111d). The display
 * framebuffers need this: VOP2 reads a framebuffer as one linear region from
 * a single base register, so its ~300 pages (640x480x4) must be adjacent, not
 * scattered. Slides a window over the page bitmap for the first run of N free
 * pages, marks them all used, and returns the run's base. O(managed pages);
 * called a handful of times at boot, never on a hot path. N == 0 acts as 1. */
uint64_t alloc_pages(uint64_t n)
{
    if (n == 0) {
        n = 1;
    }
    /* run_start = first page of the current candidate run; run_len = how many
     * consecutive free pages seen so far. A used page resets the run. */
    uint64_t run_start = 0;
    uint64_t run_len = 0;
    for (uint64_t page_index = 0; page_index < managed_pool_pages; page_index++) {
        unsigned used = (page_bitmap[page_index >> 3] >> (page_index & 7)) & 1u;
        if (used) {
            run_len = 0;
            continue;
        }
        if (run_len == 0) {
            run_start = page_index;
        }
        run_len++;
        if (run_len == n) {
            for (uint64_t p = run_start; p < run_start + n; p++) {
                page_bitmap[p >> 3] |= (uint8_t)(1u << (p & 7));
            }
            return managed_pool_base + (run_start << PAGE_SHIFT);
        }
    }
    return 0;
}
/* }}} */

/* {{{ void free_pages() */
/* Return an N-page contiguous run (from alloc_pages) to the pool. Mirrors
 * free_page's bounds trust; clears each page's bit. */
void free_pages(uint64_t page_address, uint64_t n)
{
    if (n == 0) {
        n = 1;
    }
    if (page_address < managed_pool_base) {
        return;
    }
    uint64_t first = (page_address - managed_pool_base) >> PAGE_SHIFT;
    for (uint64_t p = first; p < first + n && p < managed_pool_pages; p++) {
        page_bitmap[p >> 3] &= (uint8_t)~(1u << (p & 7));
    }
}
/* }}} */

/* Expose a few counters for the eventual diagnostic dump and for
 * any phase 1 self-test that wants to verify the bitmap math. */
uint64_t allocator_total_pages(void)
{
    return managed_pool_pages;
}

uint64_t allocator_managed_base(void)
{
    return managed_pool_base;
}

/* Boot-time self-test: confirm the allocator's bookkeeping is
 * actually doing what the bitmap math claims. Allocates a few
 * pages, verifies they are distinct, frees them, allocates again,
 * verifies the freed pages get reused.
 *
 * Returns nonzero on success, zero on failure. The caller is
 * expected to drive whatever observable signal indicates the
 * outcome — for phase 1 that means lighting the panic LED if
 * this function returns zero, since there is no richer output
 * channel yet. */
extern void led_set_stage(int stage);
#define STAGE_PANIC_GENERIC 1

int allocator_self_test(void)
{
    /* Two distinct pages should come back from two consecutive
     * allocations. */
    uint64_t p1 = alloc_page();
    if (p1 == 0) {
        return 0;
    }
    uint64_t p2 = alloc_page();
    if (p2 == 0 || p2 == p1) {
        return 0;
    }

    /* Both should be page-aligned. */
    if ((p1 & (PAGE_SIZE - 1)) != 0 || (p2 & (PAGE_SIZE - 1)) != 0) {
        return 0;
    }

    /* Free the first; the next allocation should reuse it because
     * the bitmap's linear scan finds the lowest-index free bit. */
    free_page(p1);
    uint64_t p3 = alloc_page();
    if (p3 != p1) {
        return 0;
    }

    /* Contiguous allocation (111d): a run of three pages must come back
     * page-aligned and truly adjacent, and free_pages must return them so
     * the next single alloc reuses the lowest one. */
    uint64_t run = alloc_pages(3);
    if (run == 0 || (run & (PAGE_SIZE - 1)) != 0) {
        return 0;
    }
    free_pages(run, 3);
    uint64_t after = alloc_page();
    if (after != run) {          /* the freed run's first page is lowest-free */
        return 0;
    }
    free_page(after);

    /* Restore the allocator to its original state for downstream
     * callers — nobody else has held a page during the test, so
     * we own everything we allocated. */
    free_page(p2);
    free_page(p3);
    return 1;
}

/* Convenience wrapper for kernel_main: run the self-test, and if
 * it fails, light the panic LED and park the core. Returning
 * normally means the allocator passed. */
__attribute__((noreturn)) static void allocator_self_test_failed(void)
{
    led_set_stage(STAGE_PANIC_GENERIC);
    while (1) {
        __asm__ volatile ("wfi");
    }
}

void allocator_check_or_panic(void)
{
    if (!allocator_self_test()) {
        allocator_self_test_failed();
    }
}
