/*
 * 034-test-validate.c -- breaks each invariant on purpose and checks the message.
 *
 * A validator that passes valid worlds is half a validator. The half that
 * matters is whether it names the right field when something is wrong, because
 * every later file in this project skips a check on the strength of this pass
 * having been honest.
 *
 * So each case here deliberately breaks one thing and asserts which field gets
 * named -- not merely that validation failed.
 */

#include "020-test-harness.h"
#include "033-validate.h"
#include "031-region.h"

#include <string.h>

#define M(n) ((wcoord)((n) * WC_ONE))

/* {{{ static uint32_t add_box */
static uint32_t add_box(struct world *w,
                        wcoord x0, wcoord y0, wcoord x1, wcoord y1,
                        uint32_t parent)
{
    uint32_t first = world_add_vertex(w, x0, y0);
    uint32_t region;
    struct region *r;

    /* Counter-clockwise, which is what the validator insists on. */
    world_add_vertex(w, x1, y0);
    world_add_vertex(w, x1, y1);
    world_add_vertex(w, x0, y1);

    region = world_add_region(w);
    r = world_region(w, region);
    r->first_vertex = first;
    r->vertex_count = 4;
    r->parent = parent;

    return region;
}
/* }}} */

/* {{{ static void build_a_good_world */
static void build_a_good_world(struct world *w)
{
    uint32_t room;
    uint32_t torch;
    uint32_t light;
    uint32_t wall;

    world_init(w, 16, 16, 8, 64, 8, 1024);

    room = add_box(w, 0, 0, M(20), M(20), 0);
    world_region(w, room)->name_offset = string_pool_add(&w->strings, "The Room", 8);

    wall = world_add_wall(w);
    {
        struct wall *wl = world_wall(w, wall);
        wl->ax = 0; wl->ay = 0;
        wl->bx = M(20); wl->by = 0;
        wl->flags = BLOCKS_SIGHT | BLOCKS_MOVEMENT;
    }

    torch = world_add_thing(w);
    {
        struct thing *t = world_thing(w, torch);
        t->x = M(5);
        t->y = M(5);
        t->flags = THING_EMITS_LIGHT;
        t->region = region_deepest_containing(w, t->x, t->y);
    }

    light = world_add_light(w);
    {
        struct light *l = world_light(w, light);
        l->thing = torch;
        l->radius = M(6);
        l->arc = 65535;
    }
}
/* }}} */

/* {{{ static void test_a_good_world_passes */
static void test_a_good_world_passes(void)
{
    struct world w;
    struct validation_failure failure;
    char message[256];

    TEST_CASE("a well-formed world passes");

    build_a_good_world(&w);

    if (!world_validate(&w, &failure)) {
        /* Print what went wrong, so a failure here is diagnosable at a glance. */
        vtt_report_failure(__FILE__, __LINE__,
                           validation_failure_describe(&failure, message, sizeof(message)));
    } else {
        CHECK(1);
    }

    world_release(&w);
}
/* }}} */

