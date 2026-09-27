/*
 * 028-page-stripes.c — the striped page allocator (issue 203).
 *
 * General description: one bit per 4 KB page says whether the page is in
 * use. The bits are grouped into stripes of 512 pages — exactly one 64-byte
 * cache line of bitmap — and each stripe has one owner. Owners only ever
 * search their own stripes, so the everyday allocation never meets another
 * core. When an owner runs dry it takes a stripe from the pool of stripes
 * nobody has claimed yet. A page freed by someone other than its owner is
 * pushed onto the owner's returns list, which the owner empties the next
 * time it allocates.
 *
 * Layout of the pool:
 *
 *   stripe 0 ┌──────────────┬──────────────┬─────────────────────────┐
 *            │ bitmap       │ owner table  │ per-owner stripe lists  │ ... pages
 *            └──────────────┴──────────────┴─────────────────────────┘
 *            these first pages are marked used in the bitmap at startup,
 *            so the allocator's own bookkeeping lives inside the pool it
 *            manages, as phase 1's allocator (108) already did.
 *
 * Why every bitmap write is an atomic word operation even though only the
 * owner writes its line: parking (issue 213) must be able to take back a
 * page it released, without asking the page's owner, and the owner may be
 * allocating from the same word at that instant. An atomic OR/AND on a line
 * that only one core normally touches costs almost nothing — the line is
 * already in that core's cache — and it closes that one race without a
 * lock. The issue's "no atomic at all" became "no contended atomic".
 */
#include "025-platform.h"
#include "027-primitives.h"
#include "028-page-stripes.h"

#define WORDS_PER_STRIPE (STRIPE_PAGES / 64)   /* 8 words of 64 bits = one cache line */
#define OWNER_SLOTS (OWNER_OUTSIDE + 1)
#define UNOWNED 0xFFu

/* One owner's private state, alone on its cache line(s). Only the owner
 * reads or writes anything here except `returns`, which other owners push
 * onto. */
struct owner_state {
    void    *returns;          /* stack of pages handed back by others; next pointer in each page's first word */
    int32_t *stripes;          /* the stripe numbers this owner holds */
    int32_t  n_stripes;        /* how many */
    int32_t  bookmark;         /* which of its stripes the last search stopped in */
    struct stripe_stats stats;
} LINE_ALIGNED;

static uint64_t          *bitmap;        /* one bit per page, 1 = in use */
static uint8_t           *owner_of;      /* one byte per stripe: owner number or UNOWNED */
static uint8_t           *pool;          /* first byte of the pool */
static size_t             total_pages;
static int                total_stripes;
static int                core_total;
static struct owner_state owners[OWNER_SLOTS];

/* {{{ page_index */
static size_t page_index(void *page)
{
    return (size_t)((uint8_t *)page - pool) >> PAGE_SHIFT_BITS;
}
/* }}} */

/* {{{ page_address */
static void *page_address(size_t index)
{
    return pool + (index << PAGE_SHIFT_BITS);
}
/* }}} */

/* {{{ check_owner */
static void check_owner(int owner)
{
    if (owner != OWNER_OUTSIDE && (owner < 0 || owner >= core_total)) {
        platform_halt("page allocator: asked by an owner that does not exist");
    }
}
/* }}} */

/* {{{ give_stripe */
static void give_stripe(int owner, int stripe)
{
    struct owner_state *o = &owners[owner];
    o->stripes[o->n_stripes] = stripe;
    /* Publish the stripe to the owner's list only after it is written;
     * only the owner reads this list, so ordering is for form's sake. */
    o->n_stripes++;
}
/* }}} */

