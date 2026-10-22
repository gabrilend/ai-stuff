# 205 — Resizing the canvas

phase 2, the canvas for viewers

## Current behavior

The canvas size is a setting the blitter reads at start (107). The owner's
first request asked for the size to "dynamically adjust to various size
screens".

## Intended behavior

Not yet decided. Every word on the canvas sits at a fixed row and column, so
a size change affects every voice's words at once:

- **smaller**: rows and columns past the new edge are lost, and words cut by
  the edge must be blanked whole, by the same rule as the blit;
- **larger**: the new space is empty;
- every voice's base becomes a different size from the current canvas, so
  turns that were already running are refused.

The candidate designs are listed in `docs/open-questions.md`, 5. This issue
is written as a blueprint once the owner chooses.

## Suggested implementation steps

1. Decide with the owner.
2. Then the resize operation, its marks (a resize could mark every cell as
   changed by `kuvalu`), and what voices are told.

## Related documents

- `docs/roads-not-taken.md`, "The box follows the smallest viewer"

## Open questions

- How the canvas size changes (`docs/open-questions.md`, 5).

## Blocked by

107.

## Blocks

206.
