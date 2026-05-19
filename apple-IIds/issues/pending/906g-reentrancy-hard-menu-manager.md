---
name: Menu Manager reentrancy fixes (structural)
phase: 9
status: pending (pending soramech)
blockedBy: [905g]
parent: 906
---

# 906g — Menu Manager reentrancy fixes (structural)

Structural refactor of Menu Manager routines flagged as
"structural" by issue 904.

## current behavior

After 905g, Menu Manager is lock-correct.

## intended behavior

- Likely minimal structural changes — menu interactions are modal
  and rarely contend. The audit may identify edge cases (e.g.,
  background-task menu-item enable/disable during foreground menu
  tracking) that need careful handling.

## suggested implementation steps

1. Wait for audit.
2. Design fixes if any.
3. Implement.

## related documents

- `issues/906-toolbox-reentrancy-fixes-hard.md` — parent

## notes

- May be empty or near-empty.
