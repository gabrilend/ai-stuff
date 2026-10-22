# 106 — Lay out the page in the box

phase 1, the fit and the fade

## Current behavior

Nothing exists. The layout is designed in `docs/display-box.md` and the
ordering in `docs/page-protocol.md`, "Thought lines".

## Intended behavior

From the thought ledger (105), the current box and the list of voices, build
the page record: the newest frames (at most `share` height rows per voice,
in voice order), then the fading thoughts by relevance until the box is full.
A voice whose current frame is taller than its share after the box shrank is
listed in `over-box`. Only the rows that fit are listed, and the hidden rows
are counted.

The page record is data only. Turning it into text is 201's job.

Decides whether the page changed: a new page number is taken only when the
listed thoughts or their relevance numbers (to three decimal places) differ
from the previous page.

## Suggested implementation steps

1. Box arithmetic comes from the fit check module (103).
2. Build the two groups. Sort the fading group by relevance, then voice
   order, then frame order.
3. Tests: every thought fits; the fading rows overflow; the box shrinks
   under a voice's frame; no frame yet from one voice.

## Related documents

- `docs/display-box.md`
- `docs/page-protocol.md`

## Open questions

- How a frame that no longer fits a shrunken box is shown
  (`docs/open-questions.md`, 6).

## Blocked by

103, 105.

## Blocks

107, 201.
