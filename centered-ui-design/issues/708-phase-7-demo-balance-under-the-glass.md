# 708 — Phase 7 demo: balance under the glass

**Phase:** 7 — Growing outward
**Blocked by:** 701, 702, 703, 704, 705, 706, 707, 607

**Blocks**: 804
**Related documents:** docs/roadmap.md (Phase 7)

## Current Behavior

No phase 7 demo.

## Intended Behavior

Two parts. First, a balance run: thousands of offers rolled across worker
threads, showing the spread of offer values per side, the parity margin, how
often each table entry came up against its computed expectation. Second, a
played game where one direction's foe is shown at tier 1 and again at
tier 3, side by side with the seat's own growth, to show they levelled
differently.

## Suggested Implementation Steps

1. Balance run (data) writing results to `tmp/shared-memory/`.
2. Display (view) reading those results.
