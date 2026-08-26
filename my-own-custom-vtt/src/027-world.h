/*
 * 027-world.h -- everything that is true at one instant, as flat arrays.
 *
 * The world is the only place a fact lives. Everything else -- a client, a
 * renderer, a replay -- holds a copy or a filtered view of this, and knows it.
 *
 * Every category is one block of records. Every reference is a `uint32_t` index
 * into a block, never a pointer, so that a snapshot is a copy of some bytes and
 * splitting work across threads is arithmetic. Index 0 of every block is a
 * reserved empty record meaning "nothing", which is why no code in this project
 * checks a pointer for null.
 *
 * See docs/004-the-world-and-its-tick.md, docs/005-a-thing-in-the-world.md, and
 * docs/006-the-map-is-geometry-not-a-picture.md.
 */

#ifndef VTT_WORLD_H
#define VTT_WORLD_H

#include <stdint.h>

#include "021-fixed-point.h"
#include "023-blocks.h"
#include "025-strings.h"

/* ------------------------------------------------------------------------- *
 * What blocks sight and what blocks movement
 *
 * These two flags mean the same thing on a body as they do on a wall, so they
 * are defined once and shared. An earlier draft numbered them differently in the
 * two places, which is the kind of disagreement that produces a curtain you
 * cannot walk through and a wall you can see past, with nothing obviously wrong
 * in either file.
 *
 * They are separate bits because the interesting cases are the ones where they
 * disagree. A chasm blocks movement and not sight. A curtain blocks sight and
 * not movement. A portcullis blocks movement and lets sight through. One "solid"
 * flag would delete all three.
 * ------------------------------------------------------------------------- */

#define BLOCKS_SIGHT     (1u << 0)
#define BLOCKS_MOVEMENT  (1u << 1)

/* ------------------------------------------------------------------------- *
 * A thing
 *
 * One record for everything that stands in the space: a player's character, a
 * goblin, a coffee cup, a door leaf, a torch on a bracket, a tree.
 *
 * There is no second record type, and there will be pressure to add one. It
 * arrives as "props do not need a sight cone". That is true and it is not a
 * reason: a coffee cup with sight_range 0 costs four bytes and buys the property
 * that the code moving a coffee cup IS the code moving a goblin -- which is what
 * makes a commander who owns a tavern require no new code at all.
 * ------------------------------------------------------------------------- */

/* Never sent to anyone who does not command it, whatever the geometry says. */
#define THING_HIDDEN     (1u << 2)
/* Carries an entry in the lights block. */
#define THING_EMITS_LIGHT (1u << 3)
/* Expected to move. A hint to the motion pass, not a permission. */
#define THING_MOBILE     (1u << 4)

struct thing {
    /* Four-byte fields first, so the record packs with no padding at all. */
    wcoord   x;
    wcoord   y;
    uint32_t scope;        /* Who commands this. 0 means nobody. */
    uint32_t region;       /* The deepest region containing it. 0 means open ground. */
    uint32_t kind;         /* Index into the ruleset's catalogue. Never interpreted here. */
    uint32_t sheet;        /* Index into the ruleset's storage. Never read here. */
    uint32_t sight_range;  /* How far it sees. 0 means it does not see. */

    wangle   facing;       /* A full turn is 65536; wraps by overflowing. */
    uint16_t radius;       /* How much space the body takes. */
    wangle   sight_arc;    /* How wide its cone of vision is. 32768 is everything ahead. */
    uint16_t flags;
};

/* ------------------------------------------------------------------------- *
 * A wall
 *
 * A line segment with two endpoints. Not dark pixels. The whole project rests on
 * that difference: because a wall is a segment, sight can be computed from it;
 * because sight can be computed, fog can belong to one person; because fog
 * belongs to one person, the server can decline to send what they cannot see.
 * ------------------------------------------------------------------------- */

/*
 * Blocks only from the segment's left, taking a-to-b as forward. A window you
 * can see out of but not into; a secret door that is a wall from the corridor.
 */
#define WALL_ONE_WAY (1u << 2)

struct wall {
    wcoord   ax;
    wcoord   ay;
    wcoord   bx;
    wcoord   by;
    uint32_t door;   /* The thing this is the leaf of, if any. 0 for plain wall. */
    uint16_t flags;
    uint16_t padding;
};

/* ------------------------------------------------------------------------- *
 * A region
 *
 * A named area with a closed polygon boundary and a parent. The tavern. The
 * forest. The cellar under the tavern.
 *
 * Regions are what make an abstract control scope addressable: handing somebody
 * "the tavern" is handing them a region index.
 * ------------------------------------------------------------------------- */

