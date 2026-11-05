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

## Decisions (2026-11-05; each the owner's to overturn)

1. **Only the space character separates words.** The canvas reader (102)
   already refuses tabs and other control characters, so there is nothing
   else that could.
2. **A sentence's end looks past closing quotes and brackets**: `"go."`,
   `(left!)` and `“yes?”` each end one. Without this, quoted speech would run
   on into the next sentence.
3. **A word ending in `.` always ends a sentence, abbreviation or not**
   (`e.g.` does). The document's rule is about the end of a word, and a list
   of abbreviations would be one more thing to keep. A full stop inside a
   word (`3.14`, `e.g` without its last stop) ends nothing.
4. **The last words of a canvas are a sentence** even without a full stop,
   so every word belongs to one. Several empty rows in a row make no empty
   sentences.
5. **`sentences` also returns `sentence_of`**, each word's sentence number,
   because the marks (201) and the change finder's count of sentences
   rewritten whole (104) both ask that question of a word.
6. **`owners` refuses a word that doesn't fit the size**, rather than
   drawing part of it, since the blit trusts the grid.
7. **`of_canvas(record)`** gives all three for a canvas read by 102.

## Implementation notes (2026-11-05)

- `src/008-words.lua`: `find`, `owners`, `sentences`, `ends_sentence`,
  `of_canvas`.
- `src/009-test-words.lua`: 34 pass, covering each case the issue names. Four
  mutation checks are each caught: closers ignored, empty rows not ending a
  sentence, the grid one cell too wide, and bytes counted for characters.
- A `.info.md` beside each source file. `.file-index-counter` is at 009.

**Checked here:** with LuaJIT 2.1 on Linux. This needs nothing of the owner's
machines.
