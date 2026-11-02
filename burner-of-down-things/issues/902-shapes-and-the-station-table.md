# 902 — Shapes and the station table

The switchboard plans by shape, not by content: what a parcel is made of and what is wanted back, as types ([068](../docs/068-datapath-the-switchboard.md)).

## Current Behavior

All four pieces are built (issues/completed/902a-902d): the closed type
list with a recogniser for every type, and `unknown` for anything else
(step 1's test holds); and the station table with its shape matching. The
station table holds only stations built today (807a's `txt-table`), so
step 2's own example — `integer-array + text → image` finding the chart
station — waits on the `.png` end (804) and its chart word (805) joining
the table; a shape no station gives is already said plainly. Kept open
for that.

## Intended Behavior

- **Types**, a closed list: `integer-array`, `number-array`, `text`, `table`, `image`, `clip`, `source`, `program`, `results`, `finding`, `request`. Adding one is adding a row, with how the machine recognises it without a model (an integer array is a line of integers; an image is a PNG signature; …).
- **A shape** is inputs → output: `integer-array + text → image`.
- **The station table**: one row per station — its name, the shape it takes, the shape it gives, and the command or step that runs it (the studio's ends, the machine's own steps, running a program).

## Suggested Implementation Steps

1. Types recognised without a model. **Test:** one fixture per type is recognised; an unknown thing is `unknown`, never a guess.
2. The station table and shape matching. **Test:** `integer-array + text → image` finds the chart station; a shape no station gives is said plainly.

## Sub-issues

- 902a — scalar types
- 902b — structured types
- 902c — remaining types, and `unknown`
- 902d — the station table

## Blocked by

- 804
- 807
