# 401 — Six dials, two buttons

**Phase:** 4 — The inputs
**Blocks:** 402, 403
**Related documents:** docs/datapath-input.md

## Current Behavior
No inputs.

## Intended Behavior
Three dials per side (forward, back, by the ear) report signed steps; A and B
report presses. No tap input exists anywhere. A hardware test board, and a
keyboard stand-in for the simulation, produce the same input records.

## Suggested Implementation Steps
1. Input record shapes.
2. Keyboard stand-in.
3. Tests: one record per detent turned.
