# 104 — What a voice changed

phase 1, the canvas and the blit

## Current behavior

Nothing exists. The comparison is designed in `docs/datapath-blit.md`,
step 1.

## Intended behavior

The change finder: a base canvas and a voice's canvas in, three lists out:

- **kept**: words with the same text at the same row and column in both;
- **written**: words in the voice canvas that are not identically in the
  base;
- **removed**: words in the base that are not identically in the voice
  canvas, and whose cells in the voice canvas are all spaces.

Plus counts used by the fit check (105): words changed (written plus
removed), and sentences rewritten whole (sentences of the base in which no
word was kept).

The owner chose that a voice's changes are measured against the version it
started from (its base), not against the current shared canvas. So this
function never sees the current canvas. The blit (106) does.

## Suggested implementation steps

1. Index the base's words by row and column, then walk the voice's words.
2. Tests: no change; one word replaced; a word moved one column; a word
   erased; a whole sentence rewritten; a word overwritten by a longer one.

## Related documents

- `docs/datapath-blit.md`

## Blocked by

103.

## Blocks

105, 106.
