/*
 * 050-test-tick.c -- does the world move the same way twice?
 *
 * Motion has to be reproducible before anything built on it means anything: a
 * replay that walks a body to a different place is not a replay, and a rollback
 * that re-runs a turn differently is not an undo.
 *
 * So the sharpest test here is the last one -- the same scripted run at several
 * thread counts, compared by world hash at every single beat.
 */

#include "020-test-harness.h"
#include "049-tick.h"
#include "037-fixture.h"
#include "035-worldfile.h"
#include "033-validate.h"

#include <stdlib.h>

#define M(n) ((wcoord)((n) * WC_ONE))

/* {{{ static uint32_t add_body */
static uint32_t add_body(struct world *w, wcoord x, wcoord y)
{
    uint32_t index = world_add_thing(w);
    struct thing *t = world_thing(w, index);

    t->x = x;
    t->y = y;
    t->radius = (uint16_t)(WC_ONE / 2);
    t->flags = BLOCKS_MOVEMENT;
    t->region = 0;

    return index;
}
/* }}} */

/* {{{ static void test_the_table_is_readable */
static void test_the_table_is_readable(void)
{
    uint32_t count = 0;
    const struct tick_pass *table = sim_passes(&count);

    TEST_CASE("the order of the simulation is data, not a function body");

    CHECK(table != NULL);
    CHECK(count >= 8);

    /*
     * The empty rows are the point. Intake, rules, sight, memory and outbound do
     * no work in this phase and are still in the table, because the table has to
     * be the whole truth about ordering rather than most of it.
     */
    {
        uint32_t i;
        int found_intake = 0;
        int found_outbound = 0;

        for (i = 0; i < count; i++) {
            CHECK(table[i].name != NULL);
            CHECK(table[i].what != NULL);

            if (table[i].name[0] == 'i' && table[i].name[1] == 'n' &&
                table[i].name[2] == 't' && table[i].name[3] == 'a') {
                found_intake = 1;
            }
            if (table[i].name[0] == 'o') {
                found_outbound = 1;
            }
        }

        CHECK_EQ(found_intake, 1);
        CHECK_EQ(found_outbound, 1);
    }
}
/* }}} */

/* {{{ static void test_driving */
static void test_driving(void)
{
    struct world w;
    struct pool *p = pool_start(1);
    struct sim s;
    uint32_t body;

    TEST_CASE("a driven body keeps moving while the key is held");

    world_init(&w, 8, 4, 4, 8, 4, 256);
    w.max_x = M(100);
    w.max_y = M(100);

    body = add_body(&w, 0, 0);
    sim_init(&s, &w, p, 1);

    sim_drive(&s, body, 0, WC_ONE);   /* east, one metre a beat */

    sim_tick(&s);
    CHECK_EQ(world_thing_const(&w, body)->x, WC_ONE);

    sim_tick(&s);
    sim_tick(&s);
    CHECK_EQ(world_thing_const(&w, body)->x, 3 * WC_ONE);

    TEST_CASE("and stops when it lifts");

    /*
     * A held key is an order that persists, not a step that is consumed. So
     * stopping is an explicit thing that happens, and a body that is not told to
     * stop keeps going -- which is what makes the controls feel like a video game
     * rather than a series of nudges.
     */
    sim_order_stop(&s, body);
    sim_tick(&s);
    CHECK_EQ(world_thing_const(&w, body)->x, 3 * WC_ONE);

    TEST_CASE("a driven body looks where it is going");

    sim_drive(&s, body, WA_QUARTER, WC_ONE);
    sim_tick(&s);
    CHECK_EQ(world_thing_const(&w, body)->facing, WA_QUARTER);

    sim_release(&s);
    world_release(&w);
    pool_stop(p);
}
/* }}} */

