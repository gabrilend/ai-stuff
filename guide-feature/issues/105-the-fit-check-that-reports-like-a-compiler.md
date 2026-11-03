# 105 — The fit check that reports like a compiler

phase 1, the canvas and the blit

## Current behavior

Nothing exists. The check is designed in `docs/fit-check.md`.

## Intended behavior

One shared module, used by the turn (before sending), the blitter (size
only, on arrival) and the distiller:

- **in**: the model's reply text, the base canvas, and the recommended
  change counts (words per turn, whole sentences per turn, whole numbers);
- **out**: either the reply read as rows that fit, or a list of problems.
  Each problem is a record of kind (`too-wide`, `wrong-height`), row (whole
  number, if any), measured and allowed (whole numbers). Alongside either,
  the change counts (words changed, whole sentences rewritten, whole
  numbers) for the advisory note. The change counts never refuse a reply:
  the owner made the limit soft (`docs/fit-check.md`, "The change budget is
  soft");
- **report**: the problems as the text the model is given, one line per
  problem then the closing line restating the limits, word for word as in
  `docs/fit-check.md`.

The module never trims a reply. It only measures and reports. Change counts
come from the change finder (104), so the fit check and the blitter can
never disagree about what changed.

## Suggested implementation steps

1. Size checks, the change counts, the report, the advisory note.
2. Tests: a reply that fits; one per kind of problem; several at once; the
   report text checked word for word, since it is what the model reads.

## Related documents

- `docs/fit-check.md`

## Open questions

- Characters or terminal columns (`docs/open-questions.md`, 4).

## Blocked by

104.

## Blocks

107, 404, 601.
