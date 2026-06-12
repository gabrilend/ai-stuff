# 607 — Drawer button activation

## Current behavior

The drawer surfaces (606) can open and close but nothing yet
wires the four center button events from phase 5 (502, 507) to
calling `drawer_open` and `drawer_close` on the right drawer.

## Intended behavior

A small `drawer-activation` map wires the button-down events for
the four center buttons through the drawer-swap-aware
interpretation (507) and into per-drawer open/close commands.

The mapping (default, no swap):

- `start1` button-down → toggle the bottom-left drawer.
- `select1` button-down → toggle the bottom-right drawer.
- `select2` button-down → toggle the top-left drawer.
- `start2` button-down → toggle the top-right drawer.

With the swap flag set, `start1`/`select1` toggle top-screen
drawers and `start2`/`select2` toggle bottom-screen drawers.
This is handled by 507's settings applier — the activation map
sees pre-routed events targeted at specific drawers and just
calls toggle.

"Toggle" means: if the drawer is closed, transition to opening.
If open, transition to closing. If currently animating in either
direction, reverse the animation. This last case is what makes
the drawer feel responsive — a user who half-opens a drawer and
then changes their mind sees the drawer slide back out
immediately.

Additionally, any input that lands on a screen with an open
drawer is intercepted by the drawer: touch events go to the
drawer's content (608), button events that aren't another
center-button press also go there. Pressing the drawer's owning
center button a second time closes it; the same toggle path.

## Suggested implementation steps

1. `drawer_toggle(drawer)` — handles the four state transitions.
2. The `drawer-activation` map wiring button-down events to
   `drawer_toggle`.
3. Input interception while a drawer is animating or open.
4. Load this map at boot alongside the input-poll and
   compositor-tick maps.

## Related documents

- `docs/004-input-model.md` — the four center buttons section.
- `docs/005-display-and-compositor.md`.

## Blocked by

502, 507, 606.

## Blocks

608.
