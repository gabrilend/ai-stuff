# 204 — Ring-buffered work queue

## Current behavior

The task struct exists (203) and workers are alive (202) but
there is no path between them. The gathering function from 206
produces tasks. The worker scheduling loop from 209 consumes
tasks. The queue is the data structure that connects the two.

## Intended behavior

A multi-producer, multi-consumer ring-buffered queue holds tasks
waiting to be picked up by workers. The ring's size is fixed at
build time and tuned so it never overflows under expected load —
the gathering rate times the worst-case task latency stays well
under capacity.

The queue exposes:

- `queue_push(task *)` — adds a task to the ring. Called by the
  gathering function when a box is ready to fire. Returns failure
  if the ring is full; failure is a hard error that panics the
  kernel (an oversubscribed queue means the tuning was wrong).
- `queue_pop(task **)` — removes a task from the ring and writes
  its pointer to the output parameter. Called by workers in their
  scheduling loop. Returns failure if the ring is empty; the
  worker then falls through to 210's idle path.

Both operations use the standard lock-free multi-producer
multi-consumer ring pattern: a producer-claim counter, a
consumer-claim counter, and per-cell occupancy flags. The
release/acquire ordering from 207 publishes the cell's task
pointer before the producer's claim counter increment becomes
visible to consumers.

Phase 2's first cut is a single shared queue. The per-app queues
described in `013-background-app-lifecycle.md` are the same data
structure with separate instances per app; phase 6 (compositor)
or phase 9 (lifecycle) decides which.

## Suggested implementation steps

1. `struct ring_queue` — array, producer counter, consumer
   counter, capacity.
2. `queue_init()` — allocate from 108's heap.
3. `queue_push()` — atomic claim, store, publish.
4. `queue_pop()` — atomic claim, load, mark consumed.

## Related documents

- `docs/003-threading-model.md`.

## Blocked by

108, 203, 207 (the ordering for push/pop is established there).

## Blocks

206 (the gathering function pushes onto this queue), 209.
