# 1002 -- The canvas that joins its own lines

**Phase:** 10, the engraving
**Blocked by:** [1001](1001-what-is-in-the-cells.md)
**Blocks:** [1003](1003-a-creature-is-a-tiling.md)
**Documents:** [the record log is an engraving](../../docs/018-the-record-log-is-an-engraving.md)

## Current behaviour

**Done.** `092-canvas` stores four stroke bits per position and resolves the whole
grid to characters once, through one dispatch table of sixteen rows. Nobody draws
a corner.

Two alphabets, and they are two artifacts rather than one and a degraded one. The
plain alphabet cannot tell a corner from a crossing — a plus sign is every
junction there is — which turned out to matter: the reader's chamber scan had to
be written geometrically rather than by recognising corner characters, and it is
better for it.

Glyphs win over strokes where both exist, and **collisions are counted**. Ornament
must never touch a wall, because the reader follows walls to find chambers and a
fin drawn across one is a hole it falls through — and the drawing would still look
roughly like an animal, which is the worst way to be wrong. The glyph is written
anyway so the damage is visible; the count exists so a test can insist on zero and
so the writer can refuse.

Rows are trimmed of trailing blanks, because an artifact whose correctness depends
on something invisible is an artifact somebody will break by accident and never
see why.

## Intended behaviour

A character grid that knows about **lines rather than characters**, so that where
two lines meet it produces the right corner without anybody having chosen one.

### Why this is a module and not four printf calls

The engraving's whole premise is that the carving's lines are the cell walls. A
cell wall meets another cell wall at every shared corner, and there are eleven
different junction characters depending on which of the four directions carry a
line. Choosing them by hand is how a drawing ends up with a `+` where it wanted a
`├`, and one wrong junction is a hole the reader falls into.

So the canvas stores, for every position, **which of up/down/left/right have a
stroke**, and resolves the whole grid to characters once, at the end.

This is *make the tool, not the thing*. Nobody draws a corner.

### What it holds

| Layer | What it is |
| --- | --- |
| strokes | Four bits per position: does a line leave this cell upward, downward, leftward, rightward. |
| glyphs | Characters placed directly — labels, values, an eye, a whisker. |

Glyphs win where both exist, because a label sitting on a wall means the wall was
drawn in the wrong place and hiding it would hide the mistake.

### Two alphabets

Box-drawing characters for the carving, and a plain-ASCII fallback for terminals
that cannot show them. **The fallback is a different artifact, not a degraded
one** — the reader must accept exactly one of them at a time, chosen by a marker
in the file, because a format that accepts either is a format where a corrupted
character has somewhere to hide.

## Suggested implementation steps

1. A grid of stroke-bitmaps and a parallel grid of glyphs.
2. `canvas_line` for a horizontal or vertical run, setting strokes along it.
3. `canvas_text` for glyphs.
4. A resolve step turning strokes into characters through a lookup table indexed
   by the four bits — a dispatch table, not a chain of conditionals.
5. Write the companion `.info.md`.
6. Test: every one of the sixteen stroke combinations resolves to a distinct and
   correct character, and a glyph over a stroke shows the glyph.
