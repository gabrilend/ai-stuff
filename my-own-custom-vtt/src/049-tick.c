/*
 * 049-tick.c -- seven passes, written down in order.
 *
 * Interface and reasoning are in 049-tick.h.
 *
 * The interesting content is the motion pass, which is deliberately two passes:
 * one that writes down where every body would like to be, and one that decides
 * where it actually ends up. Two bodies reaching for the same doorway both
 * write, and the resolve settles it -- so the outcome does not depend on which
 * one the loop reached first, which is what makes the beat reproducible.
 */

#include "049-tick.h"
#include "029-geometry.h"
#include "031-region.h"

#include <stdlib.h>
#include <string.h>

/* ------------------------------------------------------------------------- *
 * The table
 *
 * This is the answer to every question about what happens before what. Read it
 * top to bottom and that is the order of the simulation.
 * ------------------------------------------------------------------------- */

static const struct tick_pass passes[] = {
    { "intake",   "drain sockets, decode, refuse or accept" },
    { "intent",   "turn standing orders into intended motion" },
    { "motion",   "advance what moves, resolve against walls" },
    { "region",   "re-test what moved, and collect the crossings" },
    { "rules",    "the ruleset's slice of the beat" },
    { "sight",    "recompute what each viewer can see" },
    { "memory",   "fold sight into each viewer's fog" },
    { "outbound", "build and send each viewer's filtered update" }
};

/* {{{ const struct tick_pass *sim_passes */
const struct tick_pass *sim_passes(uint32_t *count)
{
    *count = (uint32_t)(sizeof(passes) / sizeof(passes[0]));
    return passes;
}
/* }}} */

/* {{{ void sim_attach_sprites */
void sim_attach_sprites(struct sim *s, void *sprites)
{
    s->sprites = sprites;
}
/* }}} */

/* {{{ int sim_fit_to_world */
int sim_fit_to_world(struct sim *s)
{
    uint32_t wanted = world_thing_count(s->world);

    if (wanted <= s->capacity) {
        return 1;
    }

    /*
     * Grown to the world's size rather than incrementally, because these arrays
     * are indexed by thing index and a gap between them would be a body whose
     * intent lives outside the array.
     */
    {
        struct order *orders = realloc(s->orders, (size_t)wanted * sizeof(struct order));
        struct intent *intents = realloc(s->intents, (size_t)wanted * sizeof(struct intent));

        if (orders == NULL || intents == NULL) {
            free(orders);
            free(intents);
            return 0;
        }

        memset(orders + s->capacity, 0,
               (size_t)(wanted - s->capacity) * sizeof(struct order));
        memset(intents + s->capacity, 0,
               (size_t)(wanted - s->capacity) * sizeof(struct intent));

        s->orders = orders;
        s->intents = intents;
        s->capacity = wanted;
    }

    if (wanted > s->crossing_capacity) {
        struct crossing *c = realloc(s->crossings,
                                     (size_t)wanted * sizeof(struct crossing));
        if (c == NULL) {
            return 0;
        }
        s->crossings = c;
        s->crossing_capacity = wanted;
    }

    return 1;
}
/* }}} */

/* {{{ int sim_init */
int sim_init(struct sim *s, struct world *w, struct pool *pool, uint64_t seed)
{
    memset(s, 0, sizeof(struct sim));

    s->world = w;
    s->pool = pool;
    s->tick = w->tick;

    streams_init(&s->streams, seed);

    return sim_fit_to_world(s);
}
/* }}} */

