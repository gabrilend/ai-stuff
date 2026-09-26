# Issue 515h: A Frame as a Graph

**Phase:** 5 - Rendering
**Type:** Measurement (the ceramic engine's flexibility, on a fabricated but realistic frame)
**Priority:** Medium
**Parent:** 515 (the render graph on the ceramic engine)
**Dependencies:** 515g (the kept engine copy: lock-free queue, batched hand-in, landing counted after the copy)
**Blocks:** 515i (measured on this frame), 515j (stronger opponents on this frame), 515k

---

## Current Behavior

Built, measured and reported (2026-09-25). The harness is in
`src/render/ceramic/frame/`:
- `run-frame.sh` calibrates, builds, runs and counts;
- `frame-report.lua` writes the summary and fills
  `src/viewers/ceramic-frame.html`.

The third report is published as the "Frame as a Graph" page and as
soramech case study 153 (soramech commit `d1b089b8c`).

**Shape as built.** The frame runs three ways, plus spinning variants,
repeated three times, with and without background work.
- **The ceramic graph** (`frame-gen.lua` writes `frame.map`):
  - the simulation fans out to four fog stations, each with its player as a
    static constant, and to eight pose lanes (joins);
  - each lane feeds its own culling station;
  - the host hands a whole frame in to the task queue as one batch
    (`cera_pool_batch_begin` / `_end` around every delivery).
- **The hand-written ways** (`frame-hand.c`): by system (five barriers) and
  by level (three), each with sleeping or spinning barriers, and a
  dedicated background thread.
- **Checks.** All runs agreed on one checksum. The floor (`frame-bounds.c`,
  from the plan) is a longest chain of 1.98 ms and total work of 21.2 ms,
  so the best possible frame on 12 hardware threads is about 2.05 ms.

**Found** (mean frame, no background):

| Way | Sleeping | Spinning |
|---|---|---|
| ceramic graph | 2.81 ms | 2.87 ms |
| by level | 3.45 ms | 3.6–3.9 ms |
| by system | 12.0 ms | 5.0 ms |
| one thread | 21.6 ms | |

- **The graph is 23% faster than the best barrier design**, and within 37%
  of the floor.
- **Why "by system" is slow:** the power governor idles cores at 1.2 GHz,
  and threads that sleep between stages wake on cold cores.
- **Spinning barriers cost worst frames:** by level's 99th percentile went
  from 4.8 ms to 19 ms.
- **Background decodes cost the graph 9%.** It has one first-come queue,
  and they compete with frame work (soramech issue 107). The hand-written
  dedicated thread barely noticed.
- **Threading code:** 118 lines hand-written; 52 in the ceramic host, plus
  a 92-line map from a 37-line generator.

**Reports.** The first report (the stock-engine analysis, 515a) and the
second (the lock-free design, 515g) were split apart at the same time, and
share one look through `src/viewers/ceramic-kit.css` / `.js`, spliced in by
the report tools.

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
   same frames, the same checksums, the same timing columns. The
   hand-written barriers come in two kinds, sleeping and spinning. On a
   machine whose governor slows idle cores, "sleeps between stages" and
   "has stages" have to be told apart, or the comparison blames the wrong
   thing.
3b. `frame-bounds.c`: the floor from the plan (longest chain, total work
   over the cores), so every result is read against the best possible.
4. `run-frame.sh`: build (the kept engine copy), run every way with and
   without background decoding, write the table;
   `frame-report.lua` plus the viewer `src/viewers/ceramic-frame.html`.
5. Publish the page; copy it to soramech as its next case study.

## Acceptance Criteria

- [x] All three ways produce the same checksum, every frame
- [x] Frame time, fullness (against the floor) and the background-work
      effect, measured
- [x] Threading code counted by a tool
- [x] The page and the soramech case study, with the finding stated: where
      the graph wins, where it doesn't, and why

## Related Documents

- `issues/completed/515a-copy-cost-benchmark.md`, `issues/completed/515g-lock-free-task-queue.md`
- soramech `issues/107-several-queues-a-station-may-name.md`
