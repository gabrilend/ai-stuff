# 508 — Phase 5 demo

## Current behavior

Issues 501 through 507 produce a complete input pipeline:
60Hz polling, per-button events, stick directions, touch events,
chord detection, the radial-menu chord, and settings applied at
the right interposition point. Phase 5 needs a demo that
exercises each one and proves the system end-to-end.

## Intended behavior

A tiny test app, statically embedded in the kernel, draws a
small state panel on the bottom screen and updates it from the
input event stream:

- A counter per button, incremented on `button-down`.
- A pair of arrows showing the current `stick-direction` for
  each stick.
- A pixel painted at each `touch-down`, `touch-move`, and
  `touch-up` location, color-coded by which screen the touch
  landed on.
- A character drawn whenever a `radial-menu-chord` event fires,
  showing the chord's resolved character.
- A small banner reporting the current handedness and drawer-
  swap settings.

The CDC-ACM stream emits a JSON-lines event for each input event
the demo app receives — a parallel record the developer can
grep through.

The demo script at `issues/completed/demos/phase-5/run.sh`
builds and flashes the kernel, opens the CDC-ACM stream, and
prompts the developer to:

1. Press each button in turn and confirm the counter on the
   screen increments.
2. Tilt each stick through all eight directions and confirm the
   on-screen arrow tracks.
3. Touch both screens at known positions and confirm the
   painted pixels land at the expected pixel coordinates.
4. Strike a few radial-menu chords (D-pad + face button) and
   confirm the resolved characters appear.
5. Toggle handedness through the test harness and confirm the
   banner updates and the semantic-tag stream changes.

Each step is a one-line interactive question — the developer
hits Enter to advance after confirming. The script collects the
results and reports overall pass or fail.

## Suggested implementation steps

1. The test app's static-embedded map.
2. The state-panel rendering — a small composition over the
   bottom framebuffer.
3. The script's interactive prompts.
4. The pixel-coordinate assertion for the touch step.

## Related documents

- `docs/002-roadmap.md` — phase 5 demo description.
- `docs/004-input-model.md`.

## Blocked by

All of 501 through 507.

## Closes

Phase 5.
