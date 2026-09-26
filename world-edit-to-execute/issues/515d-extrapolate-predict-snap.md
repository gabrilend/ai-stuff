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

What it builds on (515c): the draw thread takes whole states from a mailbox.
Each unit's record already holds position, velocity, facing and animation
phase, and each state the time it was true. With the feeder paced by the
draw's take, a state is about one frame (17.8 ms at 60 a second) old when
drawn; this issue's extrapolation is what the owner chose to answer that
with. Its test should show the age hidden: drawn positions matching the
direct arithmetic at the moment of drawing, within a stated error.

## Intended Behavior

**Show what arrives; guess only while it's overdue** (the owner, 2026-09-25: "Show what the server sends. But, if the server is late, we can extrapolate up to the ping x 2"):
- A state is drawn as it arrives: the server's truth, one trip across the network behind.
- The guess runs from the newest state's **arrival**, not its stamp: every state is a network trip old when it lands, so only a missing next state counts as late. Between arrivals the draw carries each unit forward (position + velocity × time since arrival; the animation sampled at the current time), never between two past states.
- **The cap:** past it, a unit stays where the guess reached, **still playing its running animation in place**, so the player can see it's lag (the owner: "so the user knows that it's lag").
- **The cap is measured from the connection's jitter** (decided with the owner, 2026-09-25, over twice the ping): the usual spread of the gaps between arrivals, plus a margin, never below 3 ticks nor above about 15 (250 ms). The pause for a silent player is separate: each player's tolerance, the lowest in force (issue 803). The camera and cursor are computed on the draw thread at the last moment. The player's own orders get an immediate local answer (click marker, acknowledgement voice, the unit turning and starting its predicted path). A correction from the truth (the server, or offline the local simulation at its fixed tick) snaps in the frame it arrives: position, and the animation at the correct moment of the true animation. The owner: cancel the swing mid-air; always show the correct state as soon as possible. Tests: a predicted swing cancelled by a death that arrives late; a position correction applied in one frame; a stalled stream, with every unit reaching the cap and running in place, then snapping when states return.

## Decisions

- **The cap is jitter-based, not twice the ping** (2026-09-25). Twice the
  ping froze units on one delayed message on a fast connection (40 ms at
  20 ms ping) and guessed for 600 ms on a slow one. The owner: "your design
  was better than mine, let's do jitter based."

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
