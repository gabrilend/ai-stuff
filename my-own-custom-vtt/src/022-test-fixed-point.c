/*
 * 022-test-fixed-point.c -- pins down the arithmetic's edge behaviour.
 *
 * The interesting content of 021-fixed-point.c is almost entirely at the edges:
 * how it rounds, what it does either side of zero, and what happens when an
 * angle wraps past a full turn. The middle of the range takes care of itself.
 *
 * So this file is mostly a specification of those edges, written as checks. If
 * somebody later "simplifies" the rounding in fx_div back to plain integer
 * division, this is what tells them what they broke.
 */

#include "020-test-harness.h"
#include "021-fixed-point.h"

/* {{{ static void test_multiply */
static void test_multiply(void)
{
    TEST_CASE("fx_mul basic identities");

    CHECK_EQ(fx_mul(WC_ONE, WC_ONE), WC_ONE);
    CHECK_EQ(fx_mul(WC_ONE, 0), 0);
    CHECK_EQ(fx_mul(0, WC_ONE), 0);
    CHECK_EQ(fx_mul(2 * WC_ONE, 3 * WC_ONE), 6 * WC_ONE);

    TEST_CASE("fx_mul is symmetric about zero");

    /*
     * This is the whole reason fx_mul exists rather than callers writing the
     * shift themselves. An arithmetic right shift rounds toward negative
     * infinity, so the naive version makes leftward movement lose a fraction
     * that rightward movement keeps -- and a body oscillating between the two
     * creeps steadily in one direction over a long session.
     */
    {
        wcoord a = 1234;
        wcoord b = 5678;

        CHECK_EQ(fx_mul(-a, b), -fx_mul(a, b));
        CHECK_EQ(fx_mul(a, -b), -fx_mul(a, b));
        CHECK_EQ(fx_mul(-a, -b), fx_mul(a, b));
    }

    TEST_CASE("fx_mul does not overflow at realistic magnitudes");

    /*
     * Two hundred metres times two hundred metres. The intermediate here is
     * about 4.2e10, which does not fit in 32 bits -- a caller multiplying by hand
     * would wrap and get nonsense.
     */
    CHECK_EQ(fx_mul(200 * WC_ONE, 200 * WC_ONE), 40000 * WC_ONE);
}
/* }}} */

/* {{{ static void test_divide */
static void test_divide(void)
{
    TEST_CASE("fx_div basic identities");

    CHECK_EQ(fx_div(WC_ONE, WC_ONE), WC_ONE);
    CHECK_EQ(fx_div(6 * WC_ONE, 3 * WC_ONE), 2 * WC_ONE);
    CHECK_EQ(fx_div(WC_ONE, 2 * WC_ONE), WC_ONE / 2);
    CHECK_EQ(fx_div(0, WC_ONE), 0);

    TEST_CASE("fx_div is symmetric about zero");

    {
        wcoord a = 7 * WC_ONE;
        wcoord b = 3 * WC_ONE;

        CHECK_EQ(fx_div(-a, b), -fx_div(a, b));
        CHECK_EQ(fx_div(a, -b), -fx_div(a, b));
        CHECK_EQ(fx_div(-a, -b), fx_div(a, b));
    }

    TEST_CASE("fx_div rounds to nearest rather than truncating");

    /*
     * One third of a unit is 341.33 in this scale. Truncation gives 341;
     * rounding to nearest gives 341 as well, so the sharper case is two thirds:
     * 682.67, where truncation gives 682 and rounding gives 683.
     */
    CHECK_EQ(fx_div(2 * WC_ONE, 3 * WC_ONE), 683);
}
/* }}} */

