# 902a — Scalar types

The first piece of 902.

## Current Behavior

Built. `src/081-the-shape-types.lua`'s `recognise(bytes)` tries
`integer-array`, `number-array`, then `text`, in that order, and returns
`nil` (never a guess) when none match. `TYPES` holds the closed list of
all eleven shape types, for 902b/902c to extend with recognisers of their
own. Checked by `tests/082-checking-the-shape-types.lua`.

## Intended Behavior

Recognisers for the simplest types, without a model: `integer-array` (a
line of integers), `number-array` (a line of numbers, a fractional part
allowed), `text` (anything else that decodes as UTF-8 lines).

## Suggested Implementation Steps

1. The three recognisers, tried in that order. Done. 2. The closed `TYPES`
   list they draw from. Done. **Test:** one fixture per type is
   recognised; a file matching none of the three falls through rather
   than being guessed. Done.

## Blocked by

None
