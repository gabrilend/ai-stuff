---
name: Event Manager reentrancy fixes (lock wrappers)
phase: 9
status: pending (pending soramech)
blockedBy: [902, 904]
parent: 905
---

# 905d — Event Manager reentrancy fixes (easy)

Lock-wrapper fixes to the Event Manager. The event queue is the
core shared state; `evt_lock` serializes its access.

## current behavior

The Event Manager's queue is a single global, accessed by
`PostEvent` (from interrupts and from the broker input device) and
`GetNextEvent` (from the task that's reading).

## intended behavior

- `evt_lock` acquired during queue updates.
- Lock is **very brief** — pushing or popping one event takes
  microseconds. Multiple tasks reading events simultaneously
  rarely contend.
- The Broker Input device's posts (from interrupt context) acquire
  the lock with interrupt-disable.

## suggested implementation steps

1. Wait for the audit's Event Manager section.
2. Add lock wrappers for queue ops.
3. Wire the Broker Input device's post path through the lock.
4. Group as `patches/203-evtmgr-locks.gsos.s.patch`.
5. Test under concurrent input from multiple sources.

## related documents

- `issues/905-toolbox-reentrancy-fixes-easy.md` — parent
- `issues/603-event-manager-native.md` — staging-ground native
- `issues/702-broker-input-device.md` — interrupt-context poster

## notes

- The Event Manager's lock is the most contended of all the 905
  locks — every task hits `GetNextEvent` in its main loop. Worth
  checking contention profile after this lands; may motivate
  fine-grained per-task event queues in a follow-up.
