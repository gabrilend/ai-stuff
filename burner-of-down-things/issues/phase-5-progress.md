# Phase 5 Progress — The design

## Goals
New code built from the blueprint alone, level by level, each issue checked by running its own acceptance commands, repaired when it fails, its reach held when it cannot be. Delivery carries the ledger's fingerprint (docs/007).

Counts: run `/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/burner-of-down-things -m`.

## Completed Issues
- 501 the design folder — a house project per case, with scratch space of its own.
- 502 running acceptance — an issue's own commands, from the design folder, with a limit; the shared capture function now reports exit status honestly.
- 503 waves, build and repair — level by level, repaired twice, held when it cannot pass, regressions caught after every wave.
- 504 delivery — the design delivered with the fingerprint of its history, and never delivered twice for nothing.
- 505 phase 5 demo — the notes program rebuilt from its blueprint alone, and run.

- 506 workflows written from the blueprint alone — referees that never see the design; delivery trusts them, not the builder's own tests.

The phase's goal is met with the stand-in: a blueprint becomes running code
without the builder ever seeing the source. Run `tests/run-tests design` and
`./run-phase-demo 5`.
