# Issue 515j: Stronger Hand-Written Opponents

**Phase:** 5 - Rendering
**Type:** Measurement (making the frame benchmark harder for the ceramic engine)
**Priority:** Medium
**Parent:** 515 (the render graph on the ceramic engine)
**Dependencies:** 515h (the frame and its harness), 515i (the destinations)

---

## Current Behavior

Built and measured (2026-09-25); the frame report shows it.

**In `frame-hand.c`:**
- **`jobs`: the job system.**
  - `frame_job` carries its kind, its unfinished inputs and the jobs it
    releases; `jobs_frame` writes the frame's graph as those links.
  - `job_queue` is one per thread, spin-locked. `job_push` puts a job on
    the owner's queue and wakes a sleeper; `job_take` pops the thread's own
    newest job or steals another's oldest; `job_run` runs one and releases
    its dependents.
  - Idle helpers spin, then sleep. The main thread works and never sleeps.
- **`systems-hybrid` and `levels-hybrid`:** the barrier (`meet`) spins
  for `SPIN_US`, then sleeps on a condition variable woken by the last
  thread to arrive.
- **`FRAME_SPIN_US`** sets the spin. `run-frame.sh` gives each of the three
  ways its best spin: a timed trial of 150 frames at 50, 200, 1000 and
  5000 µs, the fastest mean wins, and the trial is kept in
  `frame-tuning.tsv`.

**A race, found by the checksum.**
- The first full run's job system disagreed with every other way in 5 of 6
  runs, and the report tool refused the data.
- The cause: each frame the main thread reset every queue's head and tail
  without the queue's lock. A helper could read the new head with the old
  tail, "steal" a job number from the last frame, and run it twice.
- Fixed by resetting under each queue's lock. A thief's unlocked glance at
  another queue was also removed.
- Afterwards 12 of 12 runs matched the one-thread loop, and ThreadSanitizer
  (clang) reported nothing on `jobs`, `levels-hybrid` or `systems-hybrid`.
- The checksum check in `frame-report.lua` is what caught it, and it
  guards every future run.

**Measured** (the full run: 300 frames, three interleaved repeats; every
run of every way agreed on the checksum):

| Way (best spin from the trial) | No background | With background | Worst 1% |
|---|---|---|---|
| job system (200 µs) | 2.76–2.84 ms | 2.83–2.86 ms | 6.1–6.8 ms |
| ceramic graph | 2.79–3.02 ms | 2.94–2.98 ms (frame lane, one background worker) | 4.5–4.7 ms |
| by level, spin then sleep (50 µs) | 3.40–3.42 ms | 3.41–3.43 ms | 4.8–4.9 ms |
| by system, spin then sleep (200 µs) | 4.60–4.76 ms | 4.59–4.70 ms | 6.8–6.9 ms |

- **The graph matches a hand-built job system** on average: within the
  run-to-run spread without background work, and about 4% behind with it.
  There, the job system's dedicated background thread is a thirteenth
  thread the operating system time-slices.
- **The graph's worst frames are steadier.** The job system's are 6–7 ms
  against 4.5–4.7 ms.
- **What the engine's generality costs on this frame is between nothing
  measurable and a few percent.**
- **Spin-then-sleep helps the barrier designs** (by system from 12 ms
  sleeping to 4.6 ms), but they stay behind: a barrier still waits for each
  level's longest task.
- **Threading code:** the hand-written program's threading is now 330 lines
  for all its designs; the ceramic host is 80, plus a 92-line map from a
  37-line generator.

## Intended Behavior

Two more hand-written ways in `frame-hand.c`, same boxes, same plan, same
checksum:

1. **`jobs`: a hand-written job system, the design shipping engines use.**
   - Every task of the frame is a job with a count of unfinished inputs.
   - Finishing a job lowers its dependents' counts and queues each one that
     reaches zero: the simulation releases the four fog jobs and the eight
     pose lanes, and each pose lane releases its own culling.
   - Pathfinding jobs are queued with the tick.
   - Each thread has its own queue. It pushes the jobs it releases onto its
     own queue and takes from there first; an idle thread steals from the
     others. The queues are small, each guarded by its own spin lock.
   - The main thread works too, and the frame ends when the count of
     unfinished jobs reaches zero.
   - Background decoding keeps its dedicated thread, as in 515h.

   It does what the ceramic graph does, written by hand for this one frame,
   with nothing general in the way. It's the strongest fair opponent: if the
   graph stays close to it, the engine's generality costs little.
2. **Spin-then-sleep waiting**, for both the barriers and the job system's
   idle threads. A waiting thread checks for work for a short while (about
   50 µs), then sleeps. That keeps cores warm across short gaps without
   burning them through long ones. It adds `systems-hybrid` and
   `levels-hybrid`; `jobs` waits this way from the start.

**Measured:** in the same frame run as everything else, interleaved, with
and without background work, and shown in the frame report next to the
graph.

## Suggested Implementation Steps

1. The job system in `frame-hand.c`:
   - `frame_job` records (kind, index, unfinished inputs, dependents);
   - per-thread queues with spin locks;
   - push-own, pop-own, steal;
   - an outstanding count per frame;
   - spin-then-sleep when there is nothing to take.

   The frame's graph is written as job links: the same edges as
   `frame.map`, but in code.
2. The hybrid barrier: spin up to `SPIN_US`, then sleep on a condition
   variable, woken by the last thread to arrive.
3. `run-frame.sh` runs `jobs`, `systems-hybrid` and `levels-hybrid` beside
   the rest, and threading code is counted as before (the job system's
   lines will count against it honestly).
4. The frame report's ways, charts and findings include them. The
   finding states how close the graph comes to a hand-built job system.

## Acceptance Criteria

- [x] Every new way agrees on the checksum (after the race above was fixed)
- [x] Measured interleaved with the existing ways, with and without background work
- [x] The frame report compares the graph against the job system, stating the gap and its cause
- [x] Threading code counted, the job system's included

## Related Documents

- `issues/completed/515h-a-frame-as-a-graph.md`, `issues/completed/515i-destinations-a-station-may-name.md`
- `src/render/ceramic/frame/frame-hand.c`
