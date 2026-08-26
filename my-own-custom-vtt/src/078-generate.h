/*
 * 078-generate.h -- a description and a seed become a place.
 *
 * Four stages, and the split between the first two is what the whole phase rests
 * on:
 *
 *   VALIDATE  -- 076-describe. Refuse before anything expensive.
 *   LAY OUT   -- rooms and corridors as an ABSTRACT GRAPH. No coordinates.
 *   REALISE   -- topology into wall segments and region polygons.
 *   FURNISH   -- things standing in it, asked of the ruleset.
 *
 * Nearly every question worth asking about a dungeon is a question about the
 * graph: is it connected, is there a loop, is the treasure behind the guard. Each
 * is a few lines against a graph and nearly unanswerable against a pile of
 * segments -- so the graph is produced first, checked, and only then given
 * coordinates.
 *
 * Everything is deterministic from a seed, which is what lets a map be REFERRED
 * TO rather than stored: a description plus a seed is a few hundred bytes naming
 * a whole dungeon exactly.
 *
 * See docs/013-content-is-generated.md and issues 802 through 806.
 */

#ifndef VTT_GENERATE_H
#define VTT_GENERATE_H

#include <stdint.h>

#include "076-describe.h"
#include "027-world.h"
#include "047-streams.h"

#define LAYOUT_MAX_NODES 64
#define LAYOUT_MAX_EDGES 128

/* A room, before it has a position. */
struct layout_node {
    uint32_t wanted_size;    /* Metres across. */
    uint32_t feature;        /* Index into the description's required list, or 0. */

    /* Filled in by the realise stage. */
    wcoord   x;
    wcoord   y;
    wcoord   size;
    uint32_t region;
};

struct layout_edge {
    uint32_t from;
    uint32_t to;
};

struct layout {
    struct layout_node nodes[LAYOUT_MAX_NODES];
    uint32_t           node_count;

    struct layout_edge edges[LAYOUT_MAX_EDGES];
    uint32_t           edge_count;
};

/*
 * Build the graph. Returns 1, or 0 with a sentence through `why` naming the
 * constraint that could not be satisfied.
 *
 * NOT "produce something close" -- a dungeon quietly missing the cellar somebody
 * asked for is worse than an error.
 */
int layout_build(struct layout *l, const struct description *d,
                 struct stream_registry *streams, const char **why);

/* Is every node reachable from node 0? */
int layout_is_connected(const struct layout *l);

/* How many connections beyond a bare tree. */
uint32_t layout_loop_count(const struct layout *l);

/*
 * Turn the graph into geometry, into an already-initialised world.
 *
 * Produces everything the validator insists on FROM THE START rather than as a
 * repair pass -- a generator that produces worlds the validator refuses is a
 * generator nobody can use, and repairing afterwards is how a generator stops
 * matching its own output.
 */
int realise(struct world *w, struct layout *l, const struct description *d,
            struct stream_registry *streams, const char **why);

/*
 * Put things in it. `ruleset` is a `struct ruleset *` or NULL -- a ruleset with
 * no opinion produces an empty but valid world, which is a legal outcome rather
 * than a failure.
 */
int furnish(struct world *w, struct layout *l, const struct description *d,
            struct stream_registry *streams, void *ruleset, const char **why);

/*
 * All four stages. What almost every caller wants.
 *
 * The world must already be initialised with room for what a description of this
 * size implies -- generate_capacity_hint says how much.
 */
int generate(struct world *w, const struct description *d, uint64_t seed,
             void *ruleset, struct layout *layout_out, const char **why);

void generate_capacity_hint(const struct description *d,
                            uint32_t *things, uint32_t *walls,
                            uint32_t *regions, uint32_t *vertices,
                            uint32_t *lights, uint32_t *strings);

/*
 * Did the generator produce what was asked for?
 *
 * A DIFFERENT QUESTION from world_validate, which asks whether a world is
 * coherent and would happily pass a dungeon with three rooms when somebody asked
 * for eight. Only this can tell a generator from a random number visualiser.
 *
 * Reports every failure together, like the description's wall.
 */
int generate_check(const struct world *w, const struct layout *l,
                   const struct description *d, struct fault_list *faults);

#endif
