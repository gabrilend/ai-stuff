/*
 * 029-geometry.c -- integer answers to questions about segments and polygons.
 *
 * Interface and reasoning are in 029-geometry.h. What is here is the care around
 * the cases that a picture-based map would never have had to think about:
 * collinear points, shared endpoints, degenerate polygons.
 *
 * Every one of those is a real case in a generated dungeon, where corridors meet
 * at right angles and rooms share walls, so none of them is an edge case to be
 * handled later.
 */

#include "029-geometry.h"
#include "027-world.h"

/* {{{ int64_t geom_side */
int64_t geom_side(wcoord ax, wcoord ay,
                  wcoord bx, wcoord by,
                  wcoord px, wcoord py)
{
    /*
     * The z component of the cross product of (b - a) and (p - a). Widened to 64
     * bits because two positions a kilometre apart multiply to about 2^42, which
     * a 32-bit intermediate would wrap silently -- and a wrapped sign here means
     * a one-way wall that blocks from the wrong side.
     */
    int64_t abx = (int64_t)bx - (int64_t)ax;
    int64_t aby = (int64_t)by - (int64_t)ay;
    int64_t apx = (int64_t)px - (int64_t)ax;
    int64_t apy = (int64_t)py - (int64_t)ay;

    return (abx * apy) - (aby * apx);
}
/* }}} */

/* {{{ static int on_segment_when_collinear */
static int on_segment_when_collinear(wcoord ax, wcoord ay,
                                     wcoord bx, wcoord by,
                                     wcoord px, wcoord py)
{
    /*
     * Only meaningful once geom_side has said the three points are in a line.
     * At that point "is p between a and b" is a bounding-box question, because
     * a point on the line and inside the box is on the segment.
     */
    wcoord low_x  = (ax < bx) ? ax : bx;
    wcoord high_x = (ax < bx) ? bx : ax;
    wcoord low_y  = (ay < by) ? ay : by;
    wcoord high_y = (ay < by) ? by : ay;

    return px >= low_x && px <= high_x && py >= low_y && py <= high_y;
}
/* }}} */

/* {{{ int geom_segments_cross */
int geom_segments_cross(wcoord ax, wcoord ay, wcoord bx, wcoord by,
                        wcoord cx, wcoord cy, wcoord dx, wcoord dy)
{
    int64_t d1 = geom_side(cx, cy, dx, dy, ax, ay);
    int64_t d2 = geom_side(cx, cy, dx, dy, bx, by);
    int64_t d3 = geom_side(ax, ay, bx, by, cx, cy);
    int64_t d4 = geom_side(ax, ay, bx, by, dx, dy);

    /*
     * The general case: each segment has its two endpoints on opposite sides of
     * the other. Compared as products rather than as signs so that the test is
     * two multiplications rather than four comparisons.
     */
    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
        return 1;
    }

    /*
     * The collinear cases, which are the ones that actually happen in a
     * generated map. Each asks: is this endpoint, which lies on the other
     * segment's infinite line, actually within that segment?
     *
     * Touching at an endpoint counts as crossing. A body sliding along one wall
     * into a second must be stopped by the second even though it only grazes it,
     * and a polygon whose edges merely touch is still self-intersecting.
     */
    if (d1 == 0 && on_segment_when_collinear(cx, cy, dx, dy, ax, ay)) return 1;
    if (d2 == 0 && on_segment_when_collinear(cx, cy, dx, dy, bx, by)) return 1;
    if (d3 == 0 && on_segment_when_collinear(ax, ay, bx, by, cx, cy)) return 1;
    if (d4 == 0 && on_segment_when_collinear(ax, ay, bx, by, dx, dy)) return 1;

    return 0;
}
/* }}} */

/* {{{ void geom_closest_point_on_segment */
void geom_closest_point_on_segment(wcoord ax, wcoord ay,
                                   wcoord bx, wcoord by,
                                   wcoord px, wcoord py,
                                   wcoord *out_x, wcoord *out_y)
{
    int64_t abx = (int64_t)bx - (int64_t)ax;
    int64_t aby = (int64_t)by - (int64_t)ay;
    int64_t apx = (int64_t)px - (int64_t)ax;
    int64_t apy = (int64_t)py - (int64_t)ay;

    int64_t length2 = (abx * abx) + (aby * aby);
    int64_t dot;

    /*
     * A zero-length segment is its own closest point. The validator refuses
     * zero-length walls, so this is a guard against a caller error rather than a
     * path anything depends on -- but returning the endpoint is the only answer
     * that is not arbitrary, and it costs one comparison.
     */
    if (length2 == 0) {
        *out_x = ax;
        *out_y = ay;
        return;
    }

    dot = (apx * abx) + (apy * aby);

    /* Before the start: the start is nearest. */
    if (dot <= 0) {
        *out_x = ax;
        *out_y = ay;
        return;
    }

    /* Past the end: the end is nearest. */
    if (dot >= length2) {
        *out_x = bx;
        *out_y = by;
        return;
    }

    /*
     * Somewhere along the middle. The projection is dot/length2 of the way from
     * a to b, and the multiply happens before the divide so that the ratio keeps
     * its precision instead of collapsing to zero or one.
     */
    *out_x = (wcoord)((int64_t)ax + ((abx * dot) / length2));
    *out_y = (wcoord)((int64_t)ay + ((aby * dot) / length2));
}
/* }}} */

