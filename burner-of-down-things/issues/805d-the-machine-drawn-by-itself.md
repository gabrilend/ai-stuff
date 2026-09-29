# 805d — The machine drawn by itself

The fourth piece of 805: the machine's own things as the first real
content, per docs/067.

## Current Behavior

The studio can draw generic charts and diagrams; nothing of the machine's
own is drawn.

## Intended Behavior

The machine's own blueprint graph, center weights and ledger totals drawn
through 805a–805c: a blueprint-graph-to-diagram adapter, a
center-weights-to-chart adapter.

## Suggested Implementation Steps

1. The blueprint-graph adapter (043's graph → `diagram`'s boxes/arrows).
2. The center-weights adapter (→ `chart`'s data/labels). **Test:** the
   notes fixture's blueprint renders as a diagram whose boxes match its
   issue ids exactly.

## Blocked by

- 805a
- 805c
