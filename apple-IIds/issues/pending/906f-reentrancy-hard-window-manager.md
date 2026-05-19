---
name: Window Manager reentrancy fixes (structural)
phase: 9
status: pending (pending soramech)
blockedBy: [905f]
parent: 906
---

# 906f — Window Manager reentrancy fixes (structural)

Structural refactor of Window Manager routines flagged as
"structural" by issue 904.

## current behavior

After 905f, Window Manager is lock-correct. Structural concerns
mostly involve the interaction between window-list mutations and
the update-region machinery.

## intended behavior

- Per-task update regions so concurrent dirty-window tracking
  doesn't serialize.
- Refactor of the dragging / resizing inner loop so it doesn't
  hold the window-list lock during the full drag.
- Other audit-driven changes.

## suggested implementation steps

1. Wait for audit.
2. Design fixes.
3. Implement.

## related documents

- `issues/906-toolbox-reentrancy-fixes-hard.md` — parent

## notes

- Likely modest in scope — Window Manager contention is low.
