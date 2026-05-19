---
name: Event Manager reentrancy fixes (structural)
phase: 9
status: pending (pending soramech)
blockedBy: [905d]
parent: 906
---

# 906d — Event Manager reentrancy fixes (hard)

Structural refactor of Event Manager. The likely structural change:
**per-task event queues** rather than a single global queue.

## current behavior

After 905d, the event queue is lock-correct. But it's still a
single global queue, contended by every task. Under load, every
`GetNextEvent` pays the lock cost.

## intended behavior

- Each task owns its own event queue. Events are dispatched at
  post time to the queue of the task that should receive them
  (determined by event type and focus).
- A small per-event-type routing table decides destination.
- Mouse events go to the foreground task; key events go to the
  task with input focus; update events go to the task that owns
  the dirty window; etc.
- Result: `GetNextEvent` is lock-free in the common case (only
  the calling task's queue is touched).

## suggested implementation steps

1. Wait for audit.
2. Design the per-task queue and routing table.
3. Implement.
4. Verify behavioral equivalence with the global-queue version.
5. Performance-measure: target sub-microsecond `GetNextEvent`.

## related documents

- `issues/906-toolbox-reentrancy-fixes-hard.md` — parent
- `issues/603-event-manager-native.md` — staging-ground native

## notes

- This is the single highest-impact 906 fix. Event Manager
  contention can dominate under multitasking.
