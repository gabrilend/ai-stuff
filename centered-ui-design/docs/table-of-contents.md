# centered-ui-design - Table of Contents

Every document in docs/ and notes/ belongs somewhere in this tree. Source code
and issue files do not; they have their own indexes.

## Vision
- notes/vision - the founding description. Written first, read most.
  Holds all three messages and the answers to the first questions, verbatim.

## Documentation
- docs/table-of-contents.md - this file.
- docs/core-terms.md - the agreed words: hub, quadrant, tier, stand,
  courier, dial, merged stand, enhancement, underworld, and the rest.
- docs/game-design.md - the game as designed: screen, orders, production,
  team table, center-to-outer, choices and balance.
- docs/console-layout.md - the arrangement of the dashboard: buttons to
  click, dials to read.
- docs/visual-language.md - glass and metal: materials, shapes, motion, the
  rule of buttons and dials, 3D models, voxels, the far camera.
- docs/architecture.md - soramech stations, simulation and view as two
  halves, reading order, start and end.
  - docs/datapath-world-tick.md - one simulation step.
  - docs/datapath-orders.md - from a map click and a button click to a stand
    obeying.
  - docs/datapath-accordion-view.md - from a place on the sphere to a pixel,
    and when stands merge.
  - docs/datapath-production.md - factories, locked paths, engineers.
  - docs/datapath-team-vote.md - ballots to spending.
  - docs/datapath-choices.md - from seed to a level-up offer.
  - docs/datapath-glass-and-metal.md - dials, buttons, models and voxels to
    pixels.
  - docs/datapath-network.md - commands across machines.
- docs/roadmap.md - the ten phases and the demo each ends with.
- docs/open-questions.md - every question met so far, answered and waiting.
- docs/balance-updates.md - append-only log of number tweaks and why.

## Phases
Phases group related functionality, not calendar time. It is normal for the
last issue completed in a project to belong to phase 1.

1. The world beneath - soramech, headless deterministic simulation, couriers.
   (issues/phase-1-progress.md)
2. Glass and metal - the rendering kit: dials, models, voxels, far camera.
   (issues/phase-2-progress.md)
3. The wheel at the center - the dashboard, order rhythm, sphere view.
   (issues/phase-3-progress.md)
4. Factories and engineers - resources, production, locked paths.
   (issues/phase-4-progress.md)
5. The round table - seats, hot-seat switching, weighted votes.
   (issues/phase-5-progress.md)
6. Foes in every direction - terrain, the underworld, foe AI, fronts.
   (issues/phase-6-progress.md)
7. Growing outward - generated choices, roll tables, parity, heroes.
   (issues/phase-7-progress.md)
8. Across the wire - lockstep network play. (issues/phase-8-progress.md)
9. Reading the machine - a guided walk through the source, function by
   function. (issues/phase-9-progress.md)
10. The machine answers - any signal moves a fan, by one contract.
    (issues/phase-10-progress.md)

## Project files
- .file-index-counter - the highest reading-order index used by any file in
  the project, so a new file can take the next number without a search.
- run-phase-demo - asks which completed phase to demonstrate, then runs it.
