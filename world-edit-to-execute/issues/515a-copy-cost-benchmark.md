# Issue 515a: Copy-Cost Benchmark

**Phase:** 5 - Rendering
**Type:** Measurement
**Priority:** Medium
**Parent:** 515 (the render graph on the ceramic engine)
**Dependencies:** None

---

## Current Behavior

Built (`src/render/ceramic/bench/`, run with `run-copy-cost.sh`; report in
`tmp/shared-memory/ceramic/copy-cost.md`). The first run on this machine (12
cores) gave these mean times per frame, in microseconds:

| Units | Plain loop | Parallel loop | Ceramic, per unit | Ceramic, per chunk of 64 |
|-------|------------|---------------|-------------------|--------------------------|
| 128   | 309        | 166           | 787               | 513                      |
| 512   | 956        | 441           | 3007              | 523                      |
| 2048  | 3606       | 1145          | 11641             | 818                      |

- **A task per unit costs about 5 µs of overhead** (2048 units: 10.5 ms over
  the parallel loop). That's 70% of a 60 fps frame, so one task per unit is
  ruled out.
- **A task per 64 units matches or beats the parallel loop** from 512 units
  on.
- Not yet separated: how much of the 5 µs is the 2 KB copy, and how much is
  the task itself (allocation, queueing, the host delivering requests one at
  a time). A way that returns 4 bytes instead of the pose will separate them.

**The chunked way's poses were wrong.** Its checksum disagreed, differently
on every run. The cause is a bug in the ceramic engine:
- The count of collected results (`cera_map_collected`, documented as "how
  many values landed") goes up when a result's slot is reserved, *before* its
  bytes are copied in (`station_collect_result`).
- So a caller that trusts the count reads results still being copied. A 2 KB
  result finishes almost at once and hides it; a 120 KB one showed about 66
  KB copied and the rest still zero.
- Confirmed by waiting 1 ms after the count is reached: the poses then match
  the plain loop exactly, run after run.
- **The fix belongs in soramech:** a second counter that goes up after the
  copy (with release ordering), which the count reports (read with acquire).
  It waits on the owner's word, because nothing is written into that
  repository without asking.

Other findings for soramech, met while building this:
- **Value types can't hold number arrays**, only character arrays (text). A
  matrix has to be 16 named floats. `pose-types.lua` writes them, and the
  build splices them into the box file.
- **serac's documentation names `--main=FILE`, but serac has no such
  option.** The build instead emits the map's C (`--emit-c`, written beside
  the map), replaces the emitted `main` with the host's, and compiles it
  with the engine (`serac --unpack`).
- **serac can't add linker flags** (raylib will need them); the same route
  works around it.
- **Collection can be re-armed per frame** by calling it again, which resets
  the count. That's safe only with one frame in flight.

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

- [ ] All four ways produce the same poses (checked, not assumed)
- [ ] Times at the three sizes, the ceramic overhead in microseconds and as a
      share of a frame
- [ ] The finding written into 515: how big a box must be for the engine to
      pay for itself here

## Notes

- Collecting results fills a caller-owned array one reserved index at a time.
  Calling collect again points it at a new array and resets the count, which
  is how a program that runs forever reuses it. That's only safe when
  nothing is still writing: a finding for soramech (a per-frame collect).
- serac adds no linker flags of its own, so linking raylib (515b) will mean
  emitting the C (`serac --emit-c`) and compiling it ourselves: also a
  finding for soramech.
