# 305 — Couriers drawn in flight

**Phase:** 3 — The wheel at the center
**Blocked by:** 304, 301

**Blocks**: 307
**Related documents:** docs/datapath-orders.md, docs/visual-language.md
(Map)

## Current Behavior

Couriers exist in snapshots; the debug view draws them as dots.

## Intended Behavior

- Each courier is a small bright spark in its seat's paint color, with a
  short fading trail, leaving the wheel's edge and running to its stand.
- A faint dotted line from courier to stand, labeled with the order's glyph,
  so you can see what is coming.
- When it arrives, a brief ring pulse on the stand.
- A face readout shows couriers in flight for this seat.

## Suggested Implementation Steps

1. Map layer for couriers, drawn through the accordion.
2. Arrival pulse triggered by a courier vanishing between snapshots with an
   "arrived" event.
