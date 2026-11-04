# 503 — Throttle, pumps and fins

**Phase:** 5 — The crown and its heat
**Blocked by:** 502
**Blocks:** 504
**Related documents:** docs/datapath-heat.md

## Current Behavior
Nothing responds to heat.

## Intended Behavior
Warm: fewer releases. Hot: air pumps (no fans). Hotter: heat fins flare up
and out from the hair. Too hot: emitters stop. Thresholds in
docs/balance-updates.md.

## Suggested Implementation Steps
1. Heat policy as a table of thresholds to responses.
2. Fin area as a function of flare.
3. Tests: each response begins at its threshold.
