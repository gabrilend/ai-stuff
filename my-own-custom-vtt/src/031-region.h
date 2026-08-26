/*
 * 031-region.h -- named areas, and what it means to be inside one.
 *
 * A region is the tavern, the forest, the cellar under the tavern. They are what
 * make an abstract control scope addressable: handing somebody "the tavern" is
 * handing them a region index, and their scope then covers every thing whose
 * region resolves to it.
 *
 * Regions nest through a single `parent` index rather than a list of children,
 * so a scope over the forest covers the clearing inside it without listing the
 * clearing. The walk up that chain happens on every permission check, so it is a
 * loop over indices with no allocation.
 *
 * See docs/006-the-map-is-geometry-not-a-picture.md,
 * docs/008-who-controls-what.md, and issues/105-regions-nest.md.
 */

#ifndef VTT_REGION_H
#define VTT_REGION_H

#include <stdint.h>

#include "027-world.h"

/*
 * How deep regions may nest. Two or three is what a tabletop actually uses -- a
 * forest with a clearing, a tavern with a cellar -- and the limit is here so that
 * the chain walk is a loop with a known bound rather than a loop that has to
 * guard against a cycle.
 *
 * The validator enforces it once, at load, which is what lets the walk itself be
 * unguarded. A world whose chains are longer than this is refused by name.
 */
#define REGION_MAX_DEPTH 8

/*
 * The deepest region containing the point, or 0 for open ground.
 *
 * Deepest, not first: a body in the cellar is in the cellar and not in the
 * tavern above it. This is what maintains a thing's `region` field, and in phase
 * 1 it runs at load for everything; phase 3 runs it only for bodies that moved.
 *
 * Walks every region, which is right for a query that runs once per placement
 * and would be wrong for one that ran per tick.
 */
uint32_t region_deepest_containing(const struct world *w, wcoord x, wcoord y);

/*
 * Whether `region` is `ancestor`, or is nested anywhere inside it.
 *
 * The permission question. A scope over the forest returns true for the clearing
 * inside it. An ancestor of 0 means the whole map, so everything is within it --
 * which is how a GM's scope is expressed without a special case.
 */
int region_is_within(const struct world *w, uint32_t region, uint32_t ancestor);

/*
 * How many parents a region has above it. Open ground is 0, a top-level region
 * is 1. Used by the validator to enforce the depth limit, and by
 * region_deepest_containing to decide which of two containing regions is deeper.
 */
uint32_t region_depth(const struct world *w, uint32_t region);

/*
 * The first vertex of a region's boundary. The boundary is `vertex_count`
 * vertices long, consecutive, and closed by joining the last back to the first.
 * A region with no boundary returns the vertex sentinel, whose coordinates are
 * zero -- which is a shape with no interior, so nothing is inside it.
 */
const struct vertex *region_boundary(const struct world *w, uint32_t region);

/* Whether a point falls inside one particular region's boundary. */
int region_contains(const struct world *w, uint32_t region, wcoord x, wcoord y);

#endif
