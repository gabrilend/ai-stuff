# 209 — Worker scheduling loop

## Current behavior

Workers exist (202) and sit in a no-op loop. Tasks can be created
(203) and queued (204), the gathering function can fire and
queue them (206), but no worker yet pulls one off the queue and
runs it.

## Intended behavior

The worker's main loop is the heart of the runtime. Each iteration:

1. `queue_pop` from 204's work queue. If empty, drop into 210's
   idle path; when woken, retry the pop.
2. Load the task's box descriptor.
3. Call the descriptor's function pointer with the task's input
   array as `box_args_t`. The function runs on this worker, on
   this core, possibly concurrently with other invocations of
   the same descriptor on other workers (every box is
   multi-spawn).
4. Store the function's return value into the task's unique
   return slot with release ordering (207). The slot's cell
   flag flips to "occupied"; downstream consumers can now see
   the value.
5. For every wire on the box's `connections[]` array, push the
   return value into the destination slot. Each push potentially
   wakes a downstream gathering function — `try_gather` on the
   destination box's gathering atomic, from 206.
6. Free the task (203's `task_free`).
7. Loop.

The loop has no exit condition during normal operation. A worker
runs until the kernel shuts down. The only escape from the loop
is the panic path from 105's exception handlers.

## Suggested implementation steps

1. `worker_main_loop()` — replace the no-op stub from 202.
2. `dispatch_task(task *, worker_context *)` — the per-task
   work of steps 2–6.
3. `box_args_t` struct — the argument shape every box function
   sees.
4. Move the no-op stub out of 202 in favor of this implementation.

## Related documents

- `docs/003-threading-model.md`.
- `docs/012-soramech-runtime.md` — how a map runs.

## Blocked by

202, 203, 204, 205, 206, 207, 208.

## Blocks

210, 211.
