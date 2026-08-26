/*
 * 070-scope.c -- membership, and the one integer comparison everything rests on.
 *
 * Interface and reasoning are in 070-scope.h.
 */

#include "070-scope.h"
#include "031-region.h"
#include "051-commandlog.h"

#include <string.h>

/* {{{ int scope_contains */
int scope_contains(const struct world *w, uint32_t scope, uint32_t thing)
{
    const struct scope *s;

    if (scope == 0 || scope >= world_scope_count(w)) {
        return 0;
    }

    if (thing == 0 || thing >= world_thing_count(w)) {
        return 0;
    }

    s = world_scope_const(w, scope);

    if (s->membership == SCOPE_LIST) {
        uint32_t i;

        /*
         * A slice of the shared pool. Short by nature -- a party is four, a
         * commander's handful is six -- so a walk beats an index.
         */
        for (i = 0; i < s->member_count; i++) {
            if (world_member_at(w, s->first_member + i) == thing) {
                return 1;
            }
        }

        return 0;
    }

    /*
     * A region, and everything nested inside it. Evaluated from the thing's
     * CURRENT region, which is what makes a patrol crossing a boundary change
     * hands the moment it crosses.
     *
     * That is mechanically what happens and it is not settled that anybody wants
     * it -- the forest's commander may have been walking that patrol for ten
     * minutes with an intention. See open question 6.1. The demo shows the moment
     * it happens rather than this file deciding it.
     */
    {
        const struct thing *t = world_thing_const(w, thing);
        return region_is_within(w, t->region, s->region);
    }
}
/* }}} */

/* {{{ int scope_is_held_by */
int scope_is_held_by(const struct world *w, uint32_t scope, uint32_t viewer)
{
    /*
     * ONE INTEGER COMPARISON, and it is the load-bearing permission check in the
     * entire project.
     *
     * Almost every other protection here is geometric or structural. This one is
     * a field equalling a number, and it is cheap enough that nobody will ever be
     * tempted to skip it -- which is exactly the property a check everything
     * depends on should have.
     */
    if (scope == 0 || scope >= world_scope_count(w) || viewer == 0) {
        return 0;
    }

    return world_scope_const(w, scope)->viewer == viewer;
}
/* }}} */

/* {{{ uint32_t scope_of_viewer_containing */
uint32_t scope_of_viewer_containing(const struct world *w,
                                    uint32_t viewer,
                                    uint32_t thing)
{
    uint32_t count = world_scope_count(w);
    uint32_t i;

    if (viewer == 0) {
        return 0;
    }

    for (i = 1; i < count; i++) {
        if (world_scope_const(w, i)->viewer != viewer) {
            continue;
        }

        if (scope_contains(w, i, thing)) {
            return i;
        }
    }

    return 0;
}
/* }}} */

/* {{{ int scope_style_allows */
int scope_style_allows(const struct world *w, uint32_t scope, uint16_t verb)
{
    const struct scope *s;

    if (scope == 0 || scope >= world_scope_count(w)) {
        return 0;
    }

    s = world_scope_const(w, scope);

    /*
     * Style and membership do not constrain each other, and the moment they do
     * the dial has collapsed back into a list of roles. A GM can drive one goblin
     * with the keys; a player with a party of four gets the strategy interface.
     */
    switch (verb) {
    case VERB_DRIVE:
        return s->style == STYLE_DRIVEN;

    case VERB_ORDER_MOVE:
        return s->style == STYLE_ORDERED;

    case VERB_ORDER_FACE:
    case VERB_ORDER_STOP:
        /* Both styles turn and both styles stop. */
        return 1;

    default:
        return 1;
    }
}
/* }}} */

/* {{{ uint32_t scope_size */
uint32_t scope_size(const struct world *w, uint32_t scope)
{
    const struct scope *s;
    uint32_t total = 0;
    uint32_t i;

    if (scope == 0 || scope >= world_scope_count(w)) {
        return 0;
    }

    s = world_scope_const(w, scope);

    if (s->membership == SCOPE_LIST) {
        return s->member_count;
    }

    /*
     * A region scope's size is a question about the world right now, not about
     * the scope -- which is the whole difference between the two rules, and why
     * this walks rather than reads a field.
     */
    for (i = 1; i < world_thing_count(w); i++) {
        if (scope_contains(w, scope, i)) {
            total++;
        }
    }

    return total;
}
/* }}} */

