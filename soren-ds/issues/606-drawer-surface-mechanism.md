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

## Related documents

- `docs/005-display-and-compositor.md` — drawers section.

## Blocked by

601, 602, 603.

## Blocks

607, 608.
