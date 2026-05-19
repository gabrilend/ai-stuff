---
name: Toolbox in ARM — Scrap Manager
phase: 11
status: pending
blockedBy: [1104a]
parent: 1104
---

# 1104l — Toolbox in ARM: Scrap Manager

ARM-assembly port of the IIds Scrap Manager. The clipboard. Already
has a phase 6 native implementation (issue 601) and phase 9
reentrancy work; this issue ports the staging-ground version to
bare-metal ARM.

## current behavior

The Scrap Manager runs as phase 6's C-on-soramech native port
during late staging.

## intended behavior

- Native ARM-assembly implementation of: `PutScrap`, `GetScrap`,
  `ZeroScrapHandle`, `UnloadScrap`, plus the scrap-data
  structures.
- Cross-instance shared scrap (from issue 303) integrated at the
  ARM level — now a kernel-mediated shared resource between the
  two screens' bare-metal Apple IIdses.
- Preserves all the staging-ground native behavior; only the
  language changes.

## suggested implementation steps

1. Port the phase 6 C implementation (issue 601) to ARM assembly.
2. Wire shared-scrap to the bare-metal broker (issue 1106).
3. Test: copy-paste between the two screens; verify behavior
   identical to staging-ground.

## related documents

- `issues/1104-iigs-toolbox-arm.md` — parent issue
- `issues/601-scrap-manager-native.md` — staging-ground native

## notes

- The simplest of the 1104 sub-ports — small API surface, small
  state. Right "easy win" after the foundational ones (1104a-c)
  land.
