# 901 — The terminal dashboard

phase 9, seeing it

## Current behavior

Nothing exists.

## Intended behavior

`scripts/dashboard`: a terminal view that refreshes every few seconds and
changes nothing. It shows the link state and the heartbeat's age, the gate
counts per folder and kind, the oldest waiting request, the last ten ledger
entries, each program's last receipt, and the budget against this month's
spend.

## Suggested implementation steps

1. A function that gathers the numbers into one table (data).
2. A function that draws that table (viewer).

## Related documents

- `docs/architecture.md`

## Blocked by

203.

## Blocks

903.
