# 809d — Floors

The fourth piece of 809.

## Current Behavior

Nothing enforces a minimum kept per category.

## Intended Behavior

A floor per category (default 0); raising it reports how many assets it
would leave below the new floor, before anything is discarded. The pool
itself is never emptied by this utility — "nothing in it is ever deleted"
(docs/067) — it only reports the cost of raising a floor.

## Suggested Implementation Steps

1. The floor table.
2. The dry-run report, built on 809c's counts. **Test:** raising a floor
   reports how many assets fall below it; the utility discards nothing.

## Blocked by

- 809c
