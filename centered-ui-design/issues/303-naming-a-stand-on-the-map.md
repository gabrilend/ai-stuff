# 303 — Naming a stand on the map

**Phase:** 3 — The wheel at the center
**Blocked by:** 302
**Blocks**: 304, 307
**Related documents:** docs/datapath-orders.md, docs/core-terms.md (order)

## Current Behavior

Built for single units (2026-10-10): a click on the map off the dashboard
names the nearest unit within a small reach (or no one, on empty ground);
the named unit glows, the dashboard shows its seat and level, and the order
buttons brighten from de-selected. The name is written into shared memory at
the next swap. Not built yet: stands (groups) — units are named one by one
until stands exist — the foe check (a foe can be named today), and the tests
(the naming code lives in `src/016-the-game.lua` beside LÖVE and is checked
by scripted clicks and a screenshot).

## Intended Behavior

- A click on the map names who the next order is for: the click runs back
  through the projection to a place, and the nearest of the current seat's
  own stands within a click radius is named. A click on empty ground names
  no one.
- The named stand is marked on the map (a ring in the seat's color), and
  dials on the dashboard show its level, count and current order.
- A second map click before a button names someone else instead.
- Clicking a merged marker names its strongest stand (assumed; open
  question 9).

## Suggested Implementation Steps

1. Click → place → nearest own stand (view side; reads the snapshot).
2. Named-stand marker and dials.
3. Tests: a click between two stands names the nearer; a click on a foe's
   stand names no one.
