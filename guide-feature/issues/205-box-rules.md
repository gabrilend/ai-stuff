# 205 — Box rules: who decides the size of the page

phase 2, the page protocol

## Current behavior

The page keeper's box is a fixed setting in its input file.

## Intended behavior

The table of box rules from `docs/display-box.md`, chosen by name in
`input/page-keeper`:

- `fixed WxH`;
- `smallest-viewer`: the smallest width and the smallest height among
  viewers in `tmp/shared-memory/viewers` (written by 204) heard from within
  a window of time (a setting);
- `named-viewer NAME`: the box of that one viewer.

When the rule gives a new box, the page keeper checks it with the box
arithmetic (103), refuses and logs a box that is too small, and otherwise
lays out and publishes a new page with the new `box` and `share`.

## Suggested implementation steps

1. The rule table.
2. The page keeper re-reads the rule's answer on each arrival and whenever
   the viewers file changes.
3. Tests: each rule; a viewer that stops asking drops out of
   `smallest-viewer` after the window; a box that is too small is refused.

## Related documents

- `docs/display-box.md`, "Who decides the size"

## Open questions

- Which rule is the default? (`docs/open-questions.md`, 5)

## Blocked by

103, 204.

## Blocks

206.
