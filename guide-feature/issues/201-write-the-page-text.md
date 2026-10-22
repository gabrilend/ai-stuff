# 201 — Write the page text

phase 2, the page protocol

## Current behavior

Nothing exists. The page text is specified in `docs/page-protocol.md`.

## Intended behavior

A page writer: page record (106) in, page text out, exactly as specified:
header lines in order (`page`, `built`, `box`, `share`, `voices`,
`over-box`), one blank line, then one thought line per listed thought with
relevance written to exactly three decimal places.

The same text is used for the files, the HTTP answers, and the body of the
living rmail message to the voices. There is one writer, so the three can
never disagree.

## Suggested implementation steps

1. The writer.
2. A round-trip test against the page reader (202): every page the writer
   makes, the reader reads back to an equal record.
3. A test that the example in `docs/page-protocol.md` is produced byte for
   byte from its record, so the document and the code cannot drift apart.

## Related documents

- `docs/page-protocol.md`

## Blocked by

106.

## Blocks

202, 203, 303.
