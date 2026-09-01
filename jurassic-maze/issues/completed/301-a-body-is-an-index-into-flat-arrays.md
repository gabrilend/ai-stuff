# 301 — A Body Is An Index Into Flat Arrays

| | |
| --- | --- |
| Phase | 3 — The Rolling |
| Blocked by | 101 |
| Blocks | 302, 303, 307, 308, 401, 405, 501, 601, 702 |
| Reads | [a body and what it carries](../docs/011-a-body-and-what-it-carries.md) |
| Open questions | 4 (how many bodies) |

## Current behavior

One table of flat arrays, thirty of them, built from a single field list so that
adding a field is adding a row and no constructor can forget to zero one. A free
list, generation counters, and per-locomotion rosters maintained by swap-remove.

Capacity is 2000 and running out raises. The test spawns a store to capacity,
kills half, respawns, and asserts no recycled id validates against an old
generation.

## Intended behavior

**One table of flat arrays**, not an array of tables. Every body's x lives in one
contiguous array of doubles; every body's locomotion in one contiguous array of
small integers. Body twelve is the twelfth entry of each. The full field list is
in [the document](../docs/011-a-body-and-what-it-carries.md).

Two reasons, and the second decides it:

1. The move pass touches six fields out of twenty-two. An array of tables drags
   the other sixteen through cache alongside them.
2. **Slicing a flat array across a thread pool is a pair of integer bounds.**
   Slicing an array of tables is a pointer chase. The storage has to be the shape
   the pool wants before the pool can exist.

Allocated once, at a fixed capacity, never grown. Running out is an error with a
message. A store that quietly grows quietly stops fitting in cache and the frame
rate falls off a cliff for no visible reason.

Ids come off a **free list** and are recycled. Every slot carries a
**generation** bumped on reuse. Any stored id is followed only after checking the
generation, which is one comparison, and it is what stops a fencer duelling the
stranger who moved into its dead opponent's slot.

**Nothing is ever nil.** Empty is the integer zero and body zero does not exist,
so `partner == 0` reads as "nobody" unambiguously. A nil check is a question
about whether earlier code did its job, and that question belongs in a validator
at load time rather than in the inner loop.

## Suggested implementation steps

1. Write the constructor: a capacity in, a table of preallocated arrays out, plus
   the free list and the generation array.
2. Write `spawn()` — take an id, bump the generation, **zero every field** — and
   `kill()` — clear `alive`, return the id. A slot that kept its old partner or
   its old velocity hands them to whoever moves in next.
3. Write `is_valid(store, id, generation)`, the only sanctioned way to
   dereference a stored id.
4. Write the roster machinery for
   [the locomotion table](../docs/012-locomotion-is-a-dispatch-table.md): one
   contiguous array of ids per locomotion row, with swap-remove and append, both
   constant time.
5. Test: spawn to capacity, kill half at random from a seeded stream, respawn,
   and assert no recycled id ever validates against an old generation. Assert
   every roster contains exactly the live bodies of its row and nothing else.

## Related documents and tools

- [A body and what it carries](../docs/011-a-body-and-what-it-carries.md)
- [Locomotion is a dispatch table](../docs/012-locomotion-is-a-dispatch-table.md)

## Still open

Open question 4: the capacity is not chosen. Until it is, pick an order of
magnitude above the guess and make the allocation failure loud rather than
growing silently.
