# 106 — Blit changes onto the shared canvas

phase 1, the canvas and the blit

## Current behavior

Nothing exists. The blit is designed in `docs/datapath-blit.md`, steps 2–3,
and the collision rules in "Collision rules" there.

## Intended behavior

The blit: the current canvas, a voice's changes (from 104) and the
collision rule's name in, the new canvas and a change report out.

1. **Removals**: a removed word is blanked only if the current canvas still
   holds exactly that word at that place. Otherwise another voice changed it
   after this voice's base, so it is left alone and counted as a conflict.
2. **Writes**, in reading order: the word's characters go into its cells. A
   word on the canvas (as it was before this write) that lost some but not all
   of its letters is a **cut word**, and is handed to the collision rule. A
   word that lost every letter is simply covered.

**Collision rules** are a table from rule name to a function that takes the
canvas, the cut word and the write, and changes the canvas. The owner
confirmed `blank-whole` as the default ("yes, but we probably want to play
around with it"). The other rules designed are `fade-fragments`,
`keep-fragments`, `refuse-cut`, `push-aside` and `blank-sentence`
(`docs/datapath-blit.md`). This issue builds the table, `blank-whole`, and
`keep-fragments`, the plain overwrite that the others are measured against.
Each further rule is added to the table as its own sub-issue once the owner
picks it.

The change report lists every cell written and blanked, each with the word
it belonged to, and every cut word with what the rule did to it. It also
counts words written, words cut (by rule outcome), removals applied, and
conflicts. Marks (201) and the tell-the-voice cut lines (303) are made from
this report. The blit itself does not mark.

## Suggested implementation steps

1. The cell-owner grid from 103 finds the words a write cuts.
2. The rule table, with `blank-whole` and `keep-fragments`.
3. Tests from the example in `docs/datapath-blit.md` (`the cat sat on the
   mat` + `kitten`, and `dog` over `kitten`) under both rules, and: a write
   exactly covering a word; a write spanning three words; a removal of a word
   another voice already changed; two writes in one blit that touch.

## Related documents

- `docs/datapath-blit.md`

## Open questions

- None left from the collision rules: the owner chose `fade-fragments`,
  `keep-fragments` and `push-aside` after `blank-whole`
  (`docs/datapath-blit.md`, "Collision rules").

## Blocked by

103, 104.

## Blocks

107, 201, 303.
