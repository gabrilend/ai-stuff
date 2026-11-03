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

## Open questions

- *Clear after the copy?* Step 4 clears the bit once the copy is done.
  A mark made while the compositor copies would be wiped by that clear,
  and the owner's last write would never reach the screen.
- *Does a new surface start clean or marked?*
- *Do a resize and a move mark it?*
- *What may mark a surface — its owner only?*
- *What about the screen a released or moved surface uncovers?*

### Proposed answers (UNVERIFIED)

Each one is a choice Ritz can overturn.

1. *Take before the copy, never clear after.* `surface_take_dirty` reads
   the bit and clears it in one atomic exchange; the compositor calls it
   first and copies only on a 1, so a mark made during the copy is there
   for the next frame. There is no `surface_clear_dirty`: an API whose
   natural use loses marks is left out. Measured: with is-dirty, copy,
   then clear, three writers' last writes went missing in 3 of 30 runs;
   with take-then-copy, in none.
2. *Marked*, so its first frame shows it (its pixels start clear).
3. *Yes*, both, when granted; a refused one marks nothing. Each changes
   what the screen should show.
4. *Anyone holding a live handle.* A spurious mark costs one extra copy
   and never a wrong pixel, so the owner check of 601 isn't repeated
   here.
5. *Left to 603.* The pixels a surface uncovers belong to no surface
   to mark; what the compositor paints behind them (a cleared region, or
   a screen-wide mark) is the compositor's to decide.

The handle is checked under 601's table lock, held only for the slot
lookup; the bit itself is an atomic byte with release on mark and
acquire on read, as the issue asks.

## What happened

Built on the twin as answered above: `surface_mark_dirty`,
`surface_is_dirty` and `surface_take_dirty` in
`src/system/104-surfaces.c` and `.h`, and a mark on every grant,
resize and move.

`twin/tests/106-test-damage.c` (18 checks): a new surface is marked;
take answers and clears, looking does not; two marks are one; a mark
after a take waits for the next; a resize and a move mark, refused ones
don't; released and never-granted handles mark and take nothing, not
even the next grant in the slot; and three threads writing their own
pixel of one surface and marking after every write, against a
compositor thread taking and copying, end with every last write shown
and no copy ever going backwards.

## Related documents

- `docs/005-display-and-compositor.md` — damage tracking
  section.

## Blocked by

207, 601.

## Blocks

603.
