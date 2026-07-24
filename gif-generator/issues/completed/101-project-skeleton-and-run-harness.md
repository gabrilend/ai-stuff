# 101 — project skeleton and run harness

## Current Behavior

Complete. The directory skeleton stands (docs, notes, src, libs,
assets, issues, input, output, strategems); `bootstrap` recreates the
RAM tiers idempotently and refuses to run without LuaJIT (probed, not
assumed); `run` opens onto the newest runnable thing — the demo picker
until the phase-4 runner moves in, the runner afterwards; the hidden
`.file-index-counter` sits at the project root holding the next unused
index; runtime `output/` artifacts are kept out of the record by the
project's ignore file (demos keep their own gifs — those are
deliverables). The index-taking ritual is documented at the top of the
first indexed source file, per this blueprint.

## Intended Behavior

A contributor (human or otherwise) can clone the repository, run one
bootstrap script, and be standing in a working project:

- `tmp/` resolves to `/tmp/gif-generator` (executable scratch tier) and
  `tmp/shared-memory/` resolves to `/dev/shm/gif-generator` (logs and
  artifacts tier). The bootstrap recreates both if the machine rebooted
  and emptied them — every run script checks this before writing logs.
- The hidden `.file-index-counter` at the project root holds the next
  unused source-file index (single number, starts at 0). Creating a
  source file means: read the counter, prefix the filename with the
  three-digit index, increment the counter. The indices give the whole
  project one reading order.
- A `run` script at the project root executes a scene render (phase 4
  will give it its true form; until then it runs the newest demo). Like
  all scripts here: a hard-coded project path at the top in a `DIR`
  variable, overridable by first argument, all internal paths relative
  to it.
- LuaJIT is the runtime everywhere; a version probe in the bootstrap
  fails loudly if `luajit` is absent rather than falling back to any
  other lua.

## Suggested Implementation Steps

1. Write the bootstrap script (recreate tmp tiers, probe luajit,
   report what it found).
2. Write the root `run` script shell with the DIR convention and a
   dispatch that phase capstones will extend.
3. Document the index-taking ritual in a comment at the top of the
   counter file's first consumer.

## Related Documents

- docs/architecture.md (design decisions this skeleton serves)
- docs/table-of-contents.md (conventions section)
