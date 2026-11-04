# 603 — The foe commander AI

**Phase:** 6 — Foes in every direction
**Blocked by:** 602, 403

**Blocks**: 604, 607, 706
**Related documents:** docs/datapath-orders.md

## Current Behavior

Foes have outposts but do not act.

## Intended Behavior

- Each foe is played by an AI that obeys the same rules as a person: it
  gives one order to one stand at a time, through couriers from its own
  outpost, with the same transit delay. It builds factories, sets locked
  paths, and spends by its own priorities.
- AI decisions run on the AI random stream, so games stay reproducible.
- AI personalities (aggressive, shield-turtle, flanker) are data tables of
  weights, not separate code paths.

## Suggested Implementation Steps

1. `src/NNN-commander-ai.lua`: reads the snapshot-like view of its own side
   only (no cheating), emits commands.
2. Personality tables.
3. Test: an AI-vs-AI front runs to a decision and replays identically.
