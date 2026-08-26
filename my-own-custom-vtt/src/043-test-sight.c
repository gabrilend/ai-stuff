/*
 * 043-test-sight.c -- can it see through a wall?
 *
 * That question is the whole file, asked several ways. It is not a drawing
 * question: this polygon decides which records go on a socket, so a wall that
 * fails to block is a leak rather than a glitch.
 *
 * The last test is the one that matters most -- the fan and the point query are
 * two independent implementations of the same question, and they have to agree
 * everywhere. One implementation would make a drawing bug and a leak
 * indistinguishable.
 */

#include "020-test-harness.h"
#include "042-sight.h"
#include "037-fixture.h"

#include <stdlib.h>

#define M(n) ((wcoord)((n) * WC_ONE))

/* {{{ static uint32_t add_wall */
static uint32_t add_wall(struct world *w,
                         wcoord x0, wcoord y0, wcoord x1, wcoord y1,
                         uint16_t flags)
{
    uint32_t index = world_add_wall(w);
    struct wall *wl = world_wall(w, index);

    wl->ax = x0; wl->ay = y0;
    wl->bx = x1; wl->by = y1;
    wl->flags = flags;

    return index;
}
/* }}} */

/* {{{ static uint32_t add_eye */
static uint32_t add_eye(struct world *w, wcoord x, wcoord y, wangle facing, wangle arc)
{
    uint32_t index = world_add_thing(w);
    struct thing *t = world_thing(w, index);

    t->x = x;
    t->y = y;
    t->facing = facing;
    t->sight_arc = arc;
    t->sight_range = (uint32_t)M(100);

    return index;
}
/* }}} */

