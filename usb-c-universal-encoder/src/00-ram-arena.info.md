# 00-ram-arena — info

Purpose: hand out one real, contiguous block of RAM and manage spans within it.
The block is an actual FFI byte buffer, poked directly at offsets. Every access is
bounds-checked; nothing here can execute code or touch memory outside the block.

Treat the arena as a black box: "some bytes we own, plus a way to reserve, poke,
and reclaim spans of them." The layers above (the file directory) never see the raw
pointer — only offsets and the reported base address.

## External function

### `new_arena(capacity) -> arena`
- Input: `capacity` — positive integer, number of bytes to allocate up front.
- Output: an `arena` table whose methods are below. Raises if capacity is not a
  positive integer.

## Arena methods

### `arena.write_bytes(offset, data) -> written`
- Copies the Lua string `data` into the arena starting at `offset`.
- Output: number of bytes written (`#data`). Raises if the range falls outside the
  arena or `data` is not a string.

### `arena.read_bytes(offset, length) -> string`
- Reads `length` bytes at `offset` back out as a Lua string. Raises on out-of-range.

### `arena.allocate(size) -> offset`
- Reserves a span of `size` bytes (first-fit over freed spans, else grows the
  high-water mark). Output: the span's starting offset. Raises if the arena is full.

### `arena.free(offset, size)`
- Returns a previously allocated span to the pool and coalesces adjacent free spans.
  Bytes are not wiped. Raises on out-of-range.

### `arena.resize(offset, old_size, new_size) -> offset`
- Shrinks in place (same offset) or grows by relocating (new offset, bytes copied).
  Output: the span's offset after resizing (may differ when grown).

### `arena.base_address() -> integer`
- The real memory address of byte 0, as an integer, for inspection/proof-of-RAM.

### `arena.capacity() -> integer`
- The total size of the arena in bytes.

### `arena.stats() -> table`
- Snapshot: `{ capacity, used, free, high_water, free_span_count }`. Use this rather
  than hardcoding usage numbers anywhere.

## Related
- Issue: `issues/completed/11-ram-arena.md`
- Docs: `docs/architecture-overview.md` (layer [1]), `docs/safe-opcode-format.md`
- Tests: `tests/00-ram-arena-test.lua`
