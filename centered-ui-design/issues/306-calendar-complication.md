# 306 — The calendar complication

**Phase:** 3 — The wheel at the center
**Blocked by:** 207, 302

**Blocks**: 307, 504
**Related documents:** docs/console-layout.md, docs/core-terms.md (calendar
complication)

## Current Behavior

The two-level complication exists in the showroom only.

## Intended Behavior

- A game calendar in the simulation: a game-day is a fixed number of ticks;
  a game-month is a fixed number of days (both from `input/`).
- On the wheel's arc: a window showing the weekday word (day mode) or the
  month word (month mode); one level lower, the number (day of month, or
  month number). The discs turn as the calendar advances.
- A small button beside it flips day mode / month mode. Expected to be used
  often, so it is large enough to hit quickly and responds instantly.
- Phase 5 uses the chosen mode as the vote cadence.

## Suggested Implementation Steps

1. Simulation: calendar fields in the world and snapshot.
2. View: complication fed by the snapshot; the mode button.

## Open questions

- What does the calendar control? (Open question 3.)
