# Issue 515i: Destinations a Station May Name

**Phase:** 5 - Rendering
**Type:** Implementation (an experiment on the kept engine copy, for the soramech project)
**Priority:** Medium
**Parent:** 515 (the render graph on the ceramic engine)
**Dependencies:** 515g (the kept copy's lock-free queue), 515h (the frame that measures it)
**Blocks:** 515j (stronger opponents on this frame)

---

## Current Behavior

Built, tested, measured, and delivered to soramech (2026-09-25).

**What the kept copy has:**
- **Destinations.** Each is its own ring (`struct ring`); destination 0 is
  the default.
- **Workers** serve ordered lists (`worker_t.sources`; `take_for`).
- **Tasks** carry their destination (`task->dest`, copied from
  `station->destination` in `task_build`; a reused station place resets it).
- **Batches** keep one reservation per run of the same destination
  (`push_run`).
- **Release** refuses a destination nobody serves, and decides whether
  service is uniform: if it isn't, a hand-in wakes every sleeper, because the
  one woken might not serve that destination.
- **The calls:** `cera_pool_add_destination`,
  `cera_pool_set_worker_sources` / `_set_sources`,
  `cera_map_station_set_destination`, `cera_map_station_find`.

**Tests.**
- The existing queue test passes unchanged with no destination named.
- `test-destinations.c`:
  - the order is the policy;
  - an unserved destination is refused;
  - a million tasks over three destinations, with workers serving different
    lists, each run exactly once.
- ThreadSanitizer is clean.
- Soramech's suite against the copy: 46 of 48, the same two explained
  failures as before.

**What the frame taught** (the full run: 300 frames, three interleaved
repeats, with background work; mean frame and its cost over the same
engine's frame with no background):

| Arrangement | With background | Cost |
|---|---|---|
| one task queue (before) | 3.05 ms | 8.4% |
| a frame lane every worker serves first | 3.00 ms | 6.8% |
| a frame lane, and one worker serving the background | 2.92 ms | 3.8% |

- **Priority alone isn't enough.** Serving the frame first only decides
  what a free worker takes next; it can't interrupt a decode already
  running. At the start of each frame, while the simulation step runs, idle
  workers pick up the decodes and are tied up for 1.5 ms.
- **Who serves the background matters as much as what is served first.**
  Letting only one worker serve the background halves what is left of the
  background's cost.
- **Worst frames didn't change measurably** (about 4.5 ms in each
  arrangement). A shorter side-by-side run had suggested they improved;
  the full run didn't bear that out.
- **Runs far apart in time can hide effects of a few percent.** The harness
  interleaves every way within each repeat.

The frame harness runs the unchanged graph (before), the frame lane
(`FRAME_DESTINATIONS=1`), and the frame lane with one background worker
(`FRAME_DESTINATIONS=2`).

## Intended Behavior

The kept copy follows 107's model, as far as a first build needs:

- **A destination is a task queue** (the lock-free ring of 515g), plus the
  workers that serve it. Destination 0, the default, always exists and is
  served by every worker.
- **A station may name a destination**
  (`cera_map_station_set_destination`). One that names nothing delivers
  into the default, and **a program that names no destination behaves
  exactly as the copy did before**: same queue, same order. That is 107's
  most important line, and it is what makes before-and-after a fair
  comparison.
- **Each worker has an ordered list of the destinations it serves**
  (`cera_pool_set_sources`, all workers or one). It takes from the first
  that has a task. The order is the policy, and the default comes last (as
  107 says). A priority lane is a destination every worker serves before
  the default.
- **Nothing is inferred:** no station gets a destination except by being
  told.
- **A destination nobody serves is refused** when the workers are
  released, since its tasks would never run and completion would never
  come. No fallback.
- **Completion** is decided exactly as before, with "nothing queued"
  meaning nothing in any destination.
- **Batches** keep one reservation per destination, in hand-in order.
- **Finding a station by name** (`cera_map_station_find`), so a host can
  name destinations for the stations of a map it loaded.

**Measured on the 515h frame:** the frame's stations (simulation, fog, pose
lanes, culling, pathfinding) name a "frame" destination, served first by
every worker. Background decoding stays in the default. Before and after
run in the same harness, with and without background work.

## Suggested Implementation Steps

1. In the copy:
   - the ring's state moves into `struct ring`, and the pool holds an array
     of destinations;
   - `task` gains a destination, copied from its station in `task_build`;
   - the push and batch paths route by destination;
   - the take walks the worker's source list;
   - `queue_held` sums every destination.
2. Calls: `cera_pool_add_destination`, `cera_pool_set_sources`,
   `cera_pool_set_worker_sources`, `cera_map_station_set_destination`,
   `cera_map_station_find`. All are marked `FORK (issue 515i)`.
3. Tests:
   - with one worker, a task in a first-served destination runs before
     default tasks handed in earlier;
   - a destination nobody serves is refused;
   - exactly once, with tasks spread over three destinations from four
     threads;
   - the whole existing queue test, unchanged, passes with no destination
     named.
4. Soramech's suite against the copy, again.
5. `frame-host.c` gains `FRAME_DESTINATIONS=1` (a frame lane, reported
   as `…-lanes`) and `=2` (the same, with only the last worker serving the
   default: `…-lanes-one`); `run-frame.sh` runs both beside the unchanged
   graph; the frame report shows before and after.
6. Tell soramech: add what the build taught to 152 or a new note, for 107.

## Acceptance Criteria

- [x] The copy's tests pass, including the new ones; with no destination
      named, the results match the previous copy's
- [x] The frame measured before and after, with and without background
      work, all runs agreeing on the checksum
- [x] The comparison in the frame report ("After: a lane for the frame"),
      and what it taught written for soramech's 107 as its implementation
      note 154 (soramech commit `a2ec81397`)

## Related Documents

- soramech `issues/107-several-queues-a-station-may-name.md`
- `issues/completed/515g-lock-free-task-queue.md`, `issues/completed/515h-a-frame-as-a-graph.md`
