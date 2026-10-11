# 306 — The calendar dials

**Phase:** 3 — The wheel at the center
**Blocked by:** 207, 302
**Blocks**: 307, 504
**Related documents:** docs/console-layout.md, docs/core-terms.md
(calendar)

## Current Behavior

The two-level nested dial exists in the showroom only.

## Intended Behavior

- A game calendar in the simulation: a game-day is a fixed number of ticks; a
  game-month a fixed number of days (both from `input/`).
- On the dashboard, a seamless glass cut-out shows the month word and the
  weekday word; one level lower, through a window in that dial, the day
  number. The dials turn as the calendar advances.
- A painted button beside it switches the calendar's pace between day and
  month. Some players will press it often and routinely, so it is large and
  responds instantly. Votes (504) and other paced events happen on the
  calendar's boundaries at that pace.

## Suggested Implementation Steps

1. Simulation: calendar fields in the world and snapshot; a calendar station
   that emits a boundary event.
2. View: dials fed by the snapshot; the pace button.

## Open questions

- What else does the calendar pace? (Open question 8.)
