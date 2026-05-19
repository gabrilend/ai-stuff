---
name: stylus vs finger differentiation
phase: 4
status: pending
blockedBy: [104, 202]
---

# 408 — stylus vs finger differentiation

The digitizer reports stylus contacts separately from finger
contacts. This lets the broker offer richer pointer semantics — a
right-click equivalent, a precision mode for the stylus, and the
one-handed radial-keyboard mode (issue 409).

## current behavior

Touches and stylus contacts route as identical mouse events. The
broker has no way to tell which is which.

## intended behavior

- The broker reads the digitizer's capability for distinguishing
  stylus from finger (via the appropriate `EVIOCGABS` or
  `MT_TOOL_TYPE` axis on the Linux input layer). Confirmation here
  is one of the open hardware questions in issue 101.
- If supported, each touch event is tagged with `tool = "finger"` or
  `tool = "stylus"`. The broker stores this on the event.
- Routing:
  - stylus tap → ordinary mouse click
  - finger tap → ordinary mouse click
  - **finger held + stylus tap** → right-click equivalent
    (Control-click, the GS/OS-era convention)
  - or, if the stylus has a side button reported on the digitizer:
    **stylus tap with side button held** → right-click
- The right-click equivalent translates to a Control-modified click
  in the emulator's ADB.
- A diagnostic surface (in the bottom-panel status strip or in a
  settings page) shows the last detected tool, so the user can
  confirm the differentiation works.

## suggested implementation steps

1. Confirm the digitizer's capabilities by inspecting `/proc/bus/input/devices`
   and reading `EVIOCGABS` on the relevant device. Document findings
   in `docs/002-hardware-target.md`.
2. Extend the input loop to read `ABS_MT_TOOL_TYPE`; map values to
   the broker's `tool` enum.
3. Update the touch / mouse routing to attach the `tool` tag to
   each event.
4. Implement the finger-held + stylus-tap right-click logic. This
   requires tracking "is a finger currently held down" per panel.
5. If a stylus side button is reported, implement the alternative
   right-click path.
6. Test all four routes: stylus tap, finger tap, finger-held +
   stylus, stylus-with-side-button.

## related documents

- `docs/003-input-system.md` — stylus differentiation table
- `issues/104-touch-as-mouse.md` — the foundation
- `issues/202-independent-input-routing.md` — per-panel routing
- `issues/409-one-handed-mode.md` — depends on this for stylus-tap-
  on-overlay detection

## known design questions

- If the digitizer doesn't differentiate (worst case), what's the
  fallback? Long-press → right-click is a workable default. Lose
  the precision-mode and one-handed-mode improvements, accept the
  degraded UX. Don't pretend this is fine — document the limitation
  prominently.
- Does the digitizer report stylus *hover* (close but not touching)?
  If yes, that's a great affordance for the radial overlay (show
  which cell the stylus is hovering over before commit). If no, no
  hover indication. Investigate during phase 4 hardware testing.
