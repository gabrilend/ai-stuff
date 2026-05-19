---
name: phase 3 demo
phase: 3
status: pending
blockedBy: [301, 302, 303, 304, 305]
---

# 320 — phase 3 demo

The deliverable that closes phase 3. Demonstrates two coordinated
desktops sharing a filesystem, a clipboard, and an IPC channel —
the moment the device feels like one machine.

## current behavior

No phase 3 demo exists.

## intended behavior

- A script `issues/completed/demos/phase-3/run.sh` extends the phase
  2 demo.
- The phase 3 demo:
  - Boots both instances (as phase 2).
  - Demonstrates the shared volume: drag a file from screen A's
    desktop to the shared volume; refresh screen B's Finder window
    over the shared volume; the file is there.
  - Demonstrates file locking: open the file on A in a text editor,
    try to open it on B for write, see the "file in use" error.
  - Demonstrates the shared clipboard: copy a Super Hi-Res selection
    on A, paste on B; copy text on B, paste on A.
  - Demonstrates IPC: a tiny pair-program runs (a "ping/pong"
    sample), one half on each screen, exchanging packets visibly via
    the broker's packet log.
  - Shows the audit log in a window on the bottom panel (or as a
    separate desk accessory).
- The bottom-panel status strip from phase 2 grows to show
  shared-volume free space, current scrap type/age, and IPC packet
  rate.
- A short README explains what the viewer is seeing and which
  phase-3 issues each visible feature corresponds to.

## suggested implementation steps

1. Confirm phase 3 issues 301–305 are completed and moved to
   `issues/completed/`.
2. Build the ping/pong sample as a small IIds program in 65C816
   assembly; bundle both halves as part of the demo's assets.
3. Extend `run-demo.sh` to accept `3`.
4. Extend the statistics overlay to show shared-volume / scrap /
   IPC metrics.
5. Capture a screen recording of the demo.
6. Update `issues/phase-3-progress.md` to mark phase 3 complete.

## related documents

- All of phase 3 (301–305)
- `issues/220-phase-2-demo.md` — the prior demo
- `docs/004-roadmap.md` — phase 3 entry

## notes

- This is the demo where the dual-screen story becomes *visible*. In
  phases 1–2 it's two emulators that happen to sit side by side; in
  phase 3 they're cooperating. Worth investing a little in the
  presentation — make the ping/pong sample visually obvious (e.g.,
  a bouncing ball that flies off the right edge of screen A and
  appears on the left edge of screen B).
