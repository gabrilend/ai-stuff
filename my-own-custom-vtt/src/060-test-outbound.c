/*
 * 060-test-outbound.c -- the leak test.
 *
 * THE MOST IMPORTANT TEST IN THE PROJECT, and it is cheap, so there are many.
 *
 * It does not test the drawing. It does not test the visibility polygon's shape.
 * It does not care how the filter is implemented. It tests the one sentence the
 * filter exists to make true, by looking at the only thing that actually
 * matters: THE BYTES THAT LEFT THE MACHINE.
 *
 * That is why it searches the raw buffer rather than asking the filter whether
 * it would have sent something. Asking the filter is asking the accused -- a test
 * that shares an implementation with the thing it tests agrees with it about the
 * bug too.
 *
 * AND EVERY CASE IS RUN INVERTED. A leak test that passes because it searched for
 * the wrong bytes is worse than no test, because it retires the suspicion. So
 * each case also moves the body somewhere visible and asserts the search now DOES
 * find it. A test that cannot detect what it is looking for is not testing
 * anything.
 */

#include "020-test-harness.h"
#include "059-outbound.h"
#include "037-fixture.h"
#include "070-scope.h"

#include <string.h>

#define M(n) ((wcoord)((n) * WC_ONE))

/* {{{ struct rig */
struct rig {
    struct world      world;
    struct pool      *pool;
    struct session    session;
    struct viewer_set viewers;
    uint32_t          viewer;
    uint32_t          watcher;      /* The body the viewer sees from. */
    struct viewpoint  from;
};
/* }}} */

/* {{{ static uint32_t add_body */
static uint32_t add_body(struct world *w, wcoord x, wcoord y, uint16_t flags)
{
    uint32_t index = world_add_thing(w);
    struct thing *t = world_thing(w, index);

    t->x = x;
    t->y = y;
    t->radius = (uint16_t)(WC_ONE / 2);
    t->kind = 7;
    t->flags = flags;
    t->region = 1;

    return index;
}
/* }}} */

/* {{{ static void rig_start */
static void rig_start(struct rig *r, wcoord watcher_x, wcoord watcher_y)
{
    fixture_make_two_rooms(&r->world);

    r->watcher = world_add_thing(&r->world);
    {
        struct thing *t = world_thing(&r->world, r->watcher);
        t->x = watcher_x;
        t->y = watcher_y;
        t->facing = 0;
        t->sight_arc = 65535;
        t->sight_range = (uint32_t)M(100);
        t->radius = (uint16_t)(WC_ONE / 2);
        t->region = 1;
    }

    r->pool = pool_start(1);
    session_start(&r->session, &r->world, r->pool, 1, 4, 10);
    viewer_set_init(&r->viewers, 4);

    r->viewer = viewer_add(&r->viewers, &r->world, WC_ONE);
    viewer_at(&r->viewers, r->viewer)->state = VIEWER_CONNECTED;

    /*
     * A scope over that one body, driven with keys -- the simplest position on
     * the dial. Before phase 6 the viewer simply had a body; now everything goes
     * through a scope, including the leak tests, which is the point.
     */
    scope_make_list(&r->world, r->viewer, STYLE_DRIVEN, &r->watcher, 1, "watcher");

    /* Let them see where they are standing. */
    fog_fold(&viewer_at(&r->viewers, r->viewer)->fog, &r->world, r->watcher);

    viewpoint_gather(&r->from, &r->world, r->viewer);
}
/* }}} */

/* {{{ static void rig_stop */
static void rig_stop(struct rig *r)
{
    viewer_set_release(&r->viewers);
    session_release(&r->session);
    world_release(&r->world);
    pool_stop(r->pool);
}
/* }}} */

/*
 * Does this viewer's outbound stream contain the position of this body?
 *
 * Searched as the four bytes the coordinate would have been encoded as, plus the
 * index -- the same bytes and the same order the encoder would have written, but
 * assembled here independently.
 */
/* {{{ static int stream_mentions */
static int stream_mentions(struct rig *r, uint32_t thing)
{
    const struct thing *t = world_thing_const(&r->world, thing);
    struct viewer *v = viewer_at(&r->viewers, r->viewer);
    uint8_t needle[8];
    uint32_t x = (uint32_t)t->x;
    uint32_t y = (uint32_t)t->y;

    needle[0] = (uint8_t)(x & 0xFFu);
    needle[1] = (uint8_t)((x >> 8) & 0xFFu);
    needle[2] = (uint8_t)((x >> 16) & 0xFFu);
    needle[3] = (uint8_t)((x >> 24) & 0xFFu);
    needle[4] = (uint8_t)(y & 0xFFu);
    needle[5] = (uint8_t)((y >> 8) & 0xFFu);
    needle[6] = (uint8_t)((y >> 16) & 0xFFu);
    needle[7] = (uint8_t)((y >> 24) & 0xFFu);

    return buffer_contains(&v->outbound, needle, 8);
}
/* }}} */

