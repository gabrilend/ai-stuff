# 204 — Phase 2 demo

phase 2, the gate

## Current behavior

Nothing exists.

## Intended behavior

`issues/completed/demos/phase-2-demo`: a throwaway git repository and gate
in `tmp/shared-memory/`. A stand-in steward writes one request of each
kind, plus three that must be refused. The demo approves some and declines
others through the same functions `gate` uses, then shows: counts per folder
and per kind, the ledger entries written, the chain checked (phase 1), the
diff the `write` applier made, and the commit the `commit` applier made.

## Suggested implementation steps

1. The stand-in steward as a function that writes requests.
2. The demo script and its numbers.

## Related documents

- `docs/roadmap.md`, phase 2

## Blocked by

202, 203.

## Blocks

None.