struct region {
    uint32_t first_vertex;   /* Where this boundary starts in the shared vertex pool. */
    uint32_t vertex_count;   /* Closed -- the last vertex joins the first, not repeated. */
    uint32_t parent;         /* The region containing this one. 0 for top level. */
    uint32_t name_offset;    /* Into the string pool. */
};

struct vertex {
    wcoord x;
    wcoord y;
};

/* ------------------------------------------------------------------------- *
 * A light
 *
 * Geometrically the same object as an eye -- a position, an arc, a radius -- so
 * the same sweep serves both. Lights do not float free; a torch is a thing.
 * ------------------------------------------------------------------------- */

struct light {
    uint32_t thing;        /* What carries it. */
    uint32_t radius;       /* How far it reaches. */
    uint32_t dim_radius;   /* Where bright ends and dim begins. Meaning is the ruleset's. */
    uint32_t colour;       /* Packed. One of very few appearance fields in the world, */
                           /* and it is here because light shape affects what is visible. */
    wangle   arc;          /* A shuttered lantern. A full turn shines everywhere. */
    uint16_t padding;
};

/* ------------------------------------------------------------------------- *
 * The world
 * ------------------------------------------------------------------------- */

struct world {
    struct block things;
    struct block walls;
    struct block regions;
    struct block vertices;
    struct block lights;

    struct string_pool strings;

    /*
     * The extent of the map, in world units. Not a constraint on where anything
     * may stand -- it is what the fog grid is sized from, and what a renderer
     * uses to frame the view. Established when a world is loaded or generated.
     */
    wcoord min_x;
    wcoord min_y;
    wcoord max_x;
    wcoord max_y;

    /* Beats since this world started running. Phase 3 advances it. */
    uint64_t tick;
};

/*
 * Prepare an empty world with room for the given counts. Every block gets its
 * index-0 sentinel and the string pool gets its empty string.
 * Returns 1 on success, 0 if memory could not be found -- which a caller must
 * treat as fatal rather than continuing with a world it could not build.
 */
int world_init(struct world *w,
               uint32_t thing_capacity,
               uint32_t wall_capacity,
               uint32_t region_capacity,
               uint32_t vertex_capacity,
               uint32_t light_capacity,
               uint32_t string_capacity);

/* Release everything a world holds. */
void world_release(struct world *w);

/*
 * Claim a record of each kind, zeroed, and return its index.
 * Return 0 when memory could not be found.
 */
uint32_t world_add_thing(struct world *w);
uint32_t world_add_wall(struct world *w);
uint32_t world_add_region(struct world *w);
uint32_t world_add_vertex(struct world *w, wcoord x, wcoord y);
uint32_t world_add_light(struct world *w);

/*
 * Reach a record. Valid only until the next allocation of that kind, because
 * growth moves a block. Never store what these return.
 * An index past the end reads as the empty record.
 */
struct thing  *world_thing(struct world *w, uint32_t index);
struct wall   *world_wall(struct world *w, uint32_t index);
struct region *world_region(struct world *w, uint32_t index);
struct vertex *world_vertex(struct world *w, uint32_t index);
struct light  *world_light(struct world *w, uint32_t index);

const struct thing  *world_thing_const(const struct world *w, uint32_t index);
const struct wall   *world_wall_const(const struct world *w, uint32_t index);
const struct region *world_region_const(const struct world *w, uint32_t index);
const struct vertex *world_vertex_const(const struct world *w, uint32_t index);
const struct light  *world_light_const(const struct world *w, uint32_t index);

/* How many records of each kind are in use, including the sentinel at 0. */
uint32_t world_thing_count(const struct world *w);
uint32_t world_wall_count(const struct world *w);
uint32_t world_region_count(const struct world *w);
uint32_t world_vertex_count(const struct world *w);
uint32_t world_light_count(const struct world *w);

/*
 * Small predicates, offered so that nobody tests a flag bit by hand. A bit
 * tested by hand in forty places is a bit tested wrongly in one of them.
 */
int thing_blocks_sight(const struct thing *t);
int thing_blocks_movement(const struct thing *t);
int thing_is_hidden(const struct thing *t);
int thing_can_see(const struct thing *t);

int wall_blocks_sight(const struct wall *wall);
int wall_blocks_movement(const struct wall *wall);
int wall_is_one_way(const struct wall *wall);

/*
 * Copy a whole world over another, growing where it must. This is the rollback
 * ring's fast path: no encoding, no endianness, no walk over fields, because it
 * never leaves this process. The versioned file writer is a separate, slower,
 * more careful thing.
 * Returns 1 on success, 0 if memory could not be found.
 */
int world_copy(struct world *destination, const struct world *source);

#endif
