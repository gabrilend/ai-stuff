# Phase 8 Progress

## Goals
The studio: asset generation utilities for .png, .mp4, .txt and source files, painting in the owner's look (raylib lines and surfaces, dark grounds, the four-quarter flair on midlines, charts and diagrams with arrows there — here), every asset kept in a pool with a card and a tier. Ends with the machine drawing itself (docs/067).

Counts: run `/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/burner-of-down-things -m`.

## Completed Issues
- 801a the look table — the owner's style as one Lua table (`ground`,
  `flair`, `line_weight`, `arrow`), `palette` resolved from `ground` rather
  than stored, checked against docs/067's own words so the two cannot drift.
- 807a tables — the `.txt` end's first word: columns padded to their widest
  cell, measured in characters rather than bytes.
- 805a bar charts — the `chart` word's geometry: bar heights in pixels,
  proportional to their data, still unpainted (804) and unflaired (801c).
- 809a card schema — the pool's card: what an asset is, its category and
  parameters, its seed, its paintbrush, its canvas, and an empty ratings
  list, written beside the asset through 014's neighbour-file-and-rename
  writer. The pool's own folder (`project.pool`) is kept in the project,
  outside git, per open question 13's stated default.

- 809c the count utility — per-category counts read from `.card` files
  alone, never an asset; per-tier counting waits on 809b's rating format.
- 801b canvas overrides — a canvas's own look, `defaults()` with named
  fields laid on top; an unknown field is refused before any of it merges.
- 807b lists and trees — `list` (flat, bulleted) and `tree` (nested,
  indented, no bullets — a deliberate contrast), joined into 807a's file.

- 809b concurrent append — ratings appended one line at a time to a
  `.ratings` file beside the card, safe under two writers at once; a
  person's latest rating is the asset's tier (else a machine's), and the
  count utility now counts per tier too.

- 809d floors — a floor per category (0 until raised) as a text table in
  the pool; raising one says first how many assets it keeps in use and how
  many fall below it, and deletes nothing.

- 810 the viewer, without its window — the gallery (exactly what the
  count utility counts), ratings by key, floors proposed with their cost
  and set only on `y`, and each frame as a draw list, all checked with no
  display (docs/010 question 11, answered). The raylib window waits on
  raylib in `libs/`.

801c-d, 807c-d and 805b-d remain: the flair's colour math and the
night-only palette rule; box diagrams and prose templates; line-and-dot
charts, diagrams by level and the machine drawing itself.
