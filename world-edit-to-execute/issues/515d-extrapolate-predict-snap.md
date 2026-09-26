# Issue 515d: Extrapolate Predict Snap

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** Medium
**Parent:** 515 (the render graph on the ceramic engine)
**Dependencies:** 515c
**Blocks:** 515f

---

## Current Behavior

Nothing of this exists. The design is decided in issue 515 (with the owner, 2026-09-25).

## Intended Behavior

The draw computes each unit's state now from its record (position + velocity × elapsed; the animation sampled at the current time), not between two past states. The camera and cursor are computed on the draw thread at the last moment. The player's own orders get an immediate local answer (click marker, acknowledgement voice, the unit turning and starting its predicted path). A correction from the truth (the server, or offline the local simulation at its fixed tick) snaps in the frame it arrives: position, and the animation at the correct moment of the true animation. The owner: cancel the swing mid-air; always show the correct state as soon as possible. Tests: a predicted swing cancelled by a death that arrives late; a position correction applied in one frame.

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
