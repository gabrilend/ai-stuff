/*
 * 058-viewer.c -- the participants, their memory, and their two buffers.
 *
 * Interface and reasoning are in 058-viewer.h.
 *
 * There is no socket code here. A viewer holds a descriptor and does not know
 * how it got one -- the door in 061 binds and accepts, and this file is about
 * what a participant IS rather than how they arrived. Keeping them apart means
 * the filter in 059 can be tested exhaustively without a network, which is what
 * makes the leak test cheap enough to run on every build.
 */

#include "058-viewer.h"

#include <stdlib.h>
#include <string.h>

/* {{{ int viewer_set_init */
int viewer_set_init(struct viewer_set *set, uint32_t capacity)
{
    /* Room for the reserved slot at index 0, whatever was asked for. */
    if (capacity < 2) {
        capacity = 2;
    }

    set->viewers = calloc((size_t)capacity, sizeof(struct viewer));
    if (set->viewers == NULL) {
        set->capacity = 0;
        set->count = 0;
        return 0;
    }

    set->capacity = capacity;

    /*
     * Index 0 is nobody, in keeping with every other block in this project. A
     * scope with viewer 0 is a scope nobody holds -- which is the normal state of
     * the forest on an evening when nobody is playing it.
     */
    set->count = 1;
    set->viewers[0].state = VIEWER_EMPTY;
    set->viewers[0].socket = -1;

    return 1;
}
/* }}} */

/* {{{ void viewer_set_release */
void viewer_set_release(struct viewer_set *set)
{
    uint32_t i;

    for (i = 0; i < set->count; i++) {
        fog_release(&set->viewers[i].fog);
        buffer_release(&set->viewers[i].inbound);
        buffer_release(&set->viewers[i].outbound);
    }

    free(set->viewers);
    set->viewers = NULL;
    set->count = 0;
    set->capacity = 0;
}
/* }}} */

/* {{{ uint32_t viewer_add */
uint32_t viewer_add(struct viewer_set *set, const struct world *w, wcoord fog_cell)
{
    uint32_t index;
    struct viewer *v;

    /*
     * Reuse a departed slot before growing. A viewer index is referred to by
     * scopes, which are world state, so the indices have to stay meaningful --
     * but a slot whose participant has gone and whose scopes have been unheld is
     * free for somebody else.
     */
    for (index = 1; index < set->count; index++) {
        if (set->viewers[index].state == VIEWER_EMPTY) {
            break;
        }
    }

    if (index >= set->count) {
        if (set->count >= set->capacity) {
            uint32_t wanted = set->capacity * 2;
            struct viewer *moved = realloc(set->viewers,
                                           (size_t)wanted * sizeof(struct viewer));

            if (moved == NULL) {
                return 0;
            }

            memset(moved + set->capacity, 0,
                   (size_t)(wanted - set->capacity) * sizeof(struct viewer));

            set->viewers = moved;
            set->capacity = wanted;
        }

        index = set->count;
        set->count++;
    }

    v = &set->viewers[index];
    memset(v, 0, sizeof(struct viewer));

    v->state = VIEWER_WAITING;
    v->socket = -1;

    /*
     * One fog per viewer, sized from the world, allocated once. A viewer without
     * memory would have to be special-cased everywhere the outbound filter asks
     * what they remember.
     */
    if (!fog_init(&v->fog, w, fog_cell)) {
        v->state = VIEWER_EMPTY;
        return 0;
    }

    if (!buffer_init(&v->inbound, VIEWER_INTAKE_PER_TICK) ||
        !buffer_init(&v->outbound, 4096)) {
        fog_release(&v->fog);
        buffer_release(&v->inbound);
        buffer_release(&v->outbound);
        v->state = VIEWER_EMPTY;
        return 0;
    }

    return index;
}
/* }}} */

/* {{{ void viewer_departs */
void viewer_departs(struct viewer_set *set, uint32_t index)
{
    struct viewer *v;

    if (index == 0 || index >= set->count) {
        return;
    }

    v = &set->viewers[index];

    /*
     * The socket goes and the buffers empty. THE FOG STAYS.
     *
     * Whether it should is open question 4.4, and it is left standing rather
     * than decided here, because fog surviving a reconnect is the difference
     * between a dropped connection being an annoyance and being a disaster --
     * somebody who drops for thirty seconds should not have to re-explore an
     * evening's dungeon.
     *
     * Keeping it costs a few kilobytes per departed viewer and is the reversible
     * choice; throwing it away is not.
     *
     * THEIR SCOPES ARE UNHELD SEPARATELY, by whoever owns the world -- see
     * scope_unhold_all. This file deliberately knows nothing about the world, so
     * that the filter above it can be tested without one.
     */
    v->socket = -1;
    v->state = VIEWER_GONE;
    buffer_clear(&v->inbound);
    buffer_clear(&v->outbound);
}
/* }}} */

/* {{{ struct viewer *viewer_at */
struct viewer *viewer_at(struct viewer_set *set, uint32_t index)
{
    /*
     * A bad index reads as the reserved slot, which is nobody -- the same
     * discipline as every other block, so that nothing anywhere needs a null
     * check on a viewer.
     */
    if (index >= set->count) {
        return &set->viewers[0];
    }

    return &set->viewers[index];
}
/* }}} */

/* {{{ const struct viewer *viewer_at_const */
const struct viewer *viewer_at_const(const struct viewer_set *set, uint32_t index)
{
    if (index >= set->count) {
        return &set->viewers[0];
    }

    return &set->viewers[index];
}
/* }}} */

/* {{{ uint32_t viewer_count */
uint32_t viewer_count(const struct viewer_set *set)
{
    return set->count;
}
/* }}} */

/* {{{ uint32_t viewer_connected_count */
uint32_t viewer_connected_count(const struct viewer_set *set)
{
    uint32_t total = 0;
    uint32_t i;

    for (i = 1; i < set->count; i++) {
        if (set->viewers[i].state == VIEWER_CONNECTED) {
            total++;
        }
    }

    return total;
}
/* }}} */
