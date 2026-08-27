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
#include "070-scope.h"
#include "085-sprite-pool.h"

#include <string.h>

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
        CHECK_EQ(zero.beats_between_checkpoints, 1);

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

/*
 * Somebody at the table says "that goblin is wrong" without stopping play.
 *
 * Two things are being checked and the second is the load-bearing one.
 *
 * That the opinion lands in the library at all -- which is what makes
 * judge-then-curate a tabletop idea rather than a gallery one, since a rating
 * that requires quitting and opening another program is a rating nobody makes in
 * the middle of a fight.
 *
 * And that THE WORLD DOES NOT MOVE. Not a coordinate, not a hash, not a beat. A
 * command that arrives mid-turn and changes the world would have to be rolled
 * back with it, replayed with it, and compared with it -- and this one has
 * nothing to do with any of that, which is exactly why it is safe to allow while
 * the fight is still going.
 */
/* {{{ static void test_a_sprite_is_retiered_mid_session */
static void test_a_sprite_is_retiered_mid_session(void)
{
    struct world w;
    struct pool *threads = pool_start(1);
    struct sprite_pool library;
    struct session s;
    uint32_t goblin;
    uint64_t hash_before;
    uint64_t tick_before;
    uint32_t entry;
    uint16_t answer;

    TEST_CASE("a sprite is re-tiered from a running session");

    CHECK_EQ(fixture_make_two_rooms(&w), 1);
    goblin = add_body(&w, M(3), M(3));

    /* It is wearing something, which is what the generator would have given it
     * and what a hand-built fixture has to be told. */
    world_thing(&w, goblin)->sprite_category =
        string_pool_add(&w.strings, "goblin", 6);
    world_thing(&w, goblin)->sprite_seed = 4242;

    CHECK_EQ(session_start(&s, &w, threads, 12345, 8, 10), 1);
    CHECK_EQ(pool_init(&library, POOL_JUDGE_THEN_CURATE), 1);

    session_attach_sprites(&s, &library);

    hash_before = world_hash(&w);
    tick_before = s.sim.tick;

    answer = session_command(&s, VERB_RETIER, goblin, 2, 0);
    CHECK_EQ(answer, REFUSED_NOT_AT_ALL);

    /* The opinion is in the library, marked as a person's. */
    entry = pool_find(&library, "goblin", 4242);
    CHECK(entry != POOL_NOTHING);
    CHECK_EQ(pool_tier(&library, entry), 2);
    CHECK_EQ(pool_tier_provenance(&library, entry), RATED_BY_PERSON);

    /*
     * WHO rated it is a seat, not a display name. A name is display-only
     * everywhere in this project, and a library that outlives the session must
     * not be keyed on something somebody can change between one evening and the
     * next.
     */
    CHECK(strcmp(pool_at(&library, entry)->person_name, "the-table") == 0);

    /* And nothing whatsoever moved. */
    CHECK_EQ(world_hash(&w), hash_before);
    CHECK_EQ(s.sim.tick, tick_before);

    /* Play carries on from exactly where it was. */
    session_tick(&s);
    CHECK_EQ(s.sim.tick, tick_before + 1);

    TEST_CASE("a re-tier that cannot be honoured is refused by name");

    /* A tier off the scale is refused rather than clamped -- a client with a
     * ten-point scale is told so instead of having its nine become a five. */
    CHECK_EQ(session_command(&s, VERB_RETIER, goblin, 9, 0), REFUSED_NOT_A_TIER);
    CHECK_EQ(session_command(&s, VERB_RETIER, goblin, 0, 0), REFUSED_NOT_A_TIER);
    CHECK_EQ(pool_tier(&library, entry), 2);

    /* Something wearing no picture has nothing to have an opinion of. */
    {
        uint32_t bare = add_body(&w, M(4), M(4));

        sim_fit_to_world(&s.sim);
        CHECK_EQ(session_command(&s, VERB_RETIER, bare, 3, 0),
                 REFUSED_WEARS_NOTHING);
    }

    /* And nothing at all is still nothing. */
    CHECK_EQ(session_command(&s, VERB_RETIER, 0, 3, 0), REFUSED_SUBJECT_IS_NOTHING);

    TEST_CASE("with no library attached, the refusal says so");

    session_attach_sprites(&s, NULL);
    CHECK_EQ(session_command(&s, VERB_RETIER, goblin, 3, 0), REFUSED_NO_LIBRARY);

    /* A refusal is a sentence, always. */
    CHECK(strstr(refusal_sentence(REFUSED_NO_LIBRARY), "library") != NULL);
    CHECK(strstr(refusal_sentence(REFUSED_NOT_A_TIER), "1 to 5") != NULL);
    CHECK(strstr(refusal_sentence(REFUSED_WEARS_NOTHING), "picture") != NULL);

    pool_release(&library);
    session_release(&s);
    world_release(&w);
    pool_stop(threads);
}
/* }}} */

