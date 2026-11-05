# 105 — The fit check that reports like a compiler

phase 1, the canvas and the blit

## Current behavior

Nothing exists. The check is designed in `docs/fit-check.md`.

## Intended behavior

One shared module, used by the turn (before sending), the blitter (size
only, on arrival) and the distiller:

- **in**: the model's reply text, the base canvas, and the recommended
  change counts (words per turn, whole sentences per turn, whole numbers);
- **out**: either the reply read as rows that fit, or a list of problems.
  Each problem is a record of kind (`too-wide`, `wrong-height`), row (whole
  number, if any), measured and allowed (whole numbers). Alongside either,
  the change counts (words changed, whole sentences rewritten, whole
  numbers) for the advisory note. The change counts never refuse a reply:
  the owner made the limit soft (`docs/fit-check.md`, "The change budget is
  soft");
- **report**: the problems as the text the model is given, one line per
  problem then the closing line restating the limits, word for word as in
  `docs/fit-check.md`.

The module never trims a reply. It only measures and reports. Change counts
come from the change finder (104), so the fit check and the blitter can
never disagree about what changed.

## Suggested implementation steps

1. Size checks, the change counts, the report, the advisory note.
2. Tests: a reply that fits; one per kind of problem; several at once; the
   report text checked word for word, since it is what the model reads.

## Related documents

- `docs/fit-check.md`

## Open questions

- Characters or terminal columns (`docs/open-questions.md`, 4).

## Blocked by

104.

## Blocks

107, 404, 601.

## Decisions (2026-11-05; each the owner's to overturn)

1. **The reply is the canvas's rows as text.** A line ends at `\n` or
   `\r\n` (some servers send those), and a final line ending doesn't start a
   row. Nothing else is taken away: an extra blank line at the end is a row,
   and the model is told it has one too many. The module never trims.
2. **A third kind of problem, `bad-character`**: a tab or other control
   character, or bytes that aren't UTF-8. Such a row has no width to measure,
   and the canvas reader (102) would refuse it, so it must go back to the
   model like any misfit. Its line is `row 4: a tab or other control
   character at column 2; use spaces`.
3. **Problems are ordered with the height first, then by row**, since a
   wrong height is about the whole canvas.
4. **The counts are given whenever the reply has the right number of rows of
   readable text**, even when a row is too wide, so the log can show what a
   misfit tried. Otherwise they are nil: it can't be compared with its base.
5. **The advisory note is written only when a count is over its
   recommendation**, the document's "a canvas over the recommendation".
   "1 word" and "1 whole sentence" are singular, and the note is one line.
6. **The closing line is one line.** The document wraps it for reading, and
   the test compares wording, not line breaks.
7. **The blitter's check on arrival is `arrival(voice, base)`**: the size
   only, as the document says. It adds `wrong-width`, `the canvas is 64
   characters wide; it must be exactly 60`, since a voice's canvas declares
   its width and the reader has held its rows to it.
8. **The cut copy for a reply too large belongs to the turn (404)**, which
   shows it to the model. Making it here would break "the module never trims
   a reply".
9. **The recommended counts are required whole numbers**; the knobs live in
   `input/turn` (403, 404).

`docs/fit-check.md`'s table gains `bad-character`, and a note on
`wrong-width` on arrival.

Open question 4 (characters or terminal columns) stays open; width is
counted in code points by `005-utf8.lua`, the one place it would change.

## Implementation notes (2026-11-05)

- `src/012-fit-check.lua`: `check`, `report`, `advice`, `arrival`,
  `lines_of`, `LINES`.
- `src/013-test-fit-check.lua`: 37 pass. The report and the note are checked
  word for word against the document itself. Six mutation checks are each
  caught: bytes for characters, the closing's wording, sentences ignored in
  the note, `\r` kept, a misfit given rows, and plurals.
- A `.info.md` beside each source file. `.file-index-counter` is at 013.

**Checked here:** with LuaJIT 2.1 on Linux. This needs nothing of the owner's
machines. A real model reading these reports is 404's step 2, on kuvalu.
