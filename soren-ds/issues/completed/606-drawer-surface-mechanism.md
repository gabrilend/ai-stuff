# 606 — Drawer surface mechanism

## Current behavior

The compositor's render loop (603) composites surfaces but knows
nothing about overlay drawers. The visual model from
`005-display-and-compositor.md` calls for a drawer that slides
in from the left or right edge of a screen, sits above the
foreground until dismissed, and slides back out.

## Intended behavior

A `drawer_surface_t` is a special surface owned by the system
(not by any app) with these added fields:

- Edge: left or right.
- State: closed, opening, open, or closing.
- Slide progress: 0.0 (fully off-screen) to 1.0 (fully open).
- Slide rate: how much progress advances per frame during
  opening or closing. Tuned for "fast but legible" — about six
  frames from off to fully open.
- Contents pointer: the foreground app provides a small
  sub-surface the drawer wraps (608).

Geometry: a drawer occupies the screen's full height minus
about 5% margin on top and bottom, with about 5% margin on its
edge side. Width is around 40% of the screen's width. These
values come from `005-display-and-compositor.md`.

When state is `opening`, the compositor advances slide progress
toward 1.0 each frame. When `closing`, toward 0.0. When the
slide reaches its target, state transitions to `open` or
`closed`. While `open`, the contents draw at their full position.

The drawer's composite step in 603 happens after the foreground
surfaces are copied. The drawer's pixel area overwrites whatever
the foreground put there; closing reverses the overwrite by
allowing the foreground's next dirty bit to put the underlying
pixels back.

To support that, the foreground surfaces under a drawer mark
themselves dirty as the drawer slides away, so they re-paint as
the cover lifts. The drawer's render does the bookkeeping by
setting the dirty bit on every foreground surface it intersects
when transitioning out of `open`.

## Suggested implementation steps

1. `struct drawer_surface_t` — fields above.
2. Four drawer instances at kernel startup — left and right per
   screen.
3. `drawer_open(drawer)`, `drawer_close(drawer)`.
4. `drawer_render_tick()` — called from 603's per-frame walk
   per drawer with non-closed state.
5. Foreground re-dirty pass when transitioning out of `open`.

## Open questions

- *Is a drawer a surface in 601's table?* A surface must be wholly on
  its screen (601 refuses one past an edge), and a drawer spends its
  slide half off it.
- *Slide progress as 0.0 to 1.0?* The kernel is built without floating
  point (103f).
- *What puts the foreground back when a drawer lifts?* Step 5 marks
  every foreground surface the drawer intersects. That copies the
  surfaces back, but not the background where no surface is, which
  would keep the drawer's pixels.
- *What keeps an open drawer on top when the surface under it is
  copied?*
- *What is in a drawer before 608 fills it?*
- *Where do the drawer's pixels come from, and when?*
- *What opens and closes them?*

### Proposed answers (UNVERIFIED)

Each one is Claude's call, open for Ritz.

1. *No: the system's own, beside the table.* There are four drawer
   records (screen × edge) in `src/system/113-drawers.c`. The compositor
   moves them at the start of a frame and draws them last, over
   everything, clipped to the screen. They are never in an app's way,
   and nothing has to bend 601's on-screen rule.
2. *Whole frames:* progress counts 0 to `DRAWER_SLIDE_FRAMES` (6), and
   the drawer's edge moves an even step each frame.
3. *Exposure, not marks.* Each step exposes everything the drawer
   covered before the step (`surface_expose`). The frame paints the
   background there and copies back every foreground surface over it,
   then draws the drawer where it is now. This is also simpler than
   working out the strip it uncovered, and never wrong.
4. *Overlap,* as 603 does for surfaces. A drawer is drawn when it moved,
   when its contents were marked (`drawer_mark_dirty`), or when anything
   painted or copied this frame lies under it.
5. *An empty panel:* the palette's panel colour with a rule around it,
   in a canvas the size of the open drawer (`drawer_canvas`), for 608 to
   draw into.
6. *The engine's pool, the first time each drawer opens, kept for good:*
   there are only ever four.
7. *Not built here.* `drawer_open` and `drawer_close` are called from
   C; the center buttons' boxes and the drawer-swap setting are 607.
   Opening part way through a close (or the reverse) goes back from
   where the drawer is.

Geometry follows the doc: 5% margin top, bottom and on its own edge,
40% of the width. On a 640×480 screen that is 256×432, open at x 32
(left) or 352 (right).

## What happened

Built on the twin as answered above:

- `src/system/113-drawers.c` and `.h`.
- `drawers_advance` (before the gather) and `drawers_draw` (after the
  surfaces), called from 603's `compositor_screen`.

`twin/tests/114-test-drawers.c` (26 checks):

- A drawer starts shut.
- Opening slides it in over six frames, each step showing the right
  part of its pixels.
- It sits in its margins over the app.
- The app draws under it and it stays on top; marking its contents
  redraws it.
- Closing over six frames leaves the screen exactly as the app's: its
  surface, and the background where nothing is.
- Turning it round part way goes back from where it was.
- Two drawers on one screen open side by side.
- On the compositor's own timer, a drawer opened and closed from
  another thread does the same.

Without the exposure step, seven of those checks fail.

## Related documents

- `docs/005-display-and-compositor.md` — drawers section.

## Blocked by

601, 602, 603.

## Blocks

607, 608.
