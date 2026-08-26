# 023-blocks

One contiguous run of fixed-size records. Every array in the world is one of
these: bodies, walls, regions, vertices, lights.

A reference to a record is a `uint32_t` index, never a pointer — because growth
reallocates and moves the block, so a pointer held across an allocation is a bug
that only appears once a session gets busy. Indices also mean a snapshot is a
copy of some bytes rather than a graph walk, and that splitting work across
threads is arithmetic.

## The structure

| Field | Type | Meaning |
| --- | --- | --- |
| `data` | `uint8_t *` | The records, back to back. |
| `element_size` | `uint32_t` | Bytes per record. Forced to at least 4, so a freed record can hold a free-list link. |
| `count` | `uint32_t` | Records in use, **including the sentinel at index 0**. |
| `capacity` | `uint32_t` | Records allocated. |
| `first_free` | `uint32_t` | Head of a list threaded through the freed records themselves. `0` when there are none. |

## Index zero

`BLOCK_NOTHING` is 0, and index 0 of every block is a reserved zero-filled record
that is never handed out. Code reading it gets an empty record and carries on.

This is what makes "nothing in the world is ever nil" true rather than hoped for.
There is no null to check, so the question "did earlier code do its job" is asked
once by the validator instead of ten thousand times a tick by a loop. Reading an
index past the end also returns the sentinel, for the same reason.

## The functions

| Function | In | Out | Notes |
| --- | --- | --- | --- |
| `block_init` | block, element size, capacity | 1 / 0 | Claims index 0. Failure means memory ran out, which a caller must treat as fatal. |
| `block_release` | block | — | |
| `block_alloc` | block | index | Reuses a freed record before growing. The record is zeroed, so a caller never sees another record's remains. Returns `BLOCK_NOTHING` on failure. |
| `block_free` | block, index | — | Zeroes the record, then links it. Freeing index 0 or a bad index is ignored, not repaired. |
| `block_at` / `block_at_const` | block, index | pointer | **Valid only until the next allocation.** Never store what it returns. |
| `block_bytes_used` | block | `size_t` | What a snapshot copies and the file writer walks. |
| `block_copy` | destination, source | 1 / 0 | Exact. What the rollback ring does at the head of every turn. Refuses if the record sizes differ. |

## Two decisions

**Holes are reused, not compacted.** Compacting would move records, and every
index elsewhere in the world pointing at a moved record would have to be found
and rewritten — exactly the bookkeeping that indices were chosen to avoid.

**The free list is a stack**, so the most recently freed record comes back first.
The order does not matter to any caller, but it must be the *same* order every
run: an allocator handing out indices in a varying order would make every world
hash differ between runs and destroy the determinism argument.
