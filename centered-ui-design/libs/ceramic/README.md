<!-- written by Claude (Opus 5.5), 2026-10-10, when the ceramic engine was
     copied into this project (issue 109). -->

# libs/ceramic — the ceramic engine, as this project carries it

`cera.c` and `cera.h` are soramech's C engine ("the ceramic engine") in the
kept copy that world-edit-to-execute improved for a renderer's frame:

- copied from `world-edit-to-execute/src/render/ceramic/engine/` at that
  project's commit `61bb775ed` (2026-09-25), unchanged;
- which started as minimal-soramech commit `059487d` (2026-09-12), with the
  changes listed in `fork-notes.md` (marked `FORK (issue 515g)` in the
  source): a task queue without a lock, batched hand-in
  (`cera_map_deliver_arguments`), waking only sleeping workers, and several
  task queues.

Why this copy and not minimal-soramech's own engine: the batched hand-in is
what makes per-frame work cheap (one batch of chunk tasks instead of one task
per unit), and minimal-soramech has not taken it in yet. When it does, this
copy should be replaced by soramech's own engine, and this file says so.

`serac` (soramech's compiler) is built from minimal-soramech's sources by
`scripts/build-ceramics`; it emits the construction code for
`src/021-ceramics.map`, which is then compiled against this copy.
