# 210 — Worker idle and wake

## Current behavior

A worker that calls `queue_pop` (204) on an empty queue gets a
failure indication and has no defined behavior beyond that. A
naive worker would busy-spin on the queue forever, which keeps
the CPU at 100% and burns the battery for nothing.

## Intended behavior

When a worker finds the queue empty, it parks on a kernel-level
wait primitive that has near-zero idle cost — on ARM, the `WFE`
instruction (Wait For Event) plus an event flag in shared memory.
The flag's purpose is "there might be work now"; the wait is
released when the flag is set.

The path:

1. Worker calls `queue_pop`, gets empty.
2. Worker sets its own `idle` flag in its context (202).
3. Worker re-checks `queue_pop` once more (the race: a producer
   might have pushed between the first pop and the idle-flag
   set; without this re-check, the worker would sleep on a queue
   that has work).
4. If still empty, worker issues `WFE`. The CPU enters a
   low-power state, draining minimal current.
5. A producer (a box that just finished firing in 209's step 5,
   pushing onto the queue) issues `SEV` (Send Event) after the
   queue push.
6. Every parked worker receives the event and exits `WFE`.
7. Each woken worker clears its `idle` flag and retries
   `queue_pop`. The first to claim a task runs it; the others
   loop back to step 1.

`SEV` is broadcast — every idle worker wakes. That's fine; only
the worker that wins the race for the task does real work, and
the others go back to sleep within a few hundred cycles. The
cost of waking too many workers is much smaller than the cost of
not waking the one that needed to wake.

## Suggested implementation steps

1. `worker_idle()` — set flag, re-check, WFE.
2. Add `notify_workers()` call to `queue_push` (204) and to the
   slot-push that wakes downstream gather attempts (206) —
   conservative wakeup is fine, the WFE re-check filters spurious
   wakes.
3. `idle` flag in `struct worker_context` (202) — atomic byte.

## Related documents

- `docs/003-threading-model.md`.

## Blocked by

202, 204.

## Blocks

211 (idle workers are part of the steady-state behavior the
demo measures).
