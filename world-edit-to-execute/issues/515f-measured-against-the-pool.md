# Issue 515f: Measured Against The Pool

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** Medium
**Parent:** 515 (the render graph on the ceramic engine)
**Dependencies:** 515c, 515d, 515e

---

## Current Behavior

Nothing of this exists. The design is decided in issue 515 (with the owner, 2026-09-25).

## Intended Behavior

The same scene (a real map's terrain and a few hundred animated placeholder units) drawn by the ceramic path and by the existing renderer on the 512 pool, on the same machine: time per frame, time on the draw thread, how busy each core is. The verdict on the experiment goes into 515 with its numbers, and what it taught goes to soramech with its owner.

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