/* {{{ int64_t geom_distance2_to_segment */
int64_t geom_distance2_to_segment(wcoord ax, wcoord ay,
                                  wcoord bx, wcoord by,
                                  wcoord px, wcoord py)
{
    wcoord nearest_x;
    wcoord nearest_y;

    geom_closest_point_on_segment(ax, ay, bx, by, px, py, &nearest_x, &nearest_y);

    return fx_dist2(px, py, nearest_x, nearest_y);
}
/* }}} */

/* {{{ int geom_segment_within_circle */
int geom_segment_within_circle(wcoord ax, wcoord ay,
                               wcoord bx, wcoord by,
                               wcoord cx, wcoord cy,
                               wcoord radius)
{
    int64_t distance2 = geom_distance2_to_segment(ax, ay, bx, by, cx, cy);
    int64_t radius2   = (int64_t)radius * (int64_t)radius;

    return distance2 <= radius2;
}
/* }}} */

/* {{{ int geom_polygon_contains */
int geom_polygon_contains(const struct vertex *first,
                          uint32_t count,
                          wcoord px, wcoord py)
{
    uint32_t i;
    int inside = 0;

    /* Fewer than three vertices bounds no area at all. */
    if (count < 3) {
        return 0;
    }

    for (i = 0; i < count; i++) {
        /* The boundary is closed: the last vertex joins back to the first. */
        const struct vertex *a = &first[i];
        const struct vertex *b = &first[(i + 1) % count];

        /*
         * A point exactly on an edge is inside. Decided here rather than left to
         * the arithmetic, because a body walking along a region's edge has to be
         * consistently in or consistently out -- if it flickers, the ruleset gets
         * an entered-the-tavern event on every single step.
         */
        if (geom_side(a->x, a->y, b->x, b->y, px, py) == 0 &&
            on_segment_when_collinear(a->x, a->y, b->x, b->y, px, py)) {
            return 1;
        }

        /*
         * Crossing number. A horizontal ray runs from the point toward positive
         * x, and every edge it crosses flips the answer.
         *
         * The comparison is deliberately asymmetric -- one end strictly above,
         * the other not -- so that an edge whose endpoint sits exactly on the ray
         * is counted once rather than twice or not at all. This is the classic
         * place point-in-polygon goes wrong, and the asymmetry is the fix.
         */
        if ((a->y > py) != (b->y > py)) {
            int64_t dy = (int64_t)b->y - (int64_t)a->y;
            int64_t dx = (int64_t)b->x - (int64_t)a->x;
            int64_t t  = (int64_t)py - (int64_t)a->y;

            /* Where the edge crosses the ray's height, in x. */
            int64_t crossing_x = (int64_t)a->x + ((dx * t) / dy);

            if ((int64_t)px < crossing_x) {
                inside = !inside;
            }
        }
    }

    return inside;
}
/* }}} */

/* {{{ int64_t geom_polygon_area2 */
int64_t geom_polygon_area2(const struct vertex *first, uint32_t count)
{
    uint32_t i;
    int64_t total = 0;

    if (count < 3) {
        return 0;
    }

    /*
     * The shoelace sum. Each term is the cross product of two consecutive
     * vertices taken from the origin, and they cancel everywhere except around
     * the boundary.
     */
    for (i = 0; i < count; i++) {
        const struct vertex *a = &first[i];
        const struct vertex *b = &first[(i + 1) % count];

        total += ((int64_t)a->x * (int64_t)b->y) - ((int64_t)b->x * (int64_t)a->y);
    }

    return total;
}
/* }}} */

/* {{{ int geom_polygon_self_intersects */
int geom_polygon_self_intersects(const struct vertex *first, uint32_t count)
{
    uint32_t i;
    uint32_t j;

    if (count < 4) {
        /*
         * A triangle cannot cross itself. Fewer than three vertices has no edges
         * to cross. Either way there is nothing to find.
         */
        return 0;
    }

    for (i = 0; i < count; i++) {
        const struct vertex *a1 = &first[i];
        const struct vertex *a2 = &first[(i + 1) % count];

        for (j = i + 1; j < count; j++) {
            const struct vertex *b1 = &first[j];
            const struct vertex *b2 = &first[(j + 1) % count];

            /*
             * Adjacent edges share an endpoint by construction, so they always
             * "cross" and are skipped. The wrap case -- the last edge is adjacent
             * to the first -- is the second half of this condition, and leaving
             * it out makes every polygon report itself as self-intersecting.
             */
            if (j == i + 1) {
                continue;
            }
            if (i == 0 && j == count - 1) {
                continue;
            }

            if (geom_segments_cross(a1->x, a1->y, a2->x, a2->y,
                                    b1->x, b1->y, b2->x, b2->y)) {
                return 1;
            }
        }
    }

    return 0;
}
/* }}} */
