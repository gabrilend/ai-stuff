# 802 — The lobby and seat assignment

**Phase:** 8 — Across the wire
**Blocked by:** 801, 501

**Blocks**: 804
**Related documents:** docs/datapath-network.md

## Current Behavior

Seats are assigned in `input/`.

## Intended Behavior

- One machine hosts; others join by address. The lobby is a dashboard: each
  seat shown on a dial with a painted claim button beside it.
- Seats left unclaimed are run by helper AI (604) on the host's choice.
- The host sends the seed and settings; every machine starts the same game.

## Suggested Implementation Steps

1. Lobby messages over ENet.
2. Lobby dashboard, built from the phase 2 kit.
