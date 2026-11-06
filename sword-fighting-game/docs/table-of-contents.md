# sword-fighting-game - Table of Contents

Every document in docs/ and notes/ belongs somewhere in this tree. Source code
and issue files do not; they have their own indexes (each source file's
`.info.md` page, and issues/phase-N-progress.md).

## Vision
- notes/vision - the founding description. Written first, read most.

## Documentation
- docs/table-of-contents.md - this file.
- docs/glossary.md - the core terms, with exact meanings.
- docs/game-rules.md - the rules the simulation enforces.
- docs/controls.md - every binding, in each seat.
- docs/art-direction.md - claymation figures, brick armor, cat faces.
- docs/architecture.md - two halves, one clock, one source of chance.
- docs/style-guide.md - the house style and the linter that checks it.
- docs/roadmap.md - the phases and what each ends with.
- docs/balance-updates.md - append-only record of every changed knob.
- docs/open-questions.md - questions waiting for the owner.
- Datapaths, one per major feature:
  - docs/datapath-run-lifecycle.md - input/, the clock, the script, the receipt.
  - docs/datapath-battle-tick.md - one battle tick, in order.
  - docs/datapath-melee-hit.md - from the U to a blow's effect.
  - docs/datapath-volleys.md - volleys and the shield wall.
  - docs/datapath-round-and-campaign.md - the four acts and the map.
  - docs/datapath-catalogue-and-perks.md - catalogue, mods, perks, traits.
  - docs/datapath-rendering.md - records to pixels.

## Phases
Phases group related functionality, not calendar time. It is normal for the
last issue completed in a project to belong to phase 1.
- Phase 1 - The spine: configuration, chance, input and the receipt, the
  script, headless runs, screenshots, the linter, the tests, the website.
- Phase 2 - Bodies on the field: catalogue, grid, soldier, stamina,
  occupancy, tripping.
- Phase 3 - The sword: the U and the lock, swings, hits, minds, the tick.
- Phase 4 - Seeing it: matrices, clay and bricks, figures, scenery, the
  two views, the front desk.
- Phase 5 - Command and the round: volleys, the four acts, the command
  table, the campaign.
- Phase 6 - Growth: perks, unit types, armor tracks, mods.
- Phase 7 - Distance: the simulation's own thread, two players, the
  expansion arsenal.

## Project files
- .file-index-counter - the highest reading-order index used by any file in
  the project, so a new file can take the next number without a search.
- run-phase-demo - asks which completed phase to demonstrate, then runs it.
- run-game - the window. run-headless - a run with no window.
- run-many-battles - a batch across every core, totalled.
- run-tests - the linter, then every test.
- development-history/ - every screenshot, numbered, with notes.
