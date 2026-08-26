/*
 * 031-region.c -- containment, nesting, and the walk up the parent chain.
 *
 * Interface and reasoning are in 031-region.h. The geometry itself lives in
 * 029-geometry.c; this file is about which region, not about what a polygon is.
 */

#include "031-region.h"
#include "029-geometry.h"

/* {{{ const struct vertex *region_boundary */
const struct vertex *region_boundary(const struct world *w, uint32_t region)
{
    const struct region *r = world_region_const(w, region);

    /*
     * The sentinel region has first_vertex 0, which is the vertex sentinel, and
     * vertex_count 0. Callers pair this with the count, so a region with no
     * boundary yields a polygon of zero vertices -- a shape with no interior,
     * which contains nothing. No special case needed anywhere upstream.
     */
    return world_vertex_const(w, r->first_vertex);
}
/* }}} */

/* {{{ int region_contains */
int region_contains(const struct world *w, uint32_t region, wcoord x, wcoord y)
{
    const struct region *r = world_region_const(w, region);

    /* Open ground is not a region and contains nothing in particular. */
    if (region == 0) {
        return 0;
    }

    return geom_polygon_contains(region_boundary(w, region), r->vertex_count, x, y);
}
/* }}} */

/* {{{ uint32_t region_depth */
uint32_t region_depth(const struct world *w, uint32_t region)
{
    uint32_t depth = 0;
    uint32_t steps = 0;

    while (region != 0 && steps <= REGION_MAX_DEPTH) {
        const struct region *r = world_region_const(w, region);

        depth++;
        steps++;
        region = r->parent;
    }

    /*
     * The step counter is a backstop, not a cycle check. The validator
     * establishes that no chain is longer than REGION_MAX_DEPTH and that none
     * loops, which is what lets the permission walk below be unguarded. This
     * bound exists so that the validator itself -- which runs against worlds that
     * have not been checked yet -- cannot hang on a malformed one.
     */
    return depth;
}
/* }}} */

/* {{{ int region_is_within */
int region_is_within(const struct world *w, uint32_t region, uint32_t ancestor)
{
    uint32_t steps = 0;

    /*
     * An ancestor of 0 is the whole map. Everything is within it, including open
     * ground, which is how a GM's scope is expressed with no special case
     * anywhere in the permission check.
     */
    if (ancestor == 0) {
        return 1;
    }

    /*
     * Walk up. This runs on every permission check for a region-membership
     * scope, so it allocates nothing and touches only the regions block. The
     * chain is two or three long in practice.
     */
    while (region != 0 && steps <= REGION_MAX_DEPTH) {
        if (region == ancestor) {
            return 1;
        }

        region = world_region_const(w, region)->parent;
        steps++;
    }

    return 0;
}
/* }}} */

/* {{{ uint32_t region_deepest_containing */
uint32_t region_deepest_containing(const struct world *w, wcoord x, wcoord y)
{
    uint32_t count = world_region_count(w);
    uint32_t index;
    uint32_t best = 0;
    uint32_t best_depth = 0;

    /*
     * Every region is tested, and the deepest match wins. A body standing in the
     * cellar is inside both the cellar's polygon and the tavern's, and the answer
     * has to be the cellar -- otherwise a scope over the cellar would never own
     * anything, and "when they enter the cellar" would never fire.
     *
     * Walking all of them is right for a query that runs once per placement. In
     * phase 3 it runs only for bodies that actually moved, which is what keeps it
     * affordable; a version that ran for everything every tick would need an
     * index, and would then need that index maintained.
     */
    for (index = 1; index < count; index++) {
        uint32_t depth;

        if (!region_contains(w, index, x, y)) {
            continue;
        }

        depth = region_depth(w, index);

        /*
         * Strictly deeper, so that two regions at the same depth containing the
         * same point resolve to the lower index rather than to whichever was
         * tested last. Overlapping siblings are a malformed world and the
         * validator says so -- but if one slips through, the answer must at least
         * be the same on every machine, or two replays of one session diverge.
         */
        if (depth > best_depth) {
            best = index;
            best_depth = depth;
        }
    }

    return best;
}
/* }}} */
