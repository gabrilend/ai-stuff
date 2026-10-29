# distant-computer - Table of Contents

Every document in docs/ and notes/ belongs somewhere in this tree. Source code
and issue files do not; they have their own indexes.

## Vision
- notes/vision - the founding description, in the owner's own words. Written
  first, read most.

## Documentation
- docs/table-of-contents.md - this file.
- docs/architecture.md - the two computers, the one-way link, the gate,
  connected and waiting, placements, and the lines the design will not move.
  - docs/purpose.md - what the whole system is for: wishes becoming
    ventures, work as it is bidden, civic duty, and where this project fits.
  - docs/core-terms.md - the project's words for its own parts.
  - docs/roadmap.md - the nine phases and what each one's demo shows.
  - docs/open-questions.md - questions waiting for the owner.
  - docs/roads-not-taken.md - designs set aside, and why.
- Formats
  - docs/settings-files.md - `input/<program>` and the `output/goodbye`
    receipt.
  - docs/ledger-format.md - the append-only, checksum-chained record.
  - docs/request-format.md - one request file, its body per kind, answers,
    refusals.
- Datapaths
  - docs/datapath-gate.md - one request from the steward, through the gate,
    and back.
  - docs/datapath-link.md - one visit of the courier, the heartbeat, and
    waiting.
  - docs/datapath-placement.md - tracked, twinned and resident files.
  - docs/datapath-steward.md - one turn of the steward.
  - docs/datapath-outward.md - funding goals, listings, hand-me-downs.
- Operations
  - docs/provisioning.md - what makes a Linode into the distant computer.

## Phases
Phases group related functionality, not calendar time. It is normal for the
last issue completed in a project to belong to phase 1.

- Phase 1 — the record and the settings
- Phase 2 — the gate
- Phase 3 — the link
- Phase 4 — placement
- Phase 5 — the distant computer
- Phase 6 — the steward
- Phase 7 — the voices
- Phase 8 — the outward world
- Phase 9 — seeing it

## Project files
- .file-index-counter - the highest reading-order index used by any file in
  the project, so a new file can take the next number without a search.
- run-phase-demo - asks which completed phase to demonstrate, then runs it.
