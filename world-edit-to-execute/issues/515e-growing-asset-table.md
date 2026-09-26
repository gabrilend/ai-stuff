# Issue 515e: Growing Asset Table

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** Medium
**Parent:** 515 (the render graph on the ceramic engine)
**Dependencies:** 515b
**Blocks:** 515f

---

## Current Behavior

Nothing of this exists. The design is decided in issue 515 (with the owner, 2026-09-25).

## Intended Behavior

Meshes, textures, bind poses and animation tracks in an append-only table that grows while the graph runs: fixed-size blocks, never reallocated, so an entry never moves; an entry is published by one atomic increase of the count after it is complete; only the host writes (it is the one thread allowed to upload to the GPU). Stations carry an asset id (a small number), checkable against the published count. A decode station turns a model's bytes into plain arrays on any worker; the host uploads and appends between frames, then delivers the new id. Until then the unit draws as a placeholder. Tests: readers never see an unpublished entry while the table grows under them.

## Suggested Implementation Steps

1. Read issue 515's design section and the measurements from 515a before starting.
2. Build it in `src/render/ceramic/`, sharing nothing mutable with the current renderer.
3. Write the tests named above first; each fixed bug gets its own.
4. Record what it taught about the ceramic engine in 515, for soramech.

## Acceptance Criteria

- [ ] The behavior above, with its tests passing
- [ ] `.info.md` beside each new source file

## Related Documents

- `issues/515-render-graph-on-the-ceramic-engine.md`
