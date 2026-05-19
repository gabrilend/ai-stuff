---
name: phase 6 demo
phase: 6
status: pending (pending soramech)
blockedBy: [601, 602, 603, 604]
---

# 620 — phase 6 demo *(pending soramech)*

The deliverable that closes phase 6. Demonstrates the native
subsystem rewrites by exhibiting visible performance improvements
in software that exercises Scrap, File, Event, and QuickDraw II.

## current behavior

No phase 6 demo exists.

## intended behavior

- A script `issues/completed/demos/phase-6/run.sh` extends the
  phase 5 demo.
- The phase 6 demo demonstrates:
  - **Scrap Manager native:** rapid copy-paste between programs;
    no perceptible lag.
  - **File Manager native:** opening a 1 MB file in milliseconds
    instead of ~50 ms. Cataloging a directory with 1000 files
    instantly.
  - **Event Manager native:** typing on the radial keyboard with
    sub-5-ms latency. Side-by-side comparison with the
    pre-issue-603 video shows the difference.
  - **QuickDraw II native:** opening Platinum Paint, dragging a
    large selection across the screen at 60 FPS solid.
  - The side-by-side comparison aspect is important: the user
    sees what improved and how much.
- The bottom-panel status strip shows live performance counters:
  current FPS per screen, file ops per second, scrap ops per
  second, event queue depth.
- A short README references each native-rewrite issue.

## suggested implementation steps

1. Confirm phase 6 issues 601–604 are completed and moved to
   `issues/completed/`.
2. Pre-record the pre-issue baseline videos (or pull them from
   the phase 5 demo's recordings).
3. Build the side-by-side comparison: split-screen video of
   before vs after.
4. Add the live performance counters to the status strip.
5. Capture the demo video.
6. Update `issues/phase-6-progress.md`.

## related documents

- All of phase 6 (601–604)
- `issues/520-phase-5-demo.md` — the prior demo
- `docs/004-roadmap.md` — phase 6 entry

## notes

- This is the demo where the device starts feeling *fast*. Phases
  1–5 demonstrated functionality; phase 6 demonstrates
  performance.
- It's also the first demo gated on soramech being ready. Worth
  acknowledging that timeline-wise this demo may come months or
  years after phase 5's demo, depending on soramech's progress.
