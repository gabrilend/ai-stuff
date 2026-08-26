/*
 * 029-geometry.h -- the questions you are allowed to ask a wall.
 *
 * A wall is a line segment, not dark pixels, and this file is what that buys.
 * Every one of these is a question a picture could not have answered: which side
 * of this am I on, does this cross that, how close does this come.
 *
 * All of it is integer arithmetic through 021-fixed-point.h. Several of these
 * return int64_t rather than a world coordinate, because a cross product of two
 * positions is a squared quantity and does not fit in 32 bits.
 *
 * See docs/006-the-map-is-geometry-not-a-picture.md and
 * issues/104-walls-are-segments.md.
 */

#ifndef VTT_GEOMETRY_H
#define VTT_GEOMETRY_H

#include <stdint.h>

#include "021-fixed-point.h"

/*
 * Which side of the directed segment a-to-b the point p falls on.
 *
 * Returns a positive number for the left, negative for the right, and exactly
 * zero when the point is on the infinite line through a and b.
 *
 * Zero is a real case and not a rounding artefact: three points in a line
 * happens constantly in a generated map, where corridors meet at right angles
 * and walls share endpoints. Callers must decide what collinear means for them
 * rather than assuming it will not occur.
 *
 * This is what WALL_ONE_WAY is tested with -- "the segment's left" is literally
 * this function returning positive.
 */
int64_t geom_side(wcoord ax, wcoord ay,
                  wcoord bx, wcoord by,
                  wcoord px, wcoord py);

/*
 * Whether the segments a-b and c-d cross. Touching at an endpoint counts as
 * crossing, because a body sliding along one wall into another must be stopped
 * by the second even though it only grazes it.
 */
int geom_segments_cross(wcoord ax, wcoord ay, wcoord bx, wcoord by,
                        wcoord cx, wcoord cy, wcoord dx, wcoord dy);

/*
 * The point on segment a-b closest to p, written through the two out
 * parameters. Used by collision resolution to find where a body should be
 * pushed to.
 *
 * A zero-length segment returns its own endpoint, which is the only sensible
 * answer; the validator refuses zero-length walls, so this is a guard rather
 * than a path anything relies on.
 */
void geom_closest_point_on_segment(wcoord ax, wcoord ay,
                                   wcoord bx, wcoord by,
                                   wcoord px, wcoord py,
                                   wcoord *out_x, wcoord *out_y);

/*
 * The squared distance from p to the nearest point of segment a-b. Squared,
 * because every caller is comparing it against a squared radius.
 */
int64_t geom_distance2_to_segment(wcoord ax, wcoord ay,
                                  wcoord bx, wcoord by,
                                  wcoord px, wcoord py);

/*
 * Whether segment a-b comes within `radius` of the point (cx, cy).
 *
 * This is the sight broad phase's inner question and the collision broad
 * phase's. It is deliberately conservative in one direction only: it may say yes
 * for a segment that turns out not to matter, and must never say no for one that
 * does. A broad phase that is occasionally too generous costs a little sorting.
 * One that is once too strict makes a wall vanish, and somebody sees through
 * stone.
 */
int geom_segment_within_circle(wcoord ax, wcoord ay,
                               wcoord bx, wcoord by,
                               wcoord cx, wcoord cy,
                               wcoord radius);

/*
 * Whether the closed polygon given as a run of vertices contains the point.
 *
 * Vertices are given as a pointer to the first and a count; the boundary is
 * closed by joining the last back to the first, and the last vertex is not
 * repeated.
 *
 * A point exactly on the boundary is **inside**. That is arbitrary and it is
 * pinned rather than left to the arithmetic, because a body walking along a
 * region's edge must be consistently in or consistently out -- if it flickers,
 * the ruleset gets an entered-the-tavern event on every step.
 */
struct vertex;
int geom_polygon_contains(const struct vertex *first,
                          uint32_t count,
                          wcoord px, wcoord py);

/*
 * Twice the signed area of a closed polygon. Positive means the vertices wind
 * counter-clockwise.
 *
 * Doubled because halving it would throw away a bit for no reason -- nothing
 * asks for the area itself, only for its sign and for whether it is zero.
 * Zero means the polygon has no interior, which the validator refuses.
 */
int64_t geom_polygon_area2(const struct vertex *first, uint32_t count);

/* Whether any two non-adjacent edges of a closed polygon cross each other. */
int geom_polygon_self_intersects(const struct vertex *first, uint32_t count);

#endif
