/*
 * 048-test-memory-each-core-owns.c — issue 203 (striped pages) and the
 * memory half of issue 210 (size-class blocks).
 *
 * General description: every core allocates and frees pages and blocks as
 * fast as it can, stamping each with who holds it, and hands a share of
 * them to a neighbour to free. If two owners were ever handed the same
 * page, a stamp would be found overwritten. At the end every core drains
 * its returns and the page count must balance exactly. Then the cost of
 * an allocate-and-free pair is measured with one core busy and with four,
 * and the second must not be much worse — if it were, stripes would be
 * sharing cache lines.
 */
#define _GNU_SOURCE
#include "../../src/engine/025-platform.h"
#include "../../src/engine/027-primitives.h"
#include "../../src/engine/028-page-stripes.h"
#include "../../src/engine/029-blocks.h"
#include "../026-platform-twin.h"
#include "../046-metrics.h"
#include "047-check.h"

#include <pthread.h>
#include <stdatomic.h>

#define CORES 4
#define ROUNDS 200000
#define HELD 64

struct stamp {
    uint32_t core;
    uint32_t serial;
};

/* A mailbox per core: pages another core wants this one to free. */
static _Atomic(void *) mailbox[CORES][HELD];
static _Atomic int corrupt;
static _Atomic int barrier_arrived;
static _Atomic int barrier_generation;
static int measuring_cores;
static uint64_t one_core_ns[CORES];
static uint64_t four_core_ns[CORES];
static size_t free_after_pages;

/* {{{ barrier */
/* Every core waits here until all have arrived. The last to arrive resets
 * the count and moves the generation on, which releases the rest. */
static void barrier(int total)
{
    int generation = atomic_load(&barrier_generation);
    if (atomic_fetch_add(&barrier_arrived, 1) + 1 == total) {
        atomic_store(&barrier_arrived, 0);
        atomic_fetch_add(&barrier_generation, 1);
    } else {
        while (atomic_load(&barrier_generation) == generation) {
        }
    }
}
/* }}} */

/* {{{ churn */
static void churn(int core)
{
    void *held[HELD] = { 0 };
    uint32_t serial = 0;
    uint64_t rng = 0x1234567ull * (uint64_t)(core + 1);
    for (int r = 0; r < ROUNDS; r++) {
        rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17;
        int slot = (int)(rng % HELD);
        /* Free what a neighbour posted to us, checking its stamp. */
        void *posted = atomic_exchange(&mailbox[core][slot], NULL);
        if (posted) {
            page_free(core, posted);
        }
        if (held[slot]) {
            struct stamp *s = held[slot];
            if (s->core != (uint32_t)core) {
                atomic_fetch_add(&corrupt, 1);
            }
            /* One in four goes to a neighbour to free: the foreign-free
             * path through the owner's returns list. */
            if ((rng >> 20) % 4 == 0) {
                void *expected = NULL;
                int next = (core + 1) % CORES;
                if (!atomic_compare_exchange_strong(&mailbox[next][slot], &expected, held[slot])) {
                    page_free(core, held[slot]);
                }
            } else {
                page_free(core, held[slot]);
            }
            held[slot] = NULL;
        } else {
            struct stamp *s = page_alloc(core);
            if (!s) {
                atomic_fetch_add(&corrupt, 1000);
                continue;
            }
            s->core = (uint32_t)core;
            s->serial = serial++;
            held[slot] = s;
        }
    }
    for (int k = 0; k < HELD; k++) {
        if (held[k]) {
            page_free(core, held[k]);
        }
    }
}
/* }}} */

/* {{{ drain_mailboxes */
static void drain_mailboxes(int core)
{
    for (int k = 0; k < HELD; k++) {
        void *posted = atomic_exchange(&mailbox[core][k], NULL);
        if (posted) {
            page_free(core, posted);
        }
    }
}
/* }}} */

/* {{{ drain_returns */
/* One allocation drains this core's returns list; give the page back.
 * Only safe once every core has finished freeing foreign pages, or a
 * late foreign free lands on a list already drained. */
static void drain_returns(int core)
{
    void *p = page_alloc(core);
    page_free(core, p);
}
/* }}} */

/* {{{ block_churn */
static void block_churn(int core)
{
    void *held[HELD] = { 0 };
    size_t sizes[HELD];
    uint64_t rng = 0x9876543ull * (uint64_t)(core + 1);
    for (int r = 0; r < ROUNDS; r++) {
        rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17;
        int slot = (int)(rng % HELD);
        if (held[slot]) {
            uint8_t *b = held[slot];
            for (size_t i = 0; i < sizes[slot]; i++) {
                if (b[i] != (uint8_t)(core + 1)) {
                    atomic_fetch_add(&corrupt, 1);
                    break;
                }
            }
            block_free(core, b);
            held[slot] = NULL;
        } else {
            sizes[slot] = 8 + (size_t)(rng >> 40) % 3000;
            uint8_t *b = block_alloc(core, sizes[slot]);
            for (size_t i = 0; i < sizes[slot]; i++) {
                b[i] = (uint8_t)(core + 1);
            }
            held[slot] = b;
        }
    }
    for (int k = 0; k < HELD; k++) {
        if (held[k]) {
            block_free(core, held[k]);
        }
    }
}
/* }}} */

