# 505 — Health check across the machines

phase 5, bringing up the fg-sora machines

## Current behavior

Each part can be checked by hand.

## Intended behavior

One command on kuvalu that reports, per machine: rmail answering, the model
or relay answering, the thinker running, its last frame's number and age, its
goodbye receipt (and whether it is stale), and on kuvalu the page keeper and
page server. Something wrong is printed as an error and the command exits
non-zero.

## Suggested implementation steps

1. Reuse the survey's login and per-machine report layout (501).
2. A test that stops one part on the rehearsal bench and checks the report
   names it.

## Related documents

- `docs/architecture.md`

## Blocked by

504.

## Blocks

506.