/* {{{ static void test_distance */
static void test_distance(void)
{
    TEST_CASE("fx_dist on a three-four-five triangle");

    CHECK_EQ(fx_dist(0, 0, 3 * WC_ONE, 4 * WC_ONE), 5 * WC_ONE);
    CHECK_EQ(fx_dist(3 * WC_ONE, 4 * WC_ONE, 0, 0), 5 * WC_ONE);
    CHECK_EQ(fx_dist(0, 0, 0, 0), 0);

    TEST_CASE("fx_dist2 avoids the square root");

    CHECK_EQ(fx_dist2(0, 0, 3 * WC_ONE, 4 * WC_ONE),
             (int64_t)(5 * WC_ONE) * (int64_t)(5 * WC_ONE));

    TEST_CASE("fx_dist is unsigned in every direction");

    CHECK_EQ(fx_dist(0, 0, -3 * WC_ONE, -4 * WC_ONE), 5 * WC_ONE);
    CHECK_EQ(fx_dist(0, 0, -3 * WC_ONE, 4 * WC_ONE), 5 * WC_ONE);

    TEST_CASE("fx_sqrt at the extremes");

    CHECK_EQ(fx_sqrt(0), 0);
    CHECK_EQ(fx_sqrt(1), 1);
    CHECK_EQ(fx_sqrt(144), 12);

    /*
     * A distance right across the representable world, squared. This is where a
     * 32-bit intermediate would have wrapped, and it is the reason fx_dist2
     * returns 64 bits.
     */
    CHECK_EQ(fx_sqrt((int64_t)2000000000 * (int64_t)2000000000), 2000000000);
}
/* }}} */

/* {{{ static void test_trigonometry */
static void test_trigonometry(void)
{
    TEST_CASE("sine and cosine at the four cardinal angles");

    CHECK_EQ(fx_sin(0), 0);
    CHECK_EQ(fx_sin(WA_QUARTER), WC_ONE);
    CHECK_EQ(fx_sin(WA_HALF), 0);
    CHECK_EQ(fx_sin(WA_HALF + WA_QUARTER), -WC_ONE);

    CHECK_EQ(fx_cos(0), WC_ONE);
    CHECK_EQ(fx_cos(WA_QUARTER), 0);
    CHECK_EQ(fx_cos(WA_HALF), -WC_ONE);

    TEST_CASE("the angle space wraps by overflowing");

    /*
     * A full turn added to an angle is the same angle. This works because the
     * type is exactly as wide as the turn, so the wrap costs nothing and cannot
     * be forgotten.
     */
    CHECK_EQ(fx_sin((wangle)(WA_QUARTER + WA_TURN)), fx_sin(WA_QUARTER));

    TEST_CASE("a unit vector has unit length in every direction");

    /*
     * Tolerance of two thousandths of a metre. The table is quantised and so is
     * the result, so an exact equality here would be testing the rounding rather
     * than the trigonometry.
     */
    {
        int i;
        for (i = 0; i < 16; i++) {
            wangle a = (wangle)(i * (WA_TURN / 16));
            struct wvec v = fx_from_angle(a, WC_ONE);
            CHECK_NEAR(fx_dist(0, 0, v.x, v.y), WC_ONE, 2);
        }
    }
}
/* }}} */