/* {{{ static void test_ordered_movement */
static void test_ordered_movement(void)
{
    struct world w;
    struct pool *p = pool_start(1);
    struct sim s;
    uint32_t body;
    int beat;

    TEST_CASE("an ordered body walks to its destination and stops there");

    world_init(&w, 8, 4, 4, 8, 4, 256);
    w.max_x = M(100);
    w.max_y = M(100);

    body = add_body(&w, 0, 0);
    sim_init(&s, &w, p, 1);

    sim_order_move(&s, body, M(10), 0, WC_ONE);

    for (beat = 0; beat < 20; beat++) {
        sim_tick(&s);
    }

    CHECK_EQ(world_thing_const(&w, body)->x, M(10));
    CHECK_EQ(world_thing_const(&w, body)->y, 0);

    TEST_CASE("and does not overshoot and oscillate");

    /*
     * A body one centimetre from its destination steps one centimetre, not a
     * whole beat's worth past it and back again next beat. Without the clamp
     * this position would wobble forever.
     */
    {
        wcoord settled = world_thing_const(&w, body)->x;

        for (beat = 0; beat < 10; beat++) {
            sim_tick(&s);
            CHECK_EQ(world_thing_const(&w, body)->x, settled);
        }
    }

    sim_release(&s);
    world_release(&w);
    pool_stop(p);
}
/* }}} */

/* {{{ static void test_walls_stop_and_slide */
static void test_walls_stop_and_slide(void)
{
    struct world w;
    struct pool *p = pool_start(1);
    struct sim s;
    uint32_t body;
    int beat;

    TEST_CASE("a body driven straight into a wall stops");

    world_init(&w, 8, 8, 4, 8, 4, 256);
    w.max_x = M(100);
    w.max_y = M(100);

    /* A wall running north-south at x = 5. */
    {
        uint32_t wall = world_add_wall(&w);
        struct wall *wl = world_wall(&w, wall);
        wl->ax = M(5); wl->ay = M(-20);
        wl->bx = M(5); wl->by = M(20);
        wl->flags = BLOCKS_SIGHT | BLOCKS_MOVEMENT;
    }

    body = add_body(&w, 0, 0);
    sim_init(&s, &w, p, 1);

    sim_drive(&s, body, 0, WC_ONE);

    for (beat = 0; beat < 20; beat++) {
        sim_tick(&s);
    }

    CHECK(world_thing_const(&w, body)->x < M(5));
    CHECK(world_thing_const(&w, body)->x >= M(4));

    TEST_CASE("a body driven at a wall at an angle slides along it");

    /*
     * The difference between controls that feel alive and controls that feel
     * broken. Pushed north-east into a north-south wall, the body should end up
     * having travelled north.
     */
    {
        wcoord started_y;

        world_thing(&w, body)->x = 0;
        world_thing(&w, body)->y = 0;
        started_y = 0;

        sim_drive(&s, body, WA_EIGHTH, WC_ONE);   /* north-east */

        for (beat = 0; beat < 20; beat++) {
            sim_tick(&s);
        }

        CHECK(world_thing_const(&w, body)->y > started_y + M(5));
        CHECK(world_thing_const(&w, body)->x < M(5));
    }

    TEST_CASE("a wall that blocks sight but not movement is walked through");

    world_wall(&w, 1)->flags = BLOCKS_SIGHT;
    world_thing(&w, body)->x = 0;
    world_thing(&w, body)->y = 0;
    sim_drive(&s, body, 0, WC_ONE);

    for (beat = 0; beat < 20; beat++) {
        sim_tick(&s);
    }

    CHECK(world_thing_const(&w, body)->x > M(5));

    sim_release(&s);
    world_release(&w);
    pool_stop(p);
}
/* }}} */

/* {{{ static void test_crossings */
static void test_crossings(void)
{
    struct world w;
    struct pool *p = pool_start(1);
    struct sim s;
    uint32_t body;
    int beat;
    int crossings_seen = 0;

    TEST_CASE("walking into a room reports a crossing");

    /*
     * The hook everything of the form "when they enter the tavern" hangs from.
     */
    CHECK(fixture_make_two_rooms(&w) == 1);

    body = add_body(&w, M(15), M(5));
    world_thing(&w, body)->flags = 0;     /* not blocking, so it fits the corridor */
    world_thing(&w, body)->region =
        (uint32_t)0;
    sim_init(&s, &w, p, 1);

    /* Put it where it actually is, so the first beat is not a spurious crossing. */
    {
        struct validation_failure ignored;
        world_thing(&w, body)->region = 1;   /* the west room */
        (void)ignored;
    }

    sim_order_move(&s, body, M(4), M(4), WC_ONE);   /* into the cellar */

    for (beat = 0; beat < 40; beat++) {
        uint32_t count = 0;
        sim_tick(&s);
        sim_crossings(&s, &count);
        crossings_seen += (int)count;
    }

    CHECK(crossings_seen >= 1);

    /* And it ends up knowing which region it is in. */
    CHECK(world_thing_const(&w, body)->region != 1);

    TEST_CASE("a body standing still reports no crossing");

    {
        uint32_t count = 99;
        sim_order_stop(&s, body);
        sim_tick(&s);
        sim_crossings(&s, &count);
        CHECK_EQ(count, 0);
    }

    sim_release(&s);
    world_release(&w);
    pool_stop(p);
}
/* }}} */

