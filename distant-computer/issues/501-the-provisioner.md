# 501 — The provisioner

phase 5, the distant computer

## Current behavior

Nothing exists. The owner is creating the Linode.

## Intended behavior

`scripts/provision`, run on kuvalu, makes a fresh Linode into the distant
computer, doing every row of `docs/provisioning.md` "The provisioner does".
It reads the address and root login from `input/distant` (ignored by git).
Each step checks before it acts, so running it twice changes nothing the
second time. It prints each step as done, already done, or failed, and stops
at the first failure.

The monorepo clone is made by pushing from kuvalu, so the distant computer
never needs GitHub access.

## Suggested implementation steps

1. A step list, each step a { check, act } pair over SSH.
2. `--dry-run` printing what each step would do.
3. Run against the real Linode once the owner has created it.

## Open questions

- Which Linux distribution will the Linode run? The package step depends on
  it.

## Related documents

- `docs/provisioning.md`

## Blocked by

302.

## Blocks

502, 503, 602.
