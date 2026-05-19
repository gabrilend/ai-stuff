---
name: Resource Manager reentrancy fixes (structural)
phase: 9
status: pending (pending soramech)
blockedBy: [905b]
parent: 906
---

# 906b — Resource Manager reentrancy fixes (hard)

Structural refactor of Resource Manager routines flagged as
"structural" by issue 904.

## current behavior

After 905b, Resource Manager is lock-correct. The main remaining
issue is blocking I/O within long-held locks (file-read inside
`LoadResource`).

## intended behavior

- Refactor `LoadResource` to release the resource-map lock during
  the actual file read, re-acquiring only to install the loaded
  data. Requires careful map-snapshot semantics.
- Per-resource-fork caching to reduce file I/O contention.
- Other structural fixes per the audit.

## suggested implementation steps

1. Wait for audit.
2. Design the lock-release-during-IO refactor with explicit
   map-version checks on re-acquire.
3. Implement.
4. Test for the obvious race: two tasks loading from the same fork
   simultaneously; verify both get correct data.

## related documents

- `issues/906-toolbox-reentrancy-fixes-hard.md` — parent
- `issues/905b-reentrancy-easy-resource-manager.md` — prerequisite

## notes

- The lock-during-I/O is the canonical "you need structural
  refactor" pattern. Get it right here, the technique becomes
  reusable for other managers.