/* {{{ static uint64_t run_scripted_session */
static uint64_t run_scripted_session(uint32_t threads, uint64_t *per_beat, int beats)
{
    struct world w;
    struct pool *p = pool_start(threads);
    struct sim s;
    uint32_t bodies[16];
    int i;
    int beat;

    fixture_make_two_rooms(&w);

    for (i = 0; i < 16; i++) {
        bodies[i] = add_body(&w, (wcoord)((2 + i) * WC_ONE), M(3));
        world_thing(&w, bodies[i])->flags = 0;
    }

    sim_init(&s, &w, p, 4207);

    for (i = 0; i < 16; i++) {
        if ((i % 2) == 0) {
            sim_drive(&s, bodies[i], (wangle)(i * 4096), WC_ONE / 2);
        } else {
            sim_order_move(&s, bodies[i], M(40), M(10), WC_ONE / 3);
        }
    }

    for (beat = 0; beat < beats; beat++) {
        sim_tick(&s);
        if (per_beat != NULL) {
            per_beat[beat] = world_hash(&w);
        }
    }

    {
        uint64_t final_hash = world_hash(&w);
        sim_release(&s);
        world_release(&w);
        pool_stop(p);
        return final_hash;
    }
}
/* }}} */

/* {{{ static void test_thread_count_changes_nothing */
static void test_thread_count_changes_nothing(void)
{
    const int beats = 200;
    uint64_t *reference = malloc((size_t)beats * sizeof(uint64_t));
    uint64_t *compared = malloc((size_t)beats * sizeof(uint64_t));
    const uint32_t counts[] = { 1, 2, 4, 8 };
    size_t c;

    TEST_CASE("the same session runs the same way at every thread count");

    /*
     * THE CLAIM THE WHOLE PHASE RESTS ON. Compared at every beat rather than only
     * at the end, because "they differ" is not a finding and "they first differ
     * at beat 137" is.
     */
    run_scripted_session(1, reference, beats);

    for (c = 0; c < sizeof(counts) / sizeof(counts[0]); c++) {
        int beat;
        int first_difference = -1;

        run_scripted_session(counts[c], compared, beats);

        for (beat = 0; beat < beats; beat++) {
            if (reference[beat] != compared[beat]) {
                first_difference = beat;
                break;
            }
        }

        CHECK_EQ(first_difference, -1);
    }

    TEST_CASE("and the same session twice on one thread is identical");

    CHECK_EQ(run_scripted_session(1, NULL, beats),
             run_scripted_session(1, NULL, beats));

    free(reference);
    free(compared);
}
/* }}} */

/* {{{ static void test_the_world_stays_valid */
static void test_the_world_stays_valid(void)
{
    struct world w;
    struct pool *p = pool_start(4);
    struct sim s;
    struct validation_failure failure;
    char message[256];
    uint32_t body;
    int beat;

    TEST_CASE("a world that has been running still validates");

    /*
     * The region field is maintained incrementally by the motion pass, which is
     * what makes it affordable and also what lets it drift silently. The
     * validator recomputes every one from scratch, so this is the test that
     * catches the motion pass getting it wrong.
     */
    CHECK(fixture_make_two_rooms(&w) == 1);

    body = add_body(&w, M(10), M(10));
    world_thing(&w, body)->flags = 0;
    world_thing(&w, body)->region = 1;

    sim_init(&s, &w, p, 9);
    sim_order_move(&s, body, M(45), M(10), WC_ONE / 2);

    for (beat = 0; beat < 300; beat++) {
        sim_tick(&s);
    }

    if (!world_validate(&w, &failure)) {
        vtt_report_failure(__FILE__, __LINE__,
            validation_failure_describe(&failure, message, sizeof(message)));
    } else {
        CHECK(1);
    }

    sim_release(&s);
    world_release(&w);
    pool_stop(p);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_the_table_is_readable();
    test_driving();
    test_ordered_movement();
    test_walls_stop_and_slide();
    test_crossings();
    test_thread_count_changes_nothing();
    test_the_world_stays_valid();

    return vtt_test_finish("050-test-tick");
}
/* }}} */