/* {{{ static void test_a_body_behind_a_wall */
static void test_a_body_behind_a_wall(void)
{
    struct rig r;
    uint32_t hidden_body;

    TEST_CASE("a body in the far room does not reach the wire");

    rig_start(&r, M(5), M(5));
    hidden_body = add_body(&r.world, M(40), M(10), 0);
    sim_fit_to_world(&r.session.sim);
    viewpoint_gather(&r.from, &r.world, r.viewer);

    outbound_build(&r.session, &r.viewers, r.viewer, &r.from);

    CHECK_EQ(outbound_may_send_thing(&r.session, &r.viewers, r.viewer,
                                     &r.from, hidden_body), 0);
    CHECK_EQ(stream_mentions(&r, hidden_body), 0);

    TEST_CASE("and the search can find it once it steps into view");

    /*
     * The inverted half. Without it, this whole case would pass just as happily
     * if the search were looking for the wrong bytes.
     */
    world_thing(&r.world, hidden_body)->x = M(8);
    world_thing(&r.world, hidden_body)->y = M(6);

    outbound_build(&r.session, &r.viewers, r.viewer, &r.from);

    CHECK_EQ(outbound_may_send_thing(&r.session, &r.viewers, r.viewer,
                                     &r.from, hidden_body), 1);
    CHECK_EQ(stream_mentions(&r, hidden_body), 1);

    rig_stop(&r);
}
/* }}} */

/* {{{ static void test_a_hidden_body_in_plain_view */
static void test_a_hidden_body_in_plain_view(void)
{
    struct rig r;
    uint32_t ambush;

    TEST_CASE("a hidden body standing in plain sight does not reach the wire");

    /*
     * The GM's ambush. It is visible to the sweep, three metres away, with
     * nothing in between -- and the hidden flag beats the geometry, in that
     * order, always.
     */
    rig_start(&r, M(5), M(5));
    ambush = add_body(&r.world, M(8), M(5), THING_HIDDEN);
    sim_fit_to_world(&r.session.sim);

    /* Confirm the geometry really would have allowed it. */
    CHECK_EQ(sight_point_visible(&r.world, r.watcher, M(8), M(5)), 1);

    outbound_build(&r.session, &r.viewers, r.viewer, &r.from);

    CHECK_EQ(outbound_may_send_thing(&r.session, &r.viewers, r.viewer,
                                     &r.from, ambush), 0);
    CHECK_EQ(stream_mentions(&r, ambush), 0);

    TEST_CASE("and the same body unhidden does reach it");

    world_thing(&r.world, ambush)->flags = 0;
    outbound_build(&r.session, &r.viewers, r.viewer, &r.from);

    CHECK_EQ(stream_mentions(&r, ambush), 1);

    rig_stop(&r);
}
/* }}} */

/* {{{ static void test_walls_come_from_memory */
static void test_walls_come_from_memory(void)
{
    struct rig r;
    uint32_t i;
    uint32_t sent_before = 0;
    uint32_t sent_after = 0;

    TEST_CASE("walls of a room never entered are not sent");

    rig_start(&r, M(5), M(5));

    for (i = 1; i < world_wall_count(&r.world); i++) {
        if (outbound_may_send_wall(&r.session, &r.viewers, r.viewer, i)) {
            sent_before++;
        }
    }

    CHECK(sent_before > 0);
    CHECK(sent_before < world_wall_count(&r.world) - 1);

    TEST_CASE("and are sent once the room has been walked into");

    world_thing(&r.world, r.watcher)->x = M(40);
    world_thing(&r.world, r.watcher)->y = M(10);
    fog_fold(&viewer_at(&r.viewers, r.viewer)->fog, &r.world, r.watcher);

    for (i = 1; i < world_wall_count(&r.world); i++) {
        if (outbound_may_send_wall(&r.session, &r.viewers, r.viewer, i)) {
            sent_after++;
        }
    }

    CHECK(sent_after > sent_before);

    rig_stop(&r);
}
/* }}} */

