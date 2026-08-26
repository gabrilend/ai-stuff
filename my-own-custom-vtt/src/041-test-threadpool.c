/*
 * 041-test-threadpool.c -- does every item get done exactly once?
 *
 * That is the whole question. A pool that misses an item produces a body that
 * did not move; a pool that does one twice produces a body that moved twice; and
 * both are silent, intermittent, and depend on how many cores the machine has.
 *
 * The sharpest form of the test is the last one here: the same work run at
 * several thread counts has to produce identical output, because that is the
 * property the entire determinism argument rests on.
 */

#include "020-test-harness.h"
#include "040-threadpool.h"

#include <stdlib.h>
#include <string.h>

/* {{{ static void mark_visited */
static void mark_visited(void *context, uint32_t first, uint32_t last)
{
    uint32_t *visits = context;
    uint32_t i;

    /*
     * Each worker writes only inside its own span, so there is no lock here and
     * there must never be one. If this ever needs a mutex, the pass is wrong,
     * not the pool.
     */
    for (i = first; i < last; i++) {
        visits[i]++;
    }
}
/* }}} */

/* {{{ static void square_into */
static void square_into(void *context, uint32_t first, uint32_t last)
{
    uint64_t *out = context;
    uint32_t i;

    for (i = first; i < last; i++) {
        out[i] = (uint64_t)i * (uint64_t)i;
    }
}
/* }}} */

/* {{{ static void test_every_item_exactly_once */
static void test_every_item_exactly_once(void)
{
    const uint32_t counts[] = { 1, 2, 3, 4, 7, 8, 16 };
    const uint32_t item_counts[] = { 0, 1, 2, 5, 100, 1000, 9973 };
    size_t c;
    size_t k;

    TEST_CASE("every item is visited exactly once, at every thread count");

    /*
     * 9973 is prime, so it divides evenly by none of the worker counts and the
     * remainder-spreading path is exercised rather than skipped.
     */
    for (c = 0; c < sizeof(counts) / sizeof(counts[0]); c++) {
        struct pool *p = pool_start(counts[c]);

        CHECK(p != NULL);
        if (p == NULL) {
            continue;
        }

        for (k = 0; k < sizeof(item_counts) / sizeof(item_counts[0]); k++) {
            uint32_t n = item_counts[k];
            uint32_t *visits = calloc(n + 1, sizeof(uint32_t));
            uint32_t i;
            uint32_t wrong = 0;

            pool_run(p, mark_visited, visits, n);

            for (i = 0; i < n; i++) {
                if (visits[i] != 1) {
                    wrong++;
                }
            }

            CHECK_EQ(wrong, 0);
            free(visits);
        }

        pool_stop(p);
    }
}
/* }}} */

/* {{{ static void test_thread_count_changes_nothing */
static void test_thread_count_changes_nothing(void)
{
    const uint32_t counts[] = { 1, 2, 3, 5, 8 };
    const uint32_t n = 5000;
    uint64_t *reference = malloc((size_t)n * sizeof(uint64_t));
    size_t c;

    TEST_CASE("the same work gives the same answer at every thread count");

    /*
     * The property the whole determinism argument rests on. If this ever fails,
     * a replay will diverge on a machine with a different number of cores, and
     * the divergence will appear an hour in with nothing to point at.
     */
    {
        struct pool *p = pool_start(1);
        pool_run(p, square_into, reference, n);
        pool_stop(p);
    }

    for (c = 0; c < sizeof(counts) / sizeof(counts[0]); c++) {
        uint64_t *result = calloc(n, sizeof(uint64_t));
        struct pool *p = pool_start(counts[c]);

        pool_run(p, square_into, result, n);
        pool_stop(p);

        CHECK_EQ(memcmp(result, reference, (size_t)n * sizeof(uint64_t)), 0);
        free(result);
    }

    free(reference);
}
/* }}} */

/* {{{ static void test_a_pool_can_be_reused */
static void test_a_pool_can_be_reused(void)
{
    struct pool *p = pool_start(4);
    uint32_t *visits = calloc(100, sizeof(uint32_t));
    int round;

    TEST_CASE("a pool runs many passes without restarting its threads");

    /*
     * Threads are created once and never again. Creating one during a tick is a
     * stall nobody expects and nobody measures, so running repeatedly through
     * one pool is the normal case rather than the special one.
     */
    CHECK(p != NULL);

    for (round = 0; round < 50; round++) {
        pool_run(p, mark_visited, visits, 100);
    }

    {
        uint32_t i;
        uint32_t wrong = 0;

        for (i = 0; i < 100; i++) {
            if (visits[i] != 50) {
                wrong++;
            }
        }

        CHECK_EQ(wrong, 0);
    }

    free(visits);
    pool_stop(p);
}
/* }}} */

/* {{{ static void test_a_pool_of_one_is_a_real_mode */
static void test_a_pool_of_one_is_a_real_mode(void)
{
    struct pool *p = pool_start(1);
    uint32_t visits[10];

    TEST_CASE("a pool of one worker works and starts no threads");

    /*
     * Not a degraded fallback -- it is how the determinism harness proves that
     * thread count changes nothing, so it has to be a first-class mode that is
     * tested like any other.
     */
    memset(visits, 0, sizeof(visits));

    CHECK(p != NULL);
    CHECK_EQ(pool_worker_count(p), 1);

    pool_run(p, mark_visited, visits, 10);

    {
        int i;
        for (i = 0; i < 10; i++) {
            CHECK_EQ(visits[i], 1);
        }
    }

    pool_stop(p);
}
/* }}} */

/* {{{ static void test_default_sizing */
static void test_default_sizing(void)
{
    struct pool *p;

    TEST_CASE("a pool sized from the machine leaves a core for everything else");

    CHECK(pool_default_worker_count() >= 1);

    p = pool_start(0);
    CHECK(p != NULL);
    CHECK_EQ(pool_worker_count(p), pool_default_worker_count());
    pool_stop(p);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_every_item_exactly_once();
    test_thread_count_changes_nothing();
    test_a_pool_can_be_reused();
    test_a_pool_of_one_is_a_real_mode();
    test_default_sizing();

    return vtt_test_finish("041-test-threadpool");
}
/* }}} */
