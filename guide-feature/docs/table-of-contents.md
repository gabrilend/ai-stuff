# guide-feature - Table of Contents

Every document in docs/ and notes/ belongs somewhere in this tree. Source code
and issue files do not; they have their own indexes.

## Vision
- notes/vision - the founding description. Written first, read most.
  - notes/first-answers.md - the owner's answers and corrections, verbatim,
    in the order they were given.

## Documentation
- docs/table-of-contents.md - this file.
- docs/architecture.md - the core terms, the four machines, how a round goes.
  - docs/roadmap.md - the nine phases and the demo each ends with.
  - docs/open-questions.md - every question not yet worked through.
  - docs/roads-not-taken.md - the first design's ideas, and why they were
    replaced.
- Formats and agreements
  - docs/canvas-format.md - the canvas as text, in every direction it
    travels.
  - docs/canvas-protocol.md - how viewers get the canvas.
  - docs/fit-check.md - the compiler-style check on every edited canvas.
  - docs/endpoints.md - the endpoints file in the project root.
  - docs/embedding-index-contract.md - what the look tool needs from a
    project's embedding index.
    - docs/embedding-index-build-guide.md - how to give a project an index
      that meets it, followed for guide-feature itself.
- Surroundings
  - docs/network.md - the router rules, and what each part needs from them.
  - docs/rmail-constraints.md - what rmail provides and what is built around
    it.
  - docs/vendored-code.md - code this project keeps its own copy of, and the
    local upstream each copy is refreshed from.
- Datapaths (one per major feature; updated as issues change them)
  - docs/datapath-round-trip.md - the canvas going out to the voices and
    coming back.
  - docs/datapath-voice-turn.md - one turn on a mini-computer.
  - docs/datapath-blit.md - how changes land on the shared canvas, in both
    merge modes.
  - docs/datapath-looking-into-the-project.md - the project clone and the
    look tool.
  - docs/datapath-viewers.md - from the canvas to a person's eyes.

## Phases
Phases group related functionality, not calendar time. It is normal for the
last issue completed in a project to belong to phase 1.

- Phase 1 - The canvas and the blit
- Phase 2 - The canvas for viewers
- Phase 3 - The relay through rmail
- Phase 4 - The turn
- Phase 5 - Looking into the project
- Phase 6 - Distill mode
- Phase 7 - Bringing up the mini-computers
- Phase 8 - Viewers for the desk and the browser
- Phase 9 - Viewers for the pocket and the wrist

## Project files
- .file-index-counter - the highest reading-order index used by any file in
  the project, so a new file can take the next number without a search.
- run-phase-demo - asks which completed phase to demonstrate, then runs it.
- endpoints - the llama.cpp servers, and which part uses which (made by
  issue 401b; its ports are confirmed and its models added in 401a).
