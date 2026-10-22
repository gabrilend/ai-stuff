# 202 — The Lua page reader

phase 2, the page protocol

## Current behavior

Nothing exists.

## Intended behavior

The page reader described in `docs/datapath-viewers.md`: page text in, page
record out, or an error naming the line that is wrong. Used by the thinker
(to read `inbox/the-page`) and by the Lua viewers. It is written against
`docs/page-protocol.md` only, not against the writer's code, so it is a
second, independent reading of the protocol.

## Suggested implementation steps

1. Header parsing by a table of field name to parser.
2. Thought lines split on the first three spaces. The rest is text.
3. Tests: the protocol document's example; one test per malformed page
   (missing header, bad relevance, line wider than the box, more lines than
   the box height).

## Related documents

- `docs/page-protocol.md`
- `docs/datapath-viewers.md`

## Blocked by

201.

## Blocks

206, 404, 601, 602.
