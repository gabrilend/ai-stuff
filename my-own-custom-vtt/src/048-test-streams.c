/*
 * 048-test-streams.c -- does adding a roll here move the rolls over there?
 *
 * That is the question the whole design exists to answer with "no". If it ever
 * answers "yes", a seed stops meaning anything the moment somebody changes the
 * code, which is exactly when reproducing a session matters most.
 */

#include "020-test-harness.h"
#include "047-streams.h"

#include <string.h>

/* {{{ static void test_same_seed_same_sequence */
static void test_same_seed_same_sequence(void)
{
    struct stream_registry a;
    struct stream_registry b;
    uint32_t sa;
    uint32_t sb;
    int i;

    TEST_CASE("the same seed and name give the same sequence");

    streams_init(&a, 12345);
    streams_init(&b, 12345);

    sa = stream_named(&a, "attack");
    sb = stream_named(&b, "attack");

    for (i = 0; i < 100; i++) {
        CHECK_EQ(stream_next(&a, sa), stream_next(&b, sb));
    }

    TEST_CASE("a different seed gives a different sequence");

    {
        struct stream_registry c;
        uint32_t sc;
        int same = 0;

        streams_init(&c, 12346);
        sc = stream_named(&c, "attack");
        streams_init(&a, 12345);
        sa = stream_named(&a, "attack");

        for (i = 0; i < 20; i++) {
            if (stream_next(&a, sa) == stream_next(&c, sc)) {
                same++;
            }
        }

        CHECK_EQ(same, 0);
    }
}
/* }}} */

/* {{{ static void test_streams_are_independent */
static void test_streams_are_independent(void)
{
    struct stream_registry untouched;
    struct stream_registry disturbed;
    uint32_t a_wandering;
    uint32_t b_attack;
    uint32_t b_wandering;
    int i;

    TEST_CASE("drawing from one stream does not move another");

    /*
     * THE POINT OF THE WHOLE FILE.
     *
     * One registry draws only from "wandering-monsters". The other draws fifty
     * times from "attack" first -- standing in for a ruleset that started
     * checking one extra condition -- and then draws from
     * "wandering-monsters" too.
     *
     * With a single shared generator the second registry's monsters would be
     * completely different, and a written-down seed would have quietly stopped
     * meaning anything.
     */
    streams_init(&untouched, 999);
    streams_init(&disturbed, 999);

    a_wandering = stream_named(&untouched, "wandering-monsters");

    b_attack = stream_named(&disturbed, "attack");
    for (i = 0; i < 50; i++) {
        stream_next(&disturbed, b_attack);
    }
    b_wandering = stream_named(&disturbed, "wandering-monsters");

    for (i = 0; i < 50; i++) {
        CHECK_EQ(stream_next(&untouched, a_wandering),
                 stream_next(&disturbed, b_wandering));
    }

    TEST_CASE("and the order streams are created in does not matter either");

    /*
     * The subtler version. A ruleset that registers its streams in a different
     * order between two builds must still get the same numbers, or the seed
     * depends on the order of some initialisation nobody is watching.
     */
    {
        struct stream_registry forwards;
        struct stream_registry backwards;
        uint32_t f;
        uint32_t b;

        streams_init(&forwards, 4207);
        stream_named(&forwards, "attack");
        f = stream_named(&forwards, "loot");

        streams_init(&backwards, 4207);
        b = stream_named(&backwards, "loot");
        stream_named(&backwards, "attack");

        for (i = 0; i < 50; i++) {
            CHECK_EQ(stream_next(&forwards, f), stream_next(&backwards, b));
        }
    }
}
/* }}} */

/* {{{ static void test_naming */
static void test_naming(void)
{
    struct stream_registry r;
    char oversized[STREAM_NAME_MAX + 8];

    TEST_CASE("the same name always gives the same stream");

    streams_init(&r, 1);

    CHECK_EQ(stream_named(&r, "attack"), stream_named(&r, "attack"));
    CHECK(stream_named(&r, "attack") != stream_named(&r, "defence"));
    CHECK_EQ(streams_count(&r), 2);

    TEST_CASE("an empty or over-long name is refused, not truncated");

    /*
     * Two names differing only past a cut would silently become one stream, and
     * the two things drawing from them would start interfering with nothing
     * reporting it.
     */
    memset(oversized, 'x', sizeof(oversized));
    oversized[sizeof(oversized) - 1] = '\0';

    CHECK_EQ(stream_named(&r, ""), STREAMS_MAX);
    CHECK_EQ(stream_named(&r, oversized), STREAMS_MAX);

    TEST_CASE("a full table is refused rather than reusing a stream");

    {
        struct stream_registry full;
        char name[16];
        uint32_t i;

        streams_init(&full, 1);

        for (i = 0; i < STREAMS_MAX; i++) {
            name[0] = 's';
            name[1] = (char)('a' + (i / 26));
            name[2] = (char)('a' + (i % 26));
            name[3] = '\0';
            CHECK(stream_named(&full, name) < STREAMS_MAX);
        }

        CHECK_EQ(stream_named(&full, "one-too-many"), STREAMS_MAX);
    }
}
/* }}} */

