---
name: Toolbox in ARM — Memory Manager
phase: 11
status: pending
blockedBy: [1103]
parent: 1104
---

# 1104a — Toolbox in ARM: Memory Manager

ARM-assembly port of the IIds Memory Manager. **The most foundational
Toolbox sub-port** — every other manager allocates through it.

## current behavior

The Memory Manager runs in 65C816 emulation (or in the staging-
ground state from phase 6 / 9).

## intended behavior

- Native ARM implementation of: `NewHandle`, `DisposeHandle`,
  `SetHandleSize`, `GetHandleSize`, `HLock`, `HUnlock`,
  `NewPtr`, `DisposePtr`, `SetPtrSize`, `GetPtrSize`,
  `CompactMem`, `PurgeMem`, `MaxMem`, `FreeMem`, `MoveHHi`,
  and the various block manipulation routines.
- Handle and pointer data structures preserved byte-for-byte. Code
  that introspects handles still works.
- Heap fragmentation handling matches the original (the
  `CompactMem` / `MoveHHi` semantics are subtle and have to be
  exact).
- Thread safety: the heap is locked per soramech primitives;
  every entry point acquires the heap lock briefly.

## suggested implementation steps

1. Study GS/OS Memory Manager source thoroughly. Map all entry
   points and the heap data structure.
2. Implement the heap data structure in ARM. Layout matches the
   65C816 version for compatibility.
3. Implement `NewHandle` / `DisposeHandle` first.
4. Implement size operations.
5. Implement compaction.
6. Test: allocate, free, compact, repeat. Compare heap state
   byte-for-byte to the emulated baseline.

## related documents

- `issues/1104-iigs-toolbox-arm.md` — parent issue
- `issues/1103-first-module-ported.md` — pattern precedent

## notes

- This is the first sub-port to land in phase 11's Toolbox work.
  Everything else depends on it.
