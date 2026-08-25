# 103 — The World Is Flat Arrays

| | |
| --- | --- |
| Phase | 1 — The Ground and the Clock |
| Blocked by | 101 |
| Blocks | 104, 107, 201, 209, 301 |
| Reads | [the simulation tick](../docs/003-the-simulation-tick.md), [the shape of the code](../docs/018-the-shape-of-the-code.md) |
| Open questions | none |

## Current behavior

There is nowhere to put a soldier.

## Intended behavior

The world is **one table of flat arrays**, not an array of tables. Every
soldier's health lives in one contiguous array of doubles; every soldier's lane
in one contiguous array of integers. A soldier is an index, not an object.

Two reasons, and the second is the one that decides it:

1. The move pass touches four fields out of thirty. In an array of tables it
   drags the other twenty-six through cache with them. In flat arrays it touches
   four arrays and nothing else.
2. **Slicing a flat array across a thread pool is a pair of integer bounds.**
   Slicing an array of tables is a pointer chase. Since the entire simulation is
   the same arithmetic repeated over thousands of bodies, and since nothing is
   ever to be processed one-at-a-time on a single thread when the items are
   independent, the storage has to be the shape the pool wants before the pool
   can exist.

**Memory is allocated up front**, at world creation, to a fixed capacity. There
is no growing mid-tick. Ids are handed out from a free list and recycled, and
each slot carries a **generation counter** bumped on reuse — so a stale id can be
detected as stale instead of silently addressing a stranger who moved in.

Nothing in the world is ever nil. Empty means the integer zero, which is a
sentinel with a meaning. A nil check is a question about whether some earlier
code did its job, and that question belongs in a validator at load time.

## Suggested implementation steps

1. Write the store as a constructor taking a capacity and returning a table of
   preallocated arrays, one per field, plus a free list and a generation array.
2. Write `spawn()` — take an id off the free list, bump its generation, zero
   every field — and `kill()` — clear `alive`, return the id to the free list.
3. Write `is_valid(id, generation)`, the only sanctioned way to dereference a
   stored id. Every field holding another entity's id stores the generation
   beside it.
4. Do the same for the structure store, which is small and fixed-size and needs
   no free list.
5. Decide FFI struct arrays against plain Lua tables. Measure both with a
   throwaway benchmark that walks a hundred thousand entries; keep the benchmark
   marked deprecated for one commit if it has no further use, so it shows up in
   the record once.
6. Write a test that spawns to capacity, kills half at random from a seeded
   stream, respawns, and asserts that no recycled id ever validates against an
   old generation.

## Related documents and tools

- [The simulation tick](../docs/003-the-simulation-tick.md) — the world record
- [The shape of the code](../docs/018-the-shape-of-the-code.md)

## Still open

How many bodies does the capacity need to be? A continuous surge stream feeding
three lanes from both bases could be a few hundred or a few thousand depending on
how fast the stream runs, and that number is not chosen yet. Until it is, pick a
capacity an order of magnitude above the guess and make the allocation failure
loud rather than silently growing.
