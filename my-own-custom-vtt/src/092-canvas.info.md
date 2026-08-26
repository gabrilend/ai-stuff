# 092-canvas

A character grid that knows about **lines**, not characters.

## Why this is a module and not four printf calls

The engraving's premise is that the carving's lines are the cell walls. A wall
meets another wall at every shared corner, and there are eleven junction
characters depending on which of four directions carry a stroke. Choosing them by
hand is how a drawing ends up with a `+` where it wanted a `├` — and one wrong
junction is a hole the reader falls through, because the reader finds chambers by
following walls.

So the canvas stores, per position, **which of up/down/left/right have a stroke**,
and resolves the whole grid to characters once, at the end. Nobody draws a corner.

The resolution is one dispatch table with sixteen rows, all visible at once and
comparable against each other — which is how you notice that the row for "up and
left" is the wrong corner. Written as conditionals it would be twenty branches
nobody reads twice.

## Two layers

| Layer | What it is |
| --- | --- |
| strokes | Four bits per position. |
| glyphs | Characters placed directly — labels, values, an eye, a whisker. |

**Glyphs win where both exist.** A label sitting on a wall means the wall was
drawn in the wrong place, and hiding the label under the wall would hide the
mistake.

## Collisions are counted

`ornament_collisions` counts every time a non-space glyph lands on a stroke.
Ornament must never touch a wall: a fin drawn across one punches a hole the reader
falls through, and the drawing would still look roughly like an animal, which is
the worst way for it to be wrong.

The glyph is written anyway so the damage is visible, and the count exists so a
test can insist on zero for every creature — and so the writer can refuse rather
than emit a carving with holes in it. Detected rather than hoped for.

A space does not count. Padding a label is not cutting a hole in an animal.

## Two alphabets, not one and a degraded one

| Alphabet | What it is |
| --- | --- |
| `ALPHABET_CARVED` | Box-drawing characters. Sixteen stroke combinations, sixteen distinct glyphs. |
| `ALPHABET_PLAIN` | `-`, `|`, `+`. For a terminal that cannot show the other. |

A file names its alphabet in its header and a reader accepts exactly one at a
time. A format that accepts either is a format where a corrupted character has
somewhere to hide.

The plain alphabet **cannot tell a corner from a crossing** — a plus sign is every
junction there is — which is why the reader's chamber-finding is geometric rather
than character-shaped.

## Rows are trimmed

Trailing blanks are removed at emit time. Trailing spaces are invisible, and an
artifact whose correctness depends on something invisible is an artifact somebody
will break by accident and never see why.

## Functions

| Function | Does |
| --- | --- |
| `canvas_init` | Prepares a grid. Refuses an oversized one rather than clipping — a clipped creature has a wall missing. |
| `canvas_across` / `canvas_down` | A run of stroke. Each end gets only the half-stroke pointing along the run, so runs meeting at an end produce a junction. |
| `canvas_box` | Four runs; the corners fall out of the junctions. |
| `canvas_put` / `canvas_text` | Glyphs. |
| `canvas_text_right` | Right-aligned so the last character sits at a column. What a number in a chamber wants. |
| `canvas_emit` / `canvas_to_text` | Resolve and write out. |
| `canvas_glyph_for` | One stroke combination's character, so a test can check all sixteen directly. |

## Related

- [094-creature](094-creature.info.md) — what gets drawn on it
- issue [1002](../issues/completed/1002-the-canvas-that-joins-its-own-lines.md)
