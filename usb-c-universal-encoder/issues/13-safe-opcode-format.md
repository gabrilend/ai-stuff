# 13 — Safe opcode format (constants + wire primitives)

The shared definition of the "bytecode" both ends speak: the opcode numbers and
the byte-level encode/decode primitives. This is code that matches the spec in
`docs/safe-opcode-format.md` exactly.

## Current behavior

Not yet implemented. The format is specified in `docs/safe-opcode-format.md` but
no module exposes the opcode constants or the primitive readers/writers.

## Intended behavior

- Export the opcode number table (`OP_NOP`, `OP_FILE_ALLOC`, `OP_FILE_WRITE`,
  `OP_FILE_TRUNCATE`, `OP_FILE_DELETE`, `OP_FILE_META`, `OP_END`) as named
  constants, so encoder and interpreter never hardcode magic bytes.
- A **writer**: accumulate bytes for `u8`/`u16`/`u32` (little-endian), `str`
  (`u16` length + bytes), `blob` (`u32` length + bytes), and yield the finished
  byte string.
- A **reader**: a cursor over a byte string with `u8`/`u16`/`u32`/`str`/`blob`
  readers, each bounds-checked against bytes remaining, raising on a truncated
  stream (never over-reading).
- No opcode here does anything but describe data — there is no execution primitive
  to export, by design.

## Suggested implementation steps

1. `src/02-opcodes.lua`: the opcode constant table + writer + reader.
2. Little-endian pack/unpack via `string.byte`/`string.char` (portable across
   LuaJIT builds; do not depend on `string.pack`, which is 5.3+ and disallowed).
3. Reader bounds-check helper shared by all typed reads.
4. Tests in `tests/02-opcodes-test.lua`: round-trip each primitive; a `str`/`blob`
   claiming more than remains raises; endianness is exactly little-endian.

## Related documents and tools

- Authoritative spec: `docs/safe-opcode-format.md`. Feeds issues 14 and 15.
- `src/02-opcodes.info.md`.