/* {{{ stripes_init */
void stripes_init(int cores, int initial_stripes)
{
    core_total    = cores;
    pool          = platform_pool_base();
    total_pages   = platform_pool_size() >> PAGE_SHIFT_BITS;
    total_stripes = (int)(total_pages / STRIPE_PAGES);
    if (total_stripes < 2) {
        platform_halt("page allocator: the pool is smaller than two stripes");
    }

    /* Bookkeeping sizes, then carve them from the bottom of stripe 0. */
    size_t bitmap_bytes = (size_t)total_stripes * CACHE_LINE;
    size_t owner_bytes  = round_up((size_t)total_stripes, 64);
    size_t list_bytes   = (size_t)OWNER_SLOTS * (size_t)total_stripes * sizeof(int32_t);
    size_t meta_bytes   = round_up(bitmap_bytes + owner_bytes + list_bytes, PAGE_BYTES);
    size_t meta_pages   = meta_bytes >> PAGE_SHIFT_BITS;
    if (meta_pages >= STRIPE_PAGES) {
        platform_halt("page allocator: bookkeeping does not fit in the first stripe");
    }

    bitmap   = (uint64_t *)pool;
    owner_of = pool + bitmap_bytes;
    int32_t *lists = (int32_t *)(pool + bitmap_bytes + owner_bytes);

    bytes_zero(bitmap, bitmap_bytes);
    for (int s = 0; s < total_stripes; s++) {
        owner_of[s] = UNOWNED;
    }
    for (size_t p = 0; p < meta_pages; p++) {
        bitmap[p / 64] |= 1ull << (p % 64);
    }

    for (int o = 0; o < OWNER_SLOTS; o++) {
        bytes_zero(&owners[o], sizeof owners[o]);
        owners[o].stripes = lists + (size_t)o * (size_t)total_stripes;
    }

    /* Stripe 0 holds the bookkeeping and goes to the outside owner, which
     * is the only owner allocating before the cores start. Then each core
     * and the outside owner receive `initial_stripes` more, interleaved so
     * every owner's memory is spread through the pool rather than lumped
     * (issue 203: striped rather than quartered). */
    owner_of[0] = OWNER_OUTSIDE;
    give_stripe(OWNER_OUTSIDE, 0);
    int next = 1;
    for (int round = 0; round < initial_stripes; round++) {
        for (int o = 0; o <= cores; o++) {
            int who = (o == cores) ? OWNER_OUTSIDE : o;
            if (next >= total_stripes) {
                break;
            }
            owner_of[next] = (uint8_t)who;
            give_stripe(who, next);
            next++;
        }
    }
}
/* }}} */

/* {{{ drain_returns */
/* Empty this owner's returns list, marking each page free in our own
 * stripes. One atomic swap takes the whole list; nobody else pops from it,
 * so there is no ABA hazard. */
static void drain_returns(int owner)
{
    struct owner_state *o = &owners[owner];
    void *page = atomic_swap(&o->returns, (void *)0);
    while (page) {
        void *next = *(void **)page;
        size_t i = page_index(page);
        atomic_and(&bitmap[i / 64], ~(1ull << (i % 64)));
        o->stats.pages_returned++;
        page = next;
    }
}
/* }}} */

/* {{{ take_unowned_stripe */
/* Claim one stripe nobody owns. Answers its number, or -1 if none is
 * left. This is the one place two owners can meet, and it is one
 * compare-and-swap on a byte nobody else writes afterwards. */
static int take_unowned_stripe(int owner)
{
    for (int s = 1; s < total_stripes; s++) {
        uint8_t expected = UNOWNED;
        if (atomic_load_relaxed(&owner_of[s]) == UNOWNED &&
            atomic_cas(&owner_of[s], &expected, (uint8_t)owner)) {
            give_stripe(owner, s);
            owners[owner].stats.stripes_taken++;
            return s;
        }
    }
    return -1;
}
/* }}} */

