# 1005 -- The reader reads the picture, not the format

**Phase:** 10, the engraving
**Blocked by:** [1004](1004-the-writer-composes-the-creature.md)
**Blocks:** [1006](1006-intentionally-fragile.md)
**Documents:** [the record log is an engraving](../../docs/018-the-record-log-is-an-engraving.md)

## Current behaviour

**Done.** `097-read-engraving`, and `100-read-engraving` as a program.

It scans the characters, finds rectangles that walls enclose, and reads a label
and a number out of each. It does not know which creature it is looking at.

**The alphabet is described differently on purpose.** The writer holds one table
of sixteen rows indexed by four stroke bits; this holds four sets of characters,
one per direction, and asks whether a glyph carries a stroke to the right. Two
formulations of the same knowledge, so a mistake in one does not mirror a mistake
in the other — which is the entire reason for writing the pair twice.

The scan is geometric rather than character-shaped, forced by the plain alphabet
where a plus sign is every junction there is. A chamber is four unbroken walls,
exactly four rows tall, with **no stroke anywhere inside** — that last condition is
what stops two chambers side by side reading as one wide one.

Both halves of the round trip are tested, across all four creatures and both
alphabets.

### The bug that justified the whole arrangement

`take_text` truncated quietly when its buffer filled. The buffers were sized to the
label, and a chamber's interior is as wide as the wider of its label and its value
plus padding — so "rollbacks" came back as "rollback" and a sixteen-digit checksum
as fifteen.

The failure surfaced two layers away as *this carving has no chamber labelled
rollbacks*: a true sentence pointing at entirely the wrong thing. It now returns 0
rather than truncating, and the refusal says the chamber is wider than any chamber
a record has.

## Intended behaviour

The other direction: **engraving in, variables out.**

### It walks the carving

The reader does **not** know which creature it is looking at, does not know the
tiling rule, and does not ask the writer anything. It scans the characters, finds
the rectangles that box-drawing characters enclose, and pulls the label and the
number out of each one.

That is the strongest form the independence can take. The writer could get the
anatomy wrong in a way that still produced a valid tiling, and the reader would
not care, because the reader is reading **what is on the page** rather than what
the writer meant to put there.

It also makes the format self-describing. A creature nobody has written a rule
for yet still reads, as long as its chambers are chambers.

### The round trip is the test and it has two halves

| Half | What it catches |
| --- | --- |
| Write values, read them back, compare the values. | A writer that draws a number in the wrong place. |
| Write again from what was read, compare the two files byte for byte. | A reader that recovers a value by accident — from the header, from a default, from the wrong chamber. |

Anything that fails either half is a carving that cannot be trusted to be a
record.

## Suggested implementation steps

1. Find every rectangle enclosed by strokes, by scanning for corners and
   following walls.
2. Read the label and the value out of each.
3. Refuse, naming the row and column, anything that is not a closed rectangle.
4. Write the companion `.info.md`.
5. Test both halves of the round trip, across every creature and a wide range of
   values.