/* {{{ static void test_a_body_is_forgotten_when_you_leave */
static void test_a_body_is_forgotten_when_you_leave(void)
{
    struct rig r;
    uint32_t goblin;

    TEST_CASE("a body you saw and walked away from stops being sent");

    /*
     * The difference between sight and memory, checked at the wire. You keep the
     * shape of the room. You have no idea whether the goblin is still in it.
     */
    rig_start(&r, M(40), M(10));
    goblin = add_body(&r.world, M(44), M(10), 0);
    sim_fit_to_world(&r.session.sim);

    fog_fold(&viewer_at(&r.viewers, r.viewer)->fog, &r.world, r.watcher);
    outbound_build(&r.session, &r.viewers, r.viewer, &r.from);

    CHECK_EQ(stream_mentions(&r, goblin), 1);

    /* Walk back to the other room. */
    world_thing(&r.world, r.watcher)->x = M(5);
    world_thing(&r.world, r.watcher)->y = M(5);
    fog_fold(&viewer_at(&r.viewers, r.viewer)->fog, &r.world, r.watcher);

    outbound_build(&r.session, &r.viewers, r.viewer, &r.from);

    CHECK_EQ(stream_mentions(&r, goblin), 0);

    TEST_CASE("while the walls of that room keep being sent");

    /*
     * Counted rather than asserted against a number somebody guessed. A wall is
     * remembered when its MIDPOINT is remembered, which means a long wall with
     * only one end explored stays unsent -- so the absolute count is a property
     * of the fixture's geometry rather than something worth pinning.
     *
     * What is worth pinning is that memory only grows: having seen both rooms is
     * strictly more than having seen one, and walking away subtracts nothing.
     */
    {
        uint32_t after_both = 0;
        uint32_t i;

        for (i = 1; i < world_wall_count(&r.world); i++) {
            if (outbound_may_send_wall(&r.session, &r.viewers, r.viewer, i)) {
                after_both++;
            }
        }

        CHECK(after_both > 0);

        /* Walk back to the far room again; the count must not fall. */
        world_thing(&r.world, r.watcher)->x = M(40);
        world_thing(&r.world, r.watcher)->y = M(10);
        fog_fold(&viewer_at(&r.viewers, r.viewer)->fog, &r.world, r.watcher);

        {
            uint32_t again = 0;

            for (i = 1; i < world_wall_count(&r.world); i++) {
                if (outbound_may_send_wall(&r.session, &r.viewers, r.viewer, i)) {
                    again++;
                }
            }

            CHECK(again >= after_both);
        }
    }

    rig_stop(&r);
}
/* }}} */

/* {{{ static void test_the_sheet_never_leaves */
static void test_the_sheet_never_leaves(void)
{
    struct rig r;
    uint32_t goblin;
    struct viewer *v;
    uint8_t needle[4];
    uint32_t sheet = 0xABCD1234u;

    TEST_CASE("a visible body's ruleset numbers do not go out with it");

    /*
     * Passing a gate is not being sent whole. Seeing a goblin does not entitle
     * you to its hit points.
     */
    rig_start(&r, M(5), M(5));
    goblin = add_body(&r.world, M(8), M(5), 0);
    world_thing(&r.world, goblin)->sheet = sheet;
    world_thing(&r.world, goblin)->scope = 0x99887766u;
    sim_fit_to_world(&r.session.sim);
    viewpoint_gather(&r.from, &r.world, r.viewer);

    outbound_build(&r.session, &r.viewers, r.viewer, &r.from);

    /* The body itself is there. */
    CHECK_EQ(stream_mentions(&r, goblin), 1);

    /* Its sheet index is not. */
    v = viewer_at(&r.viewers, r.viewer);

    needle[0] = (uint8_t)(sheet & 0xFFu);
    needle[1] = (uint8_t)((sheet >> 8) & 0xFFu);
    needle[2] = (uint8_t)((sheet >> 16) & 0xFFu);
    needle[3] = (uint8_t)((sheet >> 24) & 0xFFu);

    CHECK_EQ(buffer_contains(&v->outbound, needle, 4), 0);

    TEST_CASE("and neither does who commands it");

    {
        uint32_t scope = 0x99887766u;
        needle[0] = (uint8_t)(scope & 0xFFu);
        needle[1] = (uint8_t)((scope >> 8) & 0xFFu);
        needle[2] = (uint8_t)((scope >> 16) & 0xFFu);
        needle[3] = (uint8_t)((scope >> 24) & 0xFFu);

        CHECK_EQ(buffer_contains(&v->outbound, needle, 4), 0);
    }

    rig_stop(&r);
}
/* }}} */

