---
name: Loader reentrancy fixes (lock wrappers)
phase: 9
status: pending (pending soramech)
blockedBy: [902, 904]
parent: 905
---

# 905c — Loader reentrancy fixes (easy)

Lock-wrapper fixes to the Loader. A single `loader_lock`
serializes segment-table updates and OMF parsing.

## current behavior

The Loader assumes single-threaded launches. Two tasks launching
applications simultaneously would corrupt the segment table.

## intended behavior

- `loader_lock` held during: `LoadSegName`, `UnloadSegName`, the
  initial-load sequence, and any segment-table mutation.
- Loading is rare (only on app launch / segment fault), so
  contention is essentially zero.

## suggested implementation steps

1. Wait for the audit's Loader section.
2. Add lock wrappers.
3. Group as `patches/202-loader-locks.gsos.s.patch`.
4. Test.

## related documents

- `issues/905-toolbox-reentrancy-fixes-easy.md` — parent
- `issues/904-toolbox-reentrancy-audit.md`

## notes

- The Loader rarely needs this — most programs don't load segments
  while another is loading. But correctness matters when it does.