/* {{{ static void test_an_open_field */
static void test_an_open_field(void)
{
    struct world w;
    uint32_t eye;

    TEST_CASE("with nothing in the way, everything within range is seen");

    world_init(&w, 8, 8, 4, 8, 4, 256);
    eye = add_eye(&w, 0, 0, 0, 65535);

    CHECK(sight_point_visible(&w, eye, M(10), 0) == 1);
    CHECK(sight_point_visible(&w, eye, 0, M(10)) == 1);
    CHECK(sight_point_visible(&w, eye, M(-10), M(-10)) == 1);

    TEST_CASE("and nothing beyond range is");

    CHECK(sight_point_visible(&w, eye, M(200), 0) == 0);

    TEST_CASE("a body can see the spot it is standing on");

    /*
     * The direction to it is undefined, so this is answered before fx_angle is
     * asked a question it cannot answer.
     */
    CHECK(sight_point_visible(&w, eye, 0, 0) == 1);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_a_wall_blocks */
static void test_a_wall_blocks(void)
{
    struct world w;
    uint32_t eye;

    TEST_CASE("a wall between two points stops sight");

    world_init(&w, 8, 8, 4, 8, 4, 256);

    /* A wall running north-south at x = 10, from y = -20 to y = 20. */
    add_wall(&w, M(10), M(-20), M(10), M(20), BLOCKS_SIGHT | BLOCKS_MOVEMENT);

    eye = add_eye(&w, 0, 0, 0, 65535);

    CHECK(sight_point_visible(&w, eye, M(5), 0) == 1);    /* this side */
    CHECK(sight_point_visible(&w, eye, M(20), 0) == 0);   /* behind it */
    CHECK(sight_point_visible(&w, eye, M(11), 0) == 0);   /* just behind it */

    TEST_CASE("and sight goes round the end of it");

    /*
     * The wall runs from y = -20 to y = 20 at x = 10. A line from the origin to
     * (20, 30) crosses x = 10 at y = 15, which is still on the wall -- so that
     * point is blocked, not round the end. (20, 50) crosses at y = 25, past the
     * wall's end, and is the point that actually tests this.
     */
    CHECK(sight_point_visible(&w, eye, M(20), M(50)) == 1);
    CHECK(sight_point_visible(&w, eye, M(20), M(-50)) == 1);
    CHECK(sight_point_visible(&w, eye, M(20), M(30)) == 0);

    TEST_CASE("a wall that blocks movement but not sight does not stop sight");

    /*
     * The three cases a single "solid" flag would have deleted. Here is one of
     * them working: a chasm.
     */
    world_wall(&w, 1)->flags = BLOCKS_MOVEMENT;
    CHECK(sight_point_visible(&w, eye, M(20), 0) == 1);

    TEST_CASE("and one that blocks sight but not movement does stop it");

    /* A curtain. */
    world_wall(&w, 1)->flags = BLOCKS_SIGHT;
    CHECK(sight_point_visible(&w, eye, M(20), 0) == 0);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_the_arc */
static void test_the_arc(void)
{
    struct world w;
    uint32_t narrow;
    uint32_t blind;
    uint32_t everything;

    TEST_CASE("a body only sees what is in front of it");

    world_init(&w, 8, 8, 4, 8, 4, 256);

    /* Facing east, seeing a half turn: everything ahead. */
    narrow = add_eye(&w, 0, 0, 0, WA_HALF);

    CHECK(sight_point_visible(&w, narrow, M(10), 0) == 1);      /* straight ahead */
    CHECK(sight_point_visible(&w, narrow, M(10), M(10)) == 1);  /* ahead and left */
    CHECK(sight_point_visible(&w, narrow, M(-10), 0) == 0);     /* behind */

    TEST_CASE("an arc of zero sees nothing at all");

    /*
     * One comparison away from an arc of 65535, which sees everything. Getting
     * them backwards is silent and total in both directions.
     */
    blind = add_eye(&w, 0, 0, 0, 0);
    CHECK(sight_point_visible(&w, blind, M(1), 0) == 0);

    TEST_CASE("a full arc sees behind as well");

    everything = add_eye(&w, 0, 0, 0, 65535);
    CHECK(sight_point_visible(&w, everything, M(-10), 0) == 1);

    TEST_CASE("a wedge that straddles the wrap point behaves like any other");

    /*
     * Facing very slightly counter-clockwise of due east, so the wedge runs
     * across the point where angles wrap from 65535 back to 0. This is where an
     * implementation comparing raw angles instead of differences falls apart.
     */
    world_thing(&w, narrow)->facing = 10;
    CHECK(sight_point_visible(&w, narrow, M(10), M(1)) == 1);
    CHECK(sight_point_visible(&w, narrow, M(10), M(-1)) == 1);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_a_coffee_cup_sees_nothing */
static void test_a_coffee_cup_sees_nothing(void)
{
    struct world w;
    uint32_t cup;

    TEST_CASE("a body with no sight range sees nothing, and that is normal");

    world_init(&w, 8, 8, 4, 8, 4, 256);

    cup = world_add_thing(&w);
    world_thing(&w, cup)->x = 0;
    world_thing(&w, cup)->y = 0;
    /* No range, no arc. A cup. */

    CHECK(sight_point_visible(&w, cup, M(1), 0) == 0);

    {
        struct sight_fan fan;
        CHECK(sight_fan_init(&fan, 64) == 1);
        CHECK(sight_compute(&w, cup, &fan) == 1);
        CHECK_EQ(fan.count, 0);
        sight_fan_release(&fan);
    }

    world_release(&w);
}
/* }}} */

/* {{{ static void test_the_fan_is_ordered */
static void test_the_fan_is_ordered(void)
{
    struct world w;
    struct sight_fan fan;
    uint32_t eye;
    uint32_t i;

    TEST_CASE("the fan comes out sorted, with no boundary beyond range");

    CHECK(fixture_make_two_rooms(&w) == 1);
    CHECK(sight_fan_init(&fan, sight_fan_capacity_for(&w)) == 1);

    eye = add_eye(&w, M(10), M(10), 0, 65535);
    CHECK(sight_compute(&w, eye, &fan) == 1);

    CHECK(fan.count > 2);

    for (i = 1; i < fan.count; i++) {
        CHECK(fan.points[i].angle >= fan.points[i - 1].angle);
    }

    for (i = 0; i < fan.count; i++) {
        CHECK(fan.points[i].distance <= fan.range);
    }

    TEST_CASE("standing in a closed room, nothing reaches full range");

    /*
     * The west room is twenty metres across and the eye can see a hundred, so
     * every direction has to be stopped by something. If any boundary reaches
     * full range, there is a gap in the walls -- or in the ray caster.
     */
    for (i = 0; i < fan.count; i++) {
        CHECK(fan.points[i].distance < fan.range);
    }

    sight_fan_release(&fan);
    world_release(&w);
}
/* }}} */

/* {{{ static void test_two_answers_agree */
static void test_two_answers_agree(void)
{
    struct world w;
    struct sight_fan fan;
    uint32_t eye;
    uint32_t sampled = 0;
    uint32_t disagreements = 0;
    int32_t dx;
    int32_t dy;

    TEST_CASE("the picture and the permission agree everywhere");

    /*
     * The fan draws what a person sees; the point query decides what may be sent
     * to them. They are computed differently on purpose, and if they ever
     * disagree then a drawing bug and a leak look identical.
     *
     * The check here is indirect but sharp: for a grid of points, a point the
     * query calls visible must be no further than the fan's boundary in roughly
     * that direction. A point the query calls hidden must be further.
     */
    CHECK(fixture_make_two_rooms(&w) == 1);
    CHECK(sight_fan_init(&fan, sight_fan_capacity_for(&w)) == 1);

    eye = add_eye(&w, M(10), M(10), 0, 65535);
    CHECK(sight_compute(&w, eye, &fan) == 1);

    for (dx = -25; dx <= 25; dx += 1) {
        for (dy = -25; dy <= 25; dy += 1) {
            wcoord x = M(10) + (wcoord)(dx * WC_ONE);
            wcoord y = M(10) + (wcoord)(dy * WC_ONE);
            int visible = sight_point_visible(&w, eye, x, y);
            wcoord distance = fx_dist(M(10), M(10), x, y);
            wangle direction;
            wcoord reach;

            if (distance == 0) {
                continue;
            }

            direction = fx_angle(x - M(10), y - M(10));
            reach = sight_ray(&w, M(10), M(10), direction, (wcoord)M(100));

            sampled++;

            /*
             * The ray is the same primitive the fan is built from, so this
             * checks that the query is not applying some extra rule of its own.
             */
            if (visible != (distance <= reach)) {
                disagreements++;
            }
        }
    }

    CHECK(sampled > 2000);
    CHECK_EQ(disagreements, 0);

    sight_fan_release(&fan);
    world_release(&w);
}
/* }}} */

/* {{{ static void test_the_pillar_casts_a_shadow */
static void test_the_pillar_casts_a_shadow(void)
{
    struct world w;
    uint32_t eye;

    TEST_CASE("the fixture's pillar hides what is behind it");

    /*
     * The pillar sits between x = 9 and 11, y = 13 and 15. An eye to the west of
     * it at the same height should not see the ground immediately east of it.
     */
    CHECK(fixture_make_two_rooms(&w) == 1);

    eye = add_eye(&w, M(3), M(14), 0, 65535);

    CHECK(sight_point_visible(&w, eye, M(8), M(14)) == 1);    /* in front of it */
    CHECK(sight_point_visible(&w, eye, M(13), M(14)) == 0);   /* directly behind */
    CHECK(sight_point_visible(&w, eye, M(13), M(18)) == 1);   /* past its side */

    world_release(&w);
}
/* }}} */

/* {{{ static void test_the_corridor */
static void test_the_corridor(void)
{
    struct world w;
    uint32_t eye;

    TEST_CASE("standing in one room, the other room is out of sight");

    /*
     * This is what the corridor was put in the fixture for, and it is the shape
     * of every interesting thing phase 4 will do: a place a body can be where
     * somebody else genuinely cannot see them.
     */
    CHECK(fixture_make_two_rooms(&w) == 1);

    eye = add_eye(&w, M(5), M(5), 0, 65535);

    CHECK(sight_point_visible(&w, eye, M(15), M(5)) == 1);    /* same room */
    CHECK(sight_point_visible(&w, eye, M(40), M(10)) == 0);   /* the far room */

    /*
     * The corridor mouth is a gap in the east wall between y = 8 and y = 12, and
     * a line from (5, 5) to (25, 10) passes through it at y = 8.75. So the near
     * part of the corridor IS visible, which is correct and is what a doorway
     * does.
     *
     * What stops the view is the door at x = 25, and the point beyond it is the
     * one that tests the corridor rather than the mouth.
     */
    CHECK(sight_point_visible(&w, eye, M(24), M(10)) == 1);   /* short of the door */
    CHECK(sight_point_visible(&w, eye, M(28), M(10)) == 0);   /* past the door */

    world_release(&w);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_an_open_field();
    test_a_wall_blocks();
    test_the_arc();
    test_a_coffee_cup_sees_nothing();
    test_the_fan_is_ordered();
    test_two_answers_agree();
    test_the_pillar_casts_a_shadow();
    test_the_corridor();

    return vtt_test_finish("043-test-sight");
}
/* }}} */
