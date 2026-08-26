# 1003 -- A creature is a tiling, and the tiling is the table

**Phase:** 10, the engraving
**Blocked by:** [1002](1002-the-canvas-that-joins-its-own-lines.md)
**Blocks:** [1004](1004-the-writer-composes-the-creature.md)
**Documents:** [the record log is an engraving](../../docs/018-the-record-log-is-an-engraving.md)

## Current behaviour

**Done.** `094-creature`. Four rules for grouping eight chambers into bands, plus
attachments that ask the tiling where its walls are.

A chamber is four rows — wall, label, value, wall — with the label **above** the
value rather than beside it. Beside it makes a chamber as wide as both together
and eight of those is a creature nobody can see the whole of.

Indents are given in eighths of the slack between a band and the widest, never in
columns. A column count is a magic number that stops being right the first time a
label changes length.

Every attachment is written in the band vocabulary: `creature_band_bounds`, the
first and last chamber of a band. None of them names a column. That is the whole
mechanism — move a wall and the ornament moves with it, out of step with the
ornament anchored to a different wall.

Ornament is glyphs, never strokes, because a fin made of box-drawing characters
could close a rectangle and the reader would read it as a cell.

### Three things the drawing said out loud

The first render put an eye inside a chamber and it overwrote the last letter of a
label — "seats" became "seato". Eyes are outside the body now.

The mammoth had six legs, because a leg was drawn under every chamber of the
bottom band and that band has three. Front pair and back pair now.

And every seed below about five hundred million million picked the fish, because
the creature came from the seed's high bits taken as given. That includes 1, 2 and
3, which is what anybody writing a test reaches for. The seed is stirred first
now, with a frozen finalizer — changing it would silently give every previously
written seed a different animal.

## Intended behaviour

**The carving is the table.** Its lines are the cell walls. Reading the engraving
and reading the database are the same act.

That sentence is a constraint, not a metaphor, and this is where it becomes
geometry: a creature is a **tiling of rectangular chambers**, and each chamber is
one cell of the spreadsheet. The creature's silhouette is the outer boundary of
the tiling. There is no picture layer over a data layer. There is one layer.

### The creatures are generated, not drawn

Four hand-drawn animals would be four things to maintain and would never fit a
different number of cells. Instead each creature is a **rule for tiling a body**,
plus attachments that hang off named edges of that tiling.

| Creature | The rule |
| --- | --- |
| fish | Chambers in a single row; tail fanning from the left edge, fins above and below, an eye in the head chamber. |
| bird | Chambers stacked into a body; wings sweeping from the upper corners, a beak from the right. |
| dragon | A long body of chambers, a neck rising from the right, wings above, legs below, a tail trailing left. |
| mammoth | A blocky body, four legs below at chamber walls, a trunk and tusks from the left. |

Which creature a run gets comes from the run's own seed, so **the creature belongs
to that run** — bespoke, as the document says, and reproducible, which is what
lets the round trip be a byte comparison.

### The attachments hang off the chambers

This is the part that makes the fragility work. A fin does not sit at a column
somebody typed; it sits at **the wall between chamber three and chamber four**. A
wing springs from **the top-right corner of the body**.

So if a value comes out one character wider, that wall moves, and the fin moves
with it — but the fin on the other side is anchored to a different wall and does
not move the same amount. The creature becomes visibly lopsided. That is the
checksum you can see, and it only works because the anatomy is defined in terms
of the table.

### Widths come from the values

A chamber is as wide as its label plus its value plus the padding. The widest
value in the set is the checksum, and the layout has to be built knowing that.

**A value that does not fit is refused, not truncated.** A truncated checksum is
a number that looks like a number and is not one.

## Suggested implementation steps

1. A chamber: position, size, label, value.
2. A creature: a function from a cell list and a seed to a tiling plus a list of
   attachments.
3. Attachments named by the chamber edge they hang from, never by a column.
4. Draw the tiling onto the canvas, then the attachments.
5. Write the companion `.info.md`, listing the creatures and their rules.
6. Test: every creature accommodates every legal cell count; the outer boundary
   is closed; no chamber overlaps another; the same seed gives the same creature.
