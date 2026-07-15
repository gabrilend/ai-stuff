# 11 — RAM arena

The foundational substrate: a real, contiguous block of memory we own and poke
directly, so that "everything is a file, stored in RAM" is literal and OS-free.

## Current behavior

Implemented and tested — this issue is complete (see `issues/completed/`). A
constructor returns an arena backed by a LuaJIT FFI `uint8_t[?]` allocation of a
fixed capacity. It exposes direct byte read/write at offsets, a first-fit region
allocator (allocate / free / resize), the arena's real base address for
inspection, and usage statistics. Every access is bounds-checked and raises on
violation rather than reading or writing out of bounds.

## Intended behavior

- Allocate a contiguous arena of N bytes at construction (memory assigned up front,
  then filled bit-by-bit — no growth surprises mid-transfer).
- Read and write raw bytes at a byte offset, bounds-checked against capacity.
- A region allocator: reserve a span of the arena, free it, resize it. First-fit
  over a free list; bump-allocate when the free list has no fit.
- Report the arena's real base address (via FFI pointer→integer) so a human or a
  test can confirm it is actual RAM, not a Lua table pretending to be memory.
- Report usage (capacity, bytes in use, free-list fragmentation) via a stats query,
  so documentation never hardcodes those numbers.
- Any out-of-bounds access, double free, or over-capacity allocation is an **error**,
  never a silent clamp or fallback.

## Suggested implementation steps

1. `src/00-ram-arena.lua`: constructor takes a capacity; `ffi.new("uint8_t[?]", cap)`
   holds the bytes. Keep the cdata alive on the arena object so it is not GC'd.
2. Direct access: `write_bytes(offset, str)` and `read_bytes(offset, len)` with a
   single shared bounds-check helper (offset ≥ 0 and offset+len ≤ capacity).
3. Region allocator: a free list of `{offset, size}` spans and a bump pointer.
   `allocate(size)` first-fits then bumps; `free(offset,size)` returns the span and
   coalesces adjacent free spans; `resize` is free+allocate when it cannot grow in
   place.
4. `base_address()` returns `tonumber(ffi.cast("uintptr_t", arena_cdata))`.
5. `stats()` returns capacity / used / free-span count.
6. Tests in `tests/00-ram-arena-test.lua`: round-trip bytes at offsets; bounds
   violations raise; allocate/free/reuse of spans; base address is nonzero.

## Related documents and tools

- `docs/architecture-overview.md` (layer [1]), `docs/safe-opcode-format.md`
  (the arena is what every opcode ultimately writes into).
- File info: `src/00-ram-arena.info.md`.
