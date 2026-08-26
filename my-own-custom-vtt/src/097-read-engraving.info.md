# 097-read-engraving

Engraving in, variables out. The important thing about it is what it does not
know.

## It walks the carving

It does not know which creature it is looking at, does not know the tiling rule,
and does not ask the writer anything. It scans the characters, finds the
rectangles that walls enclose, and pulls the label and the number out of each one.

That is the strongest form the independence can take. The writer could get the
anatomy wrong in a way that still produced a valid tiling, and this would not
care, because it is reading **what is on the page** rather than what the writer
meant to put there.

It also makes the format self-describing: a creature nobody has written a rule for
yet still reads, as long as its chambers are chambers.

## The alphabet is described differently on purpose

The writer holds one table of sixteen rows indexed by four stroke bits. This holds
four **sets of characters**, one per direction, and asks "does this glyph carry a
stroke to the right".

Two formulations of the same knowledge, so that a mistake in one does not mirror a
mistake in the other — which is the entire reason for writing the pair twice.

## The scan is geometric, not character-shaped

The plain alphabet cannot tell a corner from a crossing — a plus sign is every
junction there is — so nothing may depend on the *shape* of a character, only on
which directions it carries.

A chamber is found by: a position carrying strokes right and down; a position to
its right on the same row that turns down; four walls unbroken between them; a
height of exactly four rows; and **no stroke anywhere inside**. That last one is
what stops two chambers side by side being read as one wide one.

## Both halves of the round trip

| Half | What it catches |
| --- | --- |
| Write values, read them back, compare the values. | A writer that draws a number in the wrong place. |
| Write again from what was read, compare the two files byte for byte. | A reader that recovers a value by accident — from the header, from a default, from the chamber next door. |

A reader that guessed right once will guess the same way twice. Only the bytes
notice.

## It is fragile on purpose, and never quietly

Every refusal carries a row, a column and a sentence, because the person reading
it is going to go and look at that spot in a text editor.

`take_text` **returns 0 rather than truncating**, and that distinction cost an
afternoon: an earlier version stopped quietly when the buffer filled, so
"rollbacks" came back as "rollback" and a sixteen-digit checksum as fifteen — and
the failure surfaced two layers away as *this carving has no chamber labelled
rollbacks*, which is a true sentence pointing at entirely the wrong thing.

## Reading and being a record are separate questions

`engraving_read_text` answers "is this a well-formed carving". `engraving_to_record`
answers "does it hold the eight cells a record needs". A creature somebody drew by
hand may well answer the first and not the second, and the refusal has to say
which one failed.

## Functions

| Function | Gives |
| --- | --- |
| `engraving_read_text` / `engraving_read_file` | 1, or 0 with the fault located |
| `engraving_to_record` | the eight numbers, or 0 with a sentence |
| `engraving_error_sentence` | the fault as one line |

## As a program

| Invocation | Does |
| --- | --- |
| `100-read-engraving <path>` | prints the values |
| `100-read-engraving <path> --check` | says nothing; the exit status is the answer |
| `100-read-engraving <path> --cells` | prints the chambers as they were found, before anything decides whether they amount to a record |

## Related

- [096-engrave](096-engrave.info.md) — the other direction
- [098-test-engraving](098-test-engraving.c) — both halves of the round trip
- issues [1005](../issues/completed/1005-the-reader-reads-the-picture.md),
  [1006](../issues/completed/1006-intentionally-fragile.md)
