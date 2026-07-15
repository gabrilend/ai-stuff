# 14 — Opcode encoder (data generation)

Turn the contents of a file directory into an opcode byte stream. This is the
**data-generation** half, deliberately separate from the interpreter so a bug is
trapped on the sending side.

## Current behavior

Not yet implemented. Depends on the file directory (issue 12) and the opcode
primitives (issue 13).

## Intended behavior

- Encode a single named file to opcodes: `OP_FILE_ALLOC name,size`, then
  `OP_FILE_WRITE name,0,contents`, then an `OP_FILE_META` per metadata field.
- Encode an entire directory: every file in deterministic order, ending `OP_END`.
- Output is a plain byte string — no framing (that is Phase 2), no transport.
- The encoder only *reads* the directory; it never mutates the store or touches a
  link. Pure generation.

## Suggested implementation steps

1. `src/03-opcode-encoder.lua`: `encode_file(dir, name) -> bytes` and
   `encode_directory(dir) -> bytes`, both built on the issue-13 writer.
2. Read file bytes out of the arena via the directory's read API; emit as a `blob`.
3. Tests in `tests/03-opcode-encoder-test.lua`: encode a known file, assert the
   exact byte sequence against the spec; encode an empty directory (just `OP_END`).

## Related documents and tools

- `docs/datapath-file-transfer.md` (encoder node), `docs/safe-opcode-format.md`.
- Pairs with issue 15 (interpreter); the loopback demo (issue 16) chains them.
- `src/03-opcode-encoder.info.md`.
