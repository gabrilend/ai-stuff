<!-- written by Claude (Opus 5.5), 2026-10-10, for the first renderer slice: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 006-the-move-box

The soramech box for one unit's step: read front, move by speed × step seconds, bounce at the inner and outer limits, wrap the angle, face the direction of travel on the folded ground, write back. Touches no other unit, so order never matters.

| Offers | Takes |
|---|---|
| `move_unit(front, back, index, step_seconds, fold)` | two record arrays, the unit's index, the step's length, the fold |
| `INNER_LIMIT` | the tier distance units turn back at near the hub |
