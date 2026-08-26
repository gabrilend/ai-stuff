/*
 * 091-test-record.c -- does a session tell the truth about itself?
 *
 * Eight numbers, and the interesting cases are the boring ones. A session that
 * did nothing must produce a record saying it did nothing -- not an empty
 * record, not a zeroed one that could equally mean "never gathered". The
 * difference matters because an engraving of all zeroes and an engraving that
 * was never made look identical from the outside, and only one of them means
 * anything.
 */

#include "020-test-harness.h"
#include "090-record.h"
#include "037-fixture.h"
#include "035-worldfile.h"

#include <string.h>

#define M(n) ((wcoord)((n) * WC_ONE))

/* {{{ static void test_a_session_that_did_nothing */
static void test_a_session_that_did_nothing(void)
{
    struct world w;
    struct pool *threads = pool_start(1);
    struct session s;
    struct record r;

    TEST_CASE("a session that did nothing says so, rather than saying nothing");

    CHECK_EQ(fixture_make_two_rooms(&w), 1);
    CHECK_EQ(session_start(&s, &w, threads, 1, 8, 10), 1);

    record_gather(&r, &s, 0);

    CHECK_EQ(r.value[CELL_BEATS], 0);
    CHECK_EQ(r.value[CELL_TURNS], 0);
    CHECK_EQ(r.value[CELL_SEATS], 0);
    CHECK_EQ(r.value[CELL_COMMANDS], 0);
    CHECK_EQ(r.value[CELL_REFUSED], 0);
    CHECK_EQ(r.value[CELL_ROLLBACKS], 0);

    /* But the world exists, so its size is not zero -- which is what tells a
     * record of an empty evening from a record that was never gathered. */
    CHECK(r.value[CELL_THINGS] > 0);
    CHECK_EQ(r.value[CELL_THINGS], world_thing_count(&w) - 1u);

    /* And the checksum is the world's, which is never zero for a real world. */
    CHECK_EQ(r.value[CELL_CHECKSUM], world_hash(&w));
    CHECK(r.value[CELL_CHECKSUM] != 0);

    session_release(&s);
    world_release(&w);
    pool_stop(threads);
}
/* }}} */

/* {{{ static void test_a_session_that_did_things */
static void test_a_session_that_did_things(void)
{
    struct world w;
    struct pool *threads = pool_start(1);
    struct session s;
    struct record r;
    uint32_t body;
    int beat;

    TEST_CASE("every cell counts the thing it says it counts");

    CHECK_EQ(fixture_make_two_rooms(&w), 1);

    body = world_add_thing(&w);
    world_thing(&w, body)->x = M(3);
    world_thing(&w, body)->y = M(3);
    world_thing(&w, body)->radius = (uint16_t)(WC_ONE / 2);
    world_thing(&w, body)->region = 1;

    CHECK_EQ(session_start(&s, &w, threads, 1, 8, 5), 1);

    for (beat = 0; beat < 20; beat++) {
        /* One that works and one that cannot. */
        session_command(&s, VERB_ORDER_MOVE, body, M(5), M(5));
        session_command(&s, VERB_ORDER_MOVE, 0, M(5), M(5));
        session_tick(&s);
    }

    CHECK(session_rollback(&s, s.turn - 1u, ROLLBACK_RETCON) == 1);

    record_gather(&r, &s, 3);

    CHECK_EQ(r.value[CELL_BEATS], s.sim.tick);
    CHECK_EQ(r.value[CELL_SEATS], 3);
    CHECK_EQ(r.value[CELL_COMMANDS], s.log.count);
    CHECK_EQ(r.value[CELL_REFUSED], log_refused_count(&s.log));
    CHECK_EQ(r.value[CELL_ROLLBACKS], 1);

    /* Half the commands were impossible, so the refusal count is not zero and
     * is not everything -- a session where nothing was refused and one where
     * everything was tell you different things about the interface. */
    CHECK(r.value[CELL_REFUSED] > 0);
    CHECK(r.value[CELL_REFUSED] < r.value[CELL_COMMANDS]);

    session_release(&s);
    world_release(&w);
    pool_stop(threads);
}
/* }}} */

/*
 * The creature belongs to the run. Two sessions from one seed that ran for
 * different lengths are different runs, and get different animals.
 */
/* {{{ static void test_the_creature_belongs_to_the_run */
static void test_the_creature_belongs_to_the_run(void)
{
    struct world w;
    struct pool *threads = pool_start(1);
    struct session s;
    struct record early;
    struct record late;
    int beat;

    TEST_CASE("the seed a carving gets belongs to that run");

    CHECK_EQ(fixture_make_two_rooms(&w), 1);
    CHECK_EQ(session_start(&s, &w, threads, 555, 8, 10), 1);

    record_gather(&early, &s, 1);

    for (beat = 0; beat < 30; beat++) {
        session_tick(&s);
    }

    record_gather(&late, &s, 1);

    CHECK(early.seed != late.seed);

    session_release(&s);
    world_release(&w);
    pool_stop(threads);
}
/* }}} */

/* {{{ static void test_the_value_text */
static void test_the_value_text(void)
{
    struct record r;
    char text[RECORD_VALUE_MAX + 8];
    uint32_t cell;

    TEST_CASE("a value's text fits the chamber it was measured for");

    memset(&r, 0, sizeof(r));

    /* The largest each cell is drawn to hold. */
    r.value[CELL_BEATS]     = 99999999ull;
    r.value[CELL_TURNS]     = 999999ull;
    r.value[CELL_SEATS]     = 999ull;
    r.value[CELL_COMMANDS]  = 9999999ull;
    r.value[CELL_REFUSED]   = 9999999ull;
    r.value[CELL_ROLLBACKS] = 9999ull;
    r.value[CELL_THINGS]    = 999999ull;
    r.value[CELL_CHECKSUM]  = 0xFFFFFFFFFFFFFFFFull;

    for (cell = 0; cell < RECORD_CELLS; cell++) {
        uint32_t length = record_value_text(&r, cell, text, sizeof(text));

        CHECK_EQ(length, strlen(text));
        CHECK_EQ(length, record_widest_value(cell));
    }

    /* The checksum is a FIXED sixteen digits, always -- a number that is
     * sometimes fifteen columns and sometimes seventeen is a creature that
     * changes shape for no reason. */
    r.value[CELL_CHECKSUM] = 1;
    CHECK_EQ(record_value_text(&r, CELL_CHECKSUM, text, sizeof(text)), 16);
    CHECK(strcmp(text, "0000000000000001") == 0);

    /* Zero is one digit everywhere else. */
    r.value[CELL_SEATS] = 0;
    CHECK_EQ(record_value_text(&r, CELL_SEATS, text, sizeof(text)), 1);
    CHECK(strcmp(text, "0") == 0);

    /* A cell that is not a cell names itself as one rather than reading as
     * empty. */
    CHECK(strcmp(record_label(RECORD_CELLS), "(not a cell)") == 0);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_a_session_that_did_nothing();
    test_a_session_that_did_things();
    test_the_creature_belongs_to_the_run();
    test_the_value_text();

    return vtt_test_finish("091-test-record");
}
/* }}} */
