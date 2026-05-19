---
name: Control Manager reentrancy fixes (structural)
phase: 9
status: pending (pending soramech)
blockedBy: [905h]
parent: 906
---

# 906h — Control Manager reentrancy fixes (structural)

Structural refactor of Control Manager. Likely minimal.

## current behavior

After 905h, Control Manager is lock-correct.

## intended behavior

- Audit-driven fixes. Probably none required — controls are
  per-window and naturally serialized by Window Manager locking.

## suggested implementation steps

1. Wait for audit.
2. Implement if anything is identified.

## related documents

- `issues/906-toolbox-reentrancy-fixes-hard.md` — parent

## notes

- Likely empty.