/* {{{ alloc_in_stripe */
/* Find and mark one free page in one stripe. */
static void *alloc_in_stripe(int owner, int stripe)
{
    struct owner_state *o = &owners[owner];
    uint64_t *words = &bitmap[(size_t)stripe * WORDS_PER_STRIPE];
    for (int w = 0; w < WORDS_PER_STRIPE; w++) {
        o->stats.scan_steps++;
        uint64_t seen = atomic_load_relaxed(&words[w]);
        while (seen != ~0ull) {
            int bit = __builtin_ctzll(~seen);
            uint64_t mask = 1ull << bit;
            uint64_t before = atomic_or(&words[w], mask);
            /* Two outcomes: the bit was still clear, so the page is ours;
             * or a parked program reclaimed it an instant ago, so look
             * again with what we now know. */
            if (!(before & mask)) {
                size_t index = (size_t)stripe * STRIPE_PAGES + (size_t)w * 64 + (size_t)bit;
                o->stats.pages_allocated++;
                return page_address(index);
            }
            seen = before | mask;
        }
    }
    return (void *)0;
}
/* }}} */

/* {{{ page_alloc */
void *page_alloc(int owner)
{
    check_owner(owner);
    struct owner_state *o = &owners[owner];
    drain_returns(owner);

    /* Search our own stripes from where we last stopped, wrapping once. */
    for (int k = 0; k < o->n_stripes; k++) {
        int slot = (o->bookmark + k) % o->n_stripes;
        void *page = alloc_in_stripe(owner, o->stripes[slot]);
        if (page) {
            o->bookmark = slot;
            return page;
        }
    }
    /* Our stripes are full. Take a fresh one. */
    int stripe = take_unowned_stripe(owner);
    if (stripe >= 0) {
        o->bookmark = o->n_stripes - 1;
        return alloc_in_stripe(owner, stripe);
    }
    say_line("page allocator: owner %d is out of pages and no unowned stripe is left (%u of %u pages free elsewhere)",
        owner, (unsigned)stripes_free_pages(), (unsigned)total_pages);
    return (void *)0;
}
/* }}} */

/* {{{ run_fits */
/* Is there a run of `count` clear bits starting at bit `start` of this
 * stripe? */
static int run_fits(const uint64_t *words, int start, int count)
{
    for (int b = start; b < start + count; b++) {
        if (atomic_load_relaxed(&words[b / 64]) & (1ull << (b % 64))) {
            return 0;
        }
    }
    return 1;
}
/* }}} */

/* {{{ run_mark */
/* Mark bits [start, start+count) used. If a reclaim raced us to any of
 * them, undo what we marked and answer 0. */
static int run_mark(uint64_t *words, int start, int count)
{
    for (int b = start; b < start + count; b++) {
        uint64_t mask = 1ull << (b % 64);
        uint64_t before = atomic_or(&words[b / 64], mask);
        if (before & mask) {
            for (int u = start; u < b; u++) {
                atomic_and(&words[u / 64], ~(1ull << (u % 64)));
            }
            return 0;
        }
    }
    return 1;
}
/* }}} */

/* {{{ alloc_run_in_stripe */
static void *alloc_run_in_stripe(int owner, int stripe, int count)
{
    uint64_t *words = &bitmap[(size_t)stripe * WORDS_PER_STRIPE];
    for (int start = 0; start + count <= STRIPE_PAGES; start++) {
        owners[owner].stats.scan_steps++;
        if (run_fits(words, start, count) && run_mark(words, start, count)) {
            owners[owner].stats.pages_allocated += (uint64_t)count;
            return page_address((size_t)stripe * STRIPE_PAGES + (size_t)start);
        }
    }
    return (void *)0;
}
/* }}} */

/* {{{ pages_alloc_run */
void *pages_alloc_run(int owner, int count)
{
    check_owner(owner);
    if (count == 1) {
        return page_alloc(owner);
    }
    if (count < 1 || count > STRIPE_PAGES) {
        say_line("page allocator: a run of %d pages was asked for; runs are 1..%d", count, STRIPE_PAGES);
        return (void *)0;
    }
    struct owner_state *o = &owners[owner];
    drain_returns(owner);
    for (int k = 0; k < o->n_stripes; k++) {
        void *first = alloc_run_in_stripe(owner, o->stripes[k], count);
        if (first) {
            return first;
        }
    }
    int stripe = take_unowned_stripe(owner);
    if (stripe >= 0) {
        return alloc_run_in_stripe(owner, stripe, count);
    }
    say_line("page allocator: owner %d found no run of %d pages and no unowned stripe is left", owner, count);
    return (void *)0;
}
/* }}} */

