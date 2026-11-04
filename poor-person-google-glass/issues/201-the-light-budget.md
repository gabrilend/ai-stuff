# 201 — The light budget

**Phase:** 2 — The stored light
**Blocks:** 202, 203
**Related documents:** docs/physics-check.md, docs/datapath-light.md

## Current Behavior
No account of where the light goes.

## Intended Behavior
From emitter power (number, milliwatts) to light at the panel: losses at the
pipe, at the glass-to-filling boundaries (from the refractive indices), at
the tabs, in the store; every lost share recorded as heat (number, watts)
for phase 5.

## Suggested Implementation Steps
1. Boundary loss from two refractive indices.
2. Chain the stages; total in equals total out plus heat.
3. Tests: matched indices give near-zero boundary loss.
