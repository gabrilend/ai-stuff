# 502 — The health check

phase 5, the distant computer

## Current behavior

Nothing exists.

## Intended behavior

`scripts/health-check`, run on kuvalu: every row of `docs/provisioning.md`
"The health check reports", each printed as passed or failed with what it
found. It exits non-zero if any row failed. It changes nothing.

## Suggested implementation steps

1. Reuse the provisioner's checks (501) as the health check's rows, so the
   two never disagree about what "set up" means.
2. Add the rows only the running system has: services up, heartbeat age.

## Related documents

- `docs/provisioning.md`

## Blocked by

501.

## Blocks

503.