/* {{{ measure */
static void measure(int core, uint64_t *pair_ns)
{
    if (core >= measuring_cores) {
        return;
    }
    const int pairs = 100000;
    uint64_t start = platform_now_ns();
    for (int i = 0; i < pairs; i++) {
        void *p = page_alloc(core);
        page_free(core, p);
    }
    pair_ns[core] = (platform_now_ns() - start) / pairs;
}
/* }}} */

/* {{{ entry */
static void entry(int core)
{
    churn(core);
    barrier(CORES);
    drain_mailboxes(core);
    barrier(CORES);
    drain_returns(core);
    barrier(CORES);
    /* Pages balance here, before blocks are cut: a page cut into blocks
     * stays with the block lists for good, by design (029-blocks.c). */
    if (core == 0) {
        free_after_pages = stripes_free_pages();
    }
    barrier(CORES);
    block_churn(core);
    barrier(CORES);
    measuring_cores = 1;
    barrier(CORES);
    measure(core, one_core_ns);
    barrier(CORES);
    if (core == 0) {
        measuring_cores = CORES;
    }
    barrier(CORES);
    measure(core, four_core_ns);
}
/* }}} */

int main(void)
{
    twin_platform_init(CORES, (size_t)256 << 20);
    twin_platform_set_log(NULL, 0);
    stripes_init(CORES, 4);
    size_t free_at_start = stripes_free_pages();

    uint64_t start = platform_now_ns();
    platform_start_cores(CORES, entry);
    uint64_t elapsed = platform_now_ns() - start;

    CHECK(atomic_load(&corrupt) == 0, "no page or block was ever held by two owners (%d stamps wrong)",
          atomic_load(&corrupt));
    CHECK(free_after_pages == free_at_start,
          "every page came back: %zu free at start, %zu after the page churn", free_at_start, free_after_pages);

    uint64_t allocated = 0, freed = 0, returned = 0, taken = 0;
    for (int c = 0; c < CORES; c++) {
        struct stripe_stats s;
        stripes_stats(c, &s);
        allocated += s.pages_allocated;
        freed += s.pages_freed;
        returned += s.pages_returned;
        taken += s.stripes_taken;
    }
    CHECK(returned > 0, "the foreign-free path was exercised (%llu pages returned)", (unsigned long long)returned);

    /* Measurement: the one-core number is the baseline; four cores at
     * once should cost about the same per pair, since nothing is shared.
     * Recorded, and checked only loosely — a laptop's scheduler is not
     * the device's. */
    uint64_t one = one_core_ns[0];
    uint64_t four = 0;
    for (int c = 0; c < CORES; c++) {
        four += four_core_ns[c];
    }
    four /= CORES;
    CHECK(four < one * 4 + 200, "four cores allocating at once are not wildly slower per pair (%llu vs %llu ns)",
          (unsigned long long)four, (unsigned long long)one);

    metrics_open("048-memory-each-core-owns");
    metric_record("stripes.pair_ns.one_core", (double)one, "ns", "stripes-pair-cost",
                  "one page allocated and freed, one core busy");
    metric_record("stripes.pair_ns.four_cores", (double)four, "ns", "stripes-pair-cost",
                  "one page allocated and freed, all four cores busy at once");
    metric_record("stripes.contention_ratio", one ? (double)four / (double)one : 0, "x", "stripes-contention",
                  "four-core cost per pair divided by one-core cost; 1.0 means nothing is shared");
    metric_record("stripes.foreign_frees", (double)returned, "pages", "stripes-foreign-free",
                  "pages freed by a core that did not own them, routed home through returns lists");
    metric_record("stripes.pages_allocated", (double)allocated, "pages", "stripes-churn",
                  "page allocations over the whole run, all cores");
    metric_record("stripes.pages_freed_by_owner", (double)freed, "pages", "stripes-foreign-free",
                  "pages freed by the core that owned them (no hand-back needed)");
    metric_record("stripes.stripes_taken", (double)taken, "stripes", "stripes-taking",
                  "stripes claimed from the unowned pool after startup");
    metric_record("stripes.churn_ms", (double)elapsed / 1e6, "ms", "stripes-churn",
                  "wall time for the whole churn: pages, blocks and both measurements");
    metrics_close();
    CHECK_DONE("048 memory each core owns");
}
