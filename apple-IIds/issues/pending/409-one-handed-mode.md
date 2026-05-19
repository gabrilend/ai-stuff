---
name: one-handed mode (stylus tap commit)
phase: 4
status: pending
blockedBy: [402, 404, 408]
---

# 409 — one-handed mode

When the user has the stylus in one hand and only the other thumb on
the device, they can still type. The left stick selects a wedge as
normal; the right stick is replaced by **tapping the displayed radial
menu with the stylus** to commit a character.

## current behavior

The radial keyboard requires both sticks: left to pick a wedge, right
to pick a character. If the user has only one thumb free (e.g.,
holding a stylus), they can't type.

## intended behavior

- When the overlay is visible (left stick tilted, or training mode)
  and the user **taps a cell on the overlay with the stylus**, that
  cell's character commits.
- The cells are rendered at a minimum size that's comfortable as a
  stylus target: provisionally 32×32 panel pixels.
- The radial geometry is laid out so the wedges and sub-cells form
  unambiguous touch targets. Cell boundaries are visually distinct.
- Stylus taps on the *inactive* screen's overlay route correctly;
  taps that miss the overlay (between cells, or outside the radial
  area) are ignored.
- One-handed mode and two-handed mode coexist seamlessly: the user
  can switch within a single typing session — left stick selects
  the wedge, then either the right stick or a stylus tap commits.
- If the digitizer reports stylus hover (issue 408), hovering over a
  cell highlights it (matching what the right-stick wedge entry
  would do) without committing.

## suggested implementation steps

1. Extend the overlay renderer (issue 402) to also know the
   bounding rectangle of each cell, so taps can be hit-tested.
2. In the broker's input pipeline, intercept stylus taps that land
   on the inactive screen while the overlay is visible. Hit-test
   against the cell rectangles.
3. On a hit, fire a commit event with the corresponding (left_wedge,
   right_wedge_equivalent) — the right-wedge value comes from the
   tapped cell's logical position.
4. The commit event reuses the issue 404 emission path.
5. If issue 408 reports stylus hover, hook hover into the overlay's
   "preview-highlight" rendering.
6. Test: tilt left stick, tap a cell with the stylus, see the
   character appear in the active emulator.
7. Test the mix: tilt left stick, hover the stylus over a cell, then
   without committing, switch to right-stick commit (right-stick
   wedge entry takes precedence over hover).

## related documents

- `docs/003-input-system.md` — one-handed mode section
- `issues/402-radial-overlay-renderer.md` — provides the visible
  menu and cell geometry
- `issues/404-character-emission-adb.md` — the emission path
- `issues/408-stylus-vs-finger.md` — distinguishes stylus from
  finger touches

## known design questions

- What if the user taps a cell with a *finger* (not a stylus)?
  Default: also commits. Finger taps on the overlay are a valid
  one-handed commit gesture. The stylus is recommended for
  precision, but finger works.
- What about the active screen? The user might tap the active
  screen with the stylus too — but that's a regular mouse click
  routed to the active emulator, not a radial-keyboard commit. The
  overlay is only on the inactive screen, so this distinction is
  natural.
- Cell size on 640×480 panels: 32×32 panel pixels gives 16 cells
  along each axis, comfortably exceeding our 8×8 layout. Plenty of
  room for the wedge labels alongside the cell targets.

## notes

- This is the feature that makes the device usable when held in one
  hand (e.g., on a transit ride). It's underappreciated in concept
  but a big quality-of-life win.
