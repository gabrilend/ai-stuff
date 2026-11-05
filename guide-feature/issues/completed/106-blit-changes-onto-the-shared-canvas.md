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

## Decisions (2026-11-05; each the owner's to overturn)

1. **Removals are checked against the canvas as the blit found it**, before
   any write, and only an exact whole word counts: the same text, starting at
   the same row and column.
2. **Each write sees the canvas just before it**, so a word written earlier
   in the same blit is a word like any other. Writes go in reading order.
3. **A word touching the written word with no space between is cut too**,
   with no letters lost. Otherwise the two would read as one glued word, a
   fragment by another name. `blank-whole` blanks it; `keep-fragments` leaves
   them run together, as a terminal would. The voice's own canvas had a space
   there, since that is where its word ended.
4. **The rule's contract:** `function(grid, cut, write, report)` → outcome,
   called after the write is in place, with `cut.cells` the columns the write
   took. `refuse-cut`, when it is picked, needs the write undone, so the
   contract may grow then.
5. **The report's counts use the receipt's names** (`words-written`,
   `cut-blanked`, ...), so the blitter (107) can add them to its goodbye as
   they are.
6. **The blit returns a new canvas** and leaves the current one as it was. It
   carries the headers and marks over, and doesn't mark. `changed` is false
   when no cell differs, so no version is made (step 5).
7. **A written word off the canvas is refused.** The fit check (105) has
   already held the voice's canvas to the size.
8. **`blank-whole` is the default**, and an unknown rule's name is refused
   with the names of those built.
9. **The test reads the kitten example from `docs/datapath-blit.md` itself**
   (corrected in 104), so the document and the blit can't drift apart.

## Implementation notes (2026-11-05)

- `src/014-blit.lua`: `apply`, `RULES` (`blank-whole`, `keep-fragments`),
  `DEFAULT_RULE`.
- `src/015-test-blit.lua`: 30 pass. Mutation checks (removal unchecked, the
  write's own cells blanked, the touch before the write ignored, cut words
  taken as covered) are each caught.
- A `.info.md` beside each source file. `.file-index-counter` is at 015.

**Checked here:** with LuaJIT 2.1 on Linux. This needs nothing of the owner's
machines.
