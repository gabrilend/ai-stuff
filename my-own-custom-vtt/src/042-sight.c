/*
 * 042-sight.c -- casting rays at corners, and sorting what comes back.
 *
 * Interface and reasoning are in 042-sight.h.
 *
 * THE METHOD, AND WHY IT IS THIS ONE
 *
 * The classic answer is an angular sweep: sort every wall endpoint by angle,
 * then walk through them keeping a set of the walls currently crossing the sweep
 * ray, and emit a boundary wherever the nearest member of that set changes. It
 * is O(n log n) and it is what a large scene wants.
 *
 * This is not that. This casts a ray at every corner -- three rays, in fact, one
 * at the corner and one just to either side of it -- and takes the nearest wall
 * each ray meets. It is O(corners x walls), which is quadratic.
 *
 * The reason is that the sweep's difficulty is entirely in the active set:
 * deciding which of two overlapping segments is nearer, at an angle where they
 * overlap, in integer arithmetic, with ties broken the same way on every
 * machine. Get it slightly wrong and a wall goes missing at one angle, and
 * somebody sees through stone -- which is a security failure, not a drawing
 * glitch, because this polygon decides what goes on a socket.
 *
 * Ray casting has no active set. Each ray is independent, exact, and obviously
 * correct. At tabletop scale -- tens of walls in range, not thousands -- it is
 * also fast enough, and the phase 2 demo reports the measurement rather than
 * this comment claiming it.
 *
 * If that measurement ever says otherwise, the sweep is the answer, and the
 * tests in 043 are what will keep it honest while it is written.
 */

#include "042-sight.h"
#include "029-geometry.h"

#include <stdlib.h>

/*
 * How far to either side of a corner the extra rays go. One angle unit is about
 * 0.0055 degrees, which at fifty metres is about five millimetres -- far below
 * anything anybody can see, and far above the point where integer arithmetic
 * would round the two rays back together.
 *
 * These exist because a ray aimed exactly at a corner is ambiguous: it may stop
 * at that corner or slip past it, and which one it does is a rounding accident.
 * The rays to either side are unambiguous, and between them they capture both
 * what the corner hides and what it reveals.
 */
#define CORNER_NUDGE 2

/* {{{ int sight_fan_init */
int sight_fan_init(struct sight_fan *fan, uint32_t capacity)
{
    fan->points = calloc((size_t)capacity, sizeof(struct fan_point));
    if (fan->points == NULL) {
        fan->capacity = 0;
        fan->count = 0;
        return 0;
    }

    fan->capacity = capacity;
    fan->count    = 0;
    fan->origin_x = 0;
    fan->origin_y = 0;
    fan->centre   = 0;
    fan->arc      = 0;
    fan->range    = 0;
    fan->start    = 0;

    return 1;
}
/* }}} */

/* {{{ void sight_fan_release */
void sight_fan_release(struct sight_fan *fan)
{
    free(fan->points);
    fan->points   = NULL;
    fan->capacity = 0;
    fan->count    = 0;
}
/* }}} */

/* {{{ uint32_t sight_fan_capacity_for */
uint32_t sight_fan_capacity_for(const struct world *w)
{
    /*
     * Two endpoints per wall, three rays per endpoint, plus the two edges of the
     * wedge. Generous on purpose: running out would mean a truncated visibility
     * polygon, which is a hole somebody can see through.
     */
    return (world_wall_count(w) * 6) + 8;
}
/* }}} */

