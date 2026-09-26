# Issue 515g: A Lock-Free Task Queue in a Kept Copy of the Engine

**Phase:** 5 - Rendering
**Type:** Implementation (an experiment on the ceramic engine, for the soramech project)
**Priority:** Medium
**Parent:** 515 (the render graph on the ceramic engine)
**Dependencies:** 515a (the measurements that found the problem, and the harness that measures the fix)
**Blocks:** 515b (the host loop builds on whichever engine copy this settles on)

---

## Current Behavior

The ceramic engine keeps one queue of ready tasks for all its workers: a
ring of task pointers guarded by one mutex (`cera_pool_push`,
`worker_main` in soramech's `src/cera.c`). Handing a task in to the task
queue and taking one out both take that mutex, and every hand-in wakes
every sleeping worker (`pthread_cond_broadcast`).

515a measured the cost:
- A hand-in to the task queue costs 0.2 µs with one worker and about 5 µs
  with eleven.
- It collapses where threads outnumber the 6 physical cores (a lock
  convoy).
- Separately, the count of collected results (`cera_map_collected`) rises
  before each result is copied in, so large results can be read
  half-written.

The owner chose the design (2026-09-25): "I'm glad we're picking option 2.
It's conceptually simpler." That is a ring where a place is reserved by
counting forward, not by taking a lock. The owner asked for it to be built
here and tried before anything goes to soramech: "build the implementation
here. Add a blocker to completing the issue that we should test and see how
it goes, then either deliver a report on its effectiveness to the
ceramic-core-engine project if it doesn't work out, or deliver design
schematics if it proves useful, with explanations about our use-case so we
can see if it's a pattern worth being made permanent."

## Intended Behavior

A kept copy of the engine (`src/render/ceramic/engine/cera.c`, `cera.h`),
forked from a named soramech commit, with five changes. Each can be
switched against the stock engine in the harness:

1. **Collection counts after the copy.** A second per-port counter,
   raised after a result's bytes are copied in (release ordering), is what
   `cera_map_collected` reports. It is the input ports' own rule, "counted
   after it is published, never before", applied to the output side.
2. **The task queue is a ring of slots, each with a sequence number.**
   This is the input ports' four-state slot machine (empty, reserved,
   ready, claimed), with the lap folded into the state so a position-based
   ring can tell this lap's empty slot from last lap's.
   - A hand-in reserves its position with one atomic add on the tail,
     stores the task pointer, then publishes by setting the slot's sequence
     to "ready for this lap".
   - Taking out: a worker reads the head, checks that slot's sequence says
     ready, and claims it with one compare-and-swap on the head. It then
     marks the slot empty for the next lap.
   - No lock on either path. First-in, first-out as before.
3. **Batched hand-in.** One atomic add reserves k positions at once, then
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

**Known cost of the design:** the stock queue grows when full; a lock-free
ring can't grow in place. The ring is a fixed size
(`CERAMIC_QUEUE_SLOTS`, a power of two), and a full ring stops the program
with a message naming the variable (no fallback). Whether a growable
version (a chain of rings) is needed is part of what the report answers.

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
   - a full ring stops the program with its message;
   - large results collected under load are never read half-written;
   - termination with and without outside submitters.
4. Run soramech's own test suite against the fork, in a scratch copy of
   that repository, and record which tests pass and why any fail.
5. The harness (`run-analysis.sh`) measures both engines: every sweep,
   stock against the fork, plus batched hand-in.
6. **Deliver to soramech** (the blocker, below).

## Acceptance Criteria

- [ ] The fork builds; its tests pass; soramech's suite result recorded
- [ ] Every sweep measured on both engines; batched hand-in measured
- [ ] **Blocker:** a delivery to the soramech project, chosen by the
      results:
  - [ ] **If it doesn't pay:** a report of what was tried, the
        measurements, and why it didn't work out.
  - [ ] **If it proves useful:** design schematics (the slot states and
        their transitions, who owns each, the sleep and wake ordering, the
        batch path), with this project's use case explained (a renderer
        handing in a frame's work each frame), so that project can judge
        whether the pattern should become permanent. It goes in as an
        implementation note beside the case study
        (`docs/case-studies/151-a-renderers-frame.md`).

## Related Documents

- `issues/515a-copy-cost-benchmark.md` (the measurements and findings)
- soramech `docs/case-studies/151-a-renderers-frame.md`
- soramech `src/cera.c`: input-port slot states around `in_port_write`
  (the pattern reused); the pool (`cera_pool_push`, `worker_main`)
