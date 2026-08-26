# 096-engrave

Variables in, engraving out. One direction of a pair.

## It shares no code with the reader

Not a parser, not a character table, not a helper. What the two share is the
**contract** — the list of cell labels in [090-record](090-record.info.md) — and
nothing else.

Two implementations that share a parser agree with each other about their own
mistakes. That sentence is only worth having if it is true without exceptions,
because the moment there is one there is an argument about the second.

## What the file contains besides the picture

Three lines, all above the creature.

```
vtt-engraving 1
alphabet carved
seed B8AB04FBE3AD6049
```

| Line | Why |
| --- | --- |
| the marker and version | So a reader knows what it is holding before it starts. |
| the alphabet | A file that accepts either is a file where a corrupted character can hide. |
| the seed | So the creature can be regenerated and compared byte for byte. |

**No separate data block.** A file with the numbers written twice — once in the
picture and once in a header — is a file that can disagree with itself, and then
somebody has to decide which copy is right.

## It refuses rather than truncating

| Refusal | Because |
| --- | --- |
| a value wider than its chamber | A truncated checksum is a number that looks like a number and is not one. The sentence names the cell, the text, and both widths. |
| an alphabet that is neither | |
| a creature that would not fit a canvas | |
| ornament crossing a wall | The reader follows walls; a hole is a hole it falls through. Checked here as well as in the tests, because a creature added later will be added by somebody who has not read the tests. |
| a buffer too small | Half a carving is not a smaller picture, it is a file with walls missing. |

## Functions

| Function | Takes | Gives |
| --- | --- | --- |
| `engrave_to_text` | a record, an alphabet, a buffer | the length, or 0 with a sentence |
| `engrave_to_file` | a record, an alphabet, a path | 1, or 0 with a sentence naming the file |

## As a program

`099-engrave <path> [--seed <hex>] [--plain] [--beats N] [--turns N] ...`

Named values so a person can engrave a specific record by hand. Everything
unnamed keeps a small default rather than zero, because a carving of all zeroes
says nothing about whether the widths are right.

## Related

- [097-read-engraving](097-read-engraving.info.md) — the other direction
- issue [1004](../issues/completed/1004-the-writer-composes-the-creature.md)
