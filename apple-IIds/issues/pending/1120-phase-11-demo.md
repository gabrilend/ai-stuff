---
name: phase 11 demo
phase: 11
status: pending
blockedBy: [1101, 1102, 1103, 1104, 1105, 1106]
---

# 1120 — phase 11 demo

The deliverable that closes phase 11. Demonstrates Apple IIds
running on bare metal with no Linux underneath — the *destination*.

## current behavior

No phase 11 demo exists.

## intended behavior

- A script `issues/completed/demos/phase-11/run.sh` (which on
  bare-metal is more like "build and flash the SD card" than
  "execute on Linux") prepares the bare-metal Apple IIds image.
- The phase 11 demo:
  - Powers on the device. The boot is *fast* — under 5 seconds to
    GS/OS Finder, possibly under 2.
  - Both screens come up identical to the staging-ground demo —
    the user can't tell from looking at the screen that anything
    has changed underneath.
  - The bottom-panel status strip indicates "bare-metal mode" and
    shows the dramatic improvements: boot time, ops per second,
    free memory (way more than under Linux), battery life
    indicator (also way better).
  - All the curated app library runs unchanged. The same paint
    program, the same music player, the same games.
  - A side-by-side comparison with the staging-ground demo (run
    on a separate device, or in a recording) shows the
    differences.
- The README acknowledges that **the implementation looks
  completely different** even though the user experience is the
  same.

## suggested implementation steps

1. Confirm phase 11 issues 1101–1106 are completed and moved to
   `issues/completed/`.
2. Build the bare-metal SD card image.
3. Flash a development RG DS with it.
4. Capture comparison footage of staging-ground vs bare-metal.
5. Update `issues/phase-11-progress.md`.

## related documents

- All of phase 11 (1101–1106)
- `notes/vision/000-vision.md` — the destination is reached
- `docs/004-roadmap.md` — phase 11 entry

## notes

- This is the demo where the project's destination becomes real.
  Years of work since the staging-ground demo (phase 5) come to
  fruition. Worth a *real* recording with narration explaining
  the architecture transition.
- Pending soramech and a multi-year time horizon. Don't expect
  this issue to be checkable for a long time.
