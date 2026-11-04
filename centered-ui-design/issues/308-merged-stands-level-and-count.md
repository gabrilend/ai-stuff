# 308 — Merged stands: level and count

**Phase:** 3 — The wheel at the center
**Blocked by:** 301, 205, 105

**Blocks**: 307
**Related documents:** docs/datapath-accordion-view.md (Merging),
docs/core-terms.md (merged stand, balance color, differential triangles)

## Current Behavior

Every stand is drawn on its own, however far or crowded.

## Intended Behavior

- Where stands crowd into one screen cell, or lie far out, they merge on the
  map into one marker carrying two numbers: average level and count.
- The marker's balance color shows its strength against the threat it is
  contesting (from behind to ahead), on a scale separate from team colors.
- Differential triangles beside it carry the same information by shape:
  ▲ when ahead, ▼ when behind, more triangles for a larger difference — so
  nothing depends on seeing color.
- Merging is a view decision; the simulation still holds every unit. The
  snapshot provides each stand's level and its contested threat.

## Suggested Implementation Steps

1. `src/NNN-merge-stands.lua`: group by screen cell, compute average level,
   count, balance (viewing side, from snapshot numbers).
2. Marker drawing: a small dial for the two numbers, the balance color, the
   triangles.
3. Tests: merging three stands of levels 2, 4, 6 shows level 4 and their
   total count; triangle count matches the balance bands.
