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
- marks older than the mark lifetime (a setting, in versions) are dropped;
- when the collision rule leaves fragments to fade (`fade-fragments`), their
  cells get `orphan` marks, and when an orphan mark outlives the orphan
  lifetime its cells are blanked. That makes a new version marked as
  changed by `kuvalu`.

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

## Decisions (2026-11-05; each the owner's to overturn)

1. **Marks are made inside the blitter's publish step, before any
   publisher**, not by a publisher in the list. That way every publisher
   (the log now; files in 203; rmail in 303) is handed the version with its
   marks, and a caller's own publisher list can't leave them out.
2. **A `sentence` mark lies on the sentence's words only**, not on the
   spaces between them, as `docs/datapath-blit.md` says ("the other words of
   each sentence").
3. **A blanked cell that is in no word now** belongs to the sentence of
   the word before it on its row, unless that word ends its sentence.
   Otherwise it belongs to the sentence of the word after it on its row.
   - So a word erased mid-sentence marks its sentence.
   - A first word erased after a full stop marks the sentence that follows,
     not the one before.
   - A last word erased marks the sentence it now runs on into.
   - A word erased that leaves its row empty gets its word mark only.

   `docs/canvas-format.md` now says this.
4. **Age is the version minus the mark's version.** A mark is dropped once
   its age is *more than* `mark-lifetime`. So with 12, a mark shows on its
   own version and the 12 after it, and with 0 only on its own version.
   `mark-lifetime` is read again on every arrival, like the other settings
   except the size.
5. **Age counts versions, not time.** `docs/canvas-format.md` said "a canvas
   that stops changing ends with no marks"; that only holds while other
   parts keep changing. The document now says that a canvas where nothing
   changes at all keeps its last marks.
6. **A newer mark of any kind replaces an older one on its cell.** So a
   newer `sentence` mark replaces an older `word` mark, as the canvas
   format says: "a cell has at most one mark: the newest".
7. **Orphans:** `fade-fragments` isn't built, so no blit makes them yet.
   The marker already marks `report.orphans` cells and lists those whose
   mark runs out. The blitter stops on an expired orphan rather than
   ignoring it. The orphan lifetime setting and the `kuvalu` version that
   blanks the cells come with `fade-fragments`.
8. **Counts are in cells:** `cells-marked-word`, `cells-marked-sentence`
   and `marks-expired` in the receipt, and a `marks:` line in the log for
   each version (cells word, cells sentence, expired, runs). These are the
   numbers the phase 2 demo (206) shows.
9. **Version 1, the empty canvas, has no marks.**

## Implementation notes (2026-11-05)

- `src/020-marks.lua`: `mark`, `grid`, `runs`, `age`.
- `src/016-blitter.lua`: `publish` marks each new version and counts and
  logs the marks.
- `src/021-test-marks.lua`: 32 pass. `src/017-test-blitter.lua` now leaves
  the marks' counters to 021.
- Mutation checks were each caught:
  - expiring a version early;
  - blanked cells unmarked;
  - a full stop ignored for a blank cell's sentence;
  - the next word taken from any row;
  - runs merged across voices;
  - sentence marks over the word marks;
  - expired orphans not listed;
  - the blitter dropping marks;
  - the blitter ignoring the lifetime.

  Two mutants are equivalent:
  - letting fresh marks expire: an age of 0 is never over a lifetime of 0
    or more;
  - a rule for a gap whose two sides share a sentence: the before and
    after rules always give the same answer, so it was removed.
- `.file-index-counter` is at 021.

**Needs the owner's machine:** nothing beyond the blitter's own (107).
