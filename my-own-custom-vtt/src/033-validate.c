/*
 * 033-validate.c -- one pass that makes every later assumption true.
 *
 * Interface, and the numbered list of invariants, are in 033-validate.h.
 *
 * The order below is the order in that list, and it is not arbitrary: cheapest
 * and most fundamental first, so that a world which is badly wrong fails on
 * "this index points nowhere" rather than deep inside polygon winding, where the
 * message would be true and useless.
 */

#include "033-validate.h"
#include "029-geometry.h"
#include "031-region.h"
#include "070-scope.h"

#include <stdio.h>
#include <string.h>

/* {{{ static int fail */
static int fail(struct validation_failure *failure,
                const char *block, uint32_t index, const char *field,
                int64_t found, const char *expected)
{
    failure->block    = block;
    failure->index    = index;
    failure->field    = field;
    failure->found    = found;
    failure->expected = expected;

    /*
     * Returns 0 so that every caller can write `return fail(...)`. Validation
     * stops here: the first failure is the one worth reading, and thirty
     * consequential ones bury it.
     */
    return 0;
}
/* }}} */

/* {{{ static int check_sentinels */
static int check_sentinels(const struct world *w, struct validation_failure *failure)
{
    /*
     * Index 0 of every block must still be the zero record. If something claimed
     * it, then "zero means nothing" has quietly stopped being true, and every
     * unchecked index read in the entire program is now reading a real record
     * when it thinks it is reading emptiness.
     */
    const struct thing *t = world_thing_const(w, 0);
    const struct wall *wl = world_wall_const(w, 0);
    const struct region *r = world_region_const(w, 0);
    const struct light *l = world_light_const(w, 0);

    if (t->x != 0 || t->y != 0 || t->kind != 0 || t->flags != 0) {
        return fail(failure, "things", 0, "(the sentinel)", t->kind,
                    "index 0 to be the empty record, claimed by nothing");
    }

    if (wl->ax != 0 || wl->bx != 0 || wl->flags != 0) {
        return fail(failure, "walls", 0, "(the sentinel)", wl->flags,
                    "index 0 to be the empty record, claimed by nothing");
    }

    if (r->vertex_count != 0 || r->parent != 0) {
        return fail(failure, "regions", 0, "(the sentinel)", r->vertex_count,
                    "index 0 to be the empty record, claimed by nothing");
    }

    if (l->thing != 0 || l->radius != 0) {
        return fail(failure, "lights", 0, "(the sentinel)", l->thing,
                    "index 0 to be the empty record, claimed by nothing");
    }

    return 1;
}
/* }}} */

/* {{{ static int check_references */
static int check_references(const struct world *w, struct validation_failure *failure)
{
    uint32_t count;
    uint32_t i;

    /*
     * Every index field points inside its block. This is the invariant that lets
     * accessors skip bounds checks in release builds, and lets nothing anywhere
     * ask whether a reference is real.
     */
    count = world_thing_count(w);
    for (i = 1; i < count; i++) {
        const struct thing *t = world_thing_const(w, i);

        if (t->region >= world_region_count(w)) {
            return fail(failure, "things", i, "region", t->region,
                        "an index into the regions block");
        }
    }

    count = world_wall_count(w);
    for (i = 1; i < count; i++) {
        const struct wall *wl = world_wall_const(w, i);

        if (wl->door >= world_thing_count(w)) {
            return fail(failure, "walls", i, "door", wl->door,
                        "an index into the things block, or 0 for plain wall");
        }
    }

    count = world_region_count(w);
    for (i = 1; i < count; i++) {
        const struct region *r = world_region_const(w, i);

        if (r->parent >= count) {
            return fail(failure, "regions", i, "parent", r->parent,
                        "an index into the regions block, or 0 for top level");
        }

        /*
         * A region that is its own parent would make the chain walk spin. The
         * general cycle case is caught by the depth check further down; this one
         * is caught here because it is the common typo and the message is
         * clearer.
         */
        if (r->parent == i) {
            return fail(failure, "regions", i, "parent", r->parent,
                        "a different region, or 0 -- a region cannot contain itself");
        }
    }

    count = world_light_count(w);
    for (i = 1; i < count; i++) {
        const struct light *l = world_light_const(w, i);

        if (l->thing == 0 || l->thing >= world_thing_count(w)) {
            return fail(failure, "lights", i, "thing", l->thing,
                        "an index into the things block -- a light is carried by something");
        }
    }

    return 1;
}
/* }}} */

