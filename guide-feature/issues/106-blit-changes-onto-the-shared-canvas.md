# 106 — Blit changes onto the shared canvas

phase 1, the canvas and the blit

## Current behavior

Nothing exists. The blit is designed in `docs/datapath-blit.md`, steps 2–3.

## Intended behavior

The blit: the current canvas and a voice's changes (from 104) in, the new
canvas and a change report out.

1. **Removals**: a removed word is blanked only if the current canvas still
   holds exactly that word at that place. Otherwise another voice changed it
   after this voice's base, so it is left alone and counted as a conflict.
2. **Writes**, in reading order: the word's characters go into its cells.
   Then any word on the canvas (as it was before this write) that lost some
   but not all of its letters is blanked entirely, so no fragment of a word is
   left. A word that lost every letter is simply covered.

The change report lists every cell written and every cell blanked, each with
the word it belonged to, and counts: words written, words blanked by the
whole-word rule, removals applied, conflicts. Marks (201) are made from
this report. The blit itself does not mark.

## Suggested implementation steps

1. The cell-owner grid from 103 finds the words a write cuts into.
2. Tests built from the example in `docs/datapath-blit.md` (`the cat sat on
   the mat` + `kitten`), and: a write that exactly covers a word; a write
   spanning three words; a removal of a word another voice already changed;
   two writes in one blit that touch.

## Related documents

- `docs/datapath-blit.md`

## Open questions

- Is the whole-word rule read correctly? (`docs/open-questions.md`, 1)

## Blocked by

103, 104.

## Blocks

107, 201.
