/*
 * 038-test-fixture.c -- the fixture has to be a valid world, or nothing built on
 * it means anything.
 *
 * Every test and demo from here to phase 8 runs against this world. If it does
 * not validate, all of them are testing something broken, and the failures will
 * appear anywhere except here.
 */

#include "020-test-harness.h"
#include "037-fixture.h"
#include "033-validate.h"
#include "031-region.h"

#include <string.h>

#define M(n) ((wcoord)((n) * WC_ONE))

/* {{{ static void test_it_builds_and_validates */
static void test_it_builds_and_validates(void)
{
    struct world w;
    struct validation_failure failure;
    char message[256];

    TEST_CASE("the fixture builds");

    CHECK(fixture_make_two_rooms(&w) == 1);

    TEST_CASE("and it is a valid world");

    if (!world_validate(&w, &failure)) {
        vtt_report_failure(__FILE__, __LINE__,
            validation_failure_describe(&failure, message, sizeof(message)));
    } else {
        CHECK(1);
    }

    world_release(&w);
}
/* }}} */

/* {{{ static void test_it_has_what_later_phases_need */
static void test_it_has_what_later_phases_need(void)
{
    struct world w;

    TEST_CASE("the pieces later phases will look for are present");

    CHECK(fixture_make_two_rooms(&w) == 1);

    /* Rooms, a cellar inside one of them. */
    CHECK(world_region_count(&w) >= 4);

    /* Enough wall for two rooms, a corridor, and a pillar. */
    CHECK(world_wall_count(&w) >= 16);

    /* A door leaf, a body with eyes, a cup, a torch. */
    CHECK(world_thing_count(&w) >= 5);
    CHECK(world_light_count(&w) >= 2);

    TEST_CASE("the cellar really is nested inside the west room");

    {
        uint32_t cellar = region_deepest_containing(&w, M(4), M(4));
        uint32_t room   = region_deepest_containing(&w, M(15), M(5));

        CHECK(cellar != 0);
        CHECK(room != 0);
        CHECK(cellar != room);
        CHECK(region_is_within(&w, cellar, room) == 1);
    }

    TEST_CASE("there is a body with eyes and a body without");

    {
        uint32_t i;
        int seeing = 0;
        int blind = 0;

        for (i = 1; i < world_thing_count(&w); i++) {
            if (thing_can_see(world_thing_const(&w, i))) {
                seeing++;
            } else {
                blind++;
            }
        }

        /*
         * The claim the data model rests on, present in the fixture so that every
         * later test exercises it: a goblin and a coffee cup are the same record,
         * distinguished only by the numbers in it.
         */
        CHECK(seeing >= 1);
        CHECK(blind >= 1);
    }

    TEST_CASE("there is a door, and it is a wall pointing at a thing");

    {
        uint32_t i;
        int doors = 0;

        for (i = 1; i < world_wall_count(&w); i++) {
            if (world_wall_const(&w, i)->door != 0) {
                doors++;
            }
        }

        CHECK(doors >= 1);
    }

    world_release(&w);
}
/* }}} */

/* {{{ static void test_it_is_the_same_every_time */
static void test_it_is_the_same_every_time(void)
{
    struct world a;
    struct world b;

    TEST_CASE("the fixture takes no seed and never varies");

    /*
     * A test whose fixture varies is a test that fails intermittently, which is
     * worse than a test that fails.
     */
    CHECK(fixture_make_two_rooms(&a) == 1);
    CHECK(fixture_make_two_rooms(&b) == 1);

    CHECK_EQ(world_thing_count(&a), world_thing_count(&b));
    CHECK_EQ(world_wall_count(&a), world_wall_count(&b));

    CHECK_EQ(memcmp(a.things.data, b.things.data,
                    block_bytes_used(&a.things)), 0);
    CHECK_EQ(memcmp(a.walls.data, b.walls.data,
                    block_bytes_used(&a.walls)), 0);

    world_release(&a);
    world_release(&b);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_it_builds_and_validates();
    test_it_has_what_later_phases_need();
    test_it_is_the_same_every_time();

    return vtt_test_finish("038-test-fixture");
}
/* }}} */
