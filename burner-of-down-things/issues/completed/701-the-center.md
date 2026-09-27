# 701 — The center

The personality: weights computed from the ledger alone
([009](../docs/009-datapath-the-center.md)).

## Current Behavior

Built as `src/058-the-center.lua`, with the `center` command in `src/061-the-center-commands.lua`. The numbers live in one table (`BALANCE`), recorded with reasons in `docs/balance-updates.md`. Checked by tests/062 against a hand computation to 1e-9, for determinism, and — through the case viewer — against the page's own recomputation in JavaScript.

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