/* {{{ static void test_claimed_sentinel */
static void test_claimed_sentinel(void)
{
    struct world w;
    struct validation_failure failure;

    TEST_CASE("something claiming index zero is caught");

    /*
     * If this ever slips through, "zero means nothing" has quietly stopped being
     * true and every unchecked index read in the program is reading a real
     * record when it thinks it is reading emptiness.
     */
    build_a_good_world(&w);
    world_thing(&w, 0)->kind = 7;

    CHECK(world_validate(&w, &failure) == 0);
    CHECK_EQ(strcmp(failure.block, "things"), 0);
    CHECK_EQ(failure.index, 0);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_dangling_reference */
static void test_dangling_reference(void)
{
    struct world w;
    struct validation_failure failure;

    TEST_CASE("an index pointing past the end of its block is caught");

    build_a_good_world(&w);
    world_thing(&w, 1)->region = 9999;

    CHECK(world_validate(&w, &failure) == 0);
    CHECK_EQ(strcmp(failure.block, "things"), 0);
    CHECK_EQ(strcmp(failure.field, "region"), 0);
    CHECK_EQ(failure.found, 9999);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_zero_length_wall */
static void test_zero_length_wall(void)
{
    struct world w;
    struct validation_failure failure;

    TEST_CASE("a wall with no length is caught");

    /*
     * It has no direction, so the sweep cannot compute an angle to its endpoints
     * and the side test cannot say which side of it anything is on. Refused here
     * rather than guarded against in both, which run per body per tick.
     */
    build_a_good_world(&w);
    {
        struct wall *wl = world_wall(&w, 1);
        wl->bx = wl->ax;
        wl->by = wl->ay;
    }

    CHECK(world_validate(&w, &failure) == 0);
    CHECK_EQ(strcmp(failure.block, "walls"), 0);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_bad_boundaries */
static void test_bad_boundaries(void)
{
    struct world w;
    struct validation_failure failure;

    TEST_CASE("a polygon wound the wrong way is caught");

    build_a_good_world(&w);
    {
        /* Swap two vertices, reversing the winding. */
        struct region *r = world_region(&w, 1);
        struct vertex *a = world_vertex(&w, r->first_vertex + 1);
        struct vertex *b = world_vertex(&w, r->first_vertex + 3);
        struct vertex t = *a;
        *a = *b;
        *b = t;
    }

    CHECK(world_validate(&w, &failure) == 0);
    CHECK_EQ(strcmp(failure.block, "regions"), 0);

    world_release(&w);

    TEST_CASE("a polygon with all its vertices in a line is caught");

    build_a_good_world(&w);
    {
        struct region *r = world_region(&w, 1);
        uint32_t v;
        for (v = 0; v < 4; v++) {
            world_vertex(&w, r->first_vertex + v)->y = 0;
        }
    }

    CHECK(world_validate(&w, &failure) == 0);
    CHECK_EQ(strcmp(failure.block, "regions"), 0);

    world_release(&w);

    TEST_CASE("too few vertices is caught");

    build_a_good_world(&w);
    world_region(&w, 1)->vertex_count = 2;

    CHECK(world_validate(&w, &failure) == 0);
    CHECK_EQ(strcmp(failure.field, "vertex_count"), 0);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_region_cycle */
static void test_region_cycle(void)
{
    struct world w;
    struct validation_failure failure;
    uint32_t inner;

    TEST_CASE("a region that contains itself is caught by name");

    build_a_good_world(&w);
    world_region(&w, 1)->parent = 1;

    CHECK(world_validate(&w, &failure) == 0);
    CHECK_EQ(strcmp(failure.field, "parent"), 0);

    world_release(&w);

    TEST_CASE("a longer parent cycle is caught too");

    /*
     * The two-region loop. Caught by the depth check rather than the
     * self-reference check, and it must be caught, because region_is_within
     * runs on every permission check with no cycle guard of its own.
     */
    build_a_good_world(&w);
    inner = add_box(&w, M(2), M(2), M(8), M(8), 1);
    world_region(&w, 1)->parent = inner;

    CHECK(world_validate(&w, &failure) == 0);
    CHECK_EQ(strcmp(failure.block, "regions"), 0);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_light_disagrees_with_thing */
static void test_light_disagrees_with_thing(void)
{
    struct world w;
    struct validation_failure failure;

    TEST_CASE("a light on a thing that does not claim to glow is caught");

    /*
     * The same fact written down twice. Two representations that can disagree
     * eventually will, so the validator is where they are made to agree.
     */
    build_a_good_world(&w);
    world_thing(&w, 1)->flags = 0;

    CHECK(world_validate(&w, &failure) == 0);
    CHECK_EQ(strcmp(failure.block, "lights"), 0);
    CHECK_EQ(strcmp(failure.field, "thing"), 0);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_stale_region_field */
static void test_stale_region_field(void)
{
    struct world w;
    struct validation_failure failure;

    TEST_CASE("a body whose region field has drifted is caught");

    /*
     * The region field is maintained incrementally once the world moves, which
     * is what makes it affordable and also what lets it drift silently. This
     * check recomputes from scratch and compares, and it is the only thing
     * standing between a small bug in the motion pass and a commander quietly
     * owning the wrong goblin.
     */
    build_a_good_world(&w);
    world_thing(&w, 1)->region = 0;

    CHECK(world_validate(&w, &failure) == 0);
    CHECK_EQ(strcmp(failure.block, "things"), 0);
    CHECK_EQ(strcmp(failure.field, "region"), 0);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_bad_name_offset */
static void test_bad_name_offset(void)
{
    struct world w;
    struct validation_failure failure;

    TEST_CASE("a name offset pointing outside the pool is caught");

    build_a_good_world(&w);
    world_region(&w, 1)->name_offset = 9999;

    CHECK(world_validate(&w, &failure) == 0);
    CHECK_EQ(strcmp(failure.field, "name_offset"), 0);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_the_message_is_a_sentence */
static void test_the_message_is_a_sentence(void)
{
    struct world w;
    struct validation_failure failure;
    char message[256];

    TEST_CASE("a failure describes itself in words");

    /*
     * The message is the whole product of this file. "Validation failed" would
     * be true and worthless; naming the block, the index, the field, what was
     * there and what should have been is what ends an investigation.
     */
    build_a_good_world(&w);
    world_thing(&w, 1)->region = 9999;

    CHECK(world_validate(&w, &failure) == 0);

    validation_failure_describe(&failure, message, sizeof(message));

    CHECK(strstr(message, "things[1]") != NULL);
    CHECK(strstr(message, "region") != NULL);
    CHECK(strstr(message, "9999") != NULL);
    CHECK(strstr(message, "expected") != NULL);

    world_release(&w);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_a_good_world_passes();
    test_claimed_sentinel();
    test_dangling_reference();
    test_zero_length_wall();
    test_bad_boundaries();
    test_region_cycle();
    test_light_disagrees_with_thing();
    test_stale_region_field();
    test_bad_name_offset();
    test_the_message_is_a_sentence();

    return vtt_test_finish("034-test-validate");
}
/* }}} */
