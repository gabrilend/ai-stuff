/*
 * 030-test-geometry.c -- the collinear cases, mostly.
 *
 * The interesting content of 029-geometry.c is what it does when three points
 * are in a line, when two walls share an endpoint, and when a point sits exactly
 * on a boundary. All three happen constantly in a generated dungeon, where
 * corridors meet at right angles and rooms share walls, so none of them is an
 * edge case that can be left for later.
 */

#include "020-test-harness.h"
#include "029-geometry.h"
#include "027-world.h"

#define M(n) ((wcoord)((n) * WC_ONE))

/* {{{ static void test_which_side */
static void test_which_side(void)
{
    TEST_CASE("geom_side names left, right, and exactly on the line");

    /* A segment running east along the x axis. */
    CHECK(geom_side(0, 0, M(10), 0, M(5), M(1)) > 0);   /* north of it: left */
    CHECK(geom_side(0, 0, M(10), 0, M(5), M(-1)) < 0);  /* south of it: right */

    TEST_CASE("collinear is exactly zero and is a real case");

    /*
     * Not a rounding artefact. This is what happens every time a wall meets
     * another wall end to end, which in a rectangular room is four times.
     */
    CHECK_EQ(geom_side(0, 0, M(10), 0, M(5), 0), 0);
    CHECK_EQ(geom_side(0, 0, M(10), 0, M(20), 0), 0);   /* beyond the end, still in line */
    CHECK_EQ(geom_side(0, 0, M(10), 0, M(-5), 0), 0);

    TEST_CASE("the sign does not wrap at a kilometre");

    /*
     * Two positions a kilometre apart multiply to about 2^42. A 32-bit
     * intermediate would wrap here, and a wrapped sign means a one-way wall that
     * blocks from the wrong side.
     */
    CHECK(geom_side(0, 0, M(1000), 0, M(500), M(1)) > 0);
    CHECK(geom_side(0, 0, M(1000), 0, M(500), M(-1)) < 0);
}
/* }}} */

/* {{{ static void test_segments_crossing */
static void test_segments_crossing(void)
{
    TEST_CASE("segments that plainly cross");

    CHECK(geom_segments_cross(0, 0, M(10), M(10),
                              0, M(10), M(10), 0) == 1);

    TEST_CASE("segments that plainly do not");

    CHECK(geom_segments_cross(0, 0, M(10), 0,
                              0, M(5), M(10), M(5)) == 0);

    TEST_CASE("touching at an endpoint counts as crossing");

    /*
     * A body sliding along one wall into a second must be stopped by the second
     * even though it only grazes it. And a polygon whose edges merely touch is
     * still self-intersecting.
     */
    CHECK(geom_segments_cross(0, 0, M(10), 0,
                              M(10), 0, M(10), M(10)) == 1);

    TEST_CASE("collinear and overlapping counts, collinear and apart does not");

    CHECK(geom_segments_cross(0, 0, M(10), 0,
                              M(5), 0, M(15), 0) == 1);

    CHECK(geom_segments_cross(0, 0, M(10), 0,
                              M(20), 0, M(30), 0) == 0);
}
/* }}} */

/* {{{ static void test_closest_point */
static void test_closest_point(void)
{
    wcoord x;
    wcoord y;

    TEST_CASE("the nearest point along the middle of a segment");

    geom_closest_point_on_segment(0, 0, M(10), 0, M(5), M(3), &x, &y);
    CHECK_EQ(x, M(5));
    CHECK_EQ(y, 0);

    TEST_CASE("past either end, the end itself is nearest");

    /*
     * The two end caps. A circle can strike a wall's end rather than its side,
     * and collision resolution gets this wrong if the projection is not clamped.
     */
    geom_closest_point_on_segment(0, 0, M(10), 0, M(-5), M(3), &x, &y);
    CHECK_EQ(x, 0);
    CHECK_EQ(y, 0);

    geom_closest_point_on_segment(0, 0, M(10), 0, M(50), M(3), &x, &y);
    CHECK_EQ(x, M(10));
    CHECK_EQ(y, 0);

    TEST_CASE("a zero-length segment is its own nearest point");

    geom_closest_point_on_segment(M(4), M(4), M(4), M(4), M(9), M(9), &x, &y);
    CHECK_EQ(x, M(4));
    CHECK_EQ(y, M(4));

    TEST_CASE("distance to a segment is measured to the nearest part of it");

    CHECK_EQ(geom_distance2_to_segment(0, 0, M(10), 0, M(5), M(3)),
             (int64_t)M(3) * (int64_t)M(3));
}
/* }}} */

/* {{{ static void test_broad_phase */
static void test_broad_phase(void)
{
    TEST_CASE("a segment inside the circle is found");

    CHECK(geom_segment_within_circle(0, 0, M(10), 0, M(5), M(1), M(2)) == 1);

    TEST_CASE("a segment well outside is not");

    CHECK(geom_segment_within_circle(0, 0, M(10), 0, M(5), M(50), M(2)) == 0);

    TEST_CASE("a segment grazing the circle exactly is found");

    /*
     * The broad phase may be too generous and must never be too strict. A
     * boundary case resolving the wrong way is a wall that vanishes, and
     * somebody sees through stone.
     */
    CHECK(geom_segment_within_circle(0, 0, M(10), 0, M(5), M(2), M(2)) == 1);

    TEST_CASE("a segment whose middle is far but whose end is near is found");

    /* A long wall running away from the circle, but starting inside it. */
    CHECK(geom_segment_within_circle(0, 0, M(1000), M(1000), M(1), M(1), M(3)) == 1);
}
/* }}} */

