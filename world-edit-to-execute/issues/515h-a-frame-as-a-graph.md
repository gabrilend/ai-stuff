# Issue 515h: A Frame as a Graph

**Phase:** 5 - Rendering
**Type:** Measurement (the ceramic engine's flexibility, on a fabricated but realistic frame)
**Priority:** Medium
**Parent:** 515 (the render graph on the ceramic engine)
**Dependencies:** 515g (the kept engine copy: lock-free queue, batched hand-in, landing counted after the copy)

---

## Current Behavior

515a measured the ceramic engine on uniform work (posing every unit's
skeleton), where a hand-written parallel loop is close to ideal. The
engine matched it: within about a tenth of a self-balancing hand-written
loop, when the work is chunked or handed in as one batch.

The owner (2026-09-25): "My understanding was always that the benefit of
the ceramic core engine was in its flexibility - the ability to run
arbitrary tasks, not just the same type ... Enabling parallelism when it is
not structurally suited for it, that's the goal." Nothing measures that
yet.

## Intended Behavior

A fabricated frame with the shape of a real one, run three ways on the same
machine. Every task does deterministic work with a checkable answer, so all
three ways must produce the same per-frame checksum.

**The frame** (costs are the work each task does, fixed by a seeded
generator, so every way does identical work):

| Stage | Tasks per frame | Cost each | Depends on |
|-------|-----------------|-----------|------------|
| simulation step | 1 | ~300 µs | the frame's tick |
| fog of war, one per player | 4 | 400–1000 µs, uneven | the simulation step |
| skeleton poses, in 8 lanes | 8 | 256 units each (the real pose math) | the simulation step |
| culling, one per pose lane | 8 | ~60 µs | that lane's poses |
| pathfinding requests | 20–60, varying by frame | 10 µs – 2 ms, wildly uneven | nothing: handed in with the tick |
| background decoding | 2 | ~1.5 ms | nothing; not needed by this frame |

A frame is done when fog, culling and pathfinding have all landed.
Background decoding is not waited for, but it shares the cores.

**Three ways:**
1. **One thread:** every task in order. Its frame time is the total work.
2. **Hand-written, the usual engine shape:** persistent threads, one stage
   after another, each stage a parallel loop over its tasks (threads take
   the next task from a shared counter: the fair, self-balancing version),
   with a barrier between stages:
   - simulation;
   - then fog, poses and pathfinding together;
   - then culling.

   Background decoding runs on its own dedicated thread, as engines
   usually do it.
3. **Ceramic:** the frame as a map. Each stage starts the moment its inputs
   have arrived, so fog for one player can run while poses are still going,
   and a lane's culling starts as soon as that lane's poses land. The
   renderer's thread hands the tick, the lane requests, the frame's
   pathfinding requests and the background decodes in to the task queue as
   batches. On the kept engine copy it trusts the landed count.

**Measured:**
- frame time: mean, 99th percentile, worst;
- how full the cores are: the one-thread total work ÷ (frame time × cores),
  so idle gaps show as lost fullness;
- the frame with and without the background decoding. The ceramic engine
  runs tasks strictly in arrival order with no priorities, so background
  work can delay frame-critical work. This test says by how much, which is
  evidence for soramech's open design of several queues a station may name
  (its issue 107);
- how much threading code each way needs, counted by a tool from marked
  regions, not by hand.

**Reported as its own page and case study, the third report.** The first
report stays the stock-engine analysis (515a); the second is the lock-free
design (515g), for soramech's developers.

## Suggested Implementation Steps

1. `src/render/ceramic/frame/frame-boxes.c`: the value types and boxes,
   shared by all three ways. The work functions are deterministic hash
   chains of a given length, and the poses use the real pose math.
2. `frame-gen.lua`: the frame's workload (task counts and costs from a
   seed) as a C table, and the map (sim fanned out to four fog stations,
   each with its player as a constant on a static port, and to eight pose
   lanes, each wired to its own cull station).
3. `frame-host.c` (ceramic), `frame-hand.c` (serial and hand-written): the
   same frames, the same checksums, the same timing columns as the
   analysis.
4. `run-frame.sh`: build (the kept engine copy), run every way with and
   without background decoding, write the table;
   `frame-report.lua` plus the viewer `src/viewers/ceramic-frame.html`.
5. Publish the page; copy it to soramech as its next case study.

## Acceptance Criteria

- [ ] All three ways produce the same checksum, every frame
- [ ] Frame time, fullness and the background-work effect, measured
- [ ] Threading code counted by a tool
- [ ] The page and the soramech case study, with the finding stated: where
      the graph wins, where it doesn't, and why

## Related Documents

- `issues/completed/515a-copy-cost-benchmark.md`, `issues/completed/515g-lock-free-task-queue.md`
- soramech `issues/107-several-queues-a-station-may-name.md`
