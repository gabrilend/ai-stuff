# 705 — Health check across the machines

phase 7, bringing up the mini-computers

## Current behavior

Each part can be checked by hand.

## Intended behavior

One command on kuvalu that reports, per machine: rmail answering; the
endpoints its role uses answering; on voices, the turn runner's state, last
turn number and age, clone location (RAM or disk) and commit; on kuvalu, the
blitter, the canvas server, the current version and merge mode; and every
goodbye receipt, flagged if stale. Anything wrong is printed as an error and
the command exits non-zero.

## Suggested implementation steps

1. Reuse the survey's login and per-machine report layout (701).
2. A test on the rehearsal bench that stops one part and checks the report
   names it.

## Related documents

- `docs/architecture.md`

## Blocked by

704.

## Blocks

706.
