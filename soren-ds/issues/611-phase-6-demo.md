# 611 — Phase 6 demo

## Current behavior

Issues 601 through 610 produce the visible system: surfaces,
damage tracking, the render loop, per-screen foregrounds, boot
restoration, drawers, drawer content, inter-app exits, link
transitions. Phase 6 needs a demo that walks the user through
all of it.

## Intended behavior

Two trivial demo apps ship statically embedded:

- **`counter-app`** — shows a single integer on a surface; has
  one inter-app exit called "to increment-app" that carries the
  current count.
- **`increment-app`** — receives an integer, adds one, has one
  inter-app exit called "to counter-app" that carries the
  incremented value. Also shows the current value on its
  surface.

The two apps form a doubly-linked pair: each one's exit goes to
the other. The user walks back and forth, and each round trip
advances the count by one.

The demo script at `issues/completed/demos/phase-6/run.sh`:

1. Builds and flashes a kernel with the two demo apps and the
   compositor/drawer/linkage machinery.
2. Sets `/settings/last-foreground-bottom` to `counter-app` and
   `/settings/last-foreground-top` to a small placeholder app
   that shows "use the drawer to navigate" text.
3. Reboots. Confirms `counter-app` appears on the bottom screen
   showing "0".
4. Prompts the user to press `start1` (the leftmost center
   button) to open the bottom-left drawer.
5. The drawer contains one option: "to increment-app". The
   user picks it via radial-menu chord.
6. Confirms the bottom screen now shows `increment-app` with
   "1".
7. Prompts the user to open the bottom-left drawer again.
8. The drawer contains "to counter-app". The user picks it.
9. Confirms the bottom screen now shows `counter-app` with "1"
   (the value `increment-app` returned through the link).
10. Repeats the loop, confirming each round trip increments the
    count and that opening the drawer mid-app does not clobber
    either app's state.

## What the demo proves

- Compositor render loop and damage tracking work end-to-end.
- Per-screen foreground assignment swaps correctly on link
  transitions.
- Drawers open and close on center-button activation, and their
  contents render into the overlay surface.
- Inter-app exits drive the link transition mechanism.
- Background apps preserve state — the increment continues from
  where the user left off, on each side of every round trip.
- Boot restoration reads the persisted foreground apps and
  starts them in the right places.

## Suggested implementation steps

1. The two demo apps' map files.
2. Their `links.json` and `entries.json`.
3. Their drawer-content sub-maps.
4. The script's reboot-and-confirm sequence.

## Related documents

- `docs/002-roadmap.md` — phase 6 demo description.
- `docs/005-display-and-compositor.md`.
- `docs/008-apps-overview.md`.

## Blocked by

All of 601 through 610.

## Closes

Phase 6.