/* {{{ static int check_walls_have_length */
static int check_walls_have_length(const struct world *w,
                                   struct validation_failure *failure)
{
    uint32_t count = world_wall_count(w);
    uint32_t i;

    /*
     * A zero-length wall has no direction, so the sight sweep cannot compute an
     * angle to its endpoints and the side test cannot say which side of it
     * anything is on. Refused here rather than guarded against in both of those,
     * which run per body per tick.
     */
    for (i = 1; i < count; i++) {
        const struct wall *wl = world_wall_const(w, i);

        if (wl->ax == wl->bx && wl->ay == wl->by) {
            return fail(failure, "walls", i, "ax,ay and bx,by", wl->ax,
                        "two different endpoints -- a wall with no length has no side");
        }
    }

    return 1;
}
/* }}} */

/* {{{ static int check_region_boundaries */
static int check_region_boundaries(const struct world *w,
                                   struct validation_failure *failure)
{
    uint32_t count = world_region_count(w);
    uint32_t i;

    for (i = 1; i < count; i++) {
        const struct region *r = world_region_const(w, i);
        const struct vertex *boundary;
        int64_t area2;

        if (r->vertex_count < 3) {
            return fail(failure, "regions", i, "vertex_count", r->vertex_count,
                        "at least 3 -- fewer bounds no area");
        }

        /* The run of vertices must sit entirely inside the vertex block. */
        if (r->first_vertex == 0 ||
            r->first_vertex + r->vertex_count > world_vertex_count(w)) {
            return fail(failure, "regions", i, "first_vertex", r->first_vertex,
                        "a run of vertex_count vertices inside the vertices block");
        }

        boundary = region_boundary(w, i);
        area2 = geom_polygon_area2(boundary, r->vertex_count);

        if (area2 == 0) {
            return fail(failure, "regions", i, "(boundary)", 0,
                        "a polygon with area -- these vertices are all in a line");
        }

        /*
         * Wound counter-clockwise, which means positive doubled area. The
         * containment test does not care about winding, but the generator and
         * anything that walks a boundary in order does, and one convention
         * enforced here is cheaper than every consumer handling both.
         */
        if (area2 < 0) {
            return fail(failure, "regions", i, "(boundary)", area2,
                        "counter-clockwise winding -- this polygon is wound the other way");
        }

        if (geom_polygon_self_intersects(boundary, r->vertex_count)) {
            return fail(failure, "regions", i, "(boundary)", r->vertex_count,
                        "a boundary that does not cross itself");
        }
    }

    return 1;
}
/* }}} */

/* {{{ static int check_region_nesting */
static int check_region_nesting(const struct world *w,
                                struct validation_failure *failure)
{
    uint32_t count = world_region_count(w);
    uint32_t i;

    /*
     * Every chain terminates, within the depth limit. This is what lets
     * region_is_within -- which runs on every permission check -- be a loop with
     * no cycle guard.
     */
    for (i = 1; i < count; i++) {
        uint32_t depth = region_depth(w, i);

        if (depth > REGION_MAX_DEPTH) {
            return fail(failure, "regions", i, "parent", depth,
                        "a chain of parents no deeper than REGION_MAX_DEPTH, "
                        "terminating at 0 -- this one loops or is too deep");
        }
    }

    return 1;
}
/* }}} */

/* {{{ static int check_lights_agree_with_their_things */
static int check_lights_agree_with_their_things(const struct world *w,
                                                struct validation_failure *failure)
{
    uint32_t count = world_light_count(w);
    uint32_t i;

    /*
     * The same fact is written down twice -- a thing says it emits light, and a
     * light says which thing carries it -- so the two have to agree. Two
     * representations that can disagree eventually will.
     */
    for (i = 1; i < count; i++) {
        const struct light *l = world_light_const(w, i);
        const struct thing *t = world_thing_const(w, l->thing);

        if ((t->flags & THING_EMITS_LIGHT) == 0) {
            return fail(failure, "lights", i, "thing", l->thing,
                        "a thing with THING_EMITS_LIGHT set -- the two records disagree");
        }
    }

    return 1;
}
/* }}} */

/* {{{ static int check_things_know_their_region */
static int check_things_know_their_region(const struct world *w,
                                          struct validation_failure *failure)
{
    uint32_t count = world_thing_count(w);
    uint32_t i;

