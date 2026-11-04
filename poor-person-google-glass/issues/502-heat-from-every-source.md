# 502 — Heat from every source

**Phase:** 5 — The crown and its heat
**Blocked by:** 501
**Blocks:** 503
**Related documents:** docs/datapath-heat.md

## Current Behavior
Heat is uncounted (phase 2 records light lost as heat but nothing sums it).

## Intended Behavior
Temperature over time at each source, from the light budget, tab motion and
the controller.

## Suggested Implementation Steps
1. Simple heat model per part.
2. Tests: no releases, no heating from light.
