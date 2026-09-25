# Issue 515c: Mailbox Triple Buffer

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** Medium
**Parent:** 515 (the render graph on the ceramic engine)
**Dependencies:** 515b

---

## Current Behavior

Nothing of this exists. The design is decided in issue 515 (with the owner, 2026-09-25).

## Intended Behavior

The visual state as three buffers of per-unit records (position, velocity, facing, animation, and the time they were true): one being drawn, one holding the latest complete state, one being written. Finishing a write swaps it with the latest-complete buffer in one atomic exchange; starting a draw swaps the drawn buffer with it the same way. Neither side waits, a half-written state is never drawn, and a newer state replaces an older waiting one rather than queueing behind it (no added frames of delay). Tests: many writer and reader threads hammering the swaps, checking every drawn buffer is whole.

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
