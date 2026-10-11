# centered-ui-design - Table of Contents

Every document in docs/ and notes/ belongs somewhere in this tree. Source code
and issue files do not; they have their own indexes.

## Vision
- notes/vision - the founding description. Written first, read most.
  Holds the first message and the second, and the first answers, verbatim.

## Documentation
- docs/table-of-contents.md - this file.
- docs/core-terms.md - the agreed words: hub, quadrant, tier, stand,
  courier, accordion, readout, roll table, and the rest.
- docs/game-design.md - the game as designed: screen, orders, production,
  team table, center-to-outer, choices and balance.
- docs/console-layout.md - the arrangement of the command wheel and dials.
- docs/visual-language.md - glass and metal: materials, shapes, motion, the
  rule of buttons and numbers.
- docs/architecture.md - simulation and view as two halves, threads, reading
  order, start and end.
  - docs/datapath-world-tick.md - one simulation step.
  - docs/datapath-orders.md - from a button press to a stand obeying.
  - docs/datapath-accordion-view.md - from a world position to a pixel.
  - docs/datapath-production.md - factories, locked paths, engineers.
  - docs/datapath-team-vote.md - ballots to spending.
  - docs/datapath-choices.md - from seed to a level-up offer.
  - docs/datapath-glass-and-metal.md - one console element to pixels.
  - docs/datapath-network.md - commands across machines.
- docs/roadmap.md - the eight phases and the demo each ends with.
- docs/open-questions.md - every question met so far, answered and waiting.
- docs/balance-updates.md - append-only log of number tweaks and why.

## Phases
Phases group related functionality, not calendar time. It is normal for the
last issue completed in a project to belong to phase 1.

1. The world beneath - headless deterministic simulation, couriers, threads.
   (issues/phase-1-progress.md)
2. Glass and metal - the rendering kit. (issues/phase-2-progress.md)
3. The wheel at the center - the console, order grammar, accordion.
   (issues/phase-3-progress.md)
4. Factories and engineers - resources, production, locked paths.
   (issues/phase-4-progress.md)
5. The round table - seats, hot-seat switching, weighted votes.
   (issues/phase-5-progress.md)
6. Foes in every direction - terrain, foe AI, fronts, flanking.
   (issues/phase-6-progress.md)
7. Growing outward - generated choices, roll tables, parity, heroes.
   (issues/phase-7-progress.md)
8. Across the wire - lockstep network play. (issues/phase-8-progress.md)

## Project files
- .file-index-counter - the highest reading-order index used by any file in
  the project, so a new file can take the next number without a search.
- run-phase-demo - asks which completed phase to demonstrate, then runs it.
