# 304 — The map-then-dashboard order grammar

**Phase:** 3 — The wheel at the center
**Blocked by:** 303, 106
**Blocks**: 305, 307, 402, 606
**Related documents:** docs/datapath-orders.md (Steps), docs/game-design.md
(Giving an order: always tell someone)

## Current Behavior

Orders can only be given in code.

## Intended Behavior

- Map, then dashboard, then map, then dashboard. Always exactly one click
  each. The map click names who (303); the button click says what, sends the
  command, and clears the name.
- A button click with no one named does nothing but flash a "name someone
  first" dial.
- No menus, no right-click orders, no box-select, no keyboard order
  shortcuts. To build, you tell an engineer. To attack, you tell a stand.
- Order verbs, relative to the stand: advance, attack (nearest enemy in
  reach), hold, fall back, flank left, flank right, deploy shield (a glass
  dome where it stands), follow, build, dismantle, adventure.
- The verbs are a dispatch table from verb to its simulation behaviour and its
  button.

## Suggested Implementation Steps

1. `src/NNN-order-grammar.lua`: two states (no one named, someone named) as
   data.
2. Simulation side: behaviours for each verb (extends 104/106).
3. Shield dome: a glass dome object that blocks attacks from outside for a
   time.
4. Tests: every sequence of map/button events gives the right commands,
   never more than one per button click, never one without a named stand.

## Open questions

- How are verbs that need a second party (follow whom, attack what) given?
  (Open question 1.)
