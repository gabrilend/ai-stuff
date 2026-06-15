# 108 — Flat page allocator

## Current behavior

`src/008-allocator.c` implements a 4 KB-page allocator backed by
a one-bit-per-page bitmap. `allocator_init` reads the memory
pool bounds from 107, carves the bitmap out of the bottom of the
pool (about 96 KB on this 3 GB device, around 24 pages of the
roughly 786,000 the pool contains), zeroes it, and exposes the
remainder as the managed pool.

`alloc_page` returns a page-aligned physical address or zero if
the pool is exhausted. The implementation walks the bitmap byte
by byte, finds the lowest free bit, marks it used, and returns
the matching page address. O(n) in the pool size; sub-millisecond
on the worst case for this hardware, and the kernel does not
call it on any hot path that phase 1 has identified.

`free_page` returns a page to the pool by clearing its bit. O(1).

A boot-time self-test allocates two pages, verifies they are
distinct and page-aligned, frees one, verifies the next
allocation reuses that freed page, then frees everything it
took. `kernel_main` calls `allocator_check_or_panic` after
`allocator_init`; on failure the panic LED lights and the core
parks, so a silent bitmap-math bug surfaces as a red LED rather
than as silent memory corruption later.

What is deliberately deferred: multi-page contiguous allocation
(the framebuffer in 111a will be the first caller that wants
it, and that issue extends the API), atomic concurrency control
(phase 2's threading core adds it), and any per-app
accounting (phase 9's MMU work adds it).

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
