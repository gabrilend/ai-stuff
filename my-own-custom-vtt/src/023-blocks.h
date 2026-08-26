/*
 * 023-blocks.h -- one contiguous run of fixed-size records.
 *
 * Every category of thing in the world is stored in one of these: bodies, walls,
 * regions, lights, scopes, viewers. A reference to a record is a `uint32_t`
 * index into its block, never a pointer.
 *
 * Three reasons, in ascending order of how much they matter:
 *
 *   Walking a block is a walk through contiguous memory, so the prefetcher is
 *   right about what comes next and the loop body stays the kind of thing that
 *   could later be hand-written in assembly without restructuring anything.
 *
 *   Splitting work across threads is arithmetic -- records 0 to 4999 are yours,
 *   5000 to 9999 are mine. No traversal, no locks, no question about ownership.
 *
 *   Saving is a write. A snapshot is the blocks, copied. Nothing needs a
 *   serialiser that knows the shape of every record type, because there are no
 *   pointers to translate.
 *
 * That last one is why an index rather than a pointer: growth reallocates and
 * moves the block, so a pointer held across an allocation is a bug that only
 * appears once a session gets busy.
 *
 * See docs/004-the-world-and-its-tick.md and issues/102-the-world-is-flat-arrays.md.
 */

#ifndef VTT_BLOCKS_H
#define VTT_BLOCKS_H

#include <stdint.h>
#include <stddef.h>

/*
 * Index 0 of every block is a reserved empty record, zero-filled, never handed
 * out. Code that reads index 0 gets the empty record and carries on.
 *
 * This is what makes "nothing in the world is ever nil" true rather than hoped
 * for. There is no null to check because zero already has a meaning, so the
 * question "did some earlier code do its job" gets asked once by the validator
 * instead of ten thousand times a tick by a loop.
 */
#define BLOCK_NOTHING 0u

struct block {
    uint8_t  *data;

    uint32_t  element_size;   /* Bytes per record. At least 4; see the free list. */
    uint32_t  count;          /* Records in use, including the index-0 sentinel. */
    uint32_t  capacity;       /* Records allocated. */

    /*
     * Head of a list of freed records, threaded through the freed records
     * themselves -- the first four bytes of a free record hold the index of the
     * next one. Costs no extra memory and needs no second array.
     *
     * Holes are reused rather than compacted. Compacting would move records,
     * and every index anywhere else in the world pointing at a moved record
     * would have to be found and rewritten, which is exactly the bookkeeping
     * that indices-instead-of-pointers was chosen to avoid.
     */
    uint32_t  first_free;
};

/*
 * Prepare a block. Allocates `capacity` records, zeroes them, and claims index 0
 * as the sentinel. Returns 0 on failure to allocate, 1 on success.
 */
int block_init(struct block *b, uint32_t element_size, uint32_t capacity);

/* Release a block's memory. The block is unusable afterwards until re-inited. */
void block_release(struct block *b);

/*
 * Claim a record and return its index. The record is zeroed before it is handed
 * back, so a caller never sees another record's remains.
 * Returns BLOCK_NOTHING if memory could not be found, which a caller must treat
 * as fatal rather than continuing with a world it could not build.
 */
uint32_t block_alloc(struct block *b);

/*
 * Return a record to the free list. Freeing index 0 or an index past the end is
 * a caller error and does nothing -- the validator is what establishes that no
 * such index exists.
 */
void block_free(struct block *b, uint32_t index);

/*
 * The address of a record. Valid only until the next allocation, because growth
 * moves the block. Never store what this returns.
 */
void *block_at(struct block *b, uint32_t index);

/* The same, for a block that must not be modified. */
const void *block_at_const(const struct block *b, uint32_t index);

/*
 * How many bytes of the block are actually in use. What a snapshot copies and
 * what the file writer walks.
 */
size_t block_bytes_used(const struct block *b);

/*
 * Copy one block over another, growing the destination if it must. Used by the
 * rollback ring, which snapshots the whole world at the head of every turn.
 * Returns 1 on success, 0 if memory could not be found.
 */
int block_copy(struct block *destination, const struct block *source);

#endif
