# 102 — The canvas as text

phase 1, the canvas and the blit

## Current behavior

Nothing exists. The format is designed in `docs/canvas-format.md`.

## Intended behavior

One canvas reader and one canvas writer, used by every program in the
project (blitter, turn, viewers):

- **reader**: text in, canvas record out, or an error naming the line that
  is wrong. Which header set to expect (to voices, from a voice, for viewers)
  is an argument.
- **writer**: canvas record in, text out, rows written without trailing
  spaces.

The canvas record:

| Field | Type |
|---|---|
| headers | table from header name (string) to value. Values are parsed: whole numbers as numbers, `size` as width and height, `project` as name and commit |
| width, height | whole numbers |
| rows | list of `height` strings, each at most `width` code points, padded to exactly `width` with spaces once read |
| marks | list of records: row, column, length, version (whole numbers), voice (string), kind (`word` or `sentence`) |

Headers are parsed with a table from header name to its position and value
parser, not a chain of if-else. Any missing, repeated, unknown or
out-of-order header, a wrong row count, or a row that is too long is an error
naming the line.

The reader does not check the change budgets. That is the fit check (105).

## Suggested implementation steps

1. UTF-8 code-point counting, shared with 103 and 105.
2. Reader and writer.
3. Tests: each example in `docs/canvas-format.md` read and written back byte
   for byte; one test per kind of malformed canvas.
4. A `.info.md` beside the source file.

## Related documents

- `docs/canvas-format.md`

## Blocked by

None.

## Blocks

103, 107, 201, 202, 403, 405.
