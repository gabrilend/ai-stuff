# 401 — Metal, glass, aether, and income

**Phase:** 4 — Factories and engineers
**Blocked by:** 103

**Blocks**: 402, 405, 502, 704
**Related documents:** docs/core-terms.md (resources),
docs/datapath-production.md

## Current Behavior

Nothing costs anything.

## Intended Behavior

- The team treasury holds three resource counts: metal, glass, aether.
- Income: the hub yields a base trickle of metal and glass per tick; each
  tier band held (the front has advanced past it in a direction) adds more;
  aether comes from decided fronts and hero adventures (phase 7), plus a
  very small base trickle.
- Spending is always through a category budget (production, upgrades,
  heroes, reserve). Until phase 5's vote exists, a fixed split from `input/`
  is used — and the program prints a warning each game that the split is a
  stand-in for the vote (a fallback the owner should know about), tracked by
  issue 502.
- Face readouts show each resource.

## Suggested Implementation Steps

1. `src/NNN-treasury.lua`: counts, category budgets, income step.
2. Snapshot fields; readouts on the face.
3. Tests: income over N ticks equals the formula; overspending is refused
   with an error event.
