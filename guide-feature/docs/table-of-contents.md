# guide-feature - Table of Contents

Every document in docs/ and notes/ belongs somewhere in this tree. Source code
and issue files do not; they have their own indexes.

## Vision
- notes/vision - the founding description. Written first, read most.
  - notes/first-answers.md - the owner's answers to the first questions, and
    the two requests added while the first documents were written, verbatim.

## Documentation
- docs/table-of-contents.md - this file.
- docs/architecture.md - the core terms, the machines, and why rmail carries
  while the page keeper decides.
  - docs/rmail-constraints.md - what rmail provides and what is built around
    its limits.
  - docs/roadmap.md - the seven phases and the demo each ends with.
  - docs/open-questions.md - every question not yet worked through.
- Formats
  - docs/frame-format.md - a frame, as a voice writes it.
  - docs/page-protocol.md - the page, as every viewer reads it.
  - docs/display-box.md - the page's size in characters, each voice's share,
    and the fit check that works like a compiler error.
- Datapaths (one per major feature; updated as issues change them)
  - docs/datapath-frame-to-page.md - a frame's journey through rmail and the
    hooks to the page, and the page's journey back.
  - docs/datapath-relevance.md - how a thought is recognised as carried
    forward, and how it fades.
  - docs/datapath-thinker.md - how a voice writes its next frame, locally or
    relayed to a remote model.
  - docs/datapath-viewers.md - from the page to a person's eyes.

## Phases
Phases group related functionality, not calendar time. It is normal for the
last issue completed in a project to belong to phase 1.

- Phase 1 - The fit and the fade: frame reading, the fit check, similarity,
  relevance, page layout, the page keeper over a folder.
- Phase 2 - The page protocol: page files, the page reader, the HTTP page
  server, the box rules.
- Phase 3 - The relay through rmail: kuvalu's mailbox, the arrival hook, the
  page as a living message, a rehearsal on one machine.
- Phase 4 - The thinkers: context gathering, prompts, inference backends
  (local and relayed), retry on misfit.
- Phase 5 - Bringing up the fg-sora machines: survey, rmail, models,
  deployment, health.
- Phase 6 - Viewers for the desk and the browser: terminal view, Lua window,
  HTML page.
- Phase 7 - Viewers for the pocket and the wrist: Android app, Apple Watch
  app.

## Project files
- .file-index-counter - the highest reading-order index used by any file in
  the project, so a new file can take the next number without a search.
- run-phase-demo - asks which completed phase to demonstrate, then runs it.
