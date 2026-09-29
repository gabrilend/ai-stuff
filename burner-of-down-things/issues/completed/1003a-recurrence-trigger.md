# 1003a — The recurrence trigger

The first piece of 1003.

## Current Behavior

`strategems/` still holds only the two written by hand — nothing is
*drafted into `strategems/drafts/`* automatically yet (1003b does that).
But the trigger itself is built: `src/088-the-strategem-trigger.lua`'s
`due(counts, drafted)` names every mechanism counted at least twice and
not yet drafted, taking any counts table shaped like 1002d's own output
(1002d is not yet built, so this is exercised with a fixture counts
table). Checked by `tests/089-checking-the-strategem-trigger.lua`.

## Intended Behavior

When 1002d's count for a mechanism reaches two, a draft is triggered —
reading the count, not judging it.

## Suggested Implementation Steps

1. The trigger check (count >= 2 and no existing draft for this
   mechanism yet). Done: `088-the-strategem-trigger.lua`'s `due`. **Test:**
   one lesson drafts nothing; a second of the same mechanism drafts one.
   Done.

## Blocked by

- 1002
