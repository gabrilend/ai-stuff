# 15 — Opcode interpreter (data consumption)

Apply an opcode byte stream to a file directory, via a dispatch table. This is the
**only** code that runs against received bytes, and its whole vocabulary is "mutate
the arena." It is where the safety promise is enforced.

## Current behavior

Not yet implemented. Depends on the directory (issue 12) and opcode primitives
(issue 13).

## Intended behavior

- Read opcodes one at a time using the issue-13 reader; dispatch each opcode byte
  through a **table** (opcode → handler), never an if/else chain.
- Handlers: alloc, write (bounds-checked into the region), truncate, delete, meta.
  Each handler only calls directory/arena methods — nothing else is reachable.
- Unknown opcode byte → error. Truncated operand → error. Write past a region's
  bounds → error. No fallback silently skips or clamps.
- Validate names (reject traversal) before applying.
- After consuming the stream, the target directory reflects exactly the sender's
  files. The interpreter returns nothing executable — it only mutated a store.

## Suggested implementation steps

1. `src/04-opcode-interpreter.lua`: `apply(dir, bytes)` builds a reader and loops
   until the bytes are exhausted or `OP_END`.
2. Dispatch table maps each opcode constant to a handler `function(dir, reader)`.
3. Reuse the directory's mutation API so bounds/validation live in one place.
4. Tests in `tests/04-opcode-interpreter-test.lua`: apply a hand-built stream and
   assert the resulting files; an unknown opcode raises; a `blob` claiming past the
   buffer raises; a write past region bounds raises.

## Related documents and tools

- `docs/safe-opcode-format.md` (validation rules), `docs/architecture-overview.md`.
- Pairs with issue 14; the loopback demo (issue 16) chains encode→apply.
- `src/04-opcode-interpreter.info.md`.
