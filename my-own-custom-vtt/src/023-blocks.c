/*
 * 023-blocks.c -- the contiguous run of records that every world array is.
 *
 * Interface and reasoning are in 023-blocks.h. What is here is the growth
 * policy, the free list threaded through the freed records, and the care around
 * index zero.
 */

#include "023-blocks.h"

#include <stdlib.h>
#include <string.h>

/*
 * Blocks double when they fill. Doubling means the total copying done over a
 * block's whole life is proportional to its final size rather than to the square
 * of it, so filling a block one record at a time is not quadratic.
 *
 * The number is here rather than inline because a session's peak record count is
 * something somebody will eventually want to preallocate from, and this is what
 * they will need to reason about.
 */
#define BLOCK_GROWTH_NUMERATOR   2
#define BLOCK_GROWTH_DENOMINATOR 1

/* The smallest record that can hold a free-list link. */
#define BLOCK_MINIMUM_ELEMENT 4

/* {{{ static uint8_t *record_address */
static uint8_t *record_address(const struct block *b, uint32_t index)
{
    return b->data + ((size_t)index * (size_t)b->element_size);
}
/* }}} */

/* {{{ int block_init */
int block_init(struct block *b, uint32_t element_size, uint32_t capacity)
{
    /*
     * A record has to be wide enough to hold the free-list link that gets
     * written into it once it is freed. Every real record in this project is far
     * wider than four bytes, so this is a guard against a mistake rather than a
     * constraint anybody will feel.
     */
    if (element_size < BLOCK_MINIMUM_ELEMENT) {
        element_size = BLOCK_MINIMUM_ELEMENT;
    }

    /* Room for the sentinel at index 0, whatever the caller asked for. */
    if (capacity < 1) {
        capacity = 1;
    }

    b->data = calloc((size_t)capacity, (size_t)element_size);
    if (b->data == NULL) {
        b->element_size = 0;
        b->count        = 0;
        b->capacity     = 0;
        b->first_free   = BLOCK_NOTHING;
        return 0;
    }

    b->element_size = element_size;
    b->capacity     = capacity;
    b->first_free   = BLOCK_NOTHING;

    /*
     * Index 0 is claimed immediately and never handed out. calloc has already
     * zeroed it, which is the whole of what the sentinel needs to be.
     */
    b->count = 1;

    return 1;
}
/* }}} */

/* {{{ void block_release */
void block_release(struct block *b)
{
    free(b->data);
    b->data         = NULL;
    b->element_size = 0;
    b->count        = 0;
    b->capacity     = 0;
    b->first_free   = BLOCK_NOTHING;
}
/* }}} */

/* {{{ static int block_grow */
static int block_grow(struct block *b)
{
    uint32_t wanted;
    uint8_t *moved;

    wanted = (b->capacity * BLOCK_GROWTH_NUMERATOR) / BLOCK_GROWTH_DENOMINATOR;

    /* A block of capacity 1 would otherwise double to 1 and never grow. */
    if (wanted <= b->capacity) {
        wanted = b->capacity + 1;
    }

    moved = realloc(b->data, (size_t)wanted * (size_t)b->element_size);
    if (moved == NULL) {
        return 0;
    }

    /*
     * realloc does not zero what it added. Records are handed out zeroed, so the
     * new tail is cleared here rather than at every allocation -- one memset per
     * growth instead of one per record.
     */
    memset(moved + ((size_t)b->capacity * (size_t)b->element_size),
           0,
           (size_t)(wanted - b->capacity) * (size_t)b->element_size);

    b->data     = moved;
    b->capacity = wanted;

    return 1;
}
/* }}} */

/* {{{ uint32_t block_alloc */
uint32_t block_alloc(struct block *b)
{
    uint32_t index;

    /*
     * A previously freed record is reused before the block grows. The free list
     * is threaded through the freed records themselves, so taking one off the
     * front is a read and a write.
     */
    if (b->first_free != BLOCK_NOTHING) {
        uint32_t next;

        index = b->first_free;
        memcpy(&next, record_address(b, index), sizeof(uint32_t));
        b->first_free = next;

        memset(record_address(b, index), 0, (size_t)b->element_size);
        return index;
    }

    /* Otherwise take the next record past the end, growing if there is none. */
    if (b->count >= b->capacity) {
        if (!block_grow(b)) {
            return BLOCK_NOTHING;
        }
    }

    index = b->count;
    b->count++;

    /* Already zero: either calloc did it, or block_grow cleared the new tail. */
    return index;
}
/* }}} */

/* {{{ void block_free */
void block_free(struct block *b, uint32_t index)
{
    /*
     * Freeing the sentinel, or something past the end, is a caller error. It is
     * ignored here rather than repaired: the validator is what establishes that
     * no such index exists anywhere in a world, and quietly doing something
     * plausible would hide the fact that one did.
     */
    if (index == BLOCK_NOTHING || index >= b->count) {
        return;
    }

    /*
     * Zero the record before linking it, so that a stale index pointing at a
     * freed record reads as empty rather than as whatever used to live there.
     * Then write the link into the first four bytes.
     */
    memset(record_address(b, index), 0, (size_t)b->element_size);
    memcpy(record_address(b, index), &b->first_free, sizeof(uint32_t));

    b->first_free = index;
}
/* }}} */

/* {{{ void *block_at */
void *block_at(struct block *b, uint32_t index)
{
    /*
     * Out of range returns the sentinel rather than a null pointer. Nothing in
     * this project checks a pointer for null, and handing back index 0 keeps
     * that true: a caller reading a bad index sees an empty record and carries
     * on, and the validator is what catches the bad index itself.
     */
    if (index >= b->count) {
        return b->data;
    }

    return record_address(b, index);
}
/* }}} */

/* {{{ const void *block_at_const */
const void *block_at_const(const struct block *b, uint32_t index)
{
    if (index >= b->count) {
        return b->data;
    }

    return record_address(b, index);
}
/* }}} */

/* {{{ size_t block_bytes_used */
size_t block_bytes_used(const struct block *b)
{
    return (size_t)b->count * (size_t)b->element_size;
}
/* }}} */

/* {{{ int block_copy */
int block_copy(struct block *destination, const struct block *source)
{
    /*
     * Used by the rollback ring, which copies the whole world at the head of
     * every turn. This is the fast path -- no encoding, no endianness, no walk
     * over fields -- and it stays that way precisely because it never leaves the
     * process. The file writer in 035 is the slow, careful, versioned path.
     */
    if (destination->element_size != source->element_size) {
        return 0;
    }

    if (destination->capacity < source->count) {
        uint8_t *moved = realloc(destination->data,
                                 (size_t)source->count * (size_t)source->element_size);
        if (moved == NULL) {
            return 0;
        }
        destination->data     = moved;
        destination->capacity = source->count;
    }

    memcpy(destination->data, source->data, block_bytes_used(source));
    destination->count      = source->count;
    destination->first_free = source->first_free;

    return 1;
}
/* }}} */
