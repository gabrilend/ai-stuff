/*
 * 070-scope.h -- is this thing inside this scope?
 *
 * One question, asked constantly. Every command runs it; every outbound record
 * runs it. It allocates nothing and touches only the scopes, the members pool,
 * and the regions.
 *
 * The dial's four positions -- one body, a few bodies, a region, the map -- are
 * two facts: membership is a list or a region, and style is a separate axis. See
 * docs/008-who-controls-what.md and issues 601 through 606.
 */

#ifndef VTT_SCOPE_H
#define VTT_SCOPE_H

#include <stdint.h>

#include "027-world.h"

/*
 * Whether the scope contains the thing.
 *
 * LIST walks a slice of the members pool. REGION resolves the thing's region up
 * the parent chain looking for the scope's -- using region_is_within, built in
 * phase 1 and waiting since then for a caller.
 *
 * A scope index of 0 contains nothing. A thing index of 0 is in nothing.
 */
int scope_contains(const struct world *w, uint32_t scope, uint32_t thing);

/* Whether this viewer holds this scope. THE load-bearing permission check. */
int scope_is_held_by(const struct world *w, uint32_t scope, uint32_t viewer);

/*
 * Whether any scope this viewer holds contains this thing, and which. Returns 0
 * when none does.
 */
uint32_t scope_of_viewer_containing(const struct world *w,
                                    uint32_t viewer,
                                    uint32_t thing);

/* Whether a verb suits a scope's style. */
int scope_style_allows(const struct world *w, uint32_t scope, uint16_t verb);

/* How many things a scope contains right now. What a demo reports. */
uint32_t scope_size(const struct world *w, uint32_t scope);

/*
 * Gather the bodies with eyes that a viewer commands, into a caller's array.
 * Returns how many were found, which may exceed `capacity` -- the caller is
 * told the true count so it can report having been given fewer.
 */
uint32_t scope_eyes_of_viewer(const struct world *w, uint32_t viewer,
                              uint32_t *into, uint32_t capacity);

/* Whether any scope this viewer holds has the flag. */
int viewer_has_flag(const struct world *w, uint32_t viewer, uint16_t flag);

/*
 * Build a LIST scope over consecutive members. A convenience, because the
 * members pool being a shared slice means a caller has to add them in order and
 * getting that wrong is silent.
 */
uint32_t scope_make_list(struct world *w, uint32_t viewer, uint8_t style,
                         const uint32_t *things, uint32_t count,
                         const char *name);

/*
 * Unhold every scope this viewer held, when they go.
 *
 * The scopes REMAIN, holding whatever they held -- an unheld scope is a normal
 * thing. What happens to the departed person's own character is a separate and
 * still-open question (4.4); this settles only that the scope survives.
 *
 * Returns how many were unheld.
 */
uint32_t scope_unhold_all(struct world *w, uint32_t viewer);

/* Build a REGION scope. */
uint32_t scope_make_region(struct world *w, uint32_t viewer, uint8_t style,
                           uint32_t region, uint16_t flags, const char *name);

#endif
