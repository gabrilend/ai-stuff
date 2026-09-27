# 604 — Phase 6 demo

## Current Behavior

Built: `issues/completed/demos/phase-6-demo` and `phase-6-demo.lua`. The rebuilt notes program takes the three fixture requests in turn: each shown in the person's words, graded, its touched issue (●) and reach (○) drawn on the graph by level, the foundation one held with its grade file shown and released with `--go`, then `notes list` run to show the change (and the notes file's header appearing on the next save). Ends with the share of the design each grade rebuilt as bars, the turns each took, and the ledger's verification.

## Intended Behavior

`issues/completed/demos/phase-6-demo`: phase 5's delivered design; three
requests dropped into `input/` — a surface, a middle and a foundation one —
each graded and shown with its touched issues and reach drawn on the graph
(phase 4); the foundation one held until `--go`; the design's program run
after each to show the change. Numbers: issues rebuilt per grade, turns per
request, and the fraction of the design each touched.

## Suggested Implementation Steps

1. The demo script. **Test:** runs through `./run-phase-demo 6`.

## Blocked by

- 603
