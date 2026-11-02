# 1003 — Strategems from recurring lessons

*study and develop your strategems* — a mechanism met in two or more cases, or two or more parts of the machine, is drafted as a strategem in the house form, and the person keeps it or changes it ([069](../docs/069-the-story.md)).

## Current Behavior

All four pieces are built (issues/completed/1003a-1003d).
`machine strategems` reads `output/story/lessons.md`, and for every
mechanism met in two or more lessons writes a draft in the house form into
`strategems/drafts/` (one file per mechanism; a further recurrence
rewrites only its examples). Only the person's
`scripts/116-promote-strategem.lua` moves a draft into `strategems/`. Both
of this issue's tests hold (one lesson drafts nothing, a second drafts
one; a draft never appears in `strategems/` without the person's move).
`strategems/` still holds the four the machine's own building taught,
written by hand.

What is left: the draft's prose sections (what it means, the shape, when
not to use it) say "not yet written" — a turn drafting them from the
examples is not wired; and kept strategems are not yet handed to future
turns as crafts. Kept open for those.

## Intended Behavior

- When a mechanism's count reaches two, a turn drafts a strategem into `strategems/drafts/`: what it means, the shape, the examples (with their lessons), when not to use it — the form of rao-chat's *other people's software as a rubric*.
- A draft becomes a strategem only when the person moves it; the machine never promotes its own.
- Strategems are handed to future turns as crafts when they apply.

## Suggested Implementation Steps

1. Drafting on recurrence. **Test:** one lesson drafts nothing; a second of the same mechanism drafts one.
2. Keeping. **Test:** a draft never appears in `strategems/` without a person's move.

## Sub-issues

- 1003a — the recurrence trigger
- 1003b — the draft form
- 1003c — the drafts folder
- 1003d — the promotion gate

## Blocked by

- 1002