/* {{{ uint32_t scope_eyes_of_viewer */
uint32_t scope_eyes_of_viewer(const struct world *w, uint32_t viewer,
                              uint32_t *into, uint32_t capacity)
{
    uint32_t found = 0;
    uint32_t thing;

    if (viewer == 0) {
        return 0;
    }

    /*
     * Walked over things rather than over scopes, so that a body in two of a
     * viewer's scopes is swept once rather than twice. Sweeping is the expensive
     * pass; doing it twice for the same eyes would be paying for nothing.
     */
    for (thing = 1; thing < world_thing_count(w); thing++) {
        if (!thing_can_see(world_thing_const(w, thing))) {
            continue;
        }

        if (scope_of_viewer_containing(w, viewer, thing) == 0) {
            continue;
        }

        if (found < capacity) {
            into[found] = thing;
        }

        found++;
    }

    /*
     * The true count is returned even when it exceeds the capacity, so a caller
     * can say it was given fewer than there are rather than quietly believing it
     * has them all.
     */
    return found;
}
/* }}} */

/* {{{ int viewer_has_flag */
int viewer_has_flag(const struct world *w, uint32_t viewer, uint16_t flag)
{
    uint32_t count = world_scope_count(w);
    uint32_t i;

    if (viewer == 0) {
        return 0;
    }

    for (i = 1; i < count; i++) {
        const struct scope *s = world_scope_const(w, i);

        if (s->viewer == viewer && (s->flags & flag) != 0) {
            return 1;
        }
    }

    return 0;
}
/* }}} */

/* {{{ uint32_t scope_unhold_all */
uint32_t scope_unhold_all(struct world *w, uint32_t viewer)
{
    uint32_t count = world_scope_count(w);
    uint32_t unheld = 0;
    uint32_t i;

    if (viewer == 0) {
        return 0;
    }

    for (i = 1; i < count; i++) {
        struct scope *s = world_scope(w, i);

        if (s->viewer == viewer) {
            s->viewer = 0;
            unheld++;
        }
    }

    return unheld;
}
/* }}} */

/* {{{ uint32_t scope_make_list */
uint32_t scope_make_list(struct world *w, uint32_t viewer, uint8_t style,
                         const uint32_t *things, uint32_t count,
                         const char *name)
{
    uint32_t index = world_add_scope(w);
    uint32_t first = 0;
    uint32_t i;
    struct scope *s;

    if (index == 0) {
        return 0;
    }

    /*
     * Members must be consecutive, because a scope holds a slice of a shared
     * pool. Adding them here rather than leaving it to a caller is why this
     * function exists: getting the order wrong is silent, and the symptom is a
     * scope containing somebody else's goblins.
     */
    for (i = 0; i < count; i++) {
        uint32_t at = world_add_member(w, things[i]);

        if (at == 0) {
            return 0;
        }

        if (i == 0) {
            first = at;
        }
    }

    s = world_scope(w, index);
    s->viewer = viewer;
    s->membership = SCOPE_LIST;
    s->style = style;
    s->first_member = first;
    s->member_count = count;
    s->name_offset = (name != NULL)
                   ? string_pool_add(&w->strings, name, (uint32_t)strlen(name))
                   : 0;

    return index;
}
/* }}} */

/* {{{ uint32_t scope_make_region */
uint32_t scope_make_region(struct world *w, uint32_t viewer, uint8_t style,
                           uint32_t region, uint16_t flags, const char *name)
{
    uint32_t index = world_add_scope(w);
    struct scope *s;

    if (index == 0) {
        return 0;
    }

    s = world_scope(w, index);
    s->viewer = viewer;
    s->membership = SCOPE_REGION;
    s->style = style;
    s->region = region;
    s->flags = flags;
    s->name_offset = (name != NULL)
                   ? string_pool_add(&w->strings, name, (uint32_t)strlen(name))
                   : 0;

    return index;
}
/* }}} */
