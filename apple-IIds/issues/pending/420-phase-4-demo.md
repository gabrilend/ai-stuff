---
name: phase 4 demo
phase: 4
status: pending
blockedBy: [401, 402, 403, 404, 405, 406, 407, 408, 409, 410]
---

# 420 — phase 4 demo

The deliverable that closes phase 4. Demonstrates the complete radial
dual-stick keyboard with overlay, one-handed mode, modifiers,
training mode, and tactile feedback.

## current behavior

No phase 4 demo exists.

## intended behavior

- A script `issues/completed/demos/phase-4/run.sh` extends the
  phase 3 demo with full radial-keyboard functionality.
- The phase 4 demo:
  - Boots both instances (as phase 2).
  - Demonstrates the shared volume, clipboard, and IPC (as phase 3).
  - Demonstrates two-handed radial typing: open Teach on screen A,
    type "hello world" using the left stick + right stick.
  - Demonstrates the inactive-screen overlay: as the user types on
    screen A, the overlay appears on screen B (and vice versa
    after a focus switch).
  - Demonstrates one-handed mode: hold the device in one hand, use
    the stylus to tap cells on the overlay; type a sentence this
    way.
  - Demonstrates modifiers: type a capital letter, type a numeric
    digit from the L3 layer, type a Cmd+S shortcut (save the
    document in Teach).
  - Demonstrates training mode: toggle it on, see the overlay stay
    visible while not typing.
  - Demonstrates tactile feedback: the user can feel each commit.
  - Switches focus mid-document: types on A, presses bottom-left
    Start, types on B. Each instance receives the right characters
    in the right windows.
- The bottom-panel status strip grows to show: current layer (base
  / L3 / R3), modifier state, recent characters emitted, and a
  small WPM (words-per-minute) counter for fun.
- A short README explains the demo and references the phase-4
  issues.

## suggested implementation steps

1. Confirm phase 4 issues 401–410 are completed and moved to
   `issues/completed/`.
2. Extend `run-demo.sh` to accept `4`.
3. Extend the statistics overlay to show radial-keyboard state.
4. Pre-load Teach and a sample document for the demo's typing
   exercises.
5. Capture a screen recording showing all the typing modes.
6. Update `issues/phase-4-progress.md`.

## related documents

- All of phase 4 (401–410)
- `issues/320-phase-3-demo.md` — the prior demo
- `docs/004-roadmap.md` — phase 4 entry

## notes

- This is the demo where the device becomes properly *usable*. From
  this point on, you can use it to write things, not just demo
  things. Worth investing in a good recording — show the typing,
  show the hand positions, show the overlay shifting between
  screens.
- The WPM counter is for fun, not benchmarking. Real WPM on a
  radial keyboard is going to be low at first — measuring it just
  helps the user feel their improvement over time.
