# 403 — The turn prompt

phase 4, the turn

## Current behavior

Nothing exists.

## Intended behavior

The prompt builder: the canvas record (102), the voice's name, the
recommended change counts, the last turn's advisory note (if any) and the
look tool's description in, a conversation out (list of
turns, each a role string, `system` or `user`, and a text string), in the
order of `docs/datapath-voice-turn.md`, step 4.

The instructions live in a text file, `input/turn-instructions`, with
markers the builder fills in (voice name, size, recommended change counts, the canvas), so the
owner can change how the voices are spoken to without touching source. The
central instruction, from the owner: change as little as possible to keep
what matters on screen while fitting in what is new, and edit single words
before changing sentences. Change as much as you like, but fewer is
recommended, and the words to reach for first are the operative ones, which
carry strength or direction: "'very' being replaced to 'not very' or similar
if something changes in magnitude or quality".

The canvas goes into the prompt exactly as its rows, with a ruler of column
numbers above and row numbers beside it, so the model can see where words
sit. The ruler is explained as not part of the canvas, and the fit check
rejects a reply that includes it.

## Suggested implementation steps

1. The instruction file and its markers.
2. The builder.
3. A reference prompt for a fixed canvas, kept as a file, so any change to
   the prompt shows up as a diff.

## Related documents

- `docs/datapath-voice-turn.md`
- `docs/fit-check.md`

## Open questions

- Should the voices know who the others are? (`docs/open-questions.md`, 6)
- The look call's form: native tool calls (needs the server's `--jinja`) or
  a recognised line in the reply? (`docs/open-questions.md`, 3)

## Blocked by

102.

## Blocks

404.
