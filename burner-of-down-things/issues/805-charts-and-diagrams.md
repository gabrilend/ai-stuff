# 805 — Charts and diagrams

The words `chart` and `diagram`: *lines drawn and arrows pointed there — here* ([067](../docs/067-datapath-the-studio.md), *charts and diagrams*).

## Current Behavior

The `.png` end draws single lines, surfaces and arrows. 805a is built
(issues/completed/805a-bar-charts.md): the `chart` word's bar geometry,
unpainted until 804 and unflaired until 801c. 805b (line and dot charts),
805c (diagrams by level) and 805d (the machine drawn by itself) are not yet
built.

## Intended Behavior

- `chart{ kind = "bars" | "lines" | "dots", data = {…}, labels = {…} }` over axes, each bar's midline in the flair.
- `diagram{ boxes = {…}, arrows = { { from = "a", to = "b", there = "…", here = "…" } } }`, laid out by levels like the blueprint graph (043).
- The machine's own things drawn first: a case's blueprint graph, its center, its ledger's totals.

## Suggested Implementation Steps

1. Charts. **Test:** bar heights in pixels are proportional to the data.
2. Diagrams by level. **Test:** a diamond of four boxes lays out in three columns; every arrow starts on its `from` box and ends on its `to` box.
3. The machine drawn by itself: the notes fixture's blueprint as a diagram.

## Sub-issues

- 805a — bar charts
- 805b — line and dot charts
- 805c — diagrams by level
- 805d — the machine drawn by itself

## Blocked by

- 804
