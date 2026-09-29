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

801b-d, 807b-d, 805b-d, and 809b and 809d remain: overrides and the
flair's colour math, lists/trees/box-diagrams/prose, line-and-dot charts
and diagrams by level and the machine drawing itself, and safe concurrent
appends and floors.
