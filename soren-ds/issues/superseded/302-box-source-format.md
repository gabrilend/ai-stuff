# 302 — Box source format

## Current behavior

The map representation (301) holds in-memory state. The runtime
needs to know what shape source files have so it can load them.
Soramech proper has a JSON format documented in
`/home/ritz/programs/sora/soramech/docs/002-map-model.md`; we
adopt it nearly verbatim and pin the small Soren-DS-specific
differences.

## Intended behavior

A map source directory contains:

- `meta.json` — name, description, entry box id list, the
  src_dirs list (for compile-pipeline boxes that live in
  user-authored C).
- `boxes/*.json` — one file per box, each carrying the box's
  `id`, `kind` (`call` / `read` / `write` / `map`), `lang` (for
  Soren DS always `"c"`), `ref` (the box descriptor's name in
  the kernel's library, or the source-file path for
  on-device-compiled boxes), `inputs` array, `routing` config,
  and `connections` array for outgoing wires.

A `connections` entry on a producer box names: `from_box`,
optional `from_branch` (depends on routing kind),
`to_box`, `to_input`.

The differences from soramech proper:

- `lang` is always `"c"` — no Lua, no Bash. The loader refuses
  any other value.
- `routing` is restricted to the seven kinds 307 implements;
  unknown kinds are a load-time hard error.
- The encapsulation splicer (305) handles `kind: "map"`; the
  format matches soramech proper's `external` block convention.
- The compile pipeline that turns user-authored `src/*.c` into
  loadable function pointers lives in phase 4. Until that ships,
  every `call` box's `ref` must name a kernel-compiled-in box
  (one of the descriptors in 208's table or 309's utility
  additions).

This issue does not write a JSON parser — it documents the format
the parser in 303 will accept. The parser itself is its own
issue.

## Suggested implementation steps

1. A reference JSON file under `notes/soramech-format/000-map-
   source-shape.json` that exercises every field combination.
2. The format documentation lives in
   `docs/012-soramech-runtime.md` — confirm the doc and the
   reference example agree.
3. A small test map for phase 3's demo (`311`) authored in this
   format and statically embedded in the kernel.

## Related documents

- `docs/012-soramech-runtime.md`.
- `/home/ritz/programs/sora/soramech/docs/002-map-model.md` (the
  parent project's format doc).

## Blocked by

(nothing — this is a specification issue).

## Blocks

303 (the loader implements this format), 311 (the demo's map
file follows this format).
