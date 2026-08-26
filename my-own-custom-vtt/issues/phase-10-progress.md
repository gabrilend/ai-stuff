# Phase 10 — The engraving

**Goal:** what survives a session is a text file that is also a picture that is
also a spreadsheet.

**Status: complete.** All nine issues done. `./run-phase-demo 10` runs a session,
carves its statistics as an animal nobody chose in advance, reads it back with a
program that shares no code with the one that wrote it, engraves it again and
compares byte for byte, and then breaks it on purpose so you can watch the animal
deform.

## The issues

| Issue | What it established |
| --- | --- |
| [1001 what is in the cells](completed/1001-what-is-in-the-cells.md) | Eight numbers, small and chosen rather than accumulated. |
| [1002 the canvas that joins its own lines](completed/1002-the-canvas-that-joins-its-own-lines.md) | Store strokes, resolve characters once. Nobody draws a corner. |
| [1003 a creature is a tiling](completed/1003-a-creature-is-a-tiling.md) | The carving is the table. Ornament hangs off walls, never off columns. |
| [1004 the writer](completed/1004-the-writer-composes-the-creature.md) | Variables in, engraving out. Refuses in five ways, each with a sentence. |
| [1005 the reader](completed/1005-the-reader-reads-the-picture.md) | It reads what is on the page, not what the writer meant. |
| [1006 intentionally fragile](completed/1006-intentionally-fragile.md) | The art is a checksum you can see, and the argument for it. |
| [1007 handing it to a friend](completed/1007-handing-it-to-a-friend.md) | The other half of the trade for a format that cannot be repaired. |
| [1008 the action bar](completed/1008-the-action-bar-shows-the-cells.md) | A table's history on the wall while the table is playing. |
| [1009 the phase ten demo](completed/1009-the-phase-ten-demo.md) | The capstone. |

## What is built

| Source | What it is |
| --- | --- |
| `090-record` | The eight numbers a session tells about itself. |
| `092-canvas` | A grid that knows about lines rather than characters. |
| `094-creature` | Four rules for tiling eight chambers into an animal. |
| `096-engrave` | The writer. Also `099-engrave` as a program. |
| `097-read-engraving` | The reader. Also `100-read-engraving` as a program. |
| `101-demo-phase-10` | The capstone. |
| `./share-engraving` | Validate, then copy or print or list. |

The bridge serves the last session's carving at `/engraving` and the view hangs it
in the action bar. The server carves itself as the last thing it does.

## Four things this phase taught

**A drawing tells you what is wrong with it, instantly, and no test does.** The
first render put an eye inside a chamber and it ate the last letter of a label;
the mammoth had six legs. Neither was reachable from an assertion anybody would
have thought to write. Both were obvious the moment a person looked at the output,
which is the whole argument for the format and also, unexpectedly, the argument
for looking at your own output before writing tests about it.

**Truncating quietly is worse than failing loudly, and it lies about where.** The
reader's text buffers were sized to the label rather than to the chamber's
interior, so "rollbacks" came back as "rollback" — and the failure surfaced two
layers away as *this carving has no chamber labelled rollbacks*, a true sentence
pointing at entirely the wrong thing. Refusing to truncate turns a half-hour of
looking in the wrong place into one line naming the chamber.

**A hash of high bits is a hash of nothing if the input is small.** The creature
came from the seed's top five bits taken as given, so every seed under about five
hundred million million picked the fish — 1, 2 and 3 included, which is what
anybody writing a test reaches for. Stir first, then take bits.

**Two alphabets forced a better reader.** The plain one cannot tell a corner from a
crossing, so the chamber scan could not depend on recognising corner characters
and had to be written as geometry: four unbroken walls, exactly four rows, and no
stroke anywhere inside. That version is simpler and works for a creature nobody
has written a rule for.

## What it leaves open

Whether the **world** persists between sessions is untouched, and was never this
phase's question. The engraving carries statistics, not geometry: a creature with
last week's numbers in it does not contain the tavern the players burned down.
That is [open question 1.2](../docs/016-open-questions.md).
