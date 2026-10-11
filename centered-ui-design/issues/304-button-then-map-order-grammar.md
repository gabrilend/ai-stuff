# 304 — The button-then-map order grammar

**Phase:** 3 — The wheel at the center
**Blocked by:** 303, 106

**Blocks**: 305, 307, 402, 606
**Related documents:** docs/datapath-orders.md (Steps), docs/game-design.md
(Giving an order)

## Current Behavior

Orders can only be given in code.

## Intended Behavior

- Pressing an order button arms it (pulsing). The next map click completes
  the order for the stand under the notch: the click becomes a position via
  the accordion's inverse, and a command goes to the simulation.
- Always one, then the other: a map click with nothing armed only marks the
  spot; a second button press re-arms with the new kind; Escape or right
  click disarms. After an order is sent, nothing remains armed.
- One order goes to exactly one stand. There is no box-select and no
  multi-stand order.
- First order set: move, attack-move, hold, fall back, flank left, flank
  right, deploy shield, follow (map click on another stand).
- The order kinds are a dispatch table from kind to its simulation behaviour
  and its button look.

## Suggested Implementation Steps

1. `src/NNN-order-grammar.lua`: a tiny state machine (idle, armed) as data.
2. Simulation side: behaviours for each order kind (extends 104/106).
3. Shield dome: a glass dome object that blocks projectiles from outside for
   a time.
4. Tests: every sequence of button/map/escape events gives the right
   commands and never two at once.
