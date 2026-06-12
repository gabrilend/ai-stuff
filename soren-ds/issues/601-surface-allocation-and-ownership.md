# 601 — Surface allocation and ownership

## Current behavior

Both screens have framebuffers (phase 1) and apps want to draw
into them, but apps cannot share a screen without conflicting
writes. There is no ownership model for which box gets to draw
where.

## Intended behavior

A **surface** is a rectangle of pixels on a specific screen that
exactly one box owns the right to draw into. A surface knows:

- Which screen it lives on (top or bottom).
- Its position on that screen (x, y) and size (width, height).
- Which box owns it (the box's instance handle).
- Its pixel buffer (a region of memory the owner writes; the
  compositor reads).
- Its damage bit (601's neighbor, 602, manages this).
- Its z-order within the screen — surfaces stack from back to
  front.

The compositor exposes:

- `surface_request(screen, x, y, width, height) → handle` —
  the owning box asks for a surface. The compositor returns a
  handle if no conflict exists, or null if the requested
  rectangle overlaps a surface already owned by another box on
  the same screen.
- `surface_release(handle)` — owner relinquishes; the surface
  is freed and its pixels are no longer composited.
- `surface_resize(handle, new_width, new_height)` — owner asks
  to grow or shrink. Same conflict check as request.
- `surface_set_position(handle, x, y)` — owner asks to move.
  Same conflict check.

Two surfaces on the same screen never overlap unless the owning
box is the same. The drawer overlay (606) is a documented
exception — drawers sit above the foreground and are owned by
the system, not by any app.

The data structure is a per-screen list of allocated surfaces.
Lookups, allocations, and conflict checks scan the list; the
size is small (a handful of surfaces per screen), so linear
scans are fine.

## Suggested implementation steps

1. `struct surface_t` — fields above.
2. Per-screen surface list, allocated from 108's heap.
3. `surface_request()`, `surface_release()`, `surface_resize()`,
   `surface_set_position()`.
4. Conflict check helper.

## Related documents

- `docs/005-display-and-compositor.md`.

## Blocked by

108, 111a, 111b.

## Blocks

602, 603, every later phase 6 issue.