/* {{{ page_owner */
int page_owner(void *page)
{
    size_t i = page_index(page);
    uint8_t o = atomic_load_acquire(&owner_of[i / STRIPE_PAGES]);
    return o == UNOWNED ? -1 : (int)o;
}
/* }}} */

/* {{{ page_free */
void page_free(int owner, void *page)
{
    check_owner(owner);
    size_t i = page_index(page);
    if (i >= total_pages) {
        platform_halt("page allocator: freeing a page outside the pool");
    }
    int belongs = page_owner(page);
    /* Two paths: our own page (clear its bit — nobody else writes this
     * line), or somebody else's (hand it back through their returns list
     * so that only its owner ever clears the bit). */
    if (belongs == owner) {
        uint64_t before = atomic_and(&bitmap[i / 64], ~(1ull << (i % 64)));
        if (!(before & (1ull << (i % 64)))) {
            platform_halt("page allocator: a page was freed twice");
        }
        owners[owner].stats.pages_freed++;
        return;
    }
    if (belongs < 0) {
        platform_halt("page allocator: freeing a page in a stripe nobody owns");
    }
    struct owner_state *o = &owners[belongs];
    void *head = atomic_load_relaxed(&o->returns);
    do {
        *(void **)page = head;
    } while (!atomic_cas(&o->returns, &head, page));
}
/* }}} */

/* {{{ pages_free_run */
void pages_free_run(int owner, void *first, int count)
{
    for (int k = 0; k < count; k++) {
        page_free(owner, (uint8_t *)first + ((size_t)k << PAGE_SHIFT_BITS));
    }
}
/* }}} */

/* {{{ page_is_free */
int page_is_free(void *page)
{
    size_t i = page_index(page);
    return !(atomic_load_acquire(&bitmap[i / 64]) & (1ull << (i % 64)));
}
/* }}} */

/* {{{ page_reclaim */
int page_reclaim(void *page)
{
    size_t i = page_index(page);
    uint64_t mask = 1ull << (i % 64);
    uint64_t before = atomic_or(&bitmap[i / 64], mask);
    return !(before & mask);
}
/* }}} */

/* {{{ page_release_direct */
void page_release_direct(void *page)
{
    size_t i = page_index(page);
    uint64_t mask = 1ull << (i % 64);
    uint64_t before = atomic_and(&bitmap[i / 64], ~mask);
    if (!(before & mask)) {
        platform_halt("page allocator: a parked page was released twice");
    }
}
/* }}} */

/* {{{ stripes_stats */
void stripes_stats(int owner, struct stripe_stats *out)
{
    *out = owners[owner].stats;
}
/* }}} */

/* {{{ stripes_total_pages */
size_t stripes_total_pages(void)
{
    return total_pages;
}
/* }}} */

/* {{{ stripes_free_pages */
size_t stripes_free_pages(void)
{
    size_t used = 0;
    size_t words = (size_t)total_stripes * WORDS_PER_STRIPE;
    for (size_t w = 0; w < words; w++) {
        used += (size_t)bits_set(atomic_load_relaxed(&bitmap[w]));
    }
    return total_pages - used;
}
/* }}} */

/* {{{ stripes_total */
int stripes_total(void)
{
    return total_stripes;
}
/* }}} */

/* {{{ stripes_unowned */
int stripes_unowned(void)
{
    int n = 0;
    for (int s = 0; s < total_stripes; s++) {
        n += atomic_load_relaxed(&owner_of[s]) == UNOWNED;
    }
    return n;
}
/* }}} */
