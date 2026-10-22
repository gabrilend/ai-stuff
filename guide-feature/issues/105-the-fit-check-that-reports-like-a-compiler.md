# 105 — The fit check that reports like a compiler

phase 1, the canvas and the blit

## Current behavior

Nothing exists. The check is designed in `docs/fit-check.md`.

## Intended behavior

One shared module, used by the turn (before sending), the blitter (size
only, on arrival) and the distiller:

- **in**: the model's reply text, the base canvas, the change budgets
  (words per turn, whole sentences per turn), and whether to check the
  budgets;
- **out**: either the reply read as rows that fit, or a list of problems.
  Each problem is a record of kind (`too-wide`, `wrong-height`,
  `too-many-changes`, `rewrote-sentences`), row (whole number, if any),
  measured and allowed (whole numbers);
- **report**: the problems as the text the model is given, one line per
  problem then the closing line restating the limits, word for word as in
  `docs/fit-check.md`.

The module never trims a reply. It only measures and reports. Change counts
come from the change finder (104), so the fit check and the blitter can
never disagree about what changed.

## Suggested implementation steps

1. Size checks, budget checks, the report.
2. Tests: a reply that fits; one per kind of problem; several at once; the
   report text checked word for word, since it is what the model reads.

## Related documents

- `docs/fit-check.md`

## Open questions

- The budget values (`docs/open-questions.md`, 3).
- Characters or terminal columns (`docs/open-questions.md`, 12).

## Blocked by

104.

## Blocks

107, 404, 601.
