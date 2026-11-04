# quantity-reception-optimizer - Table of Contents

Every document in docs/ and notes/ belongs somewhere in this tree. Source code
and issue files do not; they have their own indexes.

## Vision
- notes/vision - the founding description. Written first, read most.

## Documentation
- docs/table-of-contents.md - this file.
- docs/001-what-this-makes.md - the extension in one page, and the core terms
  every other document uses.
  - docs/002-datapath-the-hover.md - pointer and page geometry into a hover
    record, then a proximity spectrum.
  - docs/003-datapath-the-quantity.md - characters into a quantity record, via
    the unit lexicon.
  - docs/004-datapath-the-analogy.md - quantity and paragraph into an analogy;
    arithmetic in Lua, judgement in the language model; the re-roll.
  - docs/005-datapath-the-picture.md - analogy into a ComfyUI graph into a
    picture; cancelling; the cache.
  - docs/006-datapath-the-bridge.md - how the extension and the Lua host talk
    over Firefox native messaging.
- docs/007-roadmap.md - the five phases and the issues in each.
- docs/008-open-questions.md - decisions still waiting on an answer.

## Phases
Phases group related functionality, not calendar time. It is normal for the
last issue completed in a project to belong to phase 1.

- Phase 1 - The Reading: text and geometry into a quantity and a weighted
  paragraph. No browser, no network.
- Phase 2 - The Bridges: the Lua host's two connections, to Firefox and to
  ComfyUI.
- Phase 3 - The Reasoning: a quantity into an analogy.
- Phase 4 - The Pictures: an analogy into an image holding exactly the right
  number of things.
- Phase 5 - The Showing: the panel beside the pointer, and the whole thing
  working.

## Project files
- .file-index-counter - the highest reading-order index used by any file in
  the project, so a new file can take the next number without a search.
- run-phase-demo - asks which completed phase to demonstrate, then runs it.
