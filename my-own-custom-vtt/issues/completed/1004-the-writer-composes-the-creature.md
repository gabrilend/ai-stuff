# 1004 -- The writer composes the creature around the values

**Phase:** 10, the engraving
**Blocked by:** [1003](1003-a-creature-is-a-tiling.md)
**Blocks:** [1005](1005-the-reader-reads-the-picture.md)
**Documents:** [the record log is an engraving](../../docs/018-the-record-log-is-an-engraving.md)

## Current behaviour

**Done.** `096-engrave`, and `099-engrave` as a program.

Three header lines and then the carving. No separate data block — a file with the
numbers written twice is a file that can disagree with itself.

It refuses rather than truncating, in five distinct ways, each with a sentence: a
value wider than its chamber (naming the cell, the text, and both widths), an
alphabet that is neither, a creature that would not fit, a buffer too small, and
ornament crossing a wall. The last is checked here as well as in the tests,
because a creature added later will be added by somebody who has not read the
tests.

The same record and seed engrave to the same bytes, which is what makes the second
half of the round trip a byte comparison rather than a judgement.

## Intended behaviour

One direction of the pair: **variables in, engraving out.** A program takes the
values it is holding and produces a new record log with the creature composed
around them.

### It is a separate program from the reader

They do not share code. This is the
[generate-then-view split](../../strategems/patterns-that-keep-working) in an
unusually literal form: the writer produces the artifact and the reader consumes
it as a stranger would, and neither can hide a bug inside the other.

Two implementations that share a parser agree with each other about their own
mistakes.

### What the file contains besides the picture

As little as possible, and all of it above the creature:

| Line | Why |
| --- | --- |
| a marker naming the format and its version | So a reader knows what it is holding before it starts. |
| which alphabet | Box-drawing or plain. A file that accepts either is a file where a corrupted character can hide. |
| the seed | So the creature can be regenerated and compared. |

Everything else is in the chambers. **No separate data block.** A file with the
numbers written twice — once in the picture and once in a header — is a file that
can disagree with itself, and then somebody has to decide which copy is right.

## Suggested implementation steps

1. A program that takes a record and a path and writes an engraving.
2. Values right-aligned in their chambers, labels left-aligned.
3. Refuse, by name, a value too wide for its chamber.
4. Write the companion `.info.md`.
5. Test: the same record and seed produce byte-identical files.
