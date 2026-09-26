# Issue 515g: A Lock-Free Task Queue in a Kept Copy of the Engine

**Phase:** 5 - Rendering
**Type:** Implementation (an experiment on the ceramic engine, for the soramech project)
**Priority:** Medium
**Parent:** 515 (the render graph on the ceramic engine)
**Dependencies:** 515a (the measurements that found the problem, and the harness that measures the fix)
**Blocks:** 515b (the host loop builds on whichever engine copy this settles on), 515h (the frame graph runs on this copy), 515i (destinations are built on this queue)

---

## Current Behavior

Built, tested, measured and delivered (2026-09-25).

**The kept copy** (`src/render/ceramic/engine/cera.c`, `cera.h`; forked
from soramech `059487d` in commit `8639d7077`; the changes are marked
`FORK (issue 515g)` and listed in `fork-notes.md`):
- **Landing.** Collected results are counted after they are copied in
  (`landed`, which `cera_map_collected` reports).
- **The ring.** The task queue is a ring of slots whose sequence numbers
  hold the input ports' four states (empty, reserved, ready, claimed) with
  the lap folded in.
  - Handing in: check for room, claim positions with a compare-and-swap on
    `tail`, write, publish.
  - Taking out: a compare-and-swap on `head`.
  - The functions are `reserve_positions`, `ring_place` and `ring_take`.
- **Batched hand-in:** `cera_pool_push_many`, `cera_pool_batch_begin` /
  `_end`, and `cera_map_deliver_arguments`.
- **Waking** only when somebody is asleep, one per task (`wake_for`), with
  the no-lost-wake-up argument written beside it.
- **Optional spinning** before sleeping (`CERAMIC_SPIN`, default 0).
- **A full ring:** the test found this. Four fast outside threads filled
  65536 slots, where the stock queue would have grown. Now an outside
  thread waits for room, and a worker (which must never wait) runs the task
  itself. Room is checked before a position is claimed, so no claimed
  position is ever left unfilled.
- **The mutex** remains for the starting gate, sleeping, stopping and
  outside submitters. Termination is decided as before.
- `CERA_FORK_TASK_QUEUE` in the header says which engine a program has.

**Tests.**
- **This copy's own** (`tests/run-engine-tests.sh`, `test-task-queue.c`):
  a million tasks each run exactly once. They are handed in from four
  outside threads (single, arrays, open batches) and from inside workers,
  and the pool must decide completion itself. The check runs on the default
  ring and on a 16-slot ring full nearly all the time, with spinning off and
  on, repeated ten times. ThreadSanitizer (clang) reported nothing.
- **Soramech's suite against the copy:** 46 of 48 pass.
  - `013-test-pool-queue` fails by design: it requires the ring to grow.
  - `075-test-latebox` fails identically on the stock engine when the tree
    is copied elsewhere.

**Measured** by `run-analysis.sh` (sweeps `@fork`, `batch`, `spin`,
`landing`), at 2048 units, 11 workers:
- **One unit per task:** stock about 10.8 ms; lock-free about 6.9 ms (what
  remains is waking); batched about 1.0 ms; spinning about 1.0 ms.
- **Chunked tasks:** all four meet at 0.57–0.65 ms.
- **Landing:** trusting the copy's count with no workaround wait gave
  exactly the one-thread loop's poses, including 120 KB answers.

**Delivered to soramech:** it proved useful, so as design schematics.
Implementation note `docs/implementation-notes/152-a-task-queue-without-a-lock.md`
(soramech commit `8806e4780`) has:
- the slot states and who owns each;
- the hand-in and take-out paths;
- the sleep and wake ordering;
- the batch path;
- this project's use case;
- the measurements;
- the other side. The full-ring policy bends soramech's guarantees P1 and
  G9, and a chain of rings would keep them. P2 no longer holds as written,
  and spinning costs a core.

Whether it becomes permanent there is that project's choice.

## Intended Behavior

A kept copy of the engine (`src/render/ceramic/engine/cera.c`, `cera.h`),
forked from a named soramech commit, with these changes, measured against
the stock engine in the harness:

1. **Collection counts after the copy.** A second per-port counter,
   raised after a result's bytes are copied in (release ordering), is what
   `cera_map_collected` reports. It is the input ports' own rule, "counted
   after it is published, never before", applied to the output side.
