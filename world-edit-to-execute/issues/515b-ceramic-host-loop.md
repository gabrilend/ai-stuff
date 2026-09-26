# Issue 515b: Ceramic Host Loop

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** Medium
**Parent:** 515 (the render graph on the ceramic engine)
**Dependencies:** 515a, 515g (the engine copy it builds on)
**Blocks:** 515c, 515e

---

## Current Behavior

Nothing of this exists. The design is decided in issue 515 (with the owner, 2026-09-25).

## Intended Behavior

A kept copy of the engine (cera.c, cera.h, with the soramech commit they came from) and a raylib program whose main thread is the host: each frame it delivers the frame's inputs (frame number, clock, orders) into the map's marked argument ports, collects results from its marked output ports, and draws. Drawing is never a station, because OpenGL calls must come from the thread that owns the window. The first map poses placeholder cubes. Built by emitting the map's C with serac and compiling it with raylib's flags.

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
