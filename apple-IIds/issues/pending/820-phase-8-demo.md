---
name: phase 8 demo
phase: 8
status: pending
blockedBy: [801, 802, 803, 804]
---

# 820 — phase 8 demo

The deliverable that closes phase 8. Demonstrates that every modern-
hardware input source (touch, stylus, radial keyboard, gyro) is now
a first-class GS/OS event, and the overlay is a native IIds
component.

## current behavior

No phase 8 demo exists.

## intended behavior

- A script `issues/completed/demos/phase-8/run.sh` extends the
  phase 5 / 7 demos.
- The phase 8 demo demonstrates:
  - **Native touch / stylus:** in a paint program, observe that
    stylus pressure (if reported) varies stroke thickness — a
    capability the original IIds never had.
  - **Native radial keyboard:** typing latency is now under 5 ms.
    Side-by-side comparison vs phase 4 timing.
  - **Native gyro:** activate fine cursor mode (hold L2), draw a
    precise 1-pixel-wide line in a paint program. Releasing L2
    returns to stylus control.
  - **Native overlay:** the overlay aesthetic now matches GS/OS
    natively. View its DA in the Apple menu.
- The status strip shows: current input source per recent event,
  fine-cursor-mode engagement, overlay DA state.

## suggested implementation steps

1. Confirm phase 8 issues 801–804 are completed and moved to
   `issues/completed/`.
2. Pre-stage a paint program that handles pressure-aware strokes
   (may require a custom IIds program; existing software ignores
   pressure).
3. Capture a screen recording showing each input source's native
   integration.
4. Update `issues/phase-8-progress.md`.

## related documents

- All of phase 8 (801–804)
- `docs/004-roadmap.md` — phase 8 entry

## notes

- After phase 8, **ADB is no longer carrying any modern-hardware
  input**. ADB remains only for compatibility with software that
  polls it directly. This is a meaningful architectural milestone.
