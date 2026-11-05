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
- **103, the words on a canvas** (2026-11-05): `src/008-words.lua` finds every
  word with its row, column and length in characters, which word covers each
  cell, and the sentences. It is what the change finder (104), the blit (106)
  and the marks (201) measure with.
- **104, what a voice changed** (2026-11-05): `src/010-changes.lua` compares
  a voice's canvas with its base: the words kept, written, erased and
  overwritten, and the counts of words changed and sentences rewritten whole.
  The fit check (105) and the blit (106) both take their changes from it.
- **105, the fit check** (2026-11-05): `src/012-fit-check.lua` measures a
  model's reply against its base canvas and reports misfits as compiler-style
  lines, word for word as `docs/fit-check.md` has them. The change counts
  from 104 become the soft-budget note, and the blitter's size check on
  arrival is here too. The blit (106) is the last piece before the blitter
  loop (107).
- **106, the blit** (2026-11-05): `src/014-blit.lua` writes a voice's
  changes onto the shared canvas. Removals apply only where the word is
  still there, and conflicts are counted. Writes go in reading order, and
  cut words go to the collision rule (`blank-whole`, `keep-fragments`). A
  report lists every cell written and blanked. With 101-106, everything the
  blitter loop (107) needs is built.
- **107, the blitter loop** (2026-11-05): `src/016-blitter.lua` takes voice
  canvases from `tmp/shared-memory/arrivals/` oldest first, refuses bad ones
  with a reason (moved to `arrivals-refused/`), blits the rest into new
  versions kept in memory, publishes each to the log, and says goodbye on a
  stop file or (through `scripts/run-blitter`) a signal. What remains of
  phase 1 is its demo (108).