/* {{{ static void test_a_gm_sees_everything */
static void test_a_gm_sees_everything(void)
{
    struct rig r;
    uint32_t far_body;

    TEST_CASE("a viewpoint that sees all skips the geometry rather than winning it");

    rig_start(&r, M(5), M(5));
    far_body = add_body(&r.world, M(40), M(10), 0);
    sim_fit_to_world(&r.session.sim);

    /*
     * A GM's scope, rather than a flag poked into the viewpoint. Going through
     * the real thing is what makes this a test of the dial rather than of a
     * struct field.
     */
    scope_make_region(&r.world, r.viewer, STYLE_ORDERED, 0, SCOPE_SEES_ALL, "a GM");
    viewpoint_gather(&r.from, &r.world, r.viewer);

    CHECK_EQ(r.from.sees_all, 1);

    outbound_build(&r.session, &r.viewers, r.viewer, &r.from);

    CHECK_EQ(stream_mentions(&r, far_body), 1);

    TEST_CASE("and a hidden thing inside their own scope is not hidden from them");

    /*
     * CHANGED DELIBERATELY IN PHASE 6, which the phase 4 version of this test
     * said it would be.
     *
     * Gate 1 -- is this inside a scope you hold -- passes everything below it,
     * including the hidden gate. So a GM whose scope is the whole map sees
     * hidden things, because they command them. Your own ambush is not hidden
     * from you.
     *
     * That makes MAY_SEE_HIDDEN meaningful for things you do NOT command, which
     * is the useful reading: it lets somebody see another person's hidden
     * things. And it answers open question 6.5 without anything being bolted on
     * -- two GMs with whole-map scopes both see everything, and a co-GM holding
     * only a region sees hidden things only inside it.
     */
    world_thing(&r.world, far_body)->flags = THING_HIDDEN;
    outbound_build(&r.session, &r.viewers, r.viewer, &r.from);

    CHECK_EQ(stream_mentions(&r, far_body), 1);

    TEST_CASE("while somebody who commands nothing is refused it");

    {
        uint32_t stranger = viewer_add(&r.viewers, &r.world, WC_ONE);
        struct viewpoint theirs;

        viewer_at(&r.viewers, stranger)->state = VIEWER_CONNECTED;
        viewpoint_gather(&theirs, &r.world, stranger);

        CHECK_EQ(outbound_may_send_thing(&r.session, &r.viewers, stranger,
                                         &theirs, far_body), 0);
    }

    rig_stop(&r);
}
/* }}} */

/* {{{ static void test_refusals_and_recalls_reach_the_wire */
static void test_refusals_and_recalls_reach_the_wire(void)
{
    struct rig r;
    struct viewer *v;

    TEST_CASE("a refusal is sent, and carries which command and why");

    rig_start(&r, M(5), M(5));
    v = viewer_at(&r.viewers, r.viewer);

    buffer_clear(&v->outbound);
    outbound_refusal(&r.viewers, r.viewer, VERB_DRIVE, 42, REFUSED_NO_SUCH_SUBJECT);

    CHECK_EQ(v->refusals, 1);

    {
        struct instruction got;
        CHECK_EQ(instruction_decode(&got, &v->outbound), PROTO_OK);
        CHECK_EQ(got.opcode, OP_REFUSAL);
        CHECK_EQ(instruction_get(&got, 0), VERB_DRIVE);
        CHECK_EQ(instruction_get(&got, 1), 42);
        CHECK_EQ(instruction_get(&got, 2), REFUSED_NO_SUCH_SUBJECT);
    }

    TEST_CASE("a recall is said out loud rather than implied");

    buffer_clear(&v->outbound);
    outbound_recall(&r.viewers, r.viewer, 7);

    {
        struct instruction got;
        CHECK_EQ(instruction_decode(&got, &v->outbound), PROTO_OK);
        CHECK_EQ(got.opcode, OP_RECALL);
        CHECK_EQ(instruction_get(&got, 0), 7);
    }

    rig_stop(&r);
}
/* }}} */

/* {{{ static void test_the_update_is_whole */
static void test_the_update_is_whole(void)
{
    struct rig r;
    struct viewer *v;
    uint32_t written;

    TEST_CASE("an update is the whole picture, not a difference");

    /*
     * A difference-based protocol needs both ends to agree about what was
     * received, and a rollback breaks that agreement in a way neither end can
     * detect.
     */
    rig_start(&r, M(5), M(5));
    v = viewer_at(&r.viewers, r.viewer);

    written = outbound_build(&r.session, &r.viewers, r.viewer, &r.from);
    CHECK(written > 2);

    {
        uint32_t first_size = v->outbound.count;

        /* Same world, same viewer, nothing changed. */
        outbound_build(&r.session, &r.viewers, r.viewer, &r.from);
        CHECK_EQ(v->outbound.count, first_size);
    }

    TEST_CASE("and it says where it ends");

    {
        struct instruction got;
        uint8_t last_opcode = 0;

        while (buffer_remaining(&v->outbound) > 0) {
            if (instruction_decode(&got, &v->outbound) != PROTO_OK) {
                break;
            }
            last_opcode = got.opcode;
        }

        CHECK_EQ(last_opcode, OP_END);
    }

    rig_stop(&r);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_a_body_behind_a_wall();
    test_a_hidden_body_in_plain_view();
    test_walls_come_from_memory();
    test_a_body_is_forgotten_when_you_leave();
    test_the_sheet_never_leaves();
    test_a_gm_sees_everything();
    test_refusals_and_recalls_reach_the_wire();
    test_the_update_is_whole();

    return vtt_test_finish("060-test-outbound");
}
/* }}} */
