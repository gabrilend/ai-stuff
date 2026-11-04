# 103 — Phase 1 demo

phase 1, the record and the settings

## Current behavior

Nothing exists. `./run-phase-demo` says no phase has a demo.

## Intended behavior

`issues/completed/demos/phase-1-demo`, run from `./run-phase-demo 1`:

1. reads its settings from `input/phase-1-demo` (entry count, workers);
2. writes a ledger of that many entries in `tmp/shared-memory/`, timing it;
3. checks the chain with 1, 2, 4... workers up to the core count and prints
   entries checked per second for each, as a small bar chart in the
   terminal;
4. copies the ledger, changes one byte in a randomly chosen entry (seed
   printed), and shows the checker naming exactly that entry;
5. writes its receipt and prints it.

## Suggested implementation steps

1. The demo script and its input file.
2. The bar chart as a tiny viewer function, separate from the numbers.
3. Run it, keep its output in this issue.

## Related documents

- `docs/roadmap.md`, phase 1

## Blocked by

101, 102.

## Blocks

None.