/*
 * A retcon does not re-snapshot, and the heads it leaves behind are still right.
 *
 * This is open question 13.2, which said the reasoning was "subtle enough to be
 * worth a test that nobody has written". This is that test.
 *
 * The claim: a retcon replays turn boundaries forward WITHOUT capturing new
 * heads, because the ring already holds those heads and overwriting them would
 * destroy the history a second rollback needs. So after a deep retcon the ring
 * holds heads captured before the correction — and rolling back again must still
 * land somewhere correct, because the state at a turn's START did not change.
 *
 * If that reasoning is wrong, a second rollback lands on a head that describes a
 * world nobody was ever in, and every check below would still pass except the
 * last.
 */
/* {{{ static void test_a_retcon_leaves_the_earlier_heads_usable */
static void test_a_retcon_leaves_the_earlier_heads_usable(void)
{
    struct world w;
    struct pool *p = pool_start(1);
    struct session s;
    uint32_t body;
    uint64_t at_the_first_head;
    uint32_t first_turn;
    int beat;

    TEST_CASE("a second rollback after a retcon lands somewhere real");

    CHECK(fixture_make_two_rooms(&w) == 1);
    body = add_body(&w, M(4), M(4));

    /* A ring deep enough that the first head is still in it at the end.
     * Four turns pass below and a shallow ring would drop it, which is a
     * legitimate outcome and not the one being tested. */
    CHECK(session_start(&s, &w, p, 77, 16, 4) == 1);

    /*
     * Tick until a turn actually OPENS, and remember exactly what its head
     * looked like.
     *
     * Not turn zero: a session starts on turn zero without begin_turn ever being
     * called for it, so turn zero has no head in the ring and cannot be rolled
     * back to. That is not a defect -- there is nothing before the start of a
     * session to return to -- but it is an asymmetry worth knowing about, and
     * this test found it by assuming otherwise.
     */
    while (s.turn == 0) {
        session_tick(&s);
    }

    first_turn = s.turn;
    at_the_first_head = world_hash(&w);

    /* Four turns of somebody walking about. */
    for (beat = 0; beat < 16; beat++) {
        if (beat % 4 == 0) {
            session_command(&s, VERB_ORDER_MOVE, body,
                            M(6 + (beat % 5)), M(8));
        }
        session_tick(&s);
    }

    CHECK(s.turn > first_turn);
    CHECK(world_hash(&w) != at_the_first_head);

    /* A deep retcon: back to a turn in the middle, replaying its commands. */
    {
        uint32_t middle = s.turn - 1u;

        CHECK_EQ(session_can_roll_back_to(&s, middle), 1);
        CHECK_EQ(session_rollback(&s, middle, ROLLBACK_RETCON), 1);
    }

    /*
     * And now the part nobody had checked. The earlier head was captured before
     * the retcon and was not recaptured by it. Rolling back to it must put the
     * world exactly where it was at that turn's start.
     */
    if (session_can_roll_back_to(&s, first_turn)) {
        CHECK_EQ(session_rollback(&s, first_turn, ROLLBACK_REDECLARE), 1);
        CHECK_EQ(world_hash(&w), at_the_first_head);
    } else {
        /*
         * It fell out of the ring, which is a legitimate answer and not the one
         * this test is about. Said out loud rather than passing quietly, because
         * a test that silently tests nothing is worse than no test.
         */
        fprintf(stderr, "    the first head fell out of the ring before the"
                        " second rollback, so this test checked nothing\n");
        CHECK(0);
    }

    session_release(&s);
    world_release(&w);
    pool_stop(p);
}
/* }}} */

