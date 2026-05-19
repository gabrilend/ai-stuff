---
name: phase 7 demo
phase: 7
status: pending
blockedBy: [701, 702, 703, 704]
---

# 720 — phase 7 demo

The deliverable that closes phase 7. Demonstrates that the broker is
a first-class GS/OS device — and that the two Finders cooperate.

## current behavior

No phase 7 demo exists.

## intended behavior

- A script `issues/completed/demos/phase-7/run.sh` extends the
  phase 5 demo (or phase 6's, if it lands first chronologically).
- The phase 7 demo:
  - Boots both instances (as phase 5 / 6).
  - Demonstrates the broker peripheral infrastructure: a tiny IIds
    program calls into `broker.echo` and shows the result. The
    same program can list all registered broker devices.
  - Demonstrates the Broker Input device (issue 702): characters
    flow into GS/OS without going through emulated ADB. Side-by-
    side timing comparison with the ADB-injection path.
  - Demonstrates the Broker Filesystem device (issue 703): the
    shared volume is now a first-class device. Cataloging it
    feels instant.
  - Demonstrates Finder dual-desktop awareness: open the "Other
    Screen" menu, see the other screen's open windows. Drag a
    file from screen A's desktop into the Other Screen view, see
    it appear on screen B's desktop.
- The status strip shows: number of registered broker devices,
  per-device call rate, Other-Screen visibility status.

## suggested implementation steps

1. Confirm phase 7 issues 701–704 are completed and moved to
   `issues/completed/`.
2. Write the tiny IIds programs needed for the demonstrations
   (broker.echo caller, device lister).
3. Pre-stage a file on screen A's desktop to be dragged across.
4. Extend `run-demo.sh` to accept `7`.
5. Capture a screen recording.
6. Update `issues/phase-7-progress.md`.

## related documents

- All of phase 7 (701, 702, 703, 704)
- `issues/520-phase-5-demo.md` or `issues/620-phase-6-demo.md` —
  the prior demo

## notes

- This demo shows the project's modification surfaces working in
  concert. Phases 1–5 demonstrated a built device; phase 7
  demonstrates a *modified* device.
- After phase 7, the architecture has all of its planned shapes
  except the input liberation (phase 8) and threading (phase 9).
  Phase 7's demo is a milestone marking "the modification pipeline
  is real."