/* {{{ static void test_bounded_draws */
static void test_bounded_draws(void)
{
    struct stream_registry r;
    uint32_t s;
    int i;

    TEST_CASE("a bounded draw stays inside its bound");

    streams_init(&r, 77);
    s = stream_named(&r, "dice");

    for (i = 0; i < 2000; i++) {
        uint64_t v = stream_below(&r, s, 6);
        CHECK(v < 6);
    }

    TEST_CASE("a die is inclusive at both ends");

    {
        int seen_low = 0;
        int seen_high = 0;

        for (i = 0; i < 2000; i++) {
            int64_t v = stream_between(&r, s, 1, 6);

            CHECK(v >= 1);
            CHECK(v <= 6);

            if (v == 1) seen_low = 1;
            if (v == 6) seen_high = 1;
        }

        /* A d6 that never rolls a 6 is a d5 wearing the wrong label. */
        CHECK_EQ(seen_low, 1);
        CHECK_EQ(seen_high, 1);
    }

    TEST_CASE("a range spanning zero does not overflow");

    for (i = 0; i < 500; i++) {
        int64_t v = stream_between(&r, s, -10, 10);
        CHECK(v >= -10);
        CHECK(v <= 10);
    }

    TEST_CASE("degenerate bounds give a defined answer");

    CHECK_EQ(stream_below(&r, s, 0), 0);
    CHECK_EQ(stream_between(&r, s, 5, 5), 5);
    CHECK_EQ(stream_between(&r, s, 5, 1), 5);
}
/* }}} */

/* {{{ static void test_distribution_is_not_loaded */
static void test_distribution_is_not_loaded(void)
{
    struct stream_registry r;
    uint32_t s;
    uint32_t counts[6];
    int i;
    uint32_t lowest;
    uint32_t highest;

    TEST_CASE("a bounded draw is not biased toward its low values");

    /*
     * The reason stream_below rejects rather than taking a modulo. The bias is
     * invisible in one roll and shows up as a loaded die across ten thousand
     * generated dungeons.
     *
     * With 60,000 draws over six faces, each should land near 10,000. A spread of
     * more than a few per cent would mean something is wrong; the tolerance here
     * is deliberately loose so the test is about bias rather than about luck.
     */
    memset(counts, 0, sizeof(counts));
    streams_init(&r, 31337);
    s = stream_named(&r, "fairness");

    for (i = 0; i < 60000; i++) {
        counts[stream_below(&r, s, 6)]++;
    }

    lowest = counts[0];
    highest = counts[0];

    for (i = 1; i < 6; i++) {
        if (counts[i] < lowest)  lowest = counts[i];
        if (counts[i] > highest) highest = counts[i];
    }

    CHECK(lowest > 9000);
    CHECK(highest < 11000);
}
/* }}} */

/* {{{ static void test_snapshot_and_restore */
static void test_snapshot_and_restore(void)
{
    struct stream_registry live;
    struct stream_registry snapshot;
    uint32_t s;
    uint64_t expected[10];
    int i;

    TEST_CASE("a registry can be snapshotted and put back exactly");

    /*
     * What rollback needs. Restore the world without restoring the dice and a
     * retconned turn draws different numbers for a reason nobody can see --
     * which looks exactly like the retcon having worked.
     */
    streams_init(&live, 555);
    s = stream_named(&live, "attack");

    for (i = 0; i < 20; i++) {
        stream_next(&live, s);
    }

    streams_copy(&snapshot, &live);

    for (i = 0; i < 10; i++) {
        expected[i] = stream_next(&live, s);
    }

    /* Take the turn back. */
    streams_copy(&live, &snapshot);

    for (i = 0; i < 10; i++) {
        CHECK_EQ(stream_next(&live, s), expected[i]);
    }

    TEST_CASE("the hash notices a stream having moved");

    {
        uint64_t before;

        streams_copy(&live, &snapshot);
        before = streams_hash(&live);

        CHECK_EQ(streams_hash(&snapshot), before);

        stream_next(&live, s);
        CHECK(streams_hash(&live) != before);
    }
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_same_seed_same_sequence();
    test_streams_are_independent();
    test_naming();
    test_bounded_draws();
    test_distribution_is_not_loaded();
    test_snapshot_and_restore();

    return vtt_test_finish("048-test-streams");
}
/* }}} */
