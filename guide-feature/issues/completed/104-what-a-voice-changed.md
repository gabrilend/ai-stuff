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

## Decisions (2026-11-05; each the owner's to overturn)

1. **A fourth list, `overwritten`**: base words not kept whose cells in the
   voice's canvas aren't all spaces, so a written word covers some of them.
   They aren't changes of their own (`docs/datapath-blit.md`, step 1, leaves
   them to the overwrite rule), but naming them lets a test check that every
   base word lands in exactly one list.
2. **A moved word counts as written**, and its old place as overwritten or
   removed, as the document's rule by place says. So inserting a space early
   in a row moves, and counts, every word after it. That is also the right
   advice to a voice: change in place.
3. **A sentence counts as rewritten whole when none of its words was kept**:
   replaced or erased alike.
4. **A cell past the end of a row is a space**, so rows written without
   trailing spaces compare the same as padded ones.
5. **Canvases of different heights are refused**: they cannot be compared,
   and the fit check (105) reports the height first. Widths aren't checked
   here, since the fit check measures them.
6. **Either canvas records (006) or plain lists of rows are taken**, so the
   fit check can compare a model's reply before it is a canvas.
7. **`docs/datapath-blit.md`'s example was a column off.** "kitten" written
   over "cat" in `the cat sat on the mat` leaves `on` where it was, at column
   13, so the after-line has two spaces before it, not three. The document is
   corrected.

## Implementation notes (2026-11-05)

- `src/010-changes.lua`: `find`.
- `src/011-test-changes.lua`: 80 pass. It covers the issue's six cases and
  eight more, each checked on all four lists and both counts. Mutation checks
  (matching by place without text, any character counted as erased, removed
  words left out of the count, the sentence rule turned around) are each
  caught.
- A `.info.md` beside each source file. `.file-index-counter` is at 011.

**Checked here:** with LuaJIT 2.1 on Linux. This needs nothing of the owner's
machines.
