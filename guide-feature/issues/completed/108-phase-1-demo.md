# 108 — Phase 1 demo: three voices on one canvas

phase 1, the canvas and the blit

## Current behavior

No demos exist. `run-phase-demo` in the project root reports that no phase
has one.

## Intended behavior

`issues/completed/demos/phase-1-demo` plays a scripted series of voice
canvases into the blitter's arrivals folder. The series is made by a small
generator script, not by hand, and is written to show single-word edits,
overlapping writes, stale bases and conflicts. The demo then shows:

- each version of the canvas, drawn at its real size in the terminal, with
  the cells that changed in that version highlighted;
- after each version: words written, words blanked by the whole-word rule,
  removals, conflicts;
- one deliberately oversized canvas being refused, and the fit check's report
  for it, exactly as a model would read it.

The numbers come from the blitter's log and goodbye receipt, so the demo
shows what the blitter really did.

## Suggested implementation steps

1. The scripted-series generator.
2. The run script and the drawing.
3. Fill in `issues/phase-1-progress.md`.

## Related documents

- `docs/roadmap.md`, phase 1

## Blocked by

107.

## Blocks

None.

## Decisions (2026-11-05; each the owner's to overturn)

1. **The demo runs the real blitter in a throwaway project**, through
   `scripts/run-blitter`. `src/`, `libs/` and `scripts/` are linked in, and
   it has its own `input/blitter` and RAM tiers. A blitter already running
   on the project is never touched, and its receipt is never moved aside.
   `--keep` leaves the copy, to read its log and receipt.
2. **The canvas is 40x6**, not `input/blitter`'s 60x20, so each version
   fits on screen with its numbers. The rule is `blank-whole`, the owner's.
3. **The generator is `src/018-phase-1-series.lua`**: six rounds of short
   edits (`put`, `erase`) on a base. It turns them into whole voice
   canvases. A base is "latest" or a version's number. The bases' rows come
   from the blitter's log, so the series never predicts the blit.
4. **The series:**
   - a first write onto the empty canvas;
   - a word replaced and a word erased, made on the same version;
   - `kitten` cutting `sat`, with another voice's removal of `sat` as the
     conflict;
   - `dog` from a voice on version 2, cutting `kitten` (the document's
     example, now with a stale base);
   - an oversized canvas;
   - a turn that changes nothing;
   - a last new line.
   Under the change finder (104), a word overwritten in place is not a
   removal. So the conflict comes from an erased word, and the stale `dog`
   brings no conflict.
5. **Changed cells are highlighted in reverse video** on a terminal. When
   the output is not a terminal, or `NO_COLOR` is set, or with `--plain`,
   changed cells are marked with `^` on a line below the row instead.
   Changed means different from the version before.
6. **"Words blanked by the whole-word rule" is the log's cut count.** Under
   `blank-whole`, every cut word is blanked whole. The label names the rule
   when it is another one.
7. **Every number is read from the blitter's log** (each turn's summary
   line and each version's rows) **and from its receipt.** The demo ends by
   adding up the log and comparing it with the receipt, line by line. It
   exits 1 if they disagree.
8. **The fit check's report is computed by the demo** from the oversized
   canvas against its base, with `fit.check` and `fit.report` (105). It is
   shown word for word, each line quoted with `> `, beside the blitter's own
   refusal line. Fit-checking a reply happens on the voice's side (303).
   The blitter only checks size.
9. **Arrivals are written under a `.` name and renamed**, as the rmail hook
   does (302).
10. **The demo stops the blitter with its stop file.** The wrapper also
    sends TERM, and removes the copy, if the demo ends any other way.

## Implementation notes (2026-11-05)

- `src/018-phase-1-series.lua`: the scripted series and its generator.
- `issues/completed/demos/phase-1-demo`: the wrapper. It makes the
  throwaway project, starts nothing itself, and cleans up on exit.
- `issues/completed/demos/phase-1-demo.lua`: the body. It starts the
  blitter, plays the rounds, reads the log as it grows, draws, and checks
  the receipt.
- `src/019-test-phase-1-demo.lua`: 37 pass, about 17 seconds.
- Mutation checks were each caught:
  - no cells marked;
  - the log's written words not added up;
  - no stop file;
  - the report not quoted;
  - highlighting when piped;
  - an unchanged turn not told;
  - the copy not removed;
  - arrival times restarting each round;
  - "latest" off by one.

  Removing the series' own width guard is an equivalent mutant: the canvas
  writer (102) refuses the same canvas.
- A `.info.md` beside each new source file. `.file-index-counter` is at 019.

A run, plain, ends with the receipt:

    arrivals-taken 9, versions-made 7, versions-in-history 8,
    words-written 26, words-covered 2, cut-blanked 2, removals-applied 1,
    conflicts 1, refused-wrong-size 1, unchanged-turns 1

**Checked here:** with LuaJIT 2.1 on Linux, both piped (plain) and
through a pseudo-terminal (`script -qc`). The pseudo-terminal run showed
the reverse-video codes on exactly the changed cells, but no one has looked
at it on a real screen.

**Needs the owner's machine:** a look at the highlighted form in a
terminal, and a run at `/mnt/mtwo/programming/ai-stuff/guide-feature`.
