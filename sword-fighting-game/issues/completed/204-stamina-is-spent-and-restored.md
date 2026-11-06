# 204 — Stamina Is Spent And Restored

| | |
| --- | --- |
| Phase | 2 — Bodies on the field |
| Blocked by | 102, 203 |
| Blocks | 206, 303 |
| Files | `src/007-stamina.lua` |

## Current behavior

Built in `src/007-stamina.lua`: spending, restoring, the parry-chance curve
(bushido flattens it), and the two trip rules with the trip itself. Tested in
tests/032-bodies-on-the-field.lua.

## Intended behavior

Stamina runs from 1 to 0, and fatigue is 1 − stamina.

- **Spending** — a table of action costs (configuration): swing, overhead,
  parry made, being parried, dodge, guard held (per second), walking (per
  second, small). A cost larger than the stamina left takes it to zero, never
  below.
- **Restoring** — per second while not swinging, guarding or dodging; faster
  while standing still.
- **Parry chance** — at stamina 1 it is the configured maximum (nearly
  certain); it falls with fatigue along a curve: chance = maximum × stamina
  raised to the configured exponent, floored at the configured minimum. The
  bushido trait softens the exponent.

All three are pure functions of the soldier record and the configuration, so
they can be shown live in the documentation's slider.

## Suggested implementation steps

1. Write spend, restore and parry chance.
2. Test: chance at full stamina equals the maximum; chance falls
   monotonically; bushido's chance is never lower at the same stamina.
