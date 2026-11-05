# Phase 1 Progress — The canvas and the blit

## Goals
The shared grid of characters and the rule for writing onto it, with no
network: read and write the canvas text, find its words, work out what a
voice changed against the version it started from, and blit those changes,
blanking any word that loses part of itself. Ends with three scripted voices
editing one canvas, counted version by version.
(`docs/roadmap.md`, phase 1)

Counts of done and open issues:
`/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/guide-feature -m`

## Completed Issues
(Each completed issue adds a line here saying what it built and how it
moves the phase toward its goals.)

- **101, settings from input/ and the goodbye receipt** (2026-11-05):
  `src/001-settings.lua` reads a program's `input/<program>` and the
  `endpoints` file, refusing a bad line with its place. `src/002-goodbye.lua`
  keeps the run log and writes `output/goodbye-<program>`. Every phase-1
  program (the blitter, 107) now has its way to start and end. Tests:
  `./run-tests`.
- **102, the canvas as text** (2026-11-05): `src/006-canvas-text.lua` reads
  and writes the canvas in all three directions, byte for byte, refusing a
  malformed one at its line. `src/005-utf8.lua` counts rows in characters for
  it, 103 and 105. The word finder (103), the blitter's arrivals (107) and the
  viewers' reader (202) now have their text form.
