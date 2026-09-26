# 306 — The turn pool

Running a set of independent turns at once, then judging each
([005](../docs/005-datapath-the-hands.md), *many turns at once*).

## Current Behavior

Built as `src/039-the-turn-pool.lua`. A pool of effil threads takes shell lines from a channel until it is empty. Snapshots are taken once around the set. A change outside every writable path makes every turn of the set a breach — the design cannot say which of several simultaneous turns wrote it — so the check in step 2 is that the breach is caught and named in the ledger, and the whole set is marked. Exit 124 or 137 reads as "ran past its limit". Eight one-second stand-in turns in a pool of four take about two seconds; 48 quick turns run at about 380 a second in a pool of eight (phase 3 demo). Checked by tests/040.

## Intended Behavior

- **Run a set** (case, list of prepared turn folders, harness, pool size):
  snapshots the case folder and the source; starts up to pool-size worker
  threads, each taking the next turn from a shared queue (an effil channel)
  and running it (304); waits for all; snapshots again; compares and charges
  (303); writes each turn's `verdict` (`kept`, `breach`, `failed`); appends
  `turn-ended` for each and `breach` with the paths for any breach.
- Returns a table per turn: its folder, verdict, exit status, and the paths
  it changed.
- Pool size default: 4 for `subscription`, all hardware threads for `free`.

| Decision | What each path leads to |
|---|---|
| Any change in the source | Every turn of the set is `breach`; the caller stops the run |
| A change charged to the whole set lands outside the writable list | Every turn of the set is `breach` |

## Suggested Implementation Steps

1. The pool. **Test:** eight stand-in turns that each sleep a second finish
   in about two seconds with a pool of four.
2. Verdicts. **Test:** one of five turns writes outside; only it is a breach
   when its write is charged to it; the ledger names the path.

## Blocked by

- 303
- 304
