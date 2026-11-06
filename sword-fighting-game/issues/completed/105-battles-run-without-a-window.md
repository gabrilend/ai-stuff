# 105 — Battles Run Without A Window

| | |
| --- | --- |
| Phase | 1 — The spine |
| Blocked by | 103, 104, 305 |
| Blocks | phase 1 and 3 demos |
| Files | `src/020-headless.lua`, `run-headless`, `run-many-battles` |

## Current behavior

Built. `./run-headless` runs `src/020-headless.lua` as a program (it finds
its neighbours from its own path); modes are a table (match, battle, duel; a
duel is one soldier a side). `./run-many-battles COUNT [options]` starts one
process per core in waves and totals the receipts with
`scripts/total-receipts`. 256 battles take about eight seconds on twelve
cores. Running batches is how the first-strike bias in issue 305 was
found.

## Intended behavior

`./run-headless` runs a battle, a duel or a whole match under plain LuaJIT,
with no window, as fast as the processor allows, and writes the same receipt
the window does. The player's soldier is driven by its own soldier mind
(unless a script gives it input), so a headless battle is a full battle.
`--report` prints a summary at the end: the counters, and per-contingent
survivors.

`./run-many-battles COUNT [options]` runs COUNT headless battles with seeds
1..COUNT, spread over one process per processor core (never a single thread
for a batch), each writing its receipt under tmp/shared-memory/batches/, then
gathers them into one table: wins per side, mean length, parry rate, critical
share. Receipts are plain text, so the gathering is a reading of files.

## Suggested implementation steps

1. The headless runner is a loop: build the run from input/ and the
   arguments, tick until the battle or match is over or the script quits,
   write the receipt.
2. The batch script launches background processes in groups of the core
   count and waits for each group.
3. Test: the same seed gives the same receipt counts twice in a row.