/* {{{ static void test_angle_from_vector */
static void test_angle_from_vector(void)
{
    TEST_CASE("fx_angle at the cardinal directions");

    CHECK_EQ(fx_angle(WC_ONE, 0), 0);
    CHECK_EQ(fx_angle(0, WC_ONE), WA_QUARTER);
    CHECK_EQ(fx_angle(-WC_ONE, 0), WA_HALF);
    CHECK_EQ(fx_angle(0, -WC_ONE), WA_HALF + WA_QUARTER);

    TEST_CASE("fx_angle at the diagonals");

    CHECK_EQ(fx_angle(WC_ONE, WC_ONE), WA_EIGHTH);
    CHECK_EQ(fx_angle(-WC_ONE, WC_ONE), WA_QUARTER + WA_EIGHTH);
    CHECK_EQ(fx_angle(-WC_ONE, -WC_ONE), WA_HALF + WA_EIGHTH);
    CHECK_EQ(fx_angle(WC_ONE, -WC_ONE), WA_HALF + WA_QUARTER + WA_EIGHTH);

    TEST_CASE("the zero vector has no direction and says zero");

    CHECK_EQ(fx_angle(0, 0), 0);

    TEST_CASE("fx_angle inverts fx_from_angle");

    /*
     * The round trip is the real test, because it exercises both the octant
     * reflections and the table at once. Tolerance of sixteen angle units is
     * about a tenth of a degree, which is the arctangent table's own resolution.
     */
    {
        int i;
        for (i = 0; i < 64; i++) {
            wangle a = (wangle)(i * (WA_TURN / 64));
            struct wvec v = fx_from_angle(a, 100 * WC_ONE);
            wangle back = fx_angle(v.x, v.y);

            CHECK_NEAR(fx_angle_diff(a, back), 0, 16);
        }
    }
}
/* }}} */

/* {{{ static void test_angle_difference */
static void test_angle_difference(void)
{
    TEST_CASE("fx_angle_diff takes the short way round");

    CHECK_EQ(fx_angle_diff(0, 100), 100);
    CHECK_EQ(fx_angle_diff(100, 0), -100);

    /*
     * The case the naive subtraction gets wrong. These two angles are 636 units
     * apart going forwards, and 64,900 apart going backwards; a plain subtraction
     * reports the long way.
     */
    CHECK_EQ(fx_angle_diff(65000, 100), 636);
    CHECK_EQ(fx_angle_diff(100, 65000), -636);

    TEST_CASE("fx_angle_diff at exactly half a turn");

    /*
     * Half a turn is equally far in both directions, so either sign would be
     * defensible. It resolves negative, and that is pinned here so that a change
     * to the comparison shows up as a failing test rather than as an
     * intermittent difference in which way something turns.
     */
    CHECK_EQ(fx_angle_diff(0, WA_HALF), -WA_HALF);
}
/* }}} */

/* {{{ static void test_arc_membership */
static void test_arc_membership(void)
{
    TEST_CASE("an arc of zero sees nothing and a full arc sees everything");

    /*
     * These two are one comparison apart and getting them backwards is silent
     * and total -- every body blind, or every body all-seeing, with no error
     * raised either way.
     */
    CHECK(fx_angle_in_arc(0, 0, 0) == 0);
    CHECK(fx_angle_in_arc(WA_HALF, 0, 0) == 0);

    CHECK(fx_angle_in_arc(0, 0, 65535) == 1);
    CHECK(fx_angle_in_arc(WA_HALF, 0, 65535) == 1);

    TEST_CASE("a half-turn arc is everything in front");

    CHECK(fx_angle_in_arc(0, 0, WA_HALF) == 1);
    CHECK(fx_angle_in_arc(WA_QUARTER, 0, WA_HALF) == 1);
    CHECK(fx_angle_in_arc((wangle)(WA_QUARTER + 1), 0, WA_HALF) == 0);
    CHECK(fx_angle_in_arc(WA_HALF, 0, WA_HALF) == 0);

    TEST_CASE("an arc works the same when it straddles zero");

    /*
     * A body facing very slightly counter-clockwise of due east. Its wedge runs
     * across the wrap point, which is where an implementation that compares raw
     * angle values instead of differences falls apart.
     */
    CHECK(fx_angle_in_arc(65000, 0, WA_QUARTER) == 1);
    CHECK(fx_angle_in_arc(500, 0, WA_QUARTER) == 1);
    CHECK(fx_angle_in_arc(WA_QUARTER, 0, WA_QUARTER) == 0);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_multiply();
    test_divide();
    test_distance();
    test_trigonometry();
    test_angle_from_vector();
    test_angle_difference();
    test_arc_membership();

    return vtt_test_finish("022-test-fixed-point");
}
/* }}} */
