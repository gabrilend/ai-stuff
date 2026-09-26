# 107 — Phase 1 demo

## Current Behavior

No demo.

## Intended Behavior

`issues/completed/demos/phase-1-demo`: opens a throwaway case in the scratch
space, appends tens of thousands of ledger lines, verifies the chain, then
changes one byte in the middle of the file and shows the verifier naming that
exact line — then changes the hash to match and shows the next line catching
it. Leads with numbers: lines per second appended, lines per second verified,
SHA-256 megabytes per second, the head hash before and after.

## Suggested Implementation Steps

1. The demo script, runnable from any folder with `DIR` at its top.
2. **Test:** runs to the end through `./run-phase-demo 1`.

## Blocked by

- 106