2. **The task queue is a ring of slots, each with a sequence number.**
   This is the input ports' four-state slot machine (empty, reserved,
   ready, claimed), with the lap folded into the state so a position-based
   ring can tell this lap's empty slot from last lap's.
   - A hand-in first checks there is room (`tail + n - head` within the
     ring), then claims its positions with one compare-and-swap on the tail,
     stores the task pointer, and publishes by setting the slot's sequence
     to "ready for this lap". (A blind atomic add was the first draft; it
     can't back out of a position once the ring turns out to be full.)
   - Taking out: a worker reads the head, checks that slot's sequence says
     ready, and claims it with one compare-and-swap on the head. It then
     marks the slot empty for the next lap.
   - No lock on either path. First-in, first-out as before.
3. **Batched hand-in.** One compare-and-swap claims k positions at once, then
   k slots are filled and published. A map-level call hands a whole array
   of arguments in to the task queue with one reservation
   (`cera_map_deliver_arguments`). It works by having the pushes made
   during those deliveries collect in a per-thread list, which is handed
   in as one batch at the end.
4. **Wake only when someone is asleep.** An atomic count of sleeping
   workers. A hand-in touches the mutex and the condition variable only
   when the count is above zero, and wakes as many workers as it handed in
   tasks, never all of them.
5. **The mutex keeps only the rare paths:** the start gate, going to
   sleep, stopping, outside submitters. Termination is decided as before:
   the last worker to go to sleep, finding the ring empty and no outside
   submitter, stops the pool.
6. **Optional spinning:** an idle worker looks at the ring again
   `CERAMIC_SPIN` times before sleeping (default 0), so a steady stream
   of hand-ins rarely has to wake anyone.

**A full ring.** The stock queue grows when full; a lock-free ring can't
grow in place. The ring is a fixed size (`CERAMIC_QUEUE_SLOTS`, a power of
two, default 65536). A hand-in that finds no room acts by who is handing in:
- an outside thread waits for room (backpressure);
- a worker, inside a box that must never wait, runs the task itself.

This bends soramech's guarantees P1 and G9. A chain of rings that grows
would keep them, and the delivery to soramech says so. (The first draft
stopped the program on a full ring; the exactly-once test filled the ring
at once, which is how the policy above came to be.)

## Suggested Implementation Steps

1. Fork: copy `cera.c` and `cera.h` from soramech (name the commit) into
   `src/render/ceramic/engine/`, with `fork-notes.md` listing each change.
2. Make the five changes, each with the ownership argument written beside
   it in comments. That means who may touch a slot in each state, and why
   the sleep and wake ordering can't lose a wake-up.
3. Tests (`src/render/ceramic/engine/tests/`):
   - many threads handing in and taking out, where every task is taken
     exactly once;
   - batched hand-ins interleaved with single ones;
   - the same load on a tiny ring (16 slots), so outside threads wait and
     workers run tasks themselves, still exactly once;
   - large results collected under load are never read half-written;
   - termination with and without outside submitters.
4. Run soramech's own test suite against the fork, in a scratch copy of
   that repository, and record which tests pass and why any fail.
5. The harness (`run-analysis.sh`) measures both engines: every sweep,
   stock against the fork, plus batched hand-in.
6. **Deliver to soramech** (the blocker, below).

## Acceptance Criteria

- [x] The fork builds; its tests pass; soramech's suite result recorded
- [x] Every sweep measured on both engines; batched hand-in measured
- [x] **Blocker:** a delivery to the soramech project, chosen by the
      results:
  - [ ] (not taken) **If it doesn't pay:** a report of what was tried, the
        measurements, and why it didn't work out.
  - [x] **If it proves useful:** design schematics (the slot states and
        their transitions, who owns each, the sleep and wake ordering, the
        batch path), with this project's use case explained (a renderer
        handing in a frame's work each frame), so that project can judge
        whether the pattern should become permanent. It goes in as an
        implementation note beside the case study
        (`docs/case-studies/151-a-renderers-frame.md`).

## Related Documents

- `issues/completed/515a-copy-cost-benchmark.md` (the measurements and findings)
- soramech `docs/case-studies/151-a-renderers-frame.md`
- soramech `src/cera.c`: input-port slot states around `in_port_write`
  (the pattern reused); the pool (`cera_pool_push`, `worker_main`)
