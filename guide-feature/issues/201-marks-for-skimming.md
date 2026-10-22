# 201 — Marks for skimming

phase 2, the canvas for viewers

## Current behavior

The blit (106) reports which cells it wrote and blanked. Nothing records
that on the canvas.

## Intended behavior

The owner: "This should enable users to skim, and see the changed sections
from all three. So, if on the previous turn one of the mini-computers
changed the phrasing on a sentence, that sentence would be marked as
'changed'."

The marker, run by the blitter after each blit, as one of its publishers'
first steps:

- every cell in the blit's change report gets a `word` mark with the voice
  and the new version;
- the other cells of every sentence (103) holding a marked word get a
  `sentence` mark with the same voice and version;
- a newer mark replaces an older one on the same cell;
- marks older than the mark lifetime (a setting, in versions) are dropped.

Marks are kept per cell in the blitter and written as runs (row, column,
length) in the canvas text (`docs/canvas-format.md`).

## Suggested implementation steps

1. A per-cell mark grid, and turning runs of equal marks into mark lines.
2. Tests: a one-word change marks that word and its sentence; a newer
   change by another voice replaces part of an older sentence mark; marks
   expire.

## Related documents

- `docs/canvas-format.md`, "Marks"
- `docs/datapath-blit.md`, step 4

## Blocked by

102, 103, 106.

## Blocks

202, 203.