/*
 * The two halves of "nothing checks who you are".
 *
 * That is the decided answer -- a kitchen table does not check identity either --
 * and it is only honest if the host can remove somebody and unwind what they
 * did. A statement of that shape with nothing behind it is worse than no position
 * at all, so this is the test that says both halves exist.
 */
/* {{{ static void test_removing_somebody */
static void test_removing_somebody(void)
{
    struct world w;
    struct pool *p = pool_start(1);
    struct session s;
    uint32_t body;
    uint32_t host = 1;
    uint32_t guest = 2;
    uint32_t taken[SESSION_MAX_EVICTIONS];
    uint32_t scope;

    TEST_CASE("the host can remove somebody, and only the host");

    CHECK(fixture_make_two_rooms(&w) == 1);
    body = add_body(&w, M(4), M(4));

    CHECK(session_start(&s, &w, p, 1, 8, 5) == 1);
    sim_fit_to_world(&s.sim);

    scope = scope_make_list(&w, guest, STYLE_DRIVEN, &body, 1, "the guest");
    CHECK(scope != 0);

    /* The host holds a scope that may edit the world. */
    {
        uint32_t nothing = 0;
        uint32_t theirs = scope_make_list(&w, host, STYLE_ORDERED, &nothing, 0,
                                          "the host");

        CHECK(theirs != 0);
        world_scope(&w, theirs)->flags |= SCOPE_MAY_EDIT_WORLD;
    }

    /* A guest cannot remove the host. */
    CHECK_EQ(session_command_from(&s, guest, VERB_EVICT, host, 0, 0),
             REFUSED_MAY_NOT_EDIT);

    /* The host cannot remove themselves -- almost certainly a mistake, and the
     * recovery from it is restarting the server. */
    CHECK_EQ(session_command_from(&s, host, VERB_EVICT, host, 0, 0),
             REFUSED_NOT_YOURSELF);
    CHECK(strstr(refusal_sentence(REFUSED_NOT_YOURSELF), "yourself") != NULL);

    /* And nobody is nobody. */
    CHECK_EQ(session_command_from(&s, host, VERB_EVICT, 0, 0, 0),
             REFUSED_SUBJECT_IS_NOTHING);

    TEST_CASE("removing them unholds their scopes and keeps their bodies");

    CHECK_EQ(session_command_from(&s, host, VERB_EVICT, guest, 0, 0),
             REFUSED_NOT_AT_ALL);

    /* Their scope is unheld, which is a normal state -- the forest exists
     * whether anybody is playing it. */
    CHECK_EQ(world_scope(&w, scope)->viewer, 0);

    /* Their body still exists. Removing a person is not removing a character. */
    CHECK(world_thing_const(&w, body)->radius > 0);
    CHECK_EQ(world_thing_count(&w) > body, 1);

    /* And the seat is queued for the server, which owns the sockets. */
    CHECK_EQ(session_take_evictions(&s, taken, SESSION_MAX_EVICTIONS), 1);
    CHECK_EQ(taken[0], guest);

    /* Drained, so a second call finds nothing. */
    CHECK_EQ(session_take_evictions(&s, taken, SESSION_MAX_EVICTIONS), 0);

    session_release(&s);
    world_release(&w);
    pool_stop(p);
}
/* }}} */

/*
 * And unwinding what they did, without losing anybody else's evening.
 *
 * Compared against a run where the removed person never issued anything at all --
 * by world hash, because "it looks about right" is not a comparison.
 */
