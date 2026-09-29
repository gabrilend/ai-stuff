# 809c — The count utility

The third piece of 809.

## Current Behavior

Built, for category. `src/076-the-pool.lua`'s `counts(pool_dir)` walks
`.card` files only (never opens an asset) and tallies per category.
Checked by `tests/098-checking-pool-counts.lua`, including a card nested
in a subfolder and an empty pool counting nothing. Per-tier counting is
deferred: a "tier" is derived from a card's `ratings`, and 809b (which
decides the exact rating-append format) is not yet built, so there is
nothing yet to derive a tier number from.

## Intended Behavior

A utility that counts cards only, never opening an asset itself: how many
per category at each tier.

## Suggested Implementation Steps

1. A folder walk reading `.card` files only. Done: `076-the-pool.lua`'s
   `counts`.
2. The per-category, per-tier tally. Done for category; deferred for
   tier, which waits on 809b's rating format. **Test:** counts match the
   cards; nothing is read from any asset file itself. Done.

## Blocked by

- 809a
