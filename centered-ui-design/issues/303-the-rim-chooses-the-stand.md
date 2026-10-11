# 303 — The rim chooses the stand

**Phase:** 3 — The wheel at the center
**Blocked by:** 302

**Blocks**: 304, 307
**Related documents:** docs/datapath-orders.md, docs/core-terms.md (rim,
pointer notch)

## Current Behavior

The rim turns but means nothing.

## Intended Behavior

- The rim's sectors are the current seat's stands, one per sector, in a
  stable order (by stand id). Sector count changes as stands are made or
  lost; sectors re-divide smoothly.
- The sector under the pointer notch is the selected stand; it is
  highlighted on the map too.
- Each sector shows the stand's strength readout and, if a courier is headed
  to it, a countdown readout of the courier's arrival.
- Clicking a stand on the map turns the rim to bring its sector to the notch
  (it does not give an order).

## Suggested Implementation Steps

1. Rim sector list derived from the snapshot each frame.
2. Selected stand = rotor detent under the notch (from 204's event).
3. Map-click-on-stand → rotor target angle.

## Open questions

- Is the rim the stand selector? (Open question 1.)
