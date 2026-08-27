/*
 * 107-test-controls.c -- can three dial positions be turned into a point?
 *
 * The dials belong to a view and the server must never hear about them. The
 * arithmetic between them and a point in the world does not belong to a view,
 * and this is why: arithmetic in C is arithmetic that can be checked without a
 * browser, forty times, in a millisecond.
 *
 * The interesting checks are the ones about SHAPE rather than about particular
 * numbers -- that a diagonal is not longer than a straight line, that turning
 * eight times comes back to where it started, that distance does not wrap. Those
 * are the properties a person would notice through their hands without being
 * able to say what was wrong.
 */

#include "020-test-harness.h"
#include "106-controls.h"

#include <string.h>

#define M(n) ((wcoord)((n) * WC_ONE))

/* {{{ static void test_the_dials_turn */
static void test_the_dials_turn(void)
{
    struct dial d;
    int i;

    TEST_CASE("a direction wraps and a distance does not");

    dial_init(&d);
    CHECK_EQ(d.aim, AIM_NORTH);
    CHECK_EQ(d.reach, REACH_NEAR);
    CHECK_EQ(d.choosing, CHOOSING_WHOLE_PARTY);

    /* Eight turns comes back. A control you can walk off the end of is a control
     * that needs a boundary check every time it is read. */
    for (i = 0; i < 8; i++) {
        dial_turn_aim(&d, 1);
    }
    CHECK_EQ(d.aim, AIM_NORTH);

    dial_turn_aim(&d, -1);
    CHECK_EQ(d.aim, AIM_NORTHWEST);

    dial_turn_aim(&d, 3);
    CHECK_EQ(d.aim, AIM_EAST);

    /*
     * Distance is a line rather than a circle. Somebody pressing "further" three
     * times expects the far end, not to be back where they started.
     */
    dial_turn_reach(&d, 5);
    CHECK_EQ(d.reach, REACH_FAR);

    dial_turn_reach(&d, -9);
    CHECK_EQ(d.reach, REACH_CLOSE);
}
/* }}} */

/* {{{ static void test_cycling_the_choice */
static void test_cycling_the_choice(void)
{
    struct dial d;

    TEST_CASE("one key walks everybody, then each of them, then everybody");

    dial_init(&d);

    dial_cycle_choice(&d, 4);
    CHECK_EQ(d.choosing, CHOOSING_ONE);
    CHECK_EQ(d.which, 0);

    dial_cycle_choice(&d, 4);
    CHECK_EQ(d.which, 1);

    dial_cycle_choice(&d, 4);
    dial_cycle_choice(&d, 4);
    CHECK_EQ(d.which, 3);

    /* And round to everybody again. The whole party is a POSITION on the same
     * dial rather than a separate mode, which is what makes pointing at all four
     * as few keystrokes as pointing at one. */
    dial_cycle_choice(&d, 4);
    CHECK_EQ(d.choosing, CHOOSING_WHOLE_PARTY);

    TEST_CASE("a party of nobody cannot be pointed at one of");

    dial_choose_one(&d, 2);
    dial_cycle_choice(&d, 0);
    CHECK_EQ(d.choosing, CHOOSING_WHOLE_PARTY);
}
/* }}} */

/* {{{ static void test_resolving_to_a_point */
static void test_resolving_to_a_point(void)
{
    struct dial d;
    wcoord x, y;

    TEST_CASE("north is up, east is right, and the distance is the distance");

    dial_init(&d);
    d.aim = AIM_NORTH;
    d.reach = REACH_NEAR;      /* eight metres */

    dial_resolve(&d, M(10), M(10), &x, &y);
    CHECK_EQ(x, M(10));
    CHECK_EQ(y, M(18));

    d.aim = AIM_EAST;
    dial_resolve(&d, M(10), M(10), &x, &y);
    CHECK_EQ(x, M(18));
    CHECK_EQ(y, M(10));

    d.aim = AIM_SOUTH;
    dial_resolve(&d, M(10), M(10), &x, &y);
    CHECK_EQ(y, M(2));

    d.aim = AIM_WEST;
    dial_resolve(&d, M(10), M(10), &x, &y);
    CHECK_EQ(x, M(2));

    TEST_CASE("close is three metres, near is eight, far is sixteen");

    d.aim = AIM_NORTH;

    d.reach = REACH_CLOSE;
    dial_resolve(&d, 0, 0, &x, &y);
    CHECK_EQ(y, M(3));

    d.reach = REACH_FAR;
    dial_resolve(&d, 0, 0, &x, &y);
    CHECK_EQ(y, M(16));
}
/* }}} */

/*
 * The property somebody would feel through their hands without being able to
 * name it: a diagonal must not travel further than a straight line.
 */
