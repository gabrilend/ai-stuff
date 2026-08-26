/*
 * 042-sight.h -- what a body can see, right now.
 *
 * Sight and memory are different things and this file is sight: recomputed from
 * scratch whenever it is asked for, never stored between ticks. Memory -- what a
 * viewer has ever seen -- is 044-fog.h, accumulates forever, and is never
 * recomputed.
 *
 * A corridor you walked an hour ago is in one and not the other, and that
 * difference is the difference between a floor plan you remember and a goblin
 * standing in it now.
 *
 * THIS IS NOT A DRAWING FEATURE. It is computed so that the outbound filter
 * knows which records it is permitted to put on a socket. That it also happens
 * to be exactly what a renderer needs for a clean edge between torchlight and
 * dark is a convergence worth noticing, not the reason it exists.
 *
 * See docs/007-sight-and-what-it-remembers.md and issues 202, 203, 204, 206.
 */

#ifndef VTT_SIGHT_H
#define VTT_SIGHT_H

#include <stdint.h>

#include "027-world.h"

/*
 * One boundary of a visibility polygon: a direction, and how far the light got
 * before something stopped it.
 */
struct fan_point {
    wangle angle;
    wcoord distance;
};

/*
 * A visibility polygon, as a fan of directions out from one eye.
 *
 * Not a bitmap and not a list of lit cells -- a polygon, because it is exact,
 * because it is small enough to put on a socket, and because a renderer can draw
 * a clean edge from it where a cell mask would stair-step.
 *
 * The points are sorted by angle measured from the wedge's starting edge, so
 * that a wedge straddling the wrap point sorts like any other.
 */
struct sight_fan {
    wcoord   origin_x;
    wcoord   origin_y;

    wangle   centre;    /* Which way the eye is looking. */
    wangle   arc;       /* How wide. 65535 means everything. */
    wcoord   range;     /* How far, before anything gets in the way. */

    wangle   start;     /* The wedge's first edge. Angles are sorted from here. */

    uint32_t count;
    uint32_t capacity;
    struct fan_point *points;
};

/* Prepare a fan with room for `capacity` boundaries. 1 on success, 0 on failure. */
int sight_fan_init(struct sight_fan *fan, uint32_t capacity);

/* Release a fan's memory. */
void sight_fan_release(struct sight_fan *fan);

/*
 * Compute what the body at `body` can see, into `fan`.
 *
 * A body with no sight range or no arc produces an empty fan, which is the
 * normal state of a coffee cup rather than an error.
 *
 * Returns 1 on success. Returns 0 only if the fan could not hold the result,
 * which is a caller error -- the capacity needed is bounded by the number of
 * walls in range, and 037-fixture-sized worlds are nowhere near it. It is
 * reported rather than silently truncated, because a truncated visibility
 * polygon is a hole somebody can see through.
 */
int sight_compute(const struct world *w, uint32_t body, struct sight_fan *fan);

/*
 * Whether the point is visible from the eye this fan was computed for.
 *
 * This does NOT read the fan -- it casts a fresh ray and compares. Two
 * independent ways of answering the same question, which is how this class of
 * bug gets found: the fan draws the picture, this decides what may be sent, and
 * a test asserts they agree.
 */
int sight_point_visible(const struct world *w, uint32_t body, wcoord x, wcoord y);

/*
 * The distance to whatever stops the light in the given direction, from the
 * given point, capped at `range`. The primitive both of the above are built on.
 */
wcoord sight_ray(const struct world *w,
                 wcoord from_x, wcoord from_y,
                 wangle direction,
                 wcoord range);

/*
 * How many boundaries a fan might need for a world with this many walls. What a
 * caller should pass to sight_fan_init.
 */
uint32_t sight_fan_capacity_for(const struct world *w);

#endif
