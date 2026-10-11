# Phase 1 Progress — The world beneath

## Goals
A headless, deterministic simulation built on soramech stations: the
program reads input/ and writes output/goodbye; stations, slots and the
worker pool; seeded randomness and a fixed tick; the world of hub,
quadrants and tier rings; stands moving in tier-time; combat as one station
per direction; couriers carrying orders with real transit delay; snapshots
handed to whatever is watching.

The demo this phase ends with is described in docs/roadmap.md.

For current done/open counts, run:

    /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/centered-ui-design -m

## Completed Issues
- 110 — Unit records in shared memory: every unit is twelve floats in a
  front and a back block; each step every unit is one task, taken first come,
  first served by six worker threads; the blocks swap when all are done. The
  ground for every later simulation issue, and the same bytes the renderer
  draws from.
- 109 — The ceramic engine runs the world: soramech's C engine on its own
  workers, C boxes compiled by serac into a library LuaJIT loads; LÖVE's main
  thread only renders and hands work in by the batch. Every later simulation
  issue writes boxes for it. (110's "one task per unit" became one task per
  chunk of 32 here.)
