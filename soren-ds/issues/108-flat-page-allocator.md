# 108 — Flat page allocator

## Current behavior

The kernel knows where the heap region starts and ends (107) but
has no way to ask "give me some memory" — every use of the heap
would have to be done by hand-crafted pointer arithmetic, which
is unsustainable past about the third caller.

## Intended behavior

A small allocator that hands out page-aligned chunks of the heap
region defined in 107. The shape:

- A single function takes a size and returns a pointer to an
  aligned region of that size, or signals failure when the heap
  is exhausted.
- A single function takes a pointer previously returned by the
  allocator and releases it.
- The allocator tracks which pages are in use through whatever
  bookkeeping is simplest — a free list, a bitmap, or a simple
  bump pointer for the earliest phase.

A boot-time self-test allocates a few pages, releases them,
allocates them again, and confirms the allocator's bookkeeping
holds. Failures are reported through 106 as fatal panics, not
silent corruptions.

The allocator's interface is the one phase 9 will reuse when the
MMU comes on. The interface stays the same; only the implementation
underneath grows to know which app is asking and which region it's
allowed to allocate from.

## Suggested implementation steps

1. Pick the simplest bookkeeping scheme that fits the heap size
   from 107. A bump pointer that never frees may be enough for
   phase 1; a real free list comes in phase 2 when threads start
   allocating and releasing rapidly.
2. Implement the allocator under `src/`.
3. Write the boot-time self-test.

## Related documents

- `docs/007-memory-model.md`.

## Blocked by

107.

## Blocks

109, 110, every later phase that allocates memory.
