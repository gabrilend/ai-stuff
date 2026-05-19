---
name: Scrap Manager reentrancy fixes (structural)
phase: 9
status: pending (pending soramech)
blockedBy: [905l]
parent: 906
---

# 906l — Scrap Manager reentrancy fixes (structural)

Structural refactor of Scrap Manager. Likely no-op (the phase 6
native version, issue 601, handles concurrency natively).

## current behavior

After 905l, Scrap Manager is lock-correct.

## intended behavior

- If issue 601 has landed: no work needed. Native Scrap Manager is
  already concurrent-safe by design.
- If issue 601 hasn't landed: audit-driven fixes to the emulated
  Scrap Manager.

## suggested implementation steps

1. Check 601's status.
2. Wait for audit if 601 hasn't landed.

## related documents

- `issues/906-toolbox-reentrancy-fixes-hard.md` — parent
- `issues/601-scrap-manager-native.md` — likely supersedes

## notes

- Likely empty.
