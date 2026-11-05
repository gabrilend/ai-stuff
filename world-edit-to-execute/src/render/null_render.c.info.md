# null_render.c

The headless renderer (issue 501c): reads the render slots the raylib
renderer reads (`slots.h`), draws nothing, and reports what one frame would
have drawn. Needs neither raylib nor Lua, so it runs with no display.
Declared in `null_render.h`.

- **`null_render_slots(slots, map, report) -> drawn`**: walks every slot as
  the draw thread does. A slot in use with no data, or not visible, is
  `hidden`; the rest are `drawn` and counted by kind (`by_kind`, the
  bridge's mesh ids: 0 circle, 1 cube, 2 triangle, 3 cylinder), as
  `placeholders` (any other mesh id: no model), `outside` (off the map's
  `NullBounds` on the ground, x and y, edges inside; `map` may be NULL) and
  `selected`. `checksum` is FNV-1a (64-bit) over every drawn item in slot
  order.
- **`null_render_hash_item(hash, entity_id, item)`**: one item folded into
  the checksum: the entity id, mesh, position, rotation, spin, facing,
  scale, colour, selection, team, animation frame and time, written byte
  by byte in that order (floats as their bits, little-endian), so the
  same frame gives the same number on any machine.
- **`null_report_format(report, buf, size)`**: the report as four lines of
  text.

When the page (`page.h`, issue 501) replaces the slots, the same report is
taken over the page.
