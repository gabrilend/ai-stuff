# 094-creature

A creature is a **tiling of rectangular chambers**, and each chamber is one cell
of the spreadsheet. The creature's silhouette is the boundary of the tiling.

There is no picture layer over a data layer. There is one layer.

## The creatures are generated, not drawn

Four hand-drawn animals would be four things to maintain and would never fit a
different number of cells. Each creature is a **rule for grouping chambers into
bands**, plus attachments that hang off the resulting tiling.

| Creature | Bands | Ornament |
| --- | --- | --- |
| fish | 3 / 3 / 2 | a tail fanning off the widest band's left wall, a dorsal fin, a pelvic fin, a head with an eye |
| bird | 2 / 3 / 2 / 1 | two wings sweeping from either end of the widest band, a head, tail feathers |
| dragon | 4 / 4 | a neck rising from the top band's right wall, a wing, a leg under each bottom chamber, a tail |
| mammoth | 3 / 2 / 3 | a shaggy back, four legs, a trunk and tusk, an ear |

Indents are given in **eighths of the slack** between a band and the widest one,
never in columns — a column count would be a magic number that stopped being right
the first time a label changed length.

## A chamber is four rows

Top wall, label, value, bottom wall. The label sits **above** the value rather than
beside it, because beside it makes a chamber as wide as both together and eight of
those is a creature nobody can see the whole of.

Chamber width is `max(label, widest value) + 4` — two walls and a column of
padding either side. Neighbouring chambers share a wall.

## The attachments hang off the chambers

This is what makes the fragility work. A fin does not sit at a column somebody
typed; it sits at the wall between two chambers, reached through
`creature_band_bounds` and the first/last chamber of a band.

So when a hand-edit pushes a value one character wider, that wall moves, every
wall to its right on that row moves with it, and the animal is visibly lopsided
against the rows above and below. **That is the checksum you can see**, and it only
works because the anatomy is defined in terms of the table.

## Ornament is glyphs, never strokes

A fin drawn with box-drawing characters could accidentally close a rectangle, and
the reader finds chambers by looking for closed rectangles — so an ornamental one
would read as a cell.

**Ornament may never touch a wall.** The canvas counts it when one does; a test
insists on zero for every creature, and the writer refuses to emit a carving with
collisions in it.

## The seed is stirred before the animal is chosen

An earlier version took the high bits of the seed as given, which meant every
seed below about five hundred million million picked the fish — including 1, 2 and
3, which is what anybody writing a test or setting a seed by hand reaches for. A
record's seed is well mixed in practice and that hid it.

The mixing is the standard splitmix finalizer, and it is **frozen**: changing it
would silently give every previously written seed a different animal, and a record
log is a thing people keep.

## Functions

| Function | Gives |
| --- | --- |
| `creature_from_seed` | which of the four |
| `creature_name` | its word |
| `creature_lay_out` | the tiling; 0 if it would not fit, refused rather than squeezed |
| `creature_draw` | chambers then ornament, onto a canvas |
| `chamber_width_for` | how wide a chamber holding one cell must be |
| `creature_band_bounds` / `creature_band_count` / `creature_widest_band` | the vocabulary the attachments are written in |

## Related

- [092-canvas](092-canvas.info.md) — what it draws on
- [090-record](090-record.info.md) — the eight cells it tiles
- issue [1003](../issues/completed/1003-a-creature-is-a-tiling.md)
