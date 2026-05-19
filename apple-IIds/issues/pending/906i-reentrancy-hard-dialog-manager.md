---
name: Dialog Manager reentrancy fixes (structural)
phase: 9
status: pending (pending soramech)
blockedBy: [905i]
parent: 906
---

# 906i — Dialog Manager reentrancy fixes (structural)

Structural refactor of Dialog Manager. Likely minimal.

## current behavior

After 905i, Dialog Manager is lock-correct.

## intended behavior

- Audit-driven fixes. Modal dialogs serialize by definition.
- Modeless dialogs may need more attention — they coexist with
  arbitrary other tasks.

## suggested implementation steps

1. Wait for audit.
2. Implement if anything is identified.

## related documents

- `issues/906-toolbox-reentrancy-fixes-hard.md` — parent

## notes

- Modeless dialog handling is the place to look first.
