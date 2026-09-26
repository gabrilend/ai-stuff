# Phase 1 Progress — The case and the ledger

## Goals
Everything the machine knows about one piece of software lives in one folder, and everything that happened to it is one append-only file whose lines are chained by SHA-256, so any edit short of rewriting the whole history is caught at the exact line. Every run reads input/ first and writes goodbye last. Ends with a demo that tampers with a ledger and catches it (docs/003).

Counts: run `/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/burner-of-down-things -m`.

## Completed Issues
- 101 paths and scratch space — the `machine` launcher and the one module every path is built from.
- 102 text tables — the one reader and writer of tab-separated tables and of records.
- 103 SHA-256 — the checksum, in pure LuaJIT, matching the standard and `sha256sum`.
- 104 the ledger — append, verify, head hash; every tampering caught at its line.
- 105 the case folder — open, load, lock, and which requests in `input/` are new.
- 106 the command dispatcher — the shape of every run: input first, lock, verify, work, goodbye.
- 107 phase 1 demo — a 30 000 line ledger grown, verified and tampered with, twice.

The phase's goal is met: a case is one folder whose history cannot be changed
without the change being named, and every run starts from `input/` and ends
with a goodbye. Run `tests/run-tests` for the checks and `./run-phase-demo 1`
for the numbers.
