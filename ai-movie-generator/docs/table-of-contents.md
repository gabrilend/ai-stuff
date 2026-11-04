# ai-movie-generator - Table of Contents

Every document in docs/ and notes/ belongs somewhere in this tree. Source code
and issue files do not; they have their own indexes.

## Vision
- notes/vision - the founding description. Written first, read most.

## Documentation
- docs/table-of-contents.md - this file.
- docs/architecture.md - the pipeline told as a story; the files between stages.
  - docs/hardware-and-models.md - the graphics card, ComfyUI, ollama, the gif
    generator; why language and image models take turns.
  - docs/setting-and-tone.md - the first film: the station, the daily report
    log, lines from the vision kept verbatim.
- Formats
  - docs/shot-list-format.md - the film's score: film, cast, place, shot,
    monologue, and the closed set of motions.
  - docs/beat-sheet-format.md - what the ear hears, written down.
- Datapaths
  - docs/datapath-image-call.md - one description to one PNG via ComfyUI.
  - docs/datapath-shot-to-clip.md - one shot to a 3–6 second clip.
  - docs/datapath-reel-assembly.md - clips and sound to one film.
  - docs/datapath-listening.md - sound to beat sheet.
  - docs/datapath-writers-room.md - brief and beats to shot list (creator,
    writer, director).
  - docs/datapath-monologue.md - one speaker held for a whole speech.
  - docs/datapath-the-room.md - reels into a shared VR space.
- docs/roadmap.md - the six phases and what each ends with.
- docs/open-questions.md - questions waiting on the owner.

## Phases
Phases group related functionality, not calendar time. It is normal for the
last issue completed in a project to belong to phase 1.

1. The image call and the run - talking to ComfyUI; the run and its receipt.
2. Shots into motion - shot list, camera motions, drift, the gif-generator
   bridge, reel assembly, one-shot re-render.
3. The ear - loudness, onsets, sections, tempo; cuts on the beat.
4. The writers' room - creator, writer, director over ollama; the arc in
   semantic space.
5. The monologue booth - the held portrait, cutaways, mouth shapes.
6. The room - the generator loop and the VR corridor of screens.

## Project files
- .file-index-counter - the highest reading-order index used by any file in
  the project, so a new file can take the next number without a search.
- run-phase-demo - asks which completed phase to demonstrate, then runs it.