/* {{{ wcoord sight_ray */
wcoord sight_ray(const struct world *w,
                 wcoord from_x, wcoord from_y,
                 wangle direction,
                 wcoord range)
{
    struct wvec step = fx_from_angle(direction, range);
    wcoord to_x = from_x + step.x;
    wcoord to_y = from_y + step.y;

    int64_t nearest2 = (int64_t)range * (int64_t)range;
    uint32_t count = world_wall_count(w);
    uint32_t i;

    /*
     * Every wall, every ray. There is no broad-phase index yet, deliberately:
     * building one before there was a caller to shape it would have meant
     * building it against the wrong query. The phase 2 demo reports what this
     * costs, and that number is what decides whether an index earns its place.
     */
    for (i = 1; i < count; i++) {
        const struct wall *wl = world_wall_const(w, i);
        int64_t d1;
        int64_t d2;
        int64_t d3;
        int64_t d4;

        if (!wall_blocks_sight(wl)) {
            continue;
        }

        /*
         * Which side of the ray each wall endpoint is on, and which side of the
         * wall each ray endpoint is on. If the two straddle each other, they
         * cross.
         */
        d1 = geom_side(from_x, from_y, to_x, to_y, wl->ax, wl->ay);
        d2 = geom_side(from_x, from_y, to_x, to_y, wl->bx, wl->by);
        d3 = geom_side(wl->ax, wl->ay, wl->bx, wl->by, from_x, from_y);
        d4 = geom_side(wl->ax, wl->ay, wl->bx, wl->by, to_x, to_y);

        /*
         * A one-way wall blocks only from its left. The eye's side decides, and
         * it is decided once here rather than at every step of a sweep.
         */
        if (wall_is_one_way(wl) && d3 < 0) {
            continue;
        }

        /*
         * The straddle test, written to include the touching cases. A ray that
         * grazes a wall's endpoint is stopped by it -- a corner is solid, and
         * treating it as a gap is how a body sees a sliver through a join
         * between two walls.
         */
        if (((d1 > 0) == (d2 > 0)) && d1 != 0 && d2 != 0) {
            continue;
        }
        if (((d3 > 0) == (d4 > 0)) && d3 != 0 && d4 != 0) {
            continue;
        }

        /*
         * They cross. Where along the ray is found by comparing the two side
         * values: the crossing sits at d3 / (d3 - d4) of the way from the ray's
         * start to its end, because those are the perpendicular distances of the
         * two ends from the wall's line.
         */
        {
            int64_t denominator = d3 - d4;
            int64_t hit_x;
            int64_t hit_y;
            int64_t distance2;

            if (denominator == 0) {
                /*
                 * The ray runs along the wall's line. It is grazing rather than
                 * crossing, and a wall seen exactly edge-on blocks nothing --
                 * treating it as a hit would put a phantom edge in the middle of
                 * an open room whenever a body lined up with a wall.
                 */
                continue;
            }

            hit_x = (int64_t)from_x + (((int64_t)step.x * d3) / denominator);
            hit_y = (int64_t)from_y + (((int64_t)step.y * d3) / denominator);

            distance2 = fx_dist2(from_x, from_y, (wcoord)hit_x, (wcoord)hit_y);

            if (distance2 < nearest2) {
                nearest2 = distance2;
            }
        }
    }

    return fx_sqrt(nearest2);
}
/* }}} */

/* {{{ static int compare_fan_points */
static int compare_fan_points(const void *left, const void *right)
{
    const struct fan_point *a = left;
    const struct fan_point *b = right;

    /*
     * By angle, with distance as the tie-break. The tie-break is not cosmetic:
     * two rays at the same angle happen wherever two corners line up from the
     * eye, and without a defined order the sort could put them either way round
     * on different runs -- which would make the same world produce two different
     * fans, and two replays diverge.
     */
    if (a->angle != b->angle) {
        return (a->angle < b->angle) ? -1 : 1;
    }

    if (a->distance != b->distance) {
        return (a->distance < b->distance) ? -1 : 1;
    }

    return 0;
}
/* }}} */

/* {{{ static void add_ray */
static void add_ray(const struct world *w, struct sight_fan *fan, wangle direction)
{
    struct fan_point *point;

    if (fan->count >= fan->capacity) {
        return;
    }

    /* Outside the wedge is not seen, however close it is. */
    if (!fx_angle_in_arc(direction, fan->centre, fan->arc)) {
        return;
    }

    point = &fan->points[fan->count];

    /*
     * Stored as the offset from the wedge's starting edge rather than as an
     * absolute angle. That is what makes a wedge straddling the wrap point sort
     * like any other -- the subtraction wraps in the 16-bit type, so the offsets
     * come out in order with no special case anywhere.
     */
    point->angle    = (wangle)(direction - fan->start);
    point->distance = sight_ray(w, fan->origin_x, fan->origin_y, direction, fan->range);

    fan->count++;
}
/* }}} */

