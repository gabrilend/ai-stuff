# 102 — Read and check a frame

phase 1, the fit and the fade

## Current behavior

Nothing exists. The frame format is designed in `docs/frame-format.md`.

## Intended behavior

A frame reader: frame text in (string), frame record out, or an error that
says exactly what is wrong. The record:

| Field | Type |
|---|---|
| voice | string |
| frame | whole number |
| after page | whole number |
| fitted to | width and height, whole numbers |
| written | string, UTC time |
| thoughts | list of strings, one per non-empty line |

Headers must appear once each, in the documented order. Anything missing,
repeated, out of order or unknown is an error naming the line. The reader
does not check the box. That is the fit check's job (103), so the two can be
tested and changed separately.

A second function checks a record against the voice's previous record and
returns one of: `next` (frame number is one more), `skipped N` (rmail
dropped N intermediate edits, counted not refused), or `went backwards`
(an error: the thinker lost its state).

## Suggested implementation steps

1. Parse the headers with a table that maps each header name to its position
   and value parser, instead of a chain of if-else.
2. Split thoughts on newlines and drop empty lines.
3. Tests with one good frame and one test per kind of malformed frame, using
   the examples in `docs/frame-format.md`.

## Related documents

- `docs/frame-format.md`

## Blocked by

None.

## Blocks

105, 107, 406.
