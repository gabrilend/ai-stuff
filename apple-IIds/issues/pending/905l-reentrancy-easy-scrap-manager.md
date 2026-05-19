---
name: Scrap Manager reentrancy fixes (lock wrappers)
phase: 9
status: pending (pending soramech)
blockedBy: [902, 904]
parent: 905
---

# 905l — Scrap Manager reentrancy fixes (easy)

Lock-wrapper fixes to the Scrap Manager. The scrap data is the
shared state.

## current behavior

The Scrap Manager already has phase 6's native version (issue 601)
with locking baked in. This sub-issue's relevance depends on
whether 601 lands before phase 9 or after.

## intended behavior

- If 601 lands first: this sub-issue is essentially a no-op — 601's
  native version already locks.
- If 601 lands after: add lock wrappers to the emulated Scrap
  Manager as a phase 9 fix. They'll be superseded when 601 lands.

## suggested implementation steps

1. Check the phase 6 / phase 9 ordering.
2. If needed, add lock wrappers; group as
   `patches/211-scrap-locks.gsos.s.patch`.

## related documents

- `issues/905-toolbox-reentrancy-fixes-easy.md` — parent
- `issues/601-scrap-manager-native.md` — may supersede this

## notes

- Likely a no-op if 601 lands first. Tracking it for completeness.
