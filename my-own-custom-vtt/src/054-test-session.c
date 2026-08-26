/*
 * 054-test-session.c -- can a turn be run again and land in the same place?
 *
 * The sharper of the two rollback tests is the one that changes nothing: restore
 * the head, replay the same declarations, and check the world hash is exactly
 * what it was. An undo that reproduces the original bit for bit means the
 * snapshot captured everything -- including the stream positions, which are the
 * easiest thing to leave out and the hardest omission to notice, because a
 * retcon that rolls different dice looks exactly like a retcon that worked.
 */

#include "020-test-harness.h"
#include "053-session.h"
#include "037-fixture.h"
#include "035-worldfile.h"
#include "033-validate.h"

#define M(n) ((wcoord)((n) * WC_ONE))

/* {{{ static uint32_t add_body */
static uint32_t add_body(struct world *w, wcoord x, wcoord y)
{
    uint32_t index = world_add_thing(w);
    struct thing *t = world_thing(w, index);

    t->x = x;
    t->y = y;
    t->radius = (uint16_t)(WC_ONE / 2);
    t->region = 1;

    return index;
}
/* }}} */

/* {{{ static void test_turns_advance */
static void test_turns_advance(void)
{
    struct world w;
    struct pool *p = pool_start(1);
    struct session s;
    int beat;

    TEST_CASE("windows close and reopen on a cadence");

    CHECK(fixture_make_two_rooms(&w) == 1);
    CHECK(session_start(&s, &w, p, 1, 8, 10) == 1);

    CHECK_EQ(s.turn, 0);

    for (beat = 0; beat < 10; beat++) {
        session_tick(&s);
    }
    CHECK_EQ(s.turn, 1);

    for (beat = 0; beat < 30; beat++) {
        session_tick(&s);
    }
    CHECK_EQ(s.turn, 4);

    session_release(&s);
    world_release(&w);
    pool_stop(p);
}
/* }}} */

/* {{{ static void test_a_window_of_one_is_continuous_play */
static void test_a_window_of_one_is_continuous_play(void)
{
    struct world w;
    struct pool *p = pool_start(1);
    struct session s;
    int beat;

    TEST_CASE("a window of one beat is a real configuration");

    /*
     * Continuous play. It must run through exactly the same code as any other
     * window rather than down a special path, because a special path is a path
     * that stops being tested.
     */
    CHECK(fixture_make_two_rooms(&w) == 1);
    CHECK(session_start(&s, &w, p, 1, 8, 1) == 1);

    for (beat = 0; beat < 20; beat++) {
        session_tick(&s);
    }

    CHECK_EQ(s.turn, 20);

    TEST_CASE("and a window of zero is corrected rather than obeyed");

    /* A window of no beats would close before anybody could say anything. */
    {
        struct session zero;
        struct world w2;

        fixture_make_two_rooms(&w2);
        CHECK(session_start(&zero, &w2, p, 1, 4, 0) == 1);
        CHECK_EQ(zero.window_ticks, 1);

        session_release(&zero);
        world_release(&w2);
    }

    session_release(&s);
    world_release(&w);
    pool_stop(p);
}
/* }}} */

/* {{{ static void test_commands_are_recorded_even_when_refused */
static void test_commands_are_recorded_even_when_refused(void)
{
    struct world w;
    struct pool *p = pool_start(1);
    struct session s;
    uint32_t body;

    TEST_CASE("a refused command is kept, with its reason");

    /*
     * A log that only holds what succeeded cannot answer "why did nothing happen
     * when I pressed that", which is the most direct evidence there is about
     * where an interface confuses people.
     */
    CHECK(fixture_make_two_rooms(&w) == 1);
    body = add_body(&w, M(10), M(10));
    CHECK(session_start(&s, &w, p, 1, 8, 10) == 1);

    CHECK_EQ(session_command(&s, VERB_DRIVE, body, 0, WC_ONE), REFUSED_NOT_AT_ALL);
    CHECK_EQ(session_command(&s, VERB_DRIVE, 9999, 0, WC_ONE), REFUSED_NO_SUCH_SUBJECT);
    CHECK_EQ(session_command(&s, VERB_DRIVE, 0, 0, WC_ONE), REFUSED_SUBJECT_IS_NOTHING);
    CHECK_EQ(session_command(&s, 999, body, 0, 0), REFUSED_UNKNOWN_VERB);

    CHECK_EQ(s.log.count, 4);
    CHECK_EQ(log_refused_count(&s.log), 3);

    TEST_CASE("and every refusal is a sentence rather than a number");

    {
        const char *sentence = refusal_sentence(REFUSED_NO_SUCH_SUBJECT);
        CHECK(sentence != NULL);
        CHECK(sentence[0] != '\0');

        /* Including the one nobody wrote, which says so. */
        CHECK(refusal_sentence(4242)[0] != '\0');
    }

    session_release(&s);
    world_release(&w);
    pool_stop(p);
}
/* }}} */

