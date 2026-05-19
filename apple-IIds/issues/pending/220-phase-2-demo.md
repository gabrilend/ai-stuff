---
name: phase 2 demo
phase: 2
status: pending
blockedBy: [201, 202, 203]
---

# 220 — phase 2 demo

The deliverable that closes phase 2. Demonstrates two independently
usable Apple //gs instances on the RG DS, with focused stick / button
routing.

## current behavior

No phase 2 demo exists.

## intended behavior

- A script `issues/completed/demos/phase-2/run.sh` extends the phase
  1 demo to launch both instances and exercise dual-screen behavior.
- The top-level `run-demo.sh` recognizes phase 2 and dispatches to
  this script.
- The phase 2 demo:
  - Boots the RG DS into the broker.
  - Both screens show GS/OS Finder simultaneously (two cursors, two
    desktops, two boot chimes — except issue 508's "one chime per
    startup" makes it one chime; phase 2 plays the chime per-screen
    until 508 lands).
  - The user can mouse on each screen independently (touch on A
    moves A's cursor only, touch on B moves B's cursor only).
  - The user presses right-side Start to focus A; the d-pad now
    moves the cursor on A. Presses bottom-left Start to focus B;
    d-pad now moves B's cursor.
  - The user can run two different programs simultaneously — for
    example, MacPaint on screen A and Teach on screen B.
  - Crashing one emulator (e.g., loading a broken disk image) does
    not affect the other; the broker restarts the crashed one.
  - The bottom-panel status strip shows: focused screen indicator,
    each instance's frame rate, host CPU usage, free RAM.
- A short README explains what the viewer is seeing and which
  phase-2 issues each visible feature corresponds to.

## suggested implementation steps

1. Confirm phase 2 issues 201–203 are completed and moved to
   `issues/completed/`.
2. Extend `run-demo.sh` to accept `2` and launch the phase 2 script.
3. Extend the statistics overlay to show two-emulator state.
4. Test the crash-recovery path: deliberately kill instance B mid-
   demo; observe the broker restart it.
5. Capture a screen recording of the demo.
6. Update `issues/phase-2-progress.md` (which should be created when
   phase 2 starts, mirroring `phase-1-progress.md`).
7. Update `docs/000-table-of-contents.md` to reference the demo.

## related documents

- All of phase 2 (201–203)
- `issues/120-phase-1-demo.md` — the demo this extends
- `docs/004-roadmap.md` — phase 2 entry

## notes

- The phase 2 demo is a **strict extension** of the phase 1 demo,
  not a replacement. Everything phase 1 demonstrated still works;
  phase 2 adds the second screen.
- Boot chime caveat: 508 (one chime per startup) lands in phase 5.
  Until then, the phase 2 demo plays two chimes on cold boot. Note
  this in the README as a known artifact, not a bug.
