# 701 — The center

The personality: weights computed from the ledger alone
([009](../docs/009-datapath-the-center.md)).

## Current Behavior

Everything is done in age and id order; nothing remembers what the person
attends to.

## Intended Behavior

- **Compute** (ledger lines): walk in order; before each line multiply every
  weight by the keep factor; add the kind's weight to the line's `about` (for
  `graded`, one to each touched id read from the line's text). Returns a
  table: `about` → weight (number), plus the line count and head hash used.
- The keep factor and the weight table are one table in the source; changes
  go to `docs/balance-updates.md` with reasons.
- **View:** writes `center.txt` (the ten heaviest, the count, the head hash)
  and prints it; command `center`. The machine never reads `center.txt` back.

## Suggested Implementation Steps

1. **Test:** a fixture ledger's weights computed by hand match to 1e-9.
2. **Test:** the same ledger gives the same center twice; deleting
   `center.txt` changes nothing the machine does.

## Blocked by

- 104