    /*
     * A thing's region field is maintained incrementally once the world starts
     * moving -- only bodies that moved are re-tested. That is what makes it
     * affordable, and it is also what lets it drift silently. This check is the
     * thing that catches the drift, by recomputing from scratch and comparing.
     *
     * It is the most expensive check here, because it walks every region for
     * every thing. That is acceptable in a pass that runs at load and after a
     * structural change, and would not be acceptable per tick.
     */
    for (i = 1; i < count; i++) {
        const struct thing *t = world_thing_const(w, i);
        uint32_t actual = region_deepest_containing(w, t->x, t->y);

        if (t->region != actual) {
            return fail(failure, "things", i, "region", t->region,
                        "the deepest region actually containing this body");
        }
    }

    return 1;
}
/* }}} */

/* {{{ static int check_string_offsets */
static int check_string_offsets(const struct world *w,
                                struct validation_failure *failure)
{
    uint32_t count = world_region_count(w);
    uint32_t i;

    /*
     * A name offset must point at a well-formed string whose length does not run
     * past the end of the pool. This is what lets every read be a length and a
     * pointer rather than a scan that could run off the end.
     */
    for (i = 1; i < count; i++) {
        const struct region *r = world_region_const(w, i);

        if (!string_pool_offset_is_valid(&w->strings, r->name_offset)) {
            return fail(failure, "regions", i, "name_offset", r->name_offset,
                        "an offset to a well-formed string inside the pool");
        }
    }

    return 1;
}
/* }}} */

/* {{{ static int check_scopes */
static int check_scopes(const struct world *w, struct validation_failure *failure)
{
    uint32_t count = world_scope_count(w);
    uint32_t i;

    for (i = 1; i < count; i++) {
        const struct scope *s = world_scope_const(w, i);

        if (s->membership != SCOPE_LIST && s->membership != SCOPE_REGION) {
            return fail(failure, "scopes", i, "membership", s->membership,
                        "SCOPE_LIST or SCOPE_REGION -- there is no third rule");
        }

        if (s->style != STYLE_DRIVEN && s->style != STYLE_ORDERED) {
            return fail(failure, "scopes", i, "style", s->style,
                        "STYLE_DRIVEN or STYLE_ORDERED");
        }

        if (s->membership == SCOPE_LIST) {
            uint32_t member;

            /*
             * A slice of the shared pool, so both ends must be inside it. A slice
             * running past the end would have a scope quietly containing whatever
             * came after somebody else's members.
             */
            if (s->member_count > 0 &&
                (s->first_member == 0 ||
                 s->first_member + s->member_count > world_member_count(w))) {
                return fail(failure, "scopes", i, "first_member", s->first_member,
                            "a run of member_count entries inside the members pool");
            }

            for (member = 0; member < s->member_count; member++) {
                uint32_t thing = world_member_at(w, s->first_member + member);

                if (thing == 0 || thing >= world_thing_count(w)) {
                    return fail(failure, "scopes", i, "(a member)", thing,
                                "an index into the things block");
                }
            }
        } else {
            if (s->region >= world_region_count(w)) {
                return fail(failure, "scopes", i, "region", s->region,
                            "an index into the regions block, or 0 for the whole map");
            }
        }

        if (!string_pool_offset_is_valid(&w->strings, s->name_offset)) {
            return fail(failure, "scopes", i, "name_offset", s->name_offset,
                        "an offset to a well-formed string inside the pool");
        }
    }

    return 1;
}
/* }}} */

/* {{{ int world_validate */
int world_validate(const struct world *w, struct validation_failure *failure)
{
    /*
     * The order is the order of the list in the header, and it matters. A world
     * with a bad index would otherwise fail somewhere deep in polygon winding,
     * with a message that is true and useless.
     */
    if (!check_sentinels(w, failure))                     return 0;
    if (!check_references(w, failure))                    return 0;
    if (!check_walls_have_length(w, failure))             return 0;
    if (!check_region_boundaries(w, failure))             return 0;
    if (!check_region_nesting(w, failure))                return 0;
    if (!check_lights_agree_with_their_things(w, failure)) return 0;
    if (!check_things_know_their_region(w, failure))      return 0;
    if (!check_string_offsets(w, failure))                return 0;
    if (!check_scopes(w, failure))                        return 0;

    return 1;
}
/* }}} */

/* {{{ const char *validation_failure_describe */
const char *validation_failure_describe(const struct validation_failure *failure,
                                        char *buffer,
                                        uint32_t buffer_size)
{
    /*
     * One shape for every message in the project: what, where, what was there,
     * what should have been. Written here rather than at each failure site so
     * that none of them is composed in a hurry.
     */
    snprintf(buffer, (size_t)buffer_size,
             "%s[%u].%s is %lld; expected %s.",
             failure->block,
             (unsigned)failure->index,
             failure->field,
             (long long)failure->found,
             failure->expected);

    return buffer;
}
/* }}} */
