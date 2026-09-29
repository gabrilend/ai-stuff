# Phase 10 Progress

## Goals
The story: each case's ledger told back as chapters in plain words, the lessons drawn from its turning points, and strategems drafted when a mechanism recurs (docs/069).

Counts: run `/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/burner-of-down-things -m`.

## Completed Issues
- 1002a the lesson schema — a lesson's own fields, and the shape check on
  `mechanism` (a short, single-line sentence); the fuller mood-vs-
  mechanism judgement is 1002c.
- 1001a the turn kind — `storyteller` in the turn-kinds table: reads only
  the ledger and `input/`, writes only the story file, never the source.
- 1003a the recurrence trigger — a mechanism counted at least twice and
  not yet drafted is due for a strategem, taken from any counts table
  shaped like 1002d's own output.

- 1002d mechanism counting — counts an array of already-built lesson
  records rather than reading `lessons.md` (1002b was not yet built at the
  time); proved to feed 1003a's trigger unchanged, the second example of
  strategems/build-to-the-shape-not-the-neighbor.md.
- 1002b append-only write — one lesson, one Markdown section, appended in
  a single write; never opens the file for reading, never rewrites what
  is already there. No reader exists yet; 1002d's own note says it can
  take this file, parsed, unchanged, once one is built.

1002c, 1001b-d, 1003b-d and all of 1004 remain: the fuller mood-vs-
mechanism refusal; segmenting the ledger into chapters, never telling a
line twice, naming whose each thing was; the draft form, its folder and
the person's own promotion gate; and the phase 10 demo, which cannot be
built until the story and lessons it shows exist end to end.
