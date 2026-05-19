---
name: Print Manager reentrancy fixes (lock wrappers)
phase: 9
status: pending (pending soramech)
blockedBy: [902, 904]
parent: 905
---

# 905n — Print Manager reentrancy fixes (easy)

Lock-wrapper fixes to the Print Manager. The active-job list is
the shared state.

## current behavior

The Print Manager assumes single-threaded usage. Multiple tasks
printing simultaneously would corrupt the job list.

## intended behavior

- `print_lock` held during: job creation, completion, page
  iteration.

## suggested implementation steps

1. Wait for audit.
2. Add lock wrappers.
3. Group as `patches/213-print-locks.gsos.s.patch`.

## related documents

- `issues/905-toolbox-reentrancy-fixes-easy.md` — parent

## notes

- Printing is rare on Apple IIds (no physical printer); contention
  is essentially zero. Include for completeness.
