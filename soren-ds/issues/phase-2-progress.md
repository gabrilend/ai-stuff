# Phase 2 progress — Threading core

Phase 2 builds the substrate every soramech map runs on. By the
end of the phase, the device has a worker pool sized to the chip's
core count, a ring-buffered task queue those workers pull from, a
slot store that holds values flowing along wires, a gathering
function that decides when a box is ready to fire, and the
release/acquire memory ordering that makes the firing decision
safe on ARM. Every box is multi-spawn — the same box can run on
multiple cores simultaneously, and box authors write thread-safe
code accordingly.

This is the most important phase in the project. Everything above
it is composition of what phase 2 lands.

## The story of the phase

Each issue builds on the ones before. Read them in order for a
walkthrough of how the threading core comes together:

1. `201-multi-core-bring-up.md` — wake the chip's other CPU cores
   from their post-reset hold state. Phase 1 only used core zero.
2. `202-worker-thread-bootstrap.md` — give each core a stack and
   an entry function; turn each into a worker thread.
3. `203-task-struct-and-return-slot.md` — define the unit of work
   that flows through the queue, including the unique return slot
   that eliminates producer-side write contention.
4. `204-ring-buffered-work-queue.md` — the queue itself,
   multi-producer multi-consumer, contention-bounded.
5. `205-slot-store-with-ring-cells.md` — per-port input slots that
   hold queued values waiting to be popped by the gathering
   function.
6. `206-atomic-gathering-primitive.md` — the per-box atomic that
   gates the gathering decision; the gathering function that pops
   one value per slot and queues a task.
7. `207-release-acquire-memory-ordering.md` — ARM-specific memory
   ordering on the publishing and consuming atomics, so a value
   landing is visible before the flag saying "value landed" is.
8. `208-box-descriptor-table.md` — the static C array of box
   descriptors the gathering function looks up by name. Phase 2
   ships a tiny test library; the real library lives in phase 3.
9. `209-worker-scheduling-loop.md` — the body of a worker thread:
   pull a task, run the box function, push outputs along the
   producer's connections.
10. `210-worker-idle-and-wake.md` — what workers do when the queue
    is empty, and how a producer wakes a sleeping worker.
11. `211-phase-2-demo-torture-test.md` — the demo. Spin up
    millions of tiny tasks across every core and prove zero
    races, zero lost fires, no incorrect values.

## Completed issues

None yet.

## Open issues

All of 201 through 211.

## Phase demo

`issues/completed/demos/phase-2/run.sh` will exist once the phase
closes. It builds and flashes the kernel image, kicks off a
torture-test map composed of a few thousand chained increment
boxes fed from a million-value source, streams per-worker
throughput numbers through the USB CDC-ACM stream, and reports
the final aggregate count alongside the expected count. The test
passes when the two match exactly and every worker drained roughly
its proportional share of tasks.
