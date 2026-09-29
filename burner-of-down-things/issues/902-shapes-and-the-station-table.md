# 902 — Shapes and the station table

The switchboard plans by shape, not by content: what a parcel is made of and what is wanted back, as types ([068](../docs/068-datapath-the-switchboard.md)).

## Current Behavior

Nothing knows what kind of thing a parcel is.

## Intended Behavior

- **Types**, a closed list: `integer-array`, `number-array`, `text`, `table`, `image`, `clip`, `source`, `program`, `results`, `finding`, `request`. Adding one is adding a row, with how the machine recognises it without a model (an integer array is a line of integers; an image is a PNG signature; …).
- **A shape** is inputs → output: `integer-array + text → image`.
- **The station table**: one row per station — its name, the shape it takes, the shape it gives, and the command or step that runs it (the studio's ends, the machine's own steps, running a program).

## Suggested Implementation Steps

1. Types recognised without a model. **Test:** one fixture per type is recognised; an unknown thing is `unknown`, never a guess.
2. The station table and shape matching. **Test:** `integer-array + text → image` finds the chart station; a shape no station gives is said plainly.

## Blocked by

- 804
- 807
