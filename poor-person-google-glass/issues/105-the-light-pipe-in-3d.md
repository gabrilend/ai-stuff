# 105 — The light pipe in 3D, from inside

**Phase:** 1 — The mask
**Blocked by:** 008
**Related documents:** docs/core-terms.md, docs/physics-check.md,
notes/vision

## Current Behavior
Built and photographed: `src/018-the-light-pipe-model.lua`,
`scripts/make-light-pipe` → output/models/light-pipe.gltf (14 parts, 12
stations, a pale aqua filling haze). Every part is seen from at least one
station, checked by `scripts/run-tests`. The first stations stood on the
middle line, inside the beams, which filled the pictures; they were moved
off it. Still to do: step 4, the tabs driven by phase 1's tab data (101),
which does not exist yet; so this issue stays open.

## Intended Behavior
A model of the light pipe's inside, made by formula, seen as a room: the
owner asked for it "like a 3d room render, where we can get several
different perspectives internally. It should curve around like a large
atrium, and we should have perspectives all up and down and along it,
making sure that each relevant feature is featured at least in the distance
at least once across the whole set."

The parts (names from docs/core-terms.md; sizes are placeholders until
phases 1 and 2 give real ones, in millimetres):
- **light pipe wall**: a tube curving around the head like part of a crown,
  from the temple at the back to the brow at the front, mirrored inside.
- **wall ridges**: rings carved into the wall, angled to send light back
  toward the back mirror ("carved to reflect light backwards").
- **back mirror**: closing the back end; the **emitters** (red and green)
  enter from the side just in front of it (docs/physics-check.md: light
  returning into a laser diode harms it, so the back is a mirror).
- **beam**: the light down the middle, red and green, following the curve.
- **tabs**: long strips hinged at the wall, swung into the pipe at
  different angles, each a row of **slots** open or closed.
- **levers**: small paired levers that move the filling, duplicated to
  share load and to diagnose each other.
- **light vortex**: a faint spiral of light circling near the wall.
- **filling**: the index-matched liquid filling everything, shown as a
  faint haze that thickens with distance (index-matched means its edges are
  invisible; the haze shows it is there).
- **store** and **aperture**: the mirrored rotating cylinder at the front,
  with its slit.

Stations: along the curve from back to front, high and low and in the
middle, looking forward and back; the coverage measurement (008) shows
every part seen at least once.

## Suggested Implementation Steps
1. src/018-the-light-pipe-model.lua: the parts, the stations, the filling.
2. scripts/make-light-pipe: writes output/models/light-pipe.gltf.
3. View every station; check coverage; keep the pictures.
4. Later: drive the tabs from phase 1's tab data (101) instead of fixed
   angles.
