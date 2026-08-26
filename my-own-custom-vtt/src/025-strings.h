/*
 * 025-strings.h -- one pool of bytes holding every name in the world.
 *
 * Regions are called things. So are scopes, and the people connected. That is
 * the whole list -- a creature has no name here, because a creature's name is
 * the ruleset's business and never enters the world.
 *
 * Names are rare and they never change: a region is called "The Tavern" for the
 * whole session. So the pool is append-only, has no free list, and needs no
 * reference counting. Two records naming the same string share one offset.
 *
 * It exists rather than a `char *` in each record for the same reason everything
 * else is an index: a pointer cannot be written to a snapshot without being
 * translated, and a snapshot that needs translation is a format that has to know
 * the shape of every record type.
 *
 * See issues/106-names-live-in-one-pool.md.
 */

#ifndef VTT_STRINGS_H
#define VTT_STRINGS_H

#include <stdint.h>

/*
 * The pool never grows. It is allocated once, at load, to a size the world
 * implies, and refuses when it is full.
 *
 * The reason is that growing would move the pool, and a caller holding a pointer
 * from a previous read would be looking at freed memory. Rather than making
 * every reader copy what it reads, or making every caller remember a rule, the
 * pool is simply large enough from the start -- which it can be, because the
 * number of names in a world is known when the world is loaded.
 */

/*
 * Offset 0 is the empty string, present before anything is appended. A record
 * with no name points at it and reads as "", the same way index 0 of a block
 * reads as an empty record.
 */
#define STRING_NOTHING 0u

/*
 * The longest a single name may be. A name past this is refused by name, not cut
 * short -- a silently truncated name is a fallback, and a fallback is a warning,
 * and a warning is an error.
 */
#define STRING_MAX_LENGTH 255

struct string_pool {
    uint8_t  *data;
    uint32_t  used;      /* Bytes written, including the empty string at 0. */
    uint32_t  capacity;  /* Bytes allocated. Never changes after init. */
};

/* Prepare a pool of the given size in bytes. Returns 1 on success, 0 on failure. */
int string_pool_init(struct string_pool *pool, uint32_t capacity);

/* Release a pool's memory. */
void string_pool_release(struct string_pool *pool);

/*
 * Append a string and return its offset.
 *
 * Returns STRING_NOTHING when the text is too long or the pool is full, which a
 * caller must treat as an error naming what could not fit -- not as an empty
 * name it can carry on with.
 */
uint32_t string_pool_add(struct string_pool *pool, const char *text, uint32_t length);

/*
 * Read a string. Returns a pointer to the bytes and writes the length through
 * `length_out`. The bytes are not null-terminated -- a length is one read, where
 * a terminator is a scan, and a scan over bytes an attacker influenced is a scan
 * that can run off the end.
 *
 * The pointer stays valid for the life of the pool, because the pool never grows.
 * An offset past the end reads as the empty string.
 */
const char *string_pool_read(const struct string_pool *pool,
                             uint32_t offset,
                             uint32_t *length_out);

/*
 * Whether an offset points at a well-formed string inside the pool. Used by the
 * validator, once, so that nothing else has to ask.
 */
int string_pool_offset_is_valid(const struct string_pool *pool, uint32_t offset);

#endif
