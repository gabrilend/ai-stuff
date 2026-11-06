/*
 * 086-shelves.c — a table that grows without moving anything (issue 409).
 *
 * General description: see 086-shelves.h. A shelf is one block from the
 * allocator, taken zeroed; nothing here ever frees one.
 */
#include "029-blocks.h"
#include "086-shelves.h"

/* {{{ shelves_count */
int32_t shelves_count(struct shelves *s)
{
    return atomic_load_acquire(&s->count);
}
/* }}} */

/* {{{ shelves_capacity */
int32_t shelves_capacity(const struct shelves *s)
{
    return (int32_t)(s->per_shelf * SHELVES_MAX);
}
/* }}} */

/* {{{ shelves_at */
void *shelves_at(struct shelves *s, int32_t i)
{
    uint8_t *shelf = s->shelf[(uint32_t)i / s->per_shelf];
    return shelf + (size_t)((uint32_t)i % s->per_shelf) * s->item_bytes;
}
/* }}} */

/* {{{ shelves_place */
void *shelves_place(struct shelves *s, int owner, int32_t i)
{
    if (i < 0 || i >= shelves_capacity(s)) {
        return (void *)0;
    }
    uint32_t which = (uint32_t)i / s->per_shelf;
    if (!s->shelf[which]) {
        void *shelf = block_alloc_zero(owner, (size_t)s->item_bytes * s->per_shelf);
        if (!shelf) {
            return (void *)0;
        }
        /* The address is published before any count that reaches it, and
         * a reader only looks below a count it loaded with acquire. */
        atomic_store_release(&s->shelf[which], shelf);
    }
    return shelves_at(s, i);
}
/* }}} */

/* {{{ shelves_publish */
void shelves_publish(struct shelves *s, int32_t count)
{
    atomic_store_release(&s->count, count);
}
/* }}} */
