# 602 — Phase 6 demo: newest and distill, side by side

phase 6, distill mode

## Current behavior

No demo compares the merge modes.

## Intended behavior

`issues/completed/demos/phase-6-demo` replays the same recorded voice
canvases (saved from a rehearsal) through the blitter twice, once per mode,
and shows the two resulting canvases side by side for each version, with:
words changed per version, conflicts (newest mode), distill fit retries and
seconds (distill mode), and how many of each voice's changes survived to the
shared canvas in each mode.

Replaying recorded canvases keeps the comparison fair: both modes see exactly
the same input.

## Suggested implementation steps

1. Record a rehearsal's arrivals, then the run script.
2. Fill in `issues/phase-6-progress.md`.

## Related documents

- `docs/roadmap.md`, phase 6

## Blocked by

601.

## Blocks

None.

## Decisions (2026-11-05; each the owner's to overturn)

1. **The demo records its own rehearsal** each run (a minute; `--minutes`),
   and `--save FOLDER` keeps the recording, `--from FOLDER` replays one.
   No recording is kept in the repository: it would be a stand-in's output,
   and the owner's real recording belongs to the owner's machine.
2. **The recording is every voice canvas the blitter took, with the
   version it started from** (written as viewers read it), so a replay
   finds each voice's changes against the same base in both modes. The
   rehearsal gained an `on_arrival` hook for this (601).
3. **One arrival is one step in both modes**: newest blits it; distill
   holds it and distills at once. So the two canvases can be set side by
   side arrival by arrival. A live distill takes in every arrival that
   came during the last one; the replay does not batch.
4. **"Conflicts" are the blit's own** (a word a voice erased that the
   shared canvas no longer showed). The demo also shows the *words written
   over*: words already on the shared canvas that a voice's write cut into
   or covered, which is where the voices meet in practice, since a voice
   rewriting a word writes over it rather than erasing it.
5. **A change survived** when the final canvas still shows it: a word the
   voice wrote still stands where it wrote it, a word it erased (or wrote
   over) is no longer there. Counted per voice, over all its arrivals, in
   each mode.
6. **The voices write a row at a time** (047's `rewrite` gained `fill`):
   without it, a canvas with one word on it has every later turn rewrite
   that word, and the demo showed one row.
7. **The stand-in distiller's rule changed** (047; noted in 601's file):
   the first rule only wrote on blank cells, so replayed canvases, whose
   bases come from the newest-mode run, were almost never taken in.
8. **Voices' replies take 4, 5 and 6 seconds**, so a minute holds about
   thirty arrivals: enough to see the modes part, few enough to read.
9. **Changed cells are highlighted in reverse video**, or marked `^` under
   their row with `--plain` (and when the output is not a terminal); only
   word marks, not the sentence marks around them.

## What was built (2026-11-05)

- `issues/completed/demos/phase-6-demo` and `phase-6-demo.lua`.
- `src/047-stand-in-llama.lua`: `rewrite`'s `fill`; the distill reply's
  claimed-word rule. `src/068-test-distill.lua` follows it (48 checks).
- `src/069-test-phase-6-demo.lua`: 23 checks.
- `issues/phase-6-progress.md` filled in and closed.

## Needs the owner's machine

- The demo recorded from a rehearsal with the real voices' models and
  replayed with the real distiller (`use.distiller`), to compare the modes
  on real writing.
