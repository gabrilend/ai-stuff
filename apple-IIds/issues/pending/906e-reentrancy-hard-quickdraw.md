---
name: QuickDraw II reentrancy fixes (structural)
phase: 9
status: pending (pending soramech)
blockedBy: [905e]
parent: 906
---

# 906e — QuickDraw II reentrancy fixes (structural)

Structural refactor of QuickDraw. The main fix: **per-task shadow
GrafPorts** so most drawing doesn't contend on a global state lock.

## current behavior

After 905e, QuickDraw is lock-correct but the global current-port
state lock is heavily contended. Every drawing op pays the cost.

## intended behavior

- Each task has its own shadow of the current-port state. Setting
  the port (`SetPort`) writes the task-local shadow. All
  subsequent ops read from the shadow.
- The lock is only acquired at the framebuffer-write boundary —
  for actual pixel updates — and the boundary is broken down
  per-region so concurrent draws to non-overlapping regions
  parallelize.
- API surface unchanged; internal restructure only.

## suggested implementation steps

1. Wait for audit.
2. Design the shadow-port mechanism.
3. Implement.
4. Validate behavioral equivalence (the shadow must produce
   identical pixels to the global-state version).
5. Performance-measure.

## related documents

- `issues/906-toolbox-reentrancy-fixes-hard.md` — parent
- `issues/604-quickdraw-ii-native.md` — staging-ground native may
  already implement this pattern; lift the design

## notes

- QuickDraw structural fixes are second-highest-impact after Event
  Manager (906d). Together they make multitasking feel responsive
  even under heavy load.
