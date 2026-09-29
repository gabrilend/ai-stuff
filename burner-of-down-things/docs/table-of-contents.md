# burner-of-down-things - Table of Contents

Every document in docs/ and notes/ belongs somewhere in this tree. Source code
and issue files do not; they have their own indexes.

The machine has no name (notes/vision: *never name such a thing*). The folder
name is where it lives.

## Vision
- notes/vision - the founding description, then the owner's own words from
  the conversation that shaped it. Written first, read most.

## Documentation
- docs/table-of-contents.md - this file.
- docs/001-what-it-is.md - source in, blueprint written, design built from the
  blueprint alone, updates graded and rebuilt; why it is shaped so.
  - docs/002-the-terms.md - every core term and the data behind it, down to
    strings and numbers.
  - docs/012-the-commands.md - the one script that starts the machine, and
    its commands.
- Datapaths (one per major part)
  - docs/003-datapath-the-case-and-the-ledger.md - the case folder, one run
    start to end, the chained ledger.
  - docs/004-datapath-the-survey.md - reading the source without a model, in
    parallel.
  - docs/005-datapath-the-hands.md - turns, confinement, the harness table,
    crafts, the turn pool.
  - docs/006-datapath-the-blueprint.md - outline, graph, issue files.
  - docs/007-datapath-the-design.md - waves, build and repair, acceptance,
    delivery.
  - docs/008-datapath-the-update.md - requests, locating, grading, amending,
    rebuilding the reach.
  - docs/009-datapath-the-center.md - the personality, computed from the
    ledger alone.
- docs/010-open-questions.md - every question waiting on the owner.
- docs/011-roadmap.md - the seven phases and their demos.
- docs/067-datapath-the-studio.md - asset generation utilities: .png, .mp4,
  .txt, source files, in the owner's look; the pool and its cards.
- docs/068-datapath-the-switchboard.md - parcels of arbitrary inputs, routed
  by a light model, planned by shape; observations and adjustments.
- docs/069-the-story.md - the ledger told back as a story; lessons;
  strategems.
- docs/balance-updates.md - append-only record of every change to the numbers
  the machine weighs by (grade lines, the center's weights), with reasons.

## Phases
Phases group related functionality, not calendar time. It is normal for the
last issue completed in a project to belong to phase 1.

- Phase 1 - The case and the ledger: folders, tables, checksums, the chain,
  the command dispatcher.
- Phase 2 - The survey: what is in a source, found in parallel without a model.
- Phase 3 - The hands: turns of a model, kept inside their folders.
- Phase 4 - The blueprint: the source written down as issue files.
- Phase 5 - The design: new code built from the blueprint, wave by wave.
- Phase 6 - The update: requests graded by depth and rebuilt outward.
- Phase 7 - The center, and the whole loop: the personality, `run`, and the
  case viewer.
- Phase 8 - The studio: asset generation utilities in the owner's look.
- Phase 9 - The switchboard: routing and planning arbitrary inputs.
- Phase 10 - The story: narrative, lessons, strategems.

## Strategems
- strategems/a-referee-never-sees-the-answer.md - checks are made from the
  description, by someone who has not seen the work.
- strategems/dynamic-re-abstraction.md - narrow first, widen only when
  nothing is found, narrow again to fix.

## Project files
- .file-index-counter - the highest reading-order index used by any file in
  the project, so a new file can take the next number without a search.
- run-phase-demo - asks which completed phase to demonstrate, then runs it.
- machine - starts the machine; see docs/012-the-commands.md.
