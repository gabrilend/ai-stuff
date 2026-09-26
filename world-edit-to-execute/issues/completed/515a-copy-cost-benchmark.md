# Issue 515a: Copy-Cost Benchmark

**Phase:** 5 - Rendering
**Type:** Measurement
**Priority:** Medium
**Parent:** 515 (the render graph on the ceramic engine)
**Dependencies:** None
**Blocks:** 515g (the lock-free queue it measured the need for), 515b

---

## Current Behavior

Built and run. Two tools in `src/render/ceramic/bench/`:

- **`run-copy-cost.sh`**, the first pass: four ways, three army sizes.
- **`run-analysis.sh`**, the full analysis. It runs six sweeps:
  - **anatomy:** an empty task, the work with a 4-byte answer, the work with
    its 2 KB answer;
  - **size:** answers from 16 bytes to 120 KB;
  - **chunk:** 1 to 256 units per task;
  - **scale:** 1 to 11 workers;
  - **army:** 128 to 8192 units;
  - **herd:** one line of a scratch copy of the engine changed so each
    hand-in wakes one sleeping worker instead of all.

  Every frame is timed, so each run carries percentiles as well as the mean.
  `analysis-report.lua` writes the report and fills the viewer page
  (`src/viewers/ceramic-analysis.html`). The live numbers come from running
  them. The first run was published for the owner as the "Ceramic Frame
  Budget" page.

What the measurements show, on an i7-7820X (6 physical cores, 12 threads):

- **The 2 KB copy costs nothing measurable.** Answers from 16 bytes to 16 KB
  cost the same per task; only 120 KB shows copying. The owner's worry about
  moving 2 KB in and out of shared memory doesn't appear in the numbers.
- **One unit per task is ruled out, and handing tasks in is the whole
  reason.**
  - An empty task costs about 5 µs, more than the pose itself (about 1.9 µs
    on one thread), and it is all the host handing tasks in.
  - With one worker a hand-in costs about 0.2 µs. The cost climbs sharply
    once the thread count passes the 6 physical cores. The host and every
    worker share the engine's single queue lock, and past that point whoever
    holds it shares a core with the threads waiting for it: a lock convoy.
  - One unit per task gets *slower* with every worker past four.
- **Chunked tasks are the right shape.**
  - From 8 to 64 units per task the frame stays within 10% of its best:
    about 0.67 ms for 2048 units, 4% of a 60 fps frame.
  - That beats the hand-written fixed-slice loop by up to about 2×: a free
    worker takes the next chunk, while fixed slices wait for the slowest
    thread (two threads sharing a core finish late).
  - Chunked ceramic scales to about 5× on 11 workers, close to what 6 cores
    with hyperthreading give.
- **Repeated runs wander by about a third** (the hand-written loop measured
  1.2 to 1.6 ms for the same work), so smaller differences are noise.

**Findings for soramech** (written up with the owner before anything goes
into that repository):

1. **Fault: collected results are counted before they are copied in.**
   `station_collect_result` reserves the slot, raising the count that
   `cera_map_collected` reports as "how many values landed", and only then
   copies. Large answers were read half-copied, differently every run.
   - The fix: a second counter raised after the copy.
   - The workaround here: once the count is reached, wait out every worker
     mid-task. A worker's epoch is odd inside a task, and the task includes
     the copy. It costs about as long as the last copy.
2. **One queue lock is shared by the host and every worker** (the lock
   convoy above). Batched hand-ins, a queue per worker, or a lock-free queue
   would each remove it.
3. **Every hand-in wakes every sleeping worker** (`pthread_cond_broadcast`
   in `cera_pool_push`). Waking one cut the one-per-task frame by up to
   about 30%, but the lock remains the main cost.
4. **Value types can't hold number arrays**, only character arrays. A matrix
   is sixteen named floats, written by `pose-types.lua`.
5. **serac documents `--main=FILE` but has no such option, and can't add
   linker flags.** The builds emit the map's C (`--emit-c`, written beside
   the map), replace the emitted `main`, and compile with the engine
   (`serac --unpack`).
6. **Collection can be re-armed per frame** by calling it again, which
   resets the count. That's safe only with one frame in flight.

**Still open:** how the chunked ceramic path compares with the 512 thread
pool itself, rather than a stand-in loop (that's 515f's job).

## Intended Behavior

One program that poses U units of 30 bones each, per frame, for many frames,
four ways, and reports the time per frame for each:

| Way | What it is |
|-----|------------|
| plain loop | one thread, no engine: the floor |
| parallel loop | the same work split across the cores by hand-written threads: the shape of the 512 pool |
| ceramic, a task per unit | the host delivers one small request per unit; one box returns that unit's 2 KB pose |
| ceramic, a task per chunk | one request per 64 units; one box returns the chunk's poses |

It runs at U = 100, 500 and 2000. The report gives each way's time per frame
and the ceramic ways' overhead over the parallel loop, in microseconds and as
a share of a 60 fps frame (16.7 ms).

The pose math is the same function in all four ways, and it does real work (a
rotation per bone from the time and the bone's index, composed down the bone
chain). The measurement is honest only if the work per unit is realistic.

## Suggested Implementation Steps

1. Build serac from the soramech sources into our RAM tier
   (`scripts/147-build-serac.sh DIR -o tmp/ceramic/serac`), leaving that
   repository untouched.
2. `src/render/ceramic/bench/` holds:
   - the box file (the pose math as boxes, plus the value types);
   - the map files, one per ceramic way;
   - the host program, whose `main` builds and times the ways, compiled
     with `serac --main`.
3. The host delivers a frame's requests, waits until the frame's results
   have all been collected, re-arms collection for the next frame, and
   repeats. That's one frame in flight: re-arming is safe only when no task
   of the previous frame can still be writing.
4. A script builds and runs it, and writes the report to
   `tmp/shared-memory/ceramic/copy-cost.md`.

## Acceptance Criteria

- [x] All four ways produce the same poses (checked, not assumed); the full
      analysis checks every way, every run
- [x] Times at the three sizes, the ceramic overhead in microseconds and as a
      share of a frame (and the full analysis: six sweeps, published as the
      "Ceramic Frame Budget" page and as soramech case study 151)
- [x] The finding written into 515: how big a box must be for the engine to
      pay for itself here

## Notes

- Collecting results fills a caller-owned array one reserved index at a time.
  Calling collect again points it at a new array and resets the count, which
  is how a program that runs forever reuses it. That's only safe when
  nothing is still writing: a finding for soramech (a per-frame collect).
- serac adds no linker flags of its own, so linking raylib (515b) will mean
  emitting the C (`serac --emit-c`) and compiling it ourselves: also a
  finding for soramech.