/* {{{ int sight_compute */
int sight_compute(const struct world *w, uint32_t body, struct sight_fan *fan)
{
    const struct thing *eye = world_thing_const(w, body);
    uint32_t wall_count = world_wall_count(w);
    uint32_t i;

    fan->count    = 0;
    fan->origin_x = eye->x;
    fan->origin_y = eye->y;
    fan->centre   = eye->facing;
    fan->arc      = eye->sight_arc;
    fan->range    = (wcoord)eye->sight_range;

    /*
     * A body with no range or no arc sees nothing, and that is the normal state
     * of a coffee cup rather than a failure. Checked once, here, so the ray
     * casting below never runs for something with no eyes.
     */
    if (!thing_can_see(eye)) {
        fan->arc = 0;
        return 1;
    }

    /*
     * Where the wedge begins. Everything is sorted from here, so that a wedge
     * running across the wrap point needs no special handling.
     */
    fan->start = (wangle)(eye->facing - (eye->sight_arc / 2));

    /* The two edges of the wedge itself, so the polygon is closed at both ends. */
    add_ray(w, fan, fan->start);
    add_ray(w, fan, (wangle)(fan->start + fan->arc));

    /*
     * Then three rays at every wall corner: one at it, and one just to either
     * side. The corner ray is ambiguous by nature -- it may stop at the corner or
     * slip past, and which it does is a rounding accident -- so its neighbours
     * are what actually capture the shadow's edge and the light that gets round
     * it.
     */
    for (i = 1; i < wall_count; i++) {
        const struct wall *wl = world_wall_const(w, i);
        wangle to_a;
        wangle to_b;

        if (!wall_blocks_sight(wl)) {
            continue;
        }

        to_a = fx_angle(wl->ax - eye->x, wl->ay - eye->y);
        to_b = fx_angle(wl->bx - eye->x, wl->by - eye->y);

        add_ray(w, fan, (wangle)(to_a - CORNER_NUDGE));
        add_ray(w, fan, to_a);
        add_ray(w, fan, (wangle)(to_a + CORNER_NUDGE));

        add_ray(w, fan, (wangle)(to_b - CORNER_NUDGE));
        add_ray(w, fan, to_b);
        add_ray(w, fan, (wangle)(to_b + CORNER_NUDGE));
    }

    /*
     * If nothing landed inside the wedge at all -- a body in an empty field --
     * the two wedge edges are still there, and a fan of two points describes a
     * full unobstructed cone. There is no empty case to handle.
     */
    qsort(fan->points, fan->count, sizeof(struct fan_point), compare_fan_points);

    /* Ran out of room, which would be a hole somebody could see through. */
    if (fan->count >= fan->capacity) {
        return 0;
    }

    return 1;
}
/* }}} */

/* {{{ int sight_point_visible */
int sight_point_visible(const struct world *w, uint32_t body, wcoord x, wcoord y)
{
    const struct thing *eye = world_thing_const(w, body);
    wangle direction;
    wcoord distance;
    wcoord reach;

    if (!thing_can_see(eye)) {
        return 0;
    }

    /* Out of range is not seen, whatever the geometry between says. */
    distance = fx_dist(eye->x, eye->y, x, y);
    if (distance > (wcoord)eye->sight_range) {
        return 0;
    }

    /*
     * A body standing exactly where the eye is. Its direction is undefined, and
     * you can certainly see yourself, so this resolves to visible rather than
     * being handed to fx_angle, which would answer zero for a question it was
     * not asked.
     */
    if (distance == 0) {
        return 1;
    }

    direction = fx_angle(x - eye->x, y - eye->y);

    if (!fx_angle_in_arc(direction, eye->facing, eye->sight_arc)) {
        return 0;
    }

    /*
     * A fresh ray rather than a lookup into a fan. Two independent ways of
     * answering the same question: the fan draws the picture, this decides what
     * may be sent, and a test asserts they agree. One implementation would make
     * a drawing bug and a leak indistinguishable.
     */
    reach = sight_ray(w, eye->x, eye->y, direction, (wcoord)eye->sight_range);

    return distance <= reach;
}
/* }}} */
