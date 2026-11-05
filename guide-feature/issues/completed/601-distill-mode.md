# 601 — Distill mode

phase 6, distill mode

## Current behavior

The blitter has one merge mode, `newest` (107).

## Intended behavior

The owner: "This updated copy will be sent to Kuvalu, who will run all
three combined to distill it once more, and then display it to the screen.
Alternatively, kuvalu might (this is the original design) might simply
update the display to the newest one."

`distill`, the second entry in the blitter's mode table, as designed in
`docs/datapath-blit.md`, "distill":

1. The blitter keeps the newest canvas from each voice, with the words each
   changed against its own base (104).
2. On each arrival it builds a prompt from an instruction file
   (`input/distill-instructions`): the current canvas, each voice's newest
   canvas, and the words each changed, with the same rules the voices follow.
3. It asks the `distiller` endpoint, through the same ask-until-it-fits loop
   as a turn (404), with no look calls.
4. It blits the distilled canvas with the current canvas as its base.

Arrivals during a distill wait. Only each voice's newest is kept, so no queue
builds up. The mode is read from `input/blitter` on each arrival, so it can
be switched while running.

Both modes are tested in the rehearsal before this issue is complete,
because the owner's rule is that a new mode is not done until both modes are
shown working.

## Suggested implementation steps

1. Keep newest-per-voice in the blitter.
2. The distill prompt and the mode function.
3. Switch modes during a rehearsal run, and check both produce valid
   versions.

## Related documents

- `docs/datapath-blit.md`

## Open questions

- None left on credit: distilled changes carry `kuvalu`'s name and the
  distiller is not asked where each came from ("like melting two candles to
  each other", `docs/datapath-blit.md`, "distill").

## Blocked by

101, 105, 107, 401, 404.

## Blocks

602.

## Decisions (2026-11-05; each the owner's to overturn)

1. **One distill per batch, not per arrival.** The blitter takes every
   arrival waiting (each one checked as before, kept as its voice's newest
   and *held*), then runs one distill for all of them. So arrivals that come
   during a distill wait in the folder, and three arrivals at once cost one
   distill, not three. "Only each voice's newest is kept": a second arrival
   from a voice already held replaces the first (`held-replaced`).
2. **Every voice's newest is shown, not only the ones just held.** Step 2
   says "each voice's newest canvas"; a voice whose newest was already
   distilled is shown again, beside the current canvas that holds what came
   of it. Voices with no canvas yet are left out, and `{{count}}` says how
   many there are.
3. **The voices' newest is kept in both modes**, so a switch to distill
   has every voice's latest from the first distill.
4. **Words written over count as erased** in the changed-word lines (104
   lists them apart from words erased to blanks): to the distiller, a word
   gone is gone.
5. **Recommended counts for the distiller are their own settings**, in a
   new `input/distill` (36 words, 3 sentences: three voices' worth of a
   turn's 12 and 1), not in `input/blitter`, whose every test and demo
   writes its own file. Advice only, as for a voice.
6. **A failed distill keeps its arrivals held** and is tried again at the
   next step (the next second, run as a program). Nothing is dropped; the
   log and `distills-failed` say so. The model caller's timeout bounds each
   try.
7. **Held arrivals are distilled even if the mode is switched back first**:
   the mode read on their arrival decides what happens to them.
8. **Cuts a distill makes are kuvalu's**, so no voice is told of them under
   tell-the-voice.
9. **The stand-in distiller (047's `distill` reply) merges word by word**:
   each erased or written word is applied where the current canvas still
   allows it (the old word still there; the cells still blank), in the
   order shown, so an older change never undoes a newer one and the voice
   listed first keeps a contested place. A real model is free to do better;
   this only has to be deterministic for the tests and the phase 6 demo.
10. **The turn's instruction parser is shared**: 049's `parse` became
    `parse_spec(text, spec)` and `fill` is exported, so the two instruction
    files are read and refused the same way.

## What was built (2026-11-05)

- `src/016-blitter.lua`: `b.newest` (each voice's newest, both modes);
  `M.MODES.distill` and `M.HELD`; `b:accept()` (an arrival past its
  checks, used by the phase 6 replay); `b:distill_held()`, run by `step`;
  the counters `arrivals-held`, `held-replaced`, `distills`,
  `distills-failed`, `unchanged-distills`, `distill-asks`,
  `distill-tries`, `distill-milliseconds`. An unbuilt mode is still refused.
- `src/067-distill.lua` and `input/distill-instructions`, `input/distill`.
- `src/049-turn-prompt.lua`: `parse_spec`, `fill`, `SPEC`.
- `src/047-stand-in-llama.lua`: the `distill` reply.
- `src/043-rehearsal.lua`: copies the distill inputs; distills after each
  round's arrivals; the `distilled`, `held` and `replaced` outcomes;
  `on_arrival`.
- `src/068-test-distill.lua`: 47 checks, including the owner's rule: a
  rehearsal switched from newest to distill and back while it runs, every
  version valid. `src/017-test-blitter.lua` tests the unbuilt-mode refusal
  with distill taken out of the table.
- Docs: `datapath-blit.md` ("distill", "As built"), `fit-check.md`, the
  blitter's, rehearsal's, stand-in's and prompt's info files,
  `input/blitter`'s comment.

## Needs the owner's machine

- A real distiller model on `use.distiller` (the endpoints file names
  `kuvalu-qwen`): the words in `input/distill-instructions` and the
  recommended counts in `input/distill` tried and tuned, with what changes
  written to `docs/balance-updates.md`.
- How long a real distill takes beside a real turn, and whether one distill
  per batch keeps up with three voices.

## Changed by 602 (2026-11-05)

- Decision 9's stand-in rule was too strict for the phase 6 demo: replayed
  canvases' bases come from the newest-mode run, so the distill replay's
  current canvas never showed the words they replaced, and almost nothing
  was taken in. 047's `distill` reply now writes a voice's word over
  whatever word stands there, unless that word is *claimed* (some voice's
  newest wrote it there) or was written earlier in the same distill; the
  voice listed first still keeps a contested place, and an older change
  still never writes over a word another voice's newest wrote. 068's check
  of it changed with it, and gained one for the claim.

