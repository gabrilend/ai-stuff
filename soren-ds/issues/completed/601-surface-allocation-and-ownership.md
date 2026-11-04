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

## Open questions

- *Blocked by 111a and 111b?* The display hardware is still open.
- *What is "the box's instance handle"?*
- *Who may release, resize or move a surface?*
- *What is a handle, and what happens to one after release?*
- *A per-screen list from 108's heap?*
- *When are the old pixels freed?* A resize or release may happen while
  another core of the same box is still writing.
- *What does a resize keep?*
- *A rectangle partly off the screen?*
- *How do surfaces stack?*

### Proposed answers (UNVERIFIED)

Each one is a choice Ritz can overturn.

1. *Not for the surfaces.* They are portable; the twin's two screens are
   the framebuffers' stand-in, and 111a–d are only what 603 copies into
   on the device.
2. *The station.* A box asking from inside its run owns the surface as
   its station (`engine_current_station`); `surface_request_for` names
   an owner, and `SURFACE_SYSTEM` (-1) is for what no app owns — boot,
   and the drawers of 606.
3. *The owner, or anyone outside every run.* A box may change only its
   own station's surfaces (another gets `SURFACE_NOT_OWNER`); the system,
   boot and tests, which run outside the engine, may change any.
4. *A slot number and a count of the slot's reuses*, packed into one
   positive 32-bit number. A handle kept past its release answers
   `SURFACE_NO_HANDLE`, and never reaches the next grant in the slot.
5. *One table of 64 slots for both screens, behind one lock*, scanned
   whole; the pixels come from the engine's pool through a new
   `engine_memory_take`. A handful of surfaces per screen makes a scan
   cheaper than anything cleverer.
6. *Retired, not freed* — `engine_memory_retire`, on the per-core
   counters that reclaim old arrows: a box that took the pointer during
   its run can finish writing through it. Callers outside the engine
   must not race their own resize.
7. *The top-left corner and the pixels both rectangles share*; the rest
   of the new rectangle starts clear.
8. *Refused* (`SURFACE_OFF_SCREEN`), not clipped: an owner asking past an
   edge has made a mistake it should hear about.
9. *In the order granted*, back to front; `surface_list` answers them in
   that order. Raising a surface is left until something needs it.

The drawer overlay's exception (606) is not built here: drawers are the
system's, and how they sit over an app's surfaces is 606's to decide.

## What happened

Built on the twin as answered above: `src/system/104-surfaces.c` and
`.h`, and `engine_memory_take` / `engine_memory_retire` in the engine's
public header.

`twin/tests/105-test-surfaces.c` (32 checks): grants and refusals (one
pixel of overlap, the same owner stacking, touching edges, the other
screen, past every edge); the order surfaces stack in; resizing that
keeps and clears the right pixels, and resizing and moving refused
without changing anything; released handles that reach nothing, not even
the next grant in the slot; a full table; four threads asking for and
letting go of overlapping rectangles 3 000 times each with no pixel ever
held by two owners (with the check removed, the same test counts
thousands of clashes); and a surface asked for by a box belonging to its
station, which another station cannot release.

## Related documents

- `docs/005-display-and-compositor.md`.

## Blocked by

108, 111a, 111b.

## Blocks

602, 603, 612, every later phase 6 issue.
