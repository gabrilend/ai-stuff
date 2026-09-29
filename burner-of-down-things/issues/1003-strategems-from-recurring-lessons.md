# 1003 — Strategems from recurring lessons

*study and develop your strategems* — a mechanism met in two or more cases, or two or more parts of the machine, is drafted as a strategem in the house form, and the person keeps it or changes it ([069](../docs/069-the-story.md)).

## Current Behavior

`strategems/` holds the two the machine's own building taught (a referee never sees the answer; dynamic re-abstraction), written by hand. 1003a is built (issues/completed/1003a-recurrence-trigger.md): the recurrence check itself, taking any counts table shaped like 1002d's output. 1003b (the draft form), 1003c (the drafts folder) and 1003d (the promotion gate) are not yet built, so nothing is drafted automatically yet.

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