/* {{{ static void test_unwinding_one_persons_actions */
static void test_unwinding_one_persons_actions(void)
{
    struct world troubled;
    struct world clean;
    struct pool *p = pool_start(1);
    struct session with_them;
    struct session without_them;
    uint32_t theirs_a, ours_a;
    uint32_t theirs_b, ours_b;
    uint32_t guest = 2;
    uint32_t host = 1;
    uint32_t earliest;
    int beat;

    TEST_CASE("one seat's actions are unwound and everybody else's survive");

    /*
     * Two identical worlds. In one, a guest gives orders and is then expunged.
     * In the other they never say anything. The two must end identical.
     */
    CHECK(fixture_make_two_rooms(&troubled) == 1);
    theirs_a = add_body(&troubled, M(4), M(4));
    ours_a = add_body(&troubled, M(6), M(4));

    CHECK(fixture_make_two_rooms(&clean) == 1);
    theirs_b = add_body(&clean, M(4), M(4));
    ours_b = add_body(&clean, M(6), M(4));

    CHECK_EQ(theirs_a, theirs_b);
    CHECK_EQ(ours_a, ours_b);
    CHECK_EQ(world_hash(&troubled), world_hash(&clean));

    CHECK(session_start(&with_them, &troubled, p, 909, 16, 4) == 1);
    CHECK(session_start(&without_them, &clean, p, 909, 16, 4) == 1);
    sim_fit_to_world(&with_them.sim);
    sim_fit_to_world(&without_them.sim);

    scope_make_list(&troubled, guest, STYLE_ORDERED, &theirs_a, 1, "guest");
    scope_make_list(&troubled, host, STYLE_ORDERED, &ours_a, 1, "host");
    scope_make_list(&clean, guest, STYLE_ORDERED, &theirs_b, 1, "guest");
    scope_make_list(&clean, host, STYLE_ORDERED, &ours_b, 1, "host");

    /* Let a turn open in both, so there is a head to come back to. */
    while (with_them.turn == 0) {
        session_tick(&with_them);
        session_tick(&without_them);
    }

    earliest = with_them.turn;

    for (beat = 0; beat < 12; beat++) {
        if (beat % 4 == 0) {
            /* The host acts in both worlds. */
            session_command_from(&with_them, host, VERB_ORDER_MOVE, ours_a,
                                 M(9), M(7));
            session_command_from(&without_them, host, VERB_ORDER_MOVE, ours_b,
                                 M(9), M(7));

            /* The guest acts only in the troubled one. */
            session_command_from(&with_them, guest, VERB_ORDER_MOVE, theirs_a,
                                 M(2), M(9));
        }

        session_tick(&with_them);
        session_tick(&without_them);
    }

    /* They diverged, which is what makes the comparison below mean something. */
    CHECK(world_hash(&troubled) != world_hash(&clean));

    /* How far back the host has to go. */
    CHECK_EQ(session_earliest_turn_touched_by(&with_them, guest), earliest);

    CHECK_EQ(session_expunge(&with_them, guest, earliest), 1);

    /*
     * And now the two worlds are the same. Not approximately: the same number.
     */
    if (world_hash(&troubled) != world_hash(&clean)) {
        fprintf(stderr, "    after expunging, %016llx against %016llx\n",
                (unsigned long long)world_hash(&troubled),
                (unsigned long long)world_hash(&clean));
    }
    CHECK_EQ(world_hash(&troubled), world_hash(&clean));

    TEST_CASE("their commands are still in the log, marked");

    {
        uint32_t i;
        uint32_t theirs_found = 0;
        uint32_t theirs_refused = 0;

        for (i = 0; i < with_them.log.count; i++) {
            if (with_them.log.entries[i].viewer == guest) {
                theirs_found++;
                if (with_them.log.entries[i].refusal != REFUSED_NOT_AT_ALL) {
                    theirs_refused++;
                }
            }
        }

        /* A log that quietly omits the parts somebody regretted is not a log. */
        CHECK(theirs_found > 0);
        CHECK_EQ(theirs_refused, theirs_found);
    }

    TEST_CASE("a turn that has fallen out of the ring is refused");

    CHECK_EQ(session_expunge(&with_them, guest, 99999), 0);

    session_release(&with_them);
    session_release(&without_them);
    world_release(&troubled);
    world_release(&clean);
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
    test_a_sprite_is_retiered_mid_session();
    test_a_retcon_leaves_the_earlier_heads_usable();
    test_removing_somebody();
    test_unwinding_one_persons_actions();

    return vtt_test_finish("054-test-session");
}
/* }}} */
