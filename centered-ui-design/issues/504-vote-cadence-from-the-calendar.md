# 504 — Vote cadence from the calendar

**Phase:** 5 — The round table
**Blocked by:** 306, 502, 503

**Blocks**: 505
**Related documents:** docs/datapath-team-vote.md, docs/console-layout.md

## Current Behavior

Votes are tallied every tick.

## Intended Behavior

- Votes are tallied when the calendar crosses a boundary: every game-day in
  day mode, every game-month in month mode, set by the calendar
  pace button (306).
- Changing the mode is itself a team decision: the mode in force is the one
  most seats (by weight) have selected; each seat's complication shows its
  own selection and the team's.
- A readout counts down to the next tally.

## Suggested Implementation Steps

1. Calendar-boundary event in the simulation.
2. Per-seat mode choice; team mode by weighted majority.

## Open questions

- Is vote cadence what the calendar is for? (Open question 3.)
