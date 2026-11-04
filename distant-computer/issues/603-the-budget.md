# 603 — The budget

phase 6, the steward

## Current behavior

Nothing exists.

## Intended behavior

`input/budget` holds `per-month` (a decimal, in dollars) and `stop-at` (a
decimal between 0 and 1). After each turn the loop records that turn's cost,
as Claude Code reports it, into the ledger as a `note` with a `cost` field.
Before each turn it sums this month's costs. Past `per-month × stop-at`, it
files one `decision` request ("raise, hold or stop?") and runs no more turns
until answered.

## Suggested implementation steps

1. Reading a turn's cost from Claude Code's output.
2. The month sum from the ledger.
3. The stop and the request; tests with made-up costs.

## Open questions

- The budget itself (`docs/open-questions.md`, 5).

## Related documents

- `docs/architecture.md`, "What the steward may do without asking"

## Blocked by

102, 602.

## Blocks

605, 801.
