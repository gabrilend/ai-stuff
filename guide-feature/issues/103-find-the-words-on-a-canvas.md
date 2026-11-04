# 103 — Find the words on a canvas

phase 1, the canvas and the blit

## Current behavior

Nothing exists.

## Intended behavior

The word finder: canvas rows in, list of words out. A word is a run of
characters with no space in it. Each word is a record:

| Field | Type |
|---|---|
| row | whole number, 1 to H |
| column | whole number, the column of its first character, 1 to W |
| length | whole number of characters |
| text | string |

Also:

- **cell owner**: for a canvas, a grid saying which word (by its place in
  the list) covers each cell, or none. The blit (106) uses it to find words
  a write cuts into.
- **sentences**: the words in reading order, grouped into sentences. A
  sentence ends after a word ending in `.`, `!` or `?`, or at an entirely
  empty row (`docs/canvas-format.md`). Each sentence is a list of word
  numbers. Marks (201) use it.

Words never wrap across rows. A word that reaches the end of a row ends
there.

## Suggested implementation steps

1. Scan each row by code point, using the counting from 102.
2. The cell grid and the sentence grouping.
3. Tests: words at the row edges, multi-byte characters, a row of only
   spaces ending a sentence, punctuation inside a word (`e.g.`).

## Related documents

- `docs/datapath-blit.md`, "Words"
- `docs/canvas-format.md`, "Marks"

## Blocked by

102.

## Blocks

104, 106, 201.
