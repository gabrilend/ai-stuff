# 006-canvas-text — info

The one reader and the one writer of the canvas as text
(`docs/canvas-format.md`), in all three directions it travels. Issue 102 is the
blueprint.

## The header sets

| Set | Direction | Headers, in order |
|---|---|---|
| `to-voices` | kuvalu → voices (`the-canvas`) | canvas size mode project endpoint written |
| `from-voice` | a voice → kuvalu (`canvas`) | voice turn base size written |
| `for-viewers` | kuvalu → viewers | canvas size mode project written voices |

`HEADERS` is a table from header name to its value's reader, its writer and a
description for refusals. `SETS` gives each set's order. There is no if-else
chain.

## The record

| Field | Type |
|---|---|
| `set` | the header set it was read with |
| `headers` | name to parsed value: `size` as `{ width, height }`, `project` as `{ name, commit }`, `endpoint` as `{ name, address }`, `voices` as a list, the rest as numbers or text |
| `width`, `height` | whole numbers, from `size` |
| `rows` | `height` strings, each padded to exactly `width` characters |
| `marks` | list of `{ row, column, length, voice, version, kind }`, kind `word`, `sentence` or `orphan` |
| `cuts` | to-voices only: nil when there is no `cuts:` section, else a list of `{ voice, version, row, column, text }` |
| `ignored_marks` | from-voice only: how many mark lines the voice sent. A voice's marks are counted, never read, so a malformed one cannot refuse its edit |

## Exactly back

Only text the writer would write the same way is accepted: numbers without
leading zeros, one space after each header's colon, voices one space apart.
So read-then-write gives back the same bytes. Two things are read but written
tidier: trailing spaces in a row (the format lets a writer drop them), and a
missing final newline. The writer refuses a record that could not be read
back (a row too long, a mark off the canvas, a header missing or malformed),
so a mistake shows on the machine that made it.

## Refusals

Every refusal is a Lua error starting with the source and line:
`the-canvas:15: row 9 holds a control character (byte 6, code 9) ...`.
Refused: a missing, repeated, unknown or out-of-order header, a malformed
value, a canvas ending inside its headers or rows, a row too long (counted in
characters, `005-utf8.lua`), not valid UTF-8, or holding a control character
(a tab has no agreed width), too few or too many rows, no `marks:`, a
malformed mark or cut, and a `cuts:` section anywhere but in a canvas to the
voices. When a row reads `marks:` and the rows ran short, the refusal says so.

## Also

`blank(width, height, set)`: an empty record of a size, rows of spaces, for
the blitter to start from (107).

It finds `005-utf8.lua` beside itself rather than at the hard-coded root, so
a copy of the project loads its own.

Tests: `007-test-canvas-text.lua`.