/* {{{ static void test_a_diagonal_is_not_longer */
static void test_a_diagonal_is_not_longer(void)
{
    struct dial d;
    uint8_t aim;

    TEST_CASE("every direction travels the same distance");

    dial_init(&d);
    d.reach = REACH_FAR;

    for (aim = 0; aim < AIM_COUNT; aim++) {
        wcoord x, y;
        int64_t dx, dy;
        int64_t travelled;
        int64_t wanted = (int64_t)M(16);

        d.aim = aim;
        dial_resolve(&d, 0, 0, &x, &y);

        dx = (int64_t)x;
        dy = (int64_t)y;
        travelled = dx * dx + dy * dy;

        /*
         * Compared as squares, so no square root is needed and no floating point
         * enters a project that has banned it. A tolerance of one per cent,
         * because the diagonal unit is 724 of 1024 rather than the exact
         * irrational number -- and a whole-number table is what keeps a replay
         * reproducible.
         */
        {
            int64_t wanted_squared = wanted * wanted;
            int64_t slack = wanted_squared / 50;

            if (travelled > wanted_squared + slack
                || travelled < wanted_squared - slack) {
                fprintf(stderr,
                        "    %s travels a squared distance of %lld where %lld"
                        " was wanted\n",
                        aim_name(aim), (long long)travelled,
                        (long long)wanted_squared);
            }

            CHECK(travelled <= wanted_squared + slack);
            CHECK(travelled >= wanted_squared - slack);
        }
    }
}
/* }}} */

/*
 * The diagram is drawn from the dial and cannot disagree with it.
 */
/* {{{ static void test_the_diagram */
static void test_the_diagram(void)
{
    struct dial d;
    char picture[128];
    uint8_t aim;

    TEST_CASE("the mark moves when the dial does, in every direction");

    dial_init(&d);

    for (aim = 0; aim < AIM_COUNT; aim++) {
        char before[128];

        d.aim = aim;
        d.reach = REACH_NEAR;
        dial_diagram(&d, picture, sizeof(picture));

        /* You are always there, and so is the mark. */
        CHECK(strchr(picture, 'o') != NULL);
        CHECK(strchr(picture, 'X') != NULL);

        /* And it is a different picture from the one before it. */
        if (aim > 0) {
            d.aim = (uint8_t)(aim - 1u);
            dial_diagram(&d, before, sizeof(before));
            d.aim = aim;

            CHECK(strcmp(picture, before) != 0);
        }
    }

    TEST_CASE("a further reach draws a longer line");

    {
        char close_up[128];
        char far_off[128];
        uint32_t close_marks = 0;
        uint32_t far_marks = 0;
        uint32_t i;

        d.aim = AIM_NORTH;

        d.reach = REACH_CLOSE;
        dial_diagram(&d, close_up, sizeof(close_up));

        d.reach = REACH_FAR;
        dial_diagram(&d, far_off, sizeof(far_off));

        for (i = 0; close_up[i] != '\0'; i++) {
            if (close_up[i] != ' ' && close_up[i] != '\n') {
                close_marks++;
            }
        }
        for (i = 0; far_off[i] != '\0'; i++) {
            if (far_off[i] != ' ' && far_off[i] != '\n') {
                far_marks++;
            }
        }

        CHECK(far_marks > close_marks);
    }

    TEST_CASE("a buffer too small stops cleanly rather than running on");

    {
        char tiny[6];

        dial_diagram(&d, tiny, sizeof(tiny));
        CHECK(strlen(tiny) < sizeof(tiny));
    }
}
/* }}} */

/* {{{ static void test_the_names */
static void test_the_names(void)
{
    char said[128];
    struct dial d;

    TEST_CASE("every position has a word, and out of range says so");

    CHECK(strcmp(aim_name(AIM_NORTHEAST), "north-east") == 0);
    CHECK(strcmp(reach_name(REACH_FAR), "far") == 0);
    CHECK(strcmp(act_name(ACT_REACH), "reach") == 0);

    CHECK(strcmp(aim_name(AIM_COUNT), "north") != 0);
    CHECK(strcmp(reach_name(99), "close") != 0);
    CHECK(strcmp(act_name(99), "go") != 0);

    TEST_CASE("and the readout says where every dial points");

    dial_init(&d);
    dial_sentence(&d, 4, said, sizeof(said));
    CHECK(strstr(said, "all 4") != NULL);
    CHECK(strstr(said, "north") != NULL);
    CHECK(strstr(said, "8 m") != NULL);

    dial_choose_one(&d, 2);
    dial_sentence(&d, 4, said, sizeof(said));
    CHECK(strstr(said, "number 3 of 4") != NULL);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_the_dials_turn();
    test_cycling_the_choice();
    test_resolving_to_a_point();
    test_a_diagonal_is_not_longer();
    test_the_diagram();
    test_the_names();

    return vtt_test_finish("107-test-controls");
}
/* }}} */
