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

- Whose name goes on a distilled change? (`docs/open-questions.md`, 4)

## Blocked by

101, 105, 107, 401, 404.

## Blocks

602.
