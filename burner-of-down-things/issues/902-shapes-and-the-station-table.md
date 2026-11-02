# 902 — Shapes and the station table

The switchboard plans by shape, not by content: what a parcel is made of and what is wanted back, as types ([068](../docs/068-datapath-the-switchboard.md)).

## Current Behavior

902a, 902b and 902d are built (issues/completed/902a-scalar-types.md,
902b-structured-types.md, 902d-station-table.md): the closed type list;
recognisers for the three scalar types and the three structured ones
(`image`, `clip`, `table`); and the station table with its shape matching.
902c (the remaining five types and `unknown`) is not yet built, so a
parcel that is none of those six still falls through to nil rather than
`unknown`.

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
