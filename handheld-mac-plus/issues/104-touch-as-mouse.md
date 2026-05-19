---
name: touch as mouse
phase: 1
status: pending
blockedBy: [103]
---

# 104 — touch as mouse

The RG DS digitizer drives the IIgs mouse cursor on screen A. Touch and
stylus both work; stylus is the recommended pointer for GS/OS's small
click targets.

## current behavior

GS/OS is booted on screen A (issue 103) but its cursor does not respond
to anything.

## intended behavior

- A tap (finger or stylus) on screen A's digitizer registers as a
  mouse-down + mouse-up at the corresponding coordinate inside the
  emulated IIgs.
- A drag (touch-and-move) sends continuous mouse-move events while the
  finger/stylus is down, and mouse-up on release.
- The coordinate mapping accounts for the 2× integer scaling and 40 px
  letterbox used to fit the IIgs's 320×200 (or 640×400 in Super Hi-Res
  effective) onto the 640×480 panel.
- The digitizer is sampled fast enough that GS/OS sees smooth motion (the
  IIgs ADB mouse reported at ~60 Hz; matching or exceeding that is fine).

If both panels have digitizers (confirmed by the spec sheet) and only
screen A has an IIgs running in phase 1, screen B's digitizer is ignored
until phase 2 brings up the second emulator.

## suggested implementation steps

1. Read raw touch events from the appropriate `/dev/input/eventN` device
   for screen A's digitizer. Document the device path in
   `docs/002-hardware-target.md` (filling in the "to confirm" entry).
2. Map raw panel (x, y) into IIgs framebuffer (x, y) using the scaling
   parameters from issue 103. For Super Hi-Res:
   - `iigs_x = (panel_x) / 2` (clamped to [0, 319])
   - `iigs_y = (panel_y - 40) / 2` (clamped to [0, 199])
   - touches in the 40-px letterbox zones are ignored
3. Inject the events into GSplus's ADB mouse path. GSplus already has
   keyboard/mouse plumbing for SDL2 — the patch redirects it to read
   from our raw event source instead.
4. Test the golden path: tap the Apple menu, the menu opens. Tap a menu
   item, the menu item activates.
5. Test edge cases: tap-and-hold (should hold the mouse button), drag a
   window by its title bar, double-click an icon.
6. If the digitizer reports stylus vs finger separately, capture that bit
   and store it on the event — useful for the right-click equivalent
   planned in phase 4.

## related documents

- `docs/003-input-system.md` — touch as mouse section, stylus differentiation
- `docs/001-architecture-overview.md` — broker's input router

## known design questions

- Direct-touch (touch maps to the touched screen) is the default — easier
  than trackpad-style cross-screen mapping, and a stylus is naturally
  direct-manipulation.
- Long-press → right-click equivalent is deferred to phase 4 (depends on
  stylus differentiation).
