/*
 * 025-strings.c -- the append-only pool of names.
 *
 * Interface and reasoning are in 025-strings.h. What is here is the layout: a
 * two-byte length followed by that many bytes, repeated, with the empty string
 * sitting at offset 0 from the moment the pool exists.
 */

#include "025-strings.h"

#include <stdlib.h>
#include <string.h>

/* Bytes of length prefix in front of each string's characters. */
#define STRING_PREFIX_BYTES 2

/* {{{ static void write_length */
static void write_length(uint8_t *at, uint32_t length)
{
    /*
     * Written a byte at a time, little end first, rather than by casting to a
     * uint16_t pointer. Casting would assume the pool happens to be aligned for
     * a two-byte read, which it is not obliged to be, and the same byte order is
     * what the world file uses -- so the pool's layout and the file's agree by
     * construction rather than by coincidence.
     */
    at[0] = (uint8_t)(length & 0xFFu);
    at[1] = (uint8_t)((length >> 8) & 0xFFu);
}
/* }}} */

/* {{{ static uint32_t read_length */
static uint32_t read_length(const uint8_t *at)
{
    return (uint32_t)at[0] | ((uint32_t)at[1] << 8);
}
/* }}} */

/* {{{ int string_pool_init */
int string_pool_init(struct string_pool *pool, uint32_t capacity)
{
    /* Room for the empty string at offset 0, whatever was asked for. */
    if (capacity < STRING_PREFIX_BYTES) {
        capacity = STRING_PREFIX_BYTES;
    }

    pool->data = calloc((size_t)capacity, 1);
    if (pool->data == NULL) {
        pool->used     = 0;
        pool->capacity = 0;
        return 0;
    }

    pool->capacity = capacity;

    /*
     * The empty string is written first, so that offset 0 is a real, readable,
     * zero-length string rather than a special case every reader has to know
     * about. calloc has already zeroed the length prefix, which is exactly what
     * a zero-length string looks like.
     */
    pool->used = STRING_PREFIX_BYTES;

    return 1;
}
/* }}} */

/* {{{ void string_pool_release */
void string_pool_release(struct string_pool *pool)
{
    free(pool->data);
    pool->data     = NULL;
    pool->used     = 0;
    pool->capacity = 0;
}
/* }}} */

/* {{{ uint32_t string_pool_add */
uint32_t string_pool_add(struct string_pool *pool, const char *text, uint32_t length)
{
    uint32_t offset;
    uint32_t needed;

    /*
     * Too long. Refused rather than cut short: a name silently truncated is a
     * name that looks right in one place and wrong in another, and nobody ever
     * finds out which. The caller is expected to report what would not fit.
     */
    if (length > STRING_MAX_LENGTH) {
        return STRING_NOTHING;
    }

    needed = STRING_PREFIX_BYTES + length;

    /*
     * Full. Also refused rather than grown, because growing would move the pool
     * and invalidate every pointer any reader is holding. The pool is sized from
     * the world at load; running out means the world claimed fewer names than it
     * has, which is a fact worth surfacing rather than absorbing.
     */
    if (pool->used + needed > pool->capacity) {
        return STRING_NOTHING;
    }

    offset = pool->used;

    write_length(pool->data + offset, length);
    if (length > 0) {
        memcpy(pool->data + offset + STRING_PREFIX_BYTES, text, (size_t)length);
    }

    pool->used += needed;

    return offset;
}
/* }}} */

/* {{{ const char *string_pool_read */
const char *string_pool_read(const struct string_pool *pool,
                             uint32_t offset,
                             uint32_t *length_out)
{
    uint32_t length;

    /*
     * An offset past the end reads as the empty string, in keeping with the rest
     * of the project: a bad reference reads as nothing and carries on, and the
     * validator is what catches the bad reference itself. Nothing here returns
     * null, because nothing anywhere checks for null.
     */
    if (offset + STRING_PREFIX_BYTES > pool->used) {
        *length_out = 0;
        return (const char *)pool->data + STRING_PREFIX_BYTES;
    }

    length = read_length(pool->data + offset);

    /* A length running past the end of the pool is likewise read as nothing. */
    if (offset + STRING_PREFIX_BYTES + length > pool->used) {
        *length_out = 0;
        return (const char *)pool->data + STRING_PREFIX_BYTES;
    }

    *length_out = length;
    return (const char *)pool->data + offset + STRING_PREFIX_BYTES;
}
/* }}} */

/* {{{ int string_pool_offset_is_valid */
int string_pool_offset_is_valid(const struct string_pool *pool, uint32_t offset)
{
    uint32_t length;

    if (offset + STRING_PREFIX_BYTES > pool->used) {
        return 0;
    }

    length = read_length(pool->data + offset);

    if (length > STRING_MAX_LENGTH) {
        return 0;
    }

    if (offset + STRING_PREFIX_BYTES + length > pool->used) {
        return 0;
    }

    return 1;
}
/* }}} */