/* {{{ void sim_release */
void sim_release(struct sim *s)
{
    free(s->orders);
    free(s->intents);
    free(s->crossings);

    s->orders = NULL;
    s->intents = NULL;
    s->crossings = NULL;
    s->capacity = 0;
    s->crossing_capacity = 0;
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * Orders
 * ------------------------------------------------------------------------- */

/* {{{ void sim_drive */
void sim_drive(struct sim *s, uint32_t thing, wangle direction, wcoord speed)
{
    if (thing == 0 || thing >= s->capacity) {
        return;
    }

    /*
     * Not "step once" but "I am pushing this way". The order persists until it is
     * replaced or stopped, which is what a held key becomes, and it is why the
     * intent pass recomputes the direction from this every beat rather than
     * consuming it.
     */
    s->orders[thing].kind = ORDER_DRIVE;
    s->orders[thing].direction = direction;
    s->orders[thing].speed = speed;
}
/* }}} */

/* {{{ void sim_order_move */
void sim_order_move(struct sim *s, uint32_t thing, wcoord x, wcoord y, wcoord speed)
{
    if (thing == 0 || thing >= s->capacity) {
        return;
    }

    s->orders[thing].kind = ORDER_MOVE;
    s->orders[thing].target_x = x;
    s->orders[thing].target_y = y;
    s->orders[thing].speed = speed;
}
/* }}} */

/* {{{ void sim_order_face */
void sim_order_face(struct sim *s, uint32_t thing, wangle facing)
{
    if (thing == 0 || thing >= s->capacity) {
        return;
    }

    s->orders[thing].facing = facing;
    s->orders[thing].turn_to_face = 1;
}
/* }}} */

/* {{{ void sim_order_stop */
void sim_order_stop(struct sim *s, uint32_t thing)
{
    if (thing == 0 || thing >= s->capacity) {
        return;
    }

    s->orders[thing].kind = ORDER_NONE;
    s->orders[thing].turn_to_face = 0;
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * Pass 2 -- intent
 * ------------------------------------------------------------------------- */

/* {{{ static void pass_intent */
static void pass_intent(void *context, uint32_t first, uint32_t last)
{
    struct sim *s = context;
    uint32_t i;

    for (i = first; i < last; i++) {
        const struct order *o = &s->orders[i];
        struct intent *in = &s->intents[i];
        const struct thing *t = world_thing_const(s->world, i);

        /*
         * Cleared at the START of the beat rather than at the end. A stale
         * intent is a body that keeps walking after its order was cancelled,
         * and clearing here makes that impossible regardless of what happened
         * in between or which pass ran last.
         */
        in->dx = 0;
        in->dy = 0;
        in->moved = 0;
        in->wants_facing = 0;

        if (i == 0) {
            continue;   /* The sentinel does not move. */
        }

        if (o->turn_to_face) {
            in->facing = o->facing;
            in->wants_facing = 1;
        }

        if (o->kind == ORDER_DRIVE) {
            struct wvec step = fx_from_angle(o->direction, o->speed);
            in->dx = step.x;
            in->dy = step.y;

            /* A driven body looks where it is going unless told otherwise. */
            if (!o->turn_to_face) {
                in->facing = o->direction;
                in->wants_facing = 1;
            }
            continue;
        }

        if (o->kind == ORDER_MOVE) {
            wcoord remaining = fx_dist(t->x, t->y, o->target_x, o->target_y);
            wangle direction;
            struct wvec step;

            /*
             * Arrived. The order is not cleared here -- this pass may run on any
             * thread and clearing would be a write into a record another pass
             * reads. The motion pass clears it, on one thread, after the barrier.
             */
            if (remaining == 0) {
                continue;
            }

            direction = fx_angle(o->target_x - t->x, o->target_y - t->y);

            /*
             * Do not overshoot. A body one centimetre from its destination steps
             * one centimetre, not a whole tick's worth past it and back again
             * next beat.
             */
            step = fx_from_angle(direction, (remaining < o->speed) ? remaining : o->speed);

            in->dx = step.x;
            in->dy = step.y;

            if (!o->turn_to_face) {
                in->facing = direction;
                in->wants_facing = 1;
            }
        }
    }
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * Pass 3 -- motion
 * ------------------------------------------------------------------------- */

/* {{{ static int blocked_between */
static int blocked_between(const struct world *w,
                           wcoord from_x, wcoord from_y,
                           wcoord to_x, wcoord to_y,
                           uint32_t *which)
{
    uint32_t count = world_wall_count(w);
    uint32_t i;

    for (i = 1; i < count; i++) {
        const struct wall *wl = world_wall_const(w, i);

        if (!wall_blocks_movement(wl)) {
            continue;
        }

        /*
         * A one-way wall blocks only from its left, and the side that matters is
         * the side the body started on -- otherwise a body already past it would
         * be trapped.
         */
        if (wall_is_one_way(wl) &&
            geom_side(wl->ax, wl->ay, wl->bx, wl->by, from_x, from_y) < 0) {
            continue;
        }

        if (geom_segments_cross(from_x, from_y, to_x, to_y,
                                wl->ax, wl->ay, wl->bx, wl->by)) {
            *which = i;
            return 1;
        }
    }

    return 0;
}
/* }}} */

/* {{{ static void slide_along */
static void slide_along(const struct wall *wl,
                        wcoord dx, wcoord dy,
                        wcoord *out_dx, wcoord *out_dy)
{
    int64_t wx = (int64_t)wl->bx - (int64_t)wl->ax;
    int64_t wy = (int64_t)wl->by - (int64_t)wl->ay;
    int64_t length2 = (wx * wx) + (wy * wy);
    int64_t dot;

    /*
     * A zero-length wall has no direction to slide along. The validator refuses
     * those, so this is a guard rather than a path -- but sliding along nothing
     * would divide by zero.
     */
    if (length2 == 0) {
        *out_dx = 0;
        *out_dy = 0;
        return;
    }

    /*
     * The part of the movement that runs along the wall, keeping it; the part
     * that runs into the wall, discarding it. This is the difference between
     * controls that feel alive and controls that feel broken -- a body pushed
     * into a wall at an angle should slide, not halt.
     */
    dot = ((int64_t)dx * wx) + ((int64_t)dy * wy);

    *out_dx = (wcoord)((wx * dot) / length2);
    *out_dy = (wcoord)((wy * dot) / length2);
}
/* }}} */

/* {{{ static void pass_motion */
static void pass_motion(void *context, uint32_t first, uint32_t last)
{
    struct sim *s = context;
    uint32_t i;

    for (i = first; i < last; i++) {
        struct intent *in = &s->intents[i];
        struct thing *t = world_thing(s->world, i);
        wcoord dx;
        wcoord dy;
        int attempt;

        if (i == 0) {
            continue;
        }

        if (in->wants_facing) {
            t->facing = in->facing;
        }

        if (in->dx == 0 && in->dy == 0) {
            continue;
        }

        dx = in->dx;
        dy = in->dy;

        /*
         * Try the move; if a wall is in the way, project along it and try again.
         * TWICE, THEN STOP.
         *
         * Two attempts handles a corner literally: project against the first
         * wall, then against the second, then stop. Iterating until nothing
         * blocks is how a body ends up jittering in a corner forever, or
         * squeezing through it -- and both are worse than not moving.
         */
        for (attempt = 0; attempt < 2; attempt++) {
            uint32_t wall_index;

            if (dx == 0 && dy == 0) {
                break;
            }

            if (!blocked_between(s->world, t->x, t->y, t->x + dx, t->y + dy,
                                 &wall_index)) {
                t->x += dx;
                t->y += dy;
                in->moved = 1;
                break;
            }

            slide_along(world_wall_const(s->world, wall_index), dx, dy, &dx, &dy);
        }
    }
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * Pass 4 -- region
 * ------------------------------------------------------------------------- */

/* {{{ static void pass_region */
static void pass_region(struct sim *s)
{
    uint32_t count = world_thing_count(s->world);
    uint32_t i;

    s->crossing_count = 0;

    /*
     * Only bodies that actually moved are re-tested, and that is what makes this
     * affordable -- most things in a world are standing still. It is also what
     * lets the region field drift if the motion pass is ever wrong, which is why
     * the validator recomputes all of them from scratch and compares.
     *
     * Run on one thread, after the barrier, because the crossings it collects
     * are handed to a ruleset and a ruleset called from three threads at once
     * could not be deterministic.
     */
    for (i = 1; i < count && i < s->capacity; i++) {
        struct thing *t;
        uint32_t was;
        uint32_t now;

        if (!s->intents[i].moved) {
            continue;
        }

        t = world_thing(s->world, i);
        was = t->region;
        now = region_deepest_containing(s->world, t->x, t->y);

        if (was == now) {
            continue;
        }

        t->region = now;

        if (s->crossing_count < s->crossing_capacity) {
            struct crossing *c = &s->crossings[s->crossing_count];
            c->thing = i;
            c->left = was;
            c->entered = now;
            s->crossing_count++;
        }
    }
}
/* }}} */

/* {{{ static void clear_arrived_orders */
static void clear_arrived_orders(struct sim *s)
{
    uint32_t count = world_thing_count(s->world);
    uint32_t i;

    /*
     * On one thread, after motion. A body that has reached its destination stops
     * having a destination -- done here rather than inside the parallel intent
     * pass, because clearing an order there would be a write into a record
     * another worker may be reading.
     */
    for (i = 1; i < count && i < s->capacity; i++) {
        struct order *o = &s->orders[i];
        const struct thing *t = world_thing_const(s->world, i);

        if (o->kind != ORDER_MOVE) {
            continue;
        }

        if (t->x == o->target_x && t->y == o->target_y) {
            o->kind = ORDER_NONE;
        }
    }
}
/* }}} */

/* {{{ void sim_tick */
void sim_tick(struct sim *s)
{
    uint32_t count = world_thing_count(s->world);

    /*
     * The order below is the table at the top of this file, and the table is the
     * answer to every question about what happens before what.
     *
     * Rows 1, 5, 6, 7 and 8 -- intake, rules, sight, memory, outbound -- have no
     * work in this phase. They are still rows: the table stays the whole truth
     * about ordering rather than most of it, and each is where the later work
     * goes.
     */

    /* 1. intake -- no sockets yet. */

    /* 2. intent -- parallel over things. */
    pool_run(s->pool, pass_intent, s, count);

    /* 3. motion -- parallel over things. */
    pool_run(s->pool, pass_motion, s, count);

    /* 4. region -- one thread, because crossings go to a ruleset in order. */
    pass_region(s);
    clear_arrived_orders(s);

    /* 5. rules -- no ruleset yet. */
    /* 6. sight -- no viewers yet. */
    /* 7. memory -- no viewers yet. */
    /* 8. outbound -- no sockets yet. */

    s->tick++;
    s->world->tick = s->tick;
}
/* }}} */

/* {{{ const struct crossing *sim_crossings */
const struct crossing *sim_crossings(const struct sim *s, uint32_t *count)
{
    *count = s->crossing_count;
    return s->crossings;
}
/* }}} */
