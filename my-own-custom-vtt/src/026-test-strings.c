/*
 * 026-test-strings.c -- pins down the pool that holds every name in the world.
 *
 * Two properties carry the weight. A pointer handed out by a read stays valid
 * for the life of the pool, which is only true because the pool never grows. And
 * nothing is ever quietly shortened -- a name that will not fit is refused, and
 * the caller has to say so.
 */

#include "020-test-harness.h"
#include "025-strings.h"

#include <string.h>

/* {{{ static int matches */
static int matches(const struct string_pool *pool, uint32_t offset, const char *expected)
{
    uint32_t length = 0;
    const char *text = string_pool_read(pool, offset, &length);
    size_t expected_length = strlen(expected);

    if ((size_t)length != expected_length) {
        return 0;
    }

    return memcmp(text, expected, expected_length) == 0;
}
/* }}} */

/* {{{ static void test_empty_string_at_zero */
static void test_empty_string_at_zero(void)
{
    struct string_pool pool;

    TEST_CASE("offset zero is a real empty string, not a special case");

    CHECK(string_pool_init(&pool, 1024) == 1);
    CHECK(matches(&pool, STRING_NOTHING, ""));

    {
        uint32_t length = 99;
        string_pool_read(&pool, STRING_NOTHING, &length);
        CHECK_EQ(length, 0);
    }

    string_pool_release(&pool);
}
/* }}} */

/* {{{ static void test_round_trip */
static void test_round_trip(void)
{
    struct string_pool pool;
    uint32_t tavern;
    uint32_t forest;
    uint32_t cellar;

    TEST_CASE("names go in and come back out");

    CHECK(string_pool_init(&pool, 1024) == 1);

    tavern = string_pool_add(&pool, "The Tavern", 10);
    forest = string_pool_add(&pool, "The Forest", 10);
    cellar = string_pool_add(&pool, "The Cellar Beneath", 18);

    CHECK(tavern != STRING_NOTHING);
    CHECK(forest != STRING_NOTHING);
    CHECK(cellar != STRING_NOTHING);

    CHECK(matches(&pool, tavern, "The Tavern"));
    CHECK(matches(&pool, forest, "The Forest"));
    CHECK(matches(&pool, cellar, "The Cellar Beneath"));

    TEST_CASE("distinct names get distinct offsets");

    CHECK(tavern != forest);
    CHECK(forest != cellar);

    TEST_CASE("a name may be empty without being nothing");

    {
        uint32_t nameless = string_pool_add(&pool, "", 0);
        CHECK(nameless != STRING_NOTHING);
        CHECK(matches(&pool, nameless, ""));
    }

    string_pool_release(&pool);
}
/* }}} */

/* {{{ static void test_pointers_survive */
static void test_pointers_survive(void)
{
    struct string_pool pool;
    uint32_t first;
    const char *held;
    uint32_t length = 0;
    int i;

    TEST_CASE("a pointer from an early read survives every later append");

    /*
     * The single property the whole design of this file exists to provide. If
     * the pool ever grew, this pointer would be looking at freed memory, and the
     * failure would appear only in a busy session.
     */
    CHECK(string_pool_init(&pool, 4096) == 1);

    first = string_pool_add(&pool, "The Tavern", 10);
    held = string_pool_read(&pool, first, &length);

    for (i = 0; i < 100; i++) {
        string_pool_add(&pool, "filler", 6);
    }

    CHECK_EQ(length, 10);
    CHECK_EQ(memcmp(held, "The Tavern", 10), 0);

    string_pool_release(&pool);
}
/* }}} */

/* {{{ static void test_refusals */
static void test_refusals(void)
{
    struct string_pool pool;
    char oversized[STRING_MAX_LENGTH + 2];

    TEST_CASE("a name past the maximum length is refused, not shortened");

    CHECK(string_pool_init(&pool, 4096) == 1);

    memset(oversized, 'x', sizeof(oversized));
    CHECK_EQ(string_pool_add(&pool, oversized, STRING_MAX_LENGTH + 1), STRING_NOTHING);

    /* And the pool is untouched by the refusal. */
    CHECK_EQ(pool.used, 2);

    TEST_CASE("a name of exactly the maximum length fits");

    CHECK(string_pool_add(&pool, oversized, STRING_MAX_LENGTH) != STRING_NOTHING);

    string_pool_release(&pool);

    TEST_CASE("a full pool refuses rather than growing");

    /*
     * Growing would move the pool and invalidate every pointer a reader is
     * holding. Refusing surfaces the fact that the world claimed fewer names
     * than it actually has, which is worth knowing.
     */
    CHECK(string_pool_init(&pool, 16) == 1);

    CHECK(string_pool_add(&pool, "abcdefgh", 8) != STRING_NOTHING);
    CHECK_EQ(string_pool_add(&pool, "abcdefgh", 8), STRING_NOTHING);

    string_pool_release(&pool);
}
/* }}} */

/* {{{ static void test_bad_offsets */
static void test_bad_offsets(void)
{
    struct string_pool pool;

    TEST_CASE("an offset past the end reads as empty rather than crashing");

    CHECK(string_pool_init(&pool, 1024) == 1);
    string_pool_add(&pool, "The Tavern", 10);

    CHECK(matches(&pool, 9999, ""));

    TEST_CASE("the validator can tell a good offset from a bad one");

    {
        uint32_t good = string_pool_add(&pool, "The Forest", 10);

        CHECK(string_pool_offset_is_valid(&pool, STRING_NOTHING) == 1);
        CHECK(string_pool_offset_is_valid(&pool, good) == 1);
        CHECK(string_pool_offset_is_valid(&pool, 9999) == 0);
    }

    string_pool_release(&pool);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_empty_string_at_zero();
    test_round_trip();
    test_pointers_survive();
    test_refusals();
    test_bad_offsets();

    return vtt_test_finish("026-test-strings");
}
/* }}} */
