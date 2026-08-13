# 602 — Damage tracking

## Current behavior

Surfaces (601) exist but the compositor has no way to tell which
ones the owner has written into since the last composite pass.
Without that, the compositor either copies every surface every
frame (wasting power on unchanged content) or never copies
anything (the screen never updates).

## Intended behavior

Every surface carries a **damage bit**. When the owning box
writes into the surface's pixel buffer, it calls
`surface_mark_dirty(handle)`, which sets the bit with release
ordering. The compositor's per-frame pass (603) does an
acquire load of the bit; surfaces with the bit set get copied
forward to the framebuffer; surfaces with the bit clear get
skipped.

After copying, the compositor clears the bit (release store) so
subsequent frames don't redundantly copy unchanged content.

A finer-grained damage model — region rectangles inside a
surface rather than the whole-surface bit — is deferred. The
launch system's surfaces are small enough that per-surface
damage is fine; the per-region version becomes worth building
when a surface gets large (the editor's text panels at full
double-width are candidates).

The damage bit survives two cores writing to one surface at once,
which is the ordinary case rather than a special one: marking dirty is
idempotent, so every writer races to set the same bit and the
compositor reads it as set regardless of who won.

This is a bit on a surface rather than state inside a box, which is why
it is allowed at all — a box may not remember anything between calls,
but the surface it writes to is a thing in the world, like a register
or a screen.

## Suggested implementation steps

1. `damage` field on `surface_t` (601), atomic byte.
2. `surface_mark_dirty(handle)` — release store.
3. `surface_is_dirty(handle)` — acquire load, used by
   compositor.
4. `surface_clear_dirty(handle)` — release store, called by
   compositor after copy.

## Related documents

- `docs/005-display-and-compositor.md` — damage tracking
  section.

## Blocked by

207, 601.

## Blocks

603.
