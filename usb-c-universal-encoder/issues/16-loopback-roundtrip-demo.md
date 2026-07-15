# 16 — Loopback round-trip demo (Phase 1 capstone)

Prove the data core end to end with no USB hardware: a file made in store A crosses
an opcode stream and reappears byte-identical in store B — and nothing ran.

## Current behavior

Not yet implemented. Depends on issues 11–15.

## Intended behavior

- Build directory A over an arena, create one or more files (varied bytes,
  including binary and a `direction` metadata field).
- Encode A to an opcode byte stream (issue 14).
- Apply that stream to a fresh directory B over its own arena (issue 15).
- Assert B's files, bytes, and metadata equal A's exactly.
- Print a human-readable before/after using a **separate viewer** module (data
  viewing kept apart from data generation), including each arena's real base
  address to show these are two distinct RAM regions.
- Also feed a deliberately corrupt/hostile stream and show the interpreter raises
  rather than misbehaving — demonstrating the safety property.

## Suggested implementation steps

1. `demos/phase-1-loopback.lua`: wire arena→directory→encoder→interpreter→directory.
2. `src/05-store-viewer.lua`: render a directory to text (the only "viewing" code).
3. A run script `run-phase.sh` at the project root that asks for a phase number
   (1..completed) and runs the matching demo, per the phase-demo protocol; wire
   phase 1 to this demo.
4. When Phase 1 completes, this demo also becomes the deliverable in
   `issues/completed/demos/`.

## Related documents and tools

- Exercises every Phase 1 doc; `docs/datapath-file-transfer.md` is the map it walks.
- `src/05-store-viewer.info.md`.