/* {{{ static void test_polygon_containment */
static void test_polygon_containment(void)
{
    /* A ten-by-ten room with its corner at the origin, wound counter-clockwise. */
    struct vertex room[4];

    room[0].x = 0;      room[0].y = 0;
    room[1].x = M(10);  room[1].y = 0;
    room[2].x = M(10);  room[2].y = M(10);
    room[3].x = 0;      room[3].y = M(10);

    TEST_CASE("plainly inside and plainly outside");

    CHECK(geom_polygon_contains(room, 4, M(5), M(5)) == 1);
    CHECK(geom_polygon_contains(room, 4, M(50), M(5)) == 0);
    CHECK(geom_polygon_contains(room, 4, M(-5), M(5)) == 0);
    CHECK(geom_polygon_contains(room, 4, M(5), M(50)) == 0);

    TEST_CASE("a point exactly on the boundary is inside");

    /*
     * Arbitrary, and pinned here rather than left to the arithmetic. A body
     * walking along a region's edge has to be consistently in or consistently
     * out; if it flickers, the ruleset gets an entered-the-tavern event on every
     * step.
     */
    CHECK(geom_polygon_contains(room, 4, M(5), 0) == 1);
    CHECK(geom_polygon_contains(room, 4, 0, M(5)) == 1);

    TEST_CASE("a point exactly on a corner is inside");

    CHECK(geom_polygon_contains(room, 4, 0, 0) == 1);
    CHECK(geom_polygon_contains(room, 4, M(10), M(10)) == 1);

    TEST_CASE("the crossing count is not fooled by a vertex on the ray");

    /*
     * The classic failure. A horizontal ray from the test point passes exactly
     * through a vertex, and a symmetric comparison counts that crossing twice or
     * not at all. Here the ray at y = 0 leaves through the corner at (10, 0).
     */
    CHECK(geom_polygon_contains(room, 4, M(-1), 0) == 0);

    TEST_CASE("an L-shaped room, where a convex test would be wrong");

    {
        struct vertex ell[6];
        ell[0].x = 0;      ell[0].y = 0;
        ell[1].x = M(10);  ell[1].y = 0;
        ell[2].x = M(10);  ell[2].y = M(4);
        ell[3].x = M(4);   ell[3].y = M(4);
        ell[4].x = M(4);   ell[4].y = M(10);
        ell[5].x = 0;      ell[5].y = M(10);

        CHECK(geom_polygon_contains(ell, 6, M(2), M(2)) == 1);   /* in the corner */
        CHECK(geom_polygon_contains(ell, 6, M(8), M(2)) == 1);   /* in the foot */
        CHECK(geom_polygon_contains(ell, 6, M(2), M(8)) == 1);   /* up the leg */
        CHECK(geom_polygon_contains(ell, 6, M(8), M(8)) == 0);   /* the notch */
    }

    TEST_CASE("fewer than three vertices contains nothing");

    CHECK(geom_polygon_contains(room, 2, M(5), M(5)) == 0);
}
/* }}} */

/* {{{ static void test_polygon_shape */
static void test_polygon_shape(void)
{
    struct vertex counter_clockwise[4];
    struct vertex clockwise[4];
    struct vertex bowtie[4];

    counter_clockwise[0].x = 0;      counter_clockwise[0].y = 0;
    counter_clockwise[1].x = M(10);  counter_clockwise[1].y = 0;
    counter_clockwise[2].x = M(10);  counter_clockwise[2].y = M(10);
    counter_clockwise[3].x = 0;      counter_clockwise[3].y = M(10);

    clockwise[0].x = 0;      clockwise[0].y = 0;
    clockwise[1].x = 0;      clockwise[1].y = M(10);
    clockwise[2].x = M(10);  clockwise[2].y = M(10);
    clockwise[3].x = M(10);  clockwise[3].y = 0;

    TEST_CASE("winding shows up as the sign of the area");

    CHECK(geom_polygon_area2(counter_clockwise, 4) > 0);
    CHECK(geom_polygon_area2(clockwise, 4) < 0);

    TEST_CASE("both windings are the same size");

    CHECK_EQ(geom_polygon_area2(counter_clockwise, 4),
             -geom_polygon_area2(clockwise, 4));

    TEST_CASE("containment does not care which way a polygon was wound");

    CHECK(geom_polygon_contains(clockwise, 4, M(5), M(5)) == 1);

    TEST_CASE("a well-formed polygon does not cross itself");

    CHECK(geom_polygon_self_intersects(counter_clockwise, 4) == 0);
    CHECK(geom_polygon_self_intersects(clockwise, 4) == 0);

    TEST_CASE("a bowtie does cross itself");

    bowtie[0].x = 0;      bowtie[0].y = 0;
    bowtie[1].x = M(10);  bowtie[1].y = M(10);
    bowtie[2].x = M(10);  bowtie[2].y = 0;
    bowtie[3].x = 0;      bowtie[3].y = M(10);

    CHECK(geom_polygon_self_intersects(bowtie, 4) == 1);

    TEST_CASE("a triangle cannot cross itself");

    CHECK(geom_polygon_self_intersects(counter_clockwise, 3) == 0);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_which_side();
    test_segments_crossing();
    test_closest_point();
    test_broad_phase();
    test_polygon_containment();
    test_polygon_shape();

    return vtt_test_finish("030-test-geometry");
}
/* }}} */
