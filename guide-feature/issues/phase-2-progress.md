# Phase 2 Progress — The canvas for viewers

## Goals
Marks that let a person skim what changed (words and their sentences,
aging), the viewer-side reader, the canvas files with history, the HTTP
canvas server, and how the canvas size changes. Ends with two readers
receiving identical versions and the marks aging over a replay.
(`docs/roadmap.md`, phase 2)

Counts of done and open issues:
`/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/guide-feature -m`

## Completed Issues
(Each completed issue adds a line here saying what it built and how it
moves the phase toward its goals.)

- **201, marks for skimming** (2026-11-05): `src/020-marks.lua` marks
  every cell a blit wrote or blanked as a changed `word` and the rest of its
  sentence as `sentence`, in the voice and version that changed it. A cell
  keeps only its newest mark, and marks are dropped once over the mark
  lifetime. The blitter marks each version before publishing it, and logs
  and counts the marks. The viewer-side reader (202) and the canvas files
  (203) now have marks to carry.
