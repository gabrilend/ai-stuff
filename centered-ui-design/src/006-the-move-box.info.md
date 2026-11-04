<!-- written by Claude (Opus 5.5), 2026-10-10, for the first renderer slice: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 006-the-move-box

The soramech box for one unit's step: read front, move by speed × step seconds, bounce at the inner and outer limits, wrap the angle, face the direction of travel on the folded ground, turn the walking phase by ground covered (one cycle per stride, plus an idle sway), write back. Touches no other unit, so order never matters.

| Offers | Takes |
|---|---|
| `move_unit(front, back, index, step_seconds, fold)` | two record arrays, the unit's index, the step's length, the fold |
| `INNER_LIMIT` | the tier distance units turn back at near the hub |
| `STRIDE_WORLD_UNITS`, `IDLE_CYCLES_PER_SECOND` | ground covered per walking cycle at tier 1; the standing sway rate |
