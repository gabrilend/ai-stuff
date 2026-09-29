# 809c — The count utility

The third piece of 809.

## Current Behavior

Nobody can say how many assets exist per category or tier.

## Intended Behavior

A utility that counts cards only, never opening an asset itself: how many
per category at each tier.

## Suggested Implementation Steps

1. A folder walk reading `.card` files only.
2. The per-category, per-tier tally. **Test:** counts match the cards;
   nothing is read from any asset file itself.

## Blocked by

- 809a