/* {{{ static void test_redeclare */
static void test_redeclare(void)
{
    struct world w;
    struct pool *p = pool_start(1);
    struct session s;
    uint32_t body;
    wcoord at_head;
    int beat;

    TEST_CASE("taking a turn back puts the world where it was");

    CHECK(fixture_make_two_rooms(&w) == 1);
    body = add_body(&w, M(10), M(10));
    CHECK(session_start(&s, &w, p, 1, 8, 10) == 1);

    /* Run a couple of turns so there is history. */
    for (beat = 0; beat < 25; beat++) {
        session_tick(&s);
    }

    at_head = world_thing_const(&w, body)->x;

    {
        uint32_t current = s.turn;

        /* This turn: walk east. */
        session_command(&s, VERB_DRIVE, body, 0, WC_ONE);
        for (beat = 0; beat < 8; beat++) {
            session_tick(&s);
        }

        CHECK(world_thing_const(&w, body)->x > at_head);

        /* Take it back. */
        CHECK(session_rollback(&s, current, ROLLBACK_REDECLARE) == 1);

        CHECK_EQ(world_thing_const(&w, body)->x, at_head);
        CHECK_EQ(s.turn, current);
    }

    TEST_CASE("and discards what was declared in it");

    CHECK_EQ(world_thing_const(&w, body)->x, at_head);

    /* The standing order went back too, so the body is not still walking. */
    for (beat = 0; beat < 5; beat++) {
        session_tick(&s);
    }
    CHECK_EQ(world_thing_const(&w, body)->x, at_head);

    session_release(&s);
    world_release(&w);
    pool_stop(p);
}
/* }}} */

/* {{{ static void test_replaying_the_same_turn_is_identical */
static void test_replaying_the_same_turn_is_identical(void)
{
    struct world w;
    struct pool *p = pool_start(1);
    struct session s;
    uint32_t body;
    uint64_t before;
    uint32_t target_turn;
    int beat;

    TEST_CASE("a turn replayed unchanged lands exactly where it did");

    /*
     * THE SHARPEST TEST HERE. If the snapshot missed anything -- and the stream
     * positions are the easiest thing to miss -- this is what catches it, because
     * a retcon that rolls different dice looks exactly like one that worked.
     */
    CHECK(fixture_make_two_rooms(&w) == 1);
    body = add_body(&w, M(10), M(10));
    CHECK(session_start(&s, &w, p, 4207, 8, 10) == 1);

    for (beat = 0; beat < 25; beat++) {
        session_tick(&s);
    }

    target_turn = s.turn;

    session_command(&s, VERB_ORDER_MOVE, body, (int32_t)M(18), (int32_t)M(14));
    for (beat = 0; beat < 20; beat++) {
        session_tick(&s);
        /* Draw from a stream mid-turn, so the positions actually move. */
        stream_below(&s.sim.streams, stream_named(&s.sim.streams, "wandering"), 20);
    }

    before = world_hash(&w);

    CHECK(session_rollback(&s, target_turn, ROLLBACK_RETCON) == 1);

    CHECK_EQ(world_hash(&w), before);

    session_release(&s);
    world_release(&w);
    pool_stop(p);
}
/* }}} */

/* {{{ static void test_retcon_changes_what_follows */
static void test_retcon_changes_what_follows(void)
{
    struct world w;
    struct pool *p = pool_start(1);
    struct session s;
    uint32_t body;
    uint32_t target_turn;
    uint32_t first_entry;
    wcoord went_east;
    int beat;

    TEST_CASE("rewriting one command makes the turn go differently");

    /*
     * The GM ruled wrongly. Restore the head, change what was declared, replay
     * forward, and everything after it follows from the correction.
     */
    CHECK(fixture_make_two_rooms(&w) == 1);
    body = add_body(&w, M(10), M(10));
    CHECK(session_start(&s, &w, p, 1, 8, 10) == 1);

    for (beat = 0; beat < 25; beat++) {
        session_tick(&s);
    }

    target_turn = s.turn;
    first_entry = log_turn_first(&s.log, target_turn);

    session_command(&s, VERB_DRIVE, body, 0, WC_ONE);   /* east */
    for (beat = 0; beat < 8; beat++) {
        session_tick(&s);
    }

    went_east = world_thing_const(&w, body)->x;
    CHECK(went_east > M(10));

    TEST_CASE("and the rewritten command is what actually runs");

    {
        struct log_entry corrected = s.log.entries[first_entry];

        /* It should have been north, not east. */
        corrected.ax = (int32_t)WA_QUARTER;
        log_rewrite(&s.log, first_entry, &corrected);

        CHECK(session_rollback(&s, target_turn, ROLLBACK_RETCON) == 1);

        /* The body went north instead, and is back where it started in x. */
        CHECK_EQ(world_thing_const(&w, body)->x, M(10));
        CHECK(world_thing_const(&w, body)->y > M(10));
    }

    session_release(&s);
    world_release(&w);
    pool_stop(p);
}
/* }}} */

