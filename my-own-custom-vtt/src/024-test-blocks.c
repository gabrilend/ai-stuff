/*
 * 024-test-blocks.c -- pins down the storage every world array is made of.
 *
 * Three properties matter here and everything else follows from them: index zero
 * is never handed out, a freed record comes back rather than being lost, and a
 * copy of a block is indistinguishable from the original. The rollback ring
 * depends on the third one being exactly true.
 */

#include "020-test-harness.h"
#include "023-blocks.h"

#include <string.h>

/* A stand-in record, wide enough to be realistic and simple enough to check. */
struct sample {
    uint32_t a;
    uint32_t b;
};

/* {{{ static void test_sentinel */
static void test_sentinel(void)
{
    struct block b;

    TEST_CASE("index zero is claimed at birth and never handed out");

    CHECK(block_init(&b, sizeof(struct sample), 4) == 1);

    /* One record in use before anybody has asked for one: the sentinel. */
    CHECK_EQ(b.count, 1);

    {
        uint32_t first  = block_alloc(&b);
        uint32_t second = block_alloc(&b);

        CHECK(first != BLOCK_NOTHING);
        CHECK(second != BLOCK_NOTHING);
        CHECK(first != second);

        /* Nothing ever comes back as zero, because zero already means nothing. */
        CHECK_EQ(first, 1);
        CHECK_EQ(second, 2);
    }

    TEST_CASE("the sentinel reads as an empty record");

    {
        const struct sample *nothing = block_at_const(&b, BLOCK_NOTHING);
        CHECK_EQ(nothing->a, 0);
        CHECK_EQ(nothing->b, 0);
    }

    TEST_CASE("a bad index reads as the sentinel rather than crashing");

    /*
     * Nothing in this project checks a pointer for null. An index past the end
     * hands back the empty record so that a caller reading a bad index sees
     * emptiness and carries on -- the validator is what catches the bad index.
     */
    {
        const struct sample *past_end = block_at_const(&b, 9999);
        CHECK_EQ(past_end->a, 0);
        CHECK_EQ(past_end->b, 0);
    }

    block_release(&b);
}
/* }}} */

/* {{{ static void test_records_are_clean */
static void test_records_are_clean(void)
{
    struct block b;
    uint32_t index;

    TEST_CASE("a record is handed back zeroed");

    CHECK(block_init(&b, sizeof(struct sample), 2) == 1);

    index = block_alloc(&b);
    {
        struct sample *s = block_at(&b, index);
        CHECK_EQ(s->a, 0);
        CHECK_EQ(s->b, 0);

        s->a = 111;
        s->b = 222;
    }

    TEST_CASE("a reused record does not carry the last one's remains");

    block_free(&b, index);

    {
        uint32_t again = block_alloc(&b);
        struct sample *s;

        /* The hole is reused rather than the block growing past it. */
        CHECK_EQ(again, index);

        s = block_at(&b, again);
        CHECK_EQ(s->a, 0);
        CHECK_EQ(s->b, 0);
    }

    block_release(&b);
}
/* }}} */

/* {{{ static void test_free_list */
static void test_free_list(void)
{
    struct block b;
    uint32_t one;
    uint32_t two;
    uint32_t three;

    TEST_CASE("freed records come back in reverse order");

    CHECK(block_init(&b, sizeof(struct sample), 8) == 1);

    one   = block_alloc(&b);
    two   = block_alloc(&b);
    three = block_alloc(&b);

    block_free(&b, one);
    block_free(&b, two);

    /*
     * The free list is a stack threaded through the freed records themselves, so
     * the most recently freed comes back first. Pinned here not because the
     * order matters to any caller, but because it must be the *same* order every
     * run -- an allocator that hands out indices in a varying order would make
     * every world hash differ between runs.
     */
    CHECK_EQ(block_alloc(&b), two);
    CHECK_EQ(block_alloc(&b), one);

    TEST_CASE("freeing the sentinel is ignored, not obeyed");

    block_free(&b, BLOCK_NOTHING);
    CHECK_EQ(b.first_free, BLOCK_NOTHING);

    TEST_CASE("freeing past the end is ignored");

    block_free(&b, 9999);
    CHECK_EQ(b.first_free, BLOCK_NOTHING);

    CHECK(three != BLOCK_NOTHING);

    block_release(&b);
}
/* }}} */

/* {{{ static void test_growth */
static void test_growth(void)
{
    struct block b;
    uint32_t i;

    TEST_CASE("a block grows past its initial capacity");

    /* Deliberately tiny, so that growth happens several times. */
    CHECK(block_init(&b, sizeof(struct sample), 1) == 1);

    for (i = 0; i < 1000; i++) {
        uint32_t index = block_alloc(&b);
        struct sample *s;

        CHECK(index != BLOCK_NOTHING);

        s = block_at(&b, index);
        s->a = i;
        s->b = i * 2;
    }

    CHECK_EQ(b.count, 1001);

    TEST_CASE("growth does not disturb what was already there");

    /*
     * The reason references are indices and not pointers. Growth reallocates and
     * may move the whole block; an index survives that and a pointer does not.
     */
    for (i = 0; i < 1000; i++) {
        const struct sample *s = block_at_const(&b, i + 1);
        CHECK_EQ(s->a, i);
        CHECK_EQ(s->b, i * 2);
    }

    block_release(&b);
}
/* }}} */

/* {{{ static void test_copy */
static void test_copy(void)
{
    struct block source;
    struct block destination;
    uint32_t i;

    TEST_CASE("a copied block is indistinguishable from its original");

    /*
     * This is what the rollback ring does at the head of every turn, and it has
     * to be exact -- if a copy differs anywhere, an undone turn replays
     * differently for a reason nobody can see.
     */
    CHECK(block_init(&source, sizeof(struct sample), 4) == 1);
    CHECK(block_init(&destination, sizeof(struct sample), 1) == 1);

    for (i = 0; i < 100; i++) {
        uint32_t index = block_alloc(&source);
        struct sample *s = block_at(&source, index);
        s->a = i * 3;
        s->b = i * 7;
    }

    /* Free a couple, so the free list has something in it to be copied too. */
    block_free(&source, 10);
    block_free(&source, 20);

    CHECK(block_copy(&destination, &source) == 1);

    CHECK_EQ(destination.count, source.count);
    CHECK_EQ(destination.first_free, source.first_free);
    CHECK_EQ(memcmp(destination.data, source.data, block_bytes_used(&source)), 0);

    TEST_CASE("a copy between mismatched record sizes is refused");

    {
        struct block wrong;
        CHECK(block_init(&wrong, sizeof(struct sample) * 2, 4) == 1);
        CHECK(block_copy(&wrong, &source) == 0);
        block_release(&wrong);
    }

    block_release(&source);
    block_release(&destination);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_sentinel();
    test_records_are_clean();
    test_free_list();
    test_growth();
    test_copy();

    return vtt_test_finish("024-test-blocks");
}
/* }}} */
