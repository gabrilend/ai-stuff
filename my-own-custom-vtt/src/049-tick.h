/*
 * 049-tick.h -- the heartbeat, as a table you can read the ordering off.
 *
 * Each beat runs a dispatch table of passes, in order. Not a sequence of calls
 * in a function body: THE ORDER OF THE SIMULATION IS A PIECE OF READABLE DATA,
 * and every "does X happen before Y?" question is answered by looking at one
 * array.
 *
 * Adding a pass is adding a row. A pass that must run twice appears twice.
 *
 * Several rows are the empty function in this phase, because there are no
 * sockets and no ruleset yet. AN EMPTY ROW IS BETTER THAN AN ABSENT ONE -- it is
 * where the later work goes, and the table stays the whole truth about ordering
 * rather than most of it.
 *
 * See docs/004-the-world-and-its-tick.md and issues 301 through 304.
 */

#ifndef VTT_TICK_H
#define VTT_TICK_H

#include <stdint.h>

#include "027-world.h"
#include "040-threadpool.h"
#include "047-streams.h"

/* ------------------------------------------------------------------------- *
 * What a body is trying to do
 *
 * Two ways of asking, one record. Driven motion is a direction being pushed and
 * is recomputed from the held command each beat; ordered motion is a destination
 * pursued over many beats. Both produce the same intent, which is what stops
 * there being two movement systems.
 * ------------------------------------------------------------------------- */

#define ORDER_NONE   0u
#define ORDER_DRIVE  1u   /* A direction being pushed. Cleared when the key lifts. */
#define ORDER_MOVE   2u   /* A destination, walked toward until reached. */

struct order {
    uint8_t  kind;
    wangle   direction;    /* ORDER_DRIVE: which way is being pushed. */
    wcoord   target_x;     /* ORDER_MOVE: where it is going. */
    wcoord   target_y;
    wcoord   speed;        /* World units per tick. */
    wangle   facing;       /* Where it wants to look. */
    uint8_t  turn_to_face; /* Whether facing is being asked for at all. */
};

/*
 * Where a body intends to be at the end of this beat. Written by the intent
 * pass, read and committed by the motion pass, and never read by anything else.
 *
 * Two passes rather than one, so that two bodies reaching for the same doorway
 * both write and the resolve decides -- the outcome does not depend on which one
 * the loop reached first.
 */
struct intent {
    wcoord  dx;
    wcoord  dy;
    wangle  facing;
    uint8_t wants_facing;
    uint8_t moved;      /* Set by the resolve, read by the region pass. */
};

/* ------------------------------------------------------------------------- *
 * A crossing
 *
 * When a body's region changes, that is the hook everything of the form "when
 * they enter the tavern" hangs from. Collected during the parallel pass and
 * delivered afterwards in index order -- a ruleset called from three threads at
 * once could not be deterministic.
 * ------------------------------------------------------------------------- */

struct crossing {
    uint32_t thing;
    uint32_t left;
    uint32_t entered;
};

/* ------------------------------------------------------------------------- *
 * The simulation
 * ------------------------------------------------------------------------- */

struct sim {
    struct world           *world;
    struct pool            *pool;
    struct stream_registry  streams;

    struct order  *orders;      /* One per thing. */
    struct intent *intents;     /* One per thing. */
    uint32_t       capacity;    /* How many of each are allocated. */

    struct crossing *crossings;
    uint32_t         crossing_count;
    uint32_t         crossing_capacity;

    uint64_t tick;

    /*
     * The sprite library, borrowed, and opaque here on purpose.
     *
     * A `struct sprite_pool *`, set by whoever owns one -- the same arrangement
     * as the session's borrowed ruleset. It is a void pointer because the tick
     * has no business knowing what a sprite is and the sprite library has no
     * business knowing what a tick is; the one command that needs both casts it
     * once, in 051-commandlog.
     *
     * NULL until somebody attaches one, and the re-tier command refuses by name
     * rather than doing nothing when it is. See issue 909.
     */
    void *sprites;
};

/*
 * Prepare a simulation over a world. The world is borrowed, not owned -- the
 * caller keeps it and releases it.
 * Returns 1 on success, 0 if memory could not be found.
 */
int sim_init(struct sim *s, struct world *w, struct pool *pool, uint64_t seed);

/* Release what the simulation allocated. Does not touch the world or the pool. */
void sim_release(struct sim *s);

/*
 * Make sure there is an order and an intent slot for every thing. Called after
 * anything is added to the world.
 */
int sim_fit_to_world(struct sim *s);

/* Advance the world one beat. */
void sim_tick(struct sim *s);

/*
 * The passes, in order, as data. Exposed so a demo can print the table and so
 * that the ordering is readable from outside rather than only from the source.
 */
struct tick_pass {
    const char *name;
    const char *what;
};

const struct tick_pass *sim_passes(uint32_t *count);

/*
 * Lend the simulation a sprite library, so that the one command about pictures
 * has somewhere to write. Borrowed -- the caller keeps it and releases it.
 *
 * Takes a void pointer for the same reason the field is one: the tick does not
 * include the sprite headers and is not going to start.
 */
void sim_attach_sprites(struct sim *s, void *sprites);

/* Give a body a standing order. */
void sim_drive(struct sim *s, uint32_t thing, wangle direction, wcoord speed);
void sim_order_move(struct sim *s, uint32_t thing, wcoord x, wcoord y, wcoord speed);
void sim_order_face(struct sim *s, uint32_t thing, wangle facing);
void sim_order_stop(struct sim *s, uint32_t thing);

/*
 * The crossings that happened on the most recent beat. Valid until the next one.
 * In index order, so that a ruleset sees them the same way every run.
 */
const struct crossing *sim_crossings(const struct sim *s, uint32_t *count);

#endif
