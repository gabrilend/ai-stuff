# 302 — The dashboard, assembled over the hub

**Phase:** 3 — The wheel at the center
**Blocked by:** 205, 206, 207, 301
**Blocks**: 303, 306, 307, 501
**Related documents:** docs/console-layout.md, docs/game-design.md (The
screen)

## Current Behavior

A first mock-up exists (2026-10-10, issue 212): metal face, eight painted
order buttons, calendar and readout dials, the named stand's window, on a
view plane over the hub. Only buttons answer clicks. Not built yet: the
layout as a data table separate from drawing code (it is partly data, partly
code in `src/014-the-dashboard.lua`), and the full set of dials (resources,
couriers in flight).

## Intended Behavior

- A large round dashboard drawn at screen center over the hub: metal face,
  arcs of painted order buttons, and dial windows (calendar, resources,
  couriers in flight, the named stand's level and count, seat name).
- Its size is a large fraction of screen height (it must be big enough that
  returning the eye to it sweeps across the map), recalculated on resize; the
  projected map starts at its edge.
- The layout (which buttons and dials, where) is a data table, so arranging
  the dashboard is editing data, not code.
- Only buttons respond to clicks.

## Suggested Implementation Steps

1. `src/NNN-dashboard-layout.lua`: the layout table.
2. `src/NNN-dashboard.lua`: builds parts from the layout and the latest
   snapshot; draws them; routes clicks to buttons only.
3. Screenshot-based check in the phase demo.
