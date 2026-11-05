# 012-fit-check — info

The check every edited canvas passes before it goes anywhere (issue 105,
`docs/fit-check.md`). Used by a voice's turn before sending (404), by the
blitter on arrival (size only, 107), and by the distiller (601).

It measures and reports. It never trims or mends a reply: a cut reply is
only ever shown to a model, by the turn (404), never made here.

## The reply

The model's reply is the canvas's rows as text. A line ends at `\n` or
`\r\n`, and a final line ending doesn't start another row. Nothing else is
taken away, so an extra blank line at the end is a row, and the model is told
it has one row too many.

## Problems

| Kind | Fields | The line the model reads |
|---|---|---|
| `wrong-height` | measured, allowed | `the canvas has 22 rows; it must have exactly 20` |
| `too-wide` | row, measured, allowed | `row 7: 64 characters, 4 over the width of 60` |
| `bad-character` | row, column (a control character) or byte (not UTF-8) | `row 4: a tab or other control character at column 2; use spaces` |
| `wrong-width` | measured, allowed (on arrival only) | `the canvas is 64 characters wide; it must be exactly 60` |

The height comes first, then each row in order. `LINES` is the table from
kind to its line.

## The counts and the note

`counts` (`words_changed`, `sentences_rewritten`) come from the change finder
(104) whenever the reply has the right number of rows of readable text, even
if a row is too wide, so the log can show what a misfit tried. The note is
written only when either count is over its recommendation. It never refuses a
reply: the owner made the budget soft. "1 word" and "1 whole sentence" are
singular.

| Name | Type | Meaning |
|---|---|---|
| `check(reply, base, recommended)` | function | `{ fits, rows (padded, when it fits), problems (when not), counts, note }`. `recommended` is `{ words, sentences }`, whole numbers |
| `report(problems, width, height)` | function | the text the model is given: `the canvas does not fit:`, one line per problem, then the closing line, word for word as the document has it |
| `advice(counts, recommended)` | function | the advisory note, or nil |
| `arrival(voice, base)` | function | the blitter's size-only check: problems, empty when the sizes agree |
| `lines_of(text)` | function | a reply's rows |
| `LINES` | table | kind to its report line |

Tests: `013-test-fit-check.lua`.
