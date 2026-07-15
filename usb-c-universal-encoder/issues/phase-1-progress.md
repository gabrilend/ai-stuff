# Phase 1 progress — The RAM data core

Phase 1 builds the transport-agnostic heart of the system: a real block of RAM we
own, a file API over it, the safe opcode format, and the encode/apply pair that
moves files as data operations — provable end to end with no USB hardware.

Do not trust the counts below as a substitute for running the tests; the authority
on "does it work" is `tests/` (run every `*-test.lua`), not this prose.

## Completed

- **11 — RAM arena** (`issues/completed/11-ram-arena.md`). The foundational
  substrate: a genuine contiguous byte buffer (LuaJIT FFI) we poke directly at
  offsets, with a first-fit region allocator, bounds-checked access, resize, and a
  reported real base address. This is what makes "modify the actual RAM locations
  itself" literal and OS-independent — the promise the vision leans on for
  universality. Verified by `tests/00-ram-arena-test.lua` (all checks passing).

## Not yet started

- **12 — File directory over the arena.** Names → regions + per-file metadata
  (incl. `direction`); the friendly "everything is a file" API over raw memory.
- **13 — Safe opcode format.** Opcode constants + little-endian wire primitives,
  matching `docs/safe-opcode-format.md`.
- **14 — Opcode encoder.** Directory → opcode byte stream (data generation).
- **15 — Opcode interpreter.** Opcode byte stream → directory via a dispatch table
  (data consumption); where the "no execution" safety property is enforced.
- **16 — Loopback round-trip demo (capstone).** A file crosses an opcode stream and
  reappears byte-identical in a second, independent arena — nothing executed.

## How this phase closes

When 16 passes, Phase 1's demo moves to `issues/completed/demos/` and a
`run-phase.sh` chooser at the project root is wired to it. Only then is the wire
(Phases 3–4) "just plumbing" over a proven core.
