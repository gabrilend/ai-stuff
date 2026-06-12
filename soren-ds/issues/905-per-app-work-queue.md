# 905 — Per-app work queue

## Current behavior

Phase 2's ring-buffered queue (204) is a single global queue
every map's tasks land on. The background-app lifecycle doc
calls for a per-app queue so the foreground and background
states can be implemented as queue-level state changes rather
than per-task tagging.

## Intended behavior

Each loaded app gets its own work queue (a fresh instance of
204's ring structure). The thread pool's workers round-robin
across the per-app queues each iteration of their main loop. A
single global queue still exists for system-level tasks (the
compositor tick, the input polling, the transcript drain) so the
worker doesn't have to walk a per-app list for those.

The worker's loop (209) updates:

1. Walk the per-app queue list in round-robin order from
   wherever the worker left off last iteration.
2. For each queue, check its state (foreground / background /
   asleep — 907). Skip asleep queues entirely. For background
   queues, only drain tasks whose source box is
   background-eligible (906).
3. Pop one task and run it.
4. If no per-app queue yields a task, fall through to the
   global queue.
5. If still no task, park on WFE (210).

The state field on a queue is a single atomic byte. Reads use
acquire; writes use release. A state change from
foreground/background to asleep takes effect on the next worker
iteration; in-flight tasks finish on whatever they were doing.

A per-app queue's size is fixed at app-load time, sized for the
app's expected load. The four launch apps each get a queue large
enough for their input rate (button events, peer messages,
compositor refreshes).

## Suggested implementation steps

1. `app_queue_t` — a 204 ring plus a state byte.
2. The thread pool's queue list — array of pointers.
3. Worker round-robin walk update in 209.
4. `app_queue_set_state(queue, state)` — the atomic transition.

## Related documents

- `docs/013-background-app-lifecycle.md`.

## Blocked by

204, 207, 209, 902.

## Blocks

906, 907, 908, 909.
