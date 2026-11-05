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

The reader does not count changes. That is the fit check (105).

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

## Decisions (2026-11-05; each the owner's to overturn)

Questions met while building, answered here so the work could go on.

1. **The three header sets are called `to-voices`, `from-voice` and
   `for-viewers`**, and the reader takes the name as its argument.
2. **Only text that writes back the same way is accepted.** Numbers have no
   leading zeros (`018` is refused), there is one space after a header's
   colon, and voices are one space apart. So "read and written back byte for
   byte" holds for every canvas the reader accepts, apart from the two
   tidyings in decision 4.
3. **A row holds printable characters only.** A tab or any other control
   character is refused, because it has no agreed width and the fit check
   could not count it. Text that is not valid UTF-8 is refused too. Rows are
   counted in code points, as `docs/fit-check.md` says. Open question 4
   (terminal columns) stays open, and would change only `005-utf8.lua`.
4. **Two things are read but written back tidier:** trailing spaces in a row
   (the format lets a writer drop them) and a missing final newline. The
   writer always ends every line with a newline.
5. **Marks are of three kinds: `word`, `sentence` and `orphan`.** The issue's
   table listed two, and `docs/canvas-format.md` has the third for the
   `fade-fragments` rule. The document wins.
6. **Cuts are part of the record**, for a canvas to the voices only: nil when
   there is no `cuts:` section, an empty list when there is an empty one, and
   each written back as it came. A `cuts:` section in any other direction is
   refused.
7. **A voice's mark lines are counted, never read** (`ignored_marks`). The
   document says a voice's marks "are ignored and counted", so a malformed one
   doesn't refuse a voice's edit. Any other line there still does.
8. **The writer refuses a record it could not read back** (a row too long, a
   mark off the canvas, a missing or malformed header), so a mistake shows on
   the machine that made it. It writes `size` from `width` and `height`.
9. **The UTF-8 counting is its own file**, `005-utf8.lua`, shared with 103
   and 105 as step 1 asks. It refuses overlong encodings, surrogates and
   anything past U+10FFFF.
10. **`blank(width, height, set)`**, an empty record of a size, is added for
    the blitter to start from (107, step 1).
11. **`006` finds `005` beside itself**, not at the hard-coded root, so a copy
    of the project (a voice's, a test's) loads its own.

## Implementation notes (2026-11-05)

- `src/005-utf8.lua`: `length`, `split` and `pad`.
- `src/006-canvas-text.lua`: `read`, `write`, `blank`, `HEADERS`, `SETS` and
  `KINDS`.
- `src/007-test-canvas-text.lua`: 77 pass. The documents' three examples are
  made whole and written back byte for byte. There is one refusal for each
  kind of malformed canvas, each at its line, and the writer's refusals.
  Mutation checks (leading zeros, the control-character check, the trim,
  bytes for characters, header order) are each caught.
- A `.info.md` beside each source file. `.file-index-counter` is at 007.

**Checked here:** with LuaJIT 2.1 on Linux. This needs nothing of the owner's
machines.
