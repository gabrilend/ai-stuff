# 809d — Floors

The fourth piece of 809.

## Current Behavior

Built. `src/076-the-pool.lua` holds the floor table (`floors`, `floor`,
`set_floor`, at `<pool>/floors.table`) and the dry-run report
`floor_report(pool_dir, category, floor)`, built on 809c's per-tier
counts: how many of the category's assets the floor keeps in use, how
many fall below it, and how many of those are unrated, in one line.
Nothing in the pool is ever deleted or rewritten; only the floor table
changes. Checked by `tests/131-checking-floors.lua`.

## Intended Behavior

A floor per category (default 0); raising it reports how many assets it
would leave below the new floor, before anything is discarded. The pool
itself is never emptied by this utility — "nothing in it is ever deleted"
(docs/067) — it only reports the cost of raising a floor.

## Suggested Implementation Steps

1. The floor table.
2. The dry-run report, built on 809c's counts. **Test:** raising a floor
   reports how many assets fall below it; the utility discards nothing.
   Done.

## Decisions

- A floor is the lowest tier a category keeps *in use*; floor 0 (every
  category's default) leaves nothing out, unrated assets included. Any
  floor above 0 leaves the unrated out too, since they have not met it;
  the report counts them separately.
- The table is a text table (014) at `<pool>/floors.table`; it is not a
  `.card`, so no count ever reads it.
- `set_floor` returns the same report `floor_report` gives, so the cost
  is said with every change, and writes the floor table alone.
- Floors run 0 to 5 (the five tiers of 809b).

## Blocked by

- 809c
