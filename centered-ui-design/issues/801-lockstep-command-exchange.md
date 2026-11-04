# 801 — Lockstep command exchange

**Phase:** 8 — Across the wire
**Blocked by:** 107, 102

**Blocks**: 802, 803, 804
**Related documents:** docs/datapath-network.md

## Current Behavior

All seats are on one machine.

## Intended Behavior

- Each command is stamped with the tick it takes effect (current tick plus a
  fixed input delay) and sent to every other machine over ENet.
- A tick runs only when every seat's commands for it (possibly none, sent as
  an explicit empty list) are present.
- The simulation is unchanged: it already takes only commands.

## Suggested Implementation Steps

1. `src/NNN-lockstep.lua`: send, receive, gate ticks.
2. Two-instances-on-one-machine test harness.
