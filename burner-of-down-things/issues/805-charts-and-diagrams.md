# 805 — Charts and diagrams

The words `chart` and `diagram`: *lines drawn and arrows pointed there — here* ([067](../docs/067-datapath-the-studio.md), *charts and diagrams*).

## Current Behavior

805a-d are built as geometry (issues/completed/805a-bar-charts.md,
805b-line-and-dot-charts.md, 805c-diagrams-by-level.md,
805d-the-machine-drawn-by-itself.md): the `chart` word's bars, lines and
dots over one axis geometry (074); the `diagram` word laid out by levels
with 043's graph (134); and adapters from a blueprint, a center and a
ledger to those words (136). Nothing is painted yet: that waits on 804's
`.png` end, and a bar's midline flair on 801c.

## Intended Behavior

- `chart{ kind = "bars" | "lines" | "dots", data = {…}, labels = {…} }` over axes, each bar's midline in the flair.
- `diagram{ boxes = {…}, arrows = { { from = "a", to = "b", there = "…", here = "…" } } }`, laid out by levels like the blueprint graph (043).
- The machine's own things drawn first: a case's blueprint graph, its center, its ledger's totals.

## Suggested Implementation Steps

1. Charts. **Test:** bar heights in pixels are proportional to the data. Done as geometry (805a-b).
2. Diagrams by level. **Test:** a diamond of four boxes lays out in three columns; every arrow starts on its `from` box and ends on its `to` box. Done as geometry (805c).
3. The machine drawn by itself: the notes fixture's blueprint as a diagram. Done as geometry (805d); its `.png` waits on 804.

## Sub-issues

- 805a — bar charts
- 805b — line and dot charts
- 805c — diagrams by level
- 805d — the machine drawn by itself

## Blocked by

- 804