/* {{{ static void test_the_ring_is_finite */
static void test_the_ring_is_finite(void)
{
    struct world w;
    struct pool *p = pool_start(1);
    struct session s;
    int beat;

    TEST_CASE("a turn that has fallen out of the ring is refused, not approximated");

    /*
     * The ring is finite and a session is long. Restoring the nearest turn we
     * still have would put the world somewhere nobody asked for, so this reports
     * failure instead.
     */
    CHECK(fixture_make_two_rooms(&w) == 1);
    CHECK(session_start(&s, &w, p, 1, 4, 10) == 1);

    for (beat = 0; beat < 200; beat++) {
        session_tick(&s);
    }

    CHECK_EQ(session_can_roll_back_to(&s, 0), 0);
    CHECK_EQ(session_rollback(&s, 0, ROLLBACK_REDECLARE), 0);

    TEST_CASE("but a recent one is still there");

    CHECK(session_can_roll_back_to(&s, s.turn) == 1);
    CHECK_EQ(session_ring_depth(&s), 4);
    CHECK_EQ(session_ring_held(&s), 4);

    TEST_CASE("and the ring's cost is knowable");

    CHECK(session_ring_bytes(&s) > 0);

    session_release(&s);
    world_release(&w);
    pool_stop(p);
}
/* }}} */

/* {{{ static void test_fog_rolls_back_too */
static void test_fog_rolls_back_too(void)
{
    struct world w;
    struct pool *p = pool_start(1);
    struct session s;
    struct fog f;
    uint32_t body;
    uint32_t target_turn;
    uint32_t at_head;
    int beat;

    TEST_CASE("memory goes back with the world");

    /*
     * Decided knowing the cost: the person still remembers the corridor. They
     * looked at it. Their map closes over a room they can describe out loud.
     *
     * It is still the right trade, because a fog left un-rolled holds a place
     * reached in a turn that never happened and contradicts the world every time
     * anybody walks there again.
     */
    CHECK(fixture_make_two_rooms(&w) == 1);

    body = world_add_thing(&w);
    {
        struct thing *t = world_thing(&w, body);
        t->x = M(5);
        t->y = M(5);
        t->sight_arc = 65535;
        t->sight_range = (uint32_t)M(100);
        t->region = 1;
    }

    CHECK(fog_init(&f, &w, WC_ONE) == 1);
    CHECK(session_start(&s, &w, p, 1, 8, 10) == 1);
    session_attach_fogs(&s, &f, 1);

    fog_fold(&f, &w, body);

    for (beat = 0; beat < 25; beat++) {
        session_tick(&s);
    }

    target_turn = s.turn;
    at_head = fog_cells_seen(&f);

    /* The turn: walk into the far room and look around. */
    world_thing(&w, body)->x = M(40);
    world_thing(&w, body)->y = M(10);
    fog_fold(&f, &w, body);

    CHECK(fog_cells_seen(&f) > at_head);
    CHECK(fog_remembers(&f, M(40), M(10)) == 1);

    CHECK(session_rollback(&s, target_turn, ROLLBACK_REDECLARE) == 1);

    CHECK_EQ(fog_cells_seen(&f), at_head);
    CHECK(fog_remembers(&f, M(40), M(10)) == 0);

    fog_release(&f);
    session_release(&s);
    world_release(&w);
    pool_stop(p);
}
/* }}} */

/* {{{ static void test_the_world_survives_it_all */
static void test_the_world_survives_it_all(void)
{
    struct world w;
    struct pool *p = pool_start(4);
    struct session s;
    struct validation_failure failure;
    char message[256];
    uint32_t body;
    int round;

    TEST_CASE("a world that has been rolled back repeatedly still validates");

    CHECK(fixture_make_two_rooms(&w) == 1);
    body = add_body(&w, M(10), M(10));
    CHECK(session_start(&s, &w, p, 77, 8, 5) == 1);

    for (round = 0; round < 20; round++) {
        uint32_t turn = s.turn;
        int beat;

        session_command(&s, VERB_DRIVE, body,
                        (int32_t)(wangle)(round * 3000), WC_ONE / 2);

        for (beat = 0; beat < 4; beat++) {
            session_tick(&s);
        }

        if ((round % 3) == 0) {
            session_rollback(&s, turn, ROLLBACK_REDECLARE);
        }

        session_tick(&s);
    }

    if (!world_validate(&w, &failure)) {
        vtt_report_failure(__FILE__, __LINE__,
            validation_failure_describe(&failure, message, sizeof(message)));
    } else {
        CHECK(1);
    }

    session_release(&s);
    world_release(&w);
    pool_stop(p);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_turns_advance();
    test_a_window_of_one_is_continuous_play();
    test_commands_are_recorded_even_when_refused();
    test_redeclare();
    test_replaying_the_same_turn_is_identical();
    test_retcon_changes_what_follows();
    test_the_ring_is_finite();
    test_fog_rolls_back_too();
    test_the_world_survives_it_all();

    return vtt_test_finish("054-test-session");
}
/* }}} */
