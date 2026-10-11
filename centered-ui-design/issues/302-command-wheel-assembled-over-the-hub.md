# 302 — The command wheel, assembled over the hub

**Phase:** 3 — The wheel at the center
**Blocked by:** 205, 206, 207, 301

**Blocks**: 303, 306, 307, 501
**Related documents:** docs/console-layout.md, docs/game-design.md (The
screen)

## Current Behavior

The rendering kit exists as separate parts in the showroom.

## Intended Behavior

- A great wheel drawn at screen center over the hub: metal rim (rotor) with
  sectors and arc text, inner face with button arcs and readouts, a center
  boss, a pointer notch at top.
- Wheel radius is a fraction of screen height (about a third), recalculated
  on resize; the accordion map starts at its edge.
- The layout (what is where) is a data table, so arranging the console is
  editing data, not code.

## Suggested Implementation Steps

1. `src/NNN-console-layout.lua`: the layout table (rings, sectors, button
   slots, readout slots, complication slot).
2. `src/NNN-command-wheel.lua`: builds elements from the layout and the
   latest snapshot; draws them.
3. Screenshot-based check in the phase demo.

## Open questions

- What text goes in the rim's sectors besides stand names? (Open question 12.)
