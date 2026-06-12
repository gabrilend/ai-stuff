# 603 — Compositor render loop

## Current behavior

Surfaces exist and they know when they're dirty (601, 602) but
nothing yet copies their pixels into the screen framebuffers
that the display controllers scan out from.

## Intended behavior

A `compositor-tick` box fires once per display refresh — the
same 60Hz cadence the input poller uses (501) but driven off a
separate timer so the input poll and the composite pass can run
on different workers concurrently.

Each tick, the compositor:

1. For each of the two screens, walk the surface list (601)
   from back to front in z-order.
2. For each surface whose owning app is the foreground on that
   screen (604) AND whose damage bit is set (602), copy the
   pixel buffer into the screen's framebuffer at the surface's
   position. The copy respects the surface's width and height,
   bounded by the screen's edges.
3. Clear each composited surface's damage bit.
4. For each drawer overlay (606) currently open on that screen,
   composite the drawer on top of whatever the foreground put
   down. Drawers do not respect z-order with foreground
   surfaces; they sit unconditionally above.

The composite copy is straight memcpy of rows from the surface
buffer into the framebuffer's pixel offset. No alpha blending,
no scaling, no filtering — surfaces produce pixels in the
screen's native format and position. Phase 9 may revisit if
the modeller (phase 10) wants alpha blending for translucent
selection highlights.

The compositor runs on a single worker per tick — the per-frame
work is small and the contention overhead of splitting it
across workers exceeds the gain. Multiple workers run other
boxes concurrently with the compositor; only the compositor
itself is serialised per frame.

## Suggested implementation steps

1. `compositor_tick_box()` — the per-frame body.
2. `composite_surface_to_framebuffer()` — the per-surface copy.
3. The `compositor-tick` box in a statically embedded map that
   runs alongside `input-poll` from 501.

## Related documents

- `docs/005-display-and-compositor.md`.

## Blocked by

601, 602.

## Blocks

604, 606, every later phase 6 issue.
