# The kept copy of the ceramic engine

`cera.c` and `cera.h` started as soramech (minimal-soramech) at commit
`059487d` (2026-09-12), copied unchanged in this project's commit
`8639d7077`. Every change after that is marked `FORK (issue 515g)` in the
source. `git diff 8639d7077 -- src/render/ceramic/engine/` shows them all.

What changed, and why (issue 515g; measured by
`src/render/ceramic/bench/run-analysis.sh`):

1. **Collected results are counted after they are copied in.**
   - A second per-port counter, `landed`, is raised after each result's
     bytes are copied (release ordering). `cera_map_collected` reports it.
   - The stock engine reported `taken`, raised before the copy, so a
     caller could read a result still being written.
2. **The task queue takes no lock.**
   - It is a fixed ring of slots, each with a sequence number that holds the
     input ports' four states (empty, reserved, ready, claimed) with the lap
     folded in.
   - A hand-in checks for room, claims positions with a compare-and-swap on
     `tail`, writes and publishes. A worker claims with a compare-and-swap
     on `head`.
3. **Batched hand-in.**
   - `cera_pool_push_many` claims positions for many tasks at once.
   - `cera_pool_batch_begin` / `_end` gather a thread's pushes into one.
   - `cera_map_deliver_arguments` delivers an array of values and hands
     every task they make ready in to the task queue as one batch.
4. **Wake only sleepers, one per task.** An atomic count of sleeping
   workers. A hand-in touches the mutex and condition variable only when
   somebody is asleep.
5. **Optional spinning** (`CERAMIC_SPIN`, default 0): an idle worker looks
   at the ring again that many times before sleeping.
6. **A full ring:** an outside thread waits for room; a worker runs the task
   itself (a box never waits). The ring's size is `CERAMIC_QUEUE_SLOTS`
   (default 65536, a power of two).
7. `#define CERA_FORK_TASK_QUEUE 1` in the header, so a program can tell
   which engine it was built against.

The mutex remains for the starting gate, going to sleep, stopping, and
outside submitters; termination is decided as before.

Tests: `tests/run-engine-tests.sh` (this copy's own); soramech's suite, run
against this copy in a scratch copy of that repository. The results are in
issue 515g.
