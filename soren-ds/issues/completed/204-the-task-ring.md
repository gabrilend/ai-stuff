# 204 — The task ring

## Current behavior

**Built and tested on the twin.** `src/engine/030-task-ring.c`: one
ring of task pointers under a ticket spin lock, doubling (and
unwrapping) when full, with high-water and growth counters. Waking
parked cores moved out of the push into the engine
(`engine_wake_sleepers`, 032-workers.c), which only sends the event when
some core is actually parked — measured as the largest per-run cost on
the twin — and pairs with a second look at the ring before a core parks,
so no wake is ever lost.

Test `049-test-task-ring.c`: a wrapped ring grows and keeps order; four
cores push and pop 250,000 each with nothing lost, doubled or reordered
per producer.

## Intended behavior

**A first-in-first-out ring holding pointers to tasks. It is the only
channel between a core that finds work and a core that performs it.**

```
   capacity 8, four tasks waiting:

        ┌───┬───┬───┬───┬───┬───┬───┬───┐
        │   │ A │ B │ C │ D │   │   │   │
        └───┴───┴───┴───┴───┴───┴───┴───┘
              ▲               ▲
             read            write
        (oldest waiting)   (next goes here)

   both indices wrap at the end.  a worker takes from read.
   a delivery adds at write.
```

**The ring holds pointers, not tasks.** Every entry is the address of a
task sitting on its own in memory. This one distinction is what makes
growth safe: nothing anywhere in the system holds a pointer *into* the
ring, so the ring's storage can be moved underneath all four cores
without producing a single dangling reference. The ring holds pointers
*out*, and a worker that takes one carries it away.

| field | type | meaning |
|---|---|---|
| slots | pointer to an array of pointers | the ring itself |
| capacity | `int` | how many entries the array holds |
| read | `int` | where the oldest waiting task sits |
| write | `int` | where the next one goes |
| lock | spin lock | guards all four of the above |

**First in, first out, so a waiting task cannot be starved.** A stack
would be faster — the most recently written pointer is still in cache —
but it can leave an old task waiting indefinitely under sustained load,
and there is no way for a map to express urgency to compensate.

**When the ring fills, it doubles.** If advancing the write index would
land it on the read index, the storage is replaced with one twice the
size, the wrapped portion is copied so the contents read contiguously
again, and both indices are corrected. All of this happens holding the
lock, so nothing else is inside.

```
   before growth (wrapped, full)  after growth (unwrapped)
   ┌───┬───┬───┬───┐              ┌───┬───┬───┬───┬───┬───┬───┬───┐
   │ C │ D │ A │ B │      ──→     │ A │ B │ C │ D │   │   │   │   │
   └───┴───┴───┴───┘              └───┴───┴───┴───┴───┴───┴───┴───┘
             ▲                      ▲               ▲
        read and write             read            write

   full is exactly "write would land on read", which is why the
   two arrows on the left are the same arrow.
```

**This is reachable, not theoretical.** One station wired to a hundred
destinations produces a hundred tasks during a single delivery, so the
ring can go from nearly empty to overflowing inside one worker's turn.

**Rejected: a core that finds the ring full runs a task itself and
retries.** Deadlock-free, and it delays the push by however long an
arbitrary box function takes. Growth delays it by a bounded memory
copy. Same shape, wildly different worst case.

**The lock is a spin lock, and on this device that is safe** in a way
it would not be on a general-purpose system. Nothing can interrupt a
core while it holds this lock, because no interrupt handler in this
design ever touches the engine — input is polled, not delivered by
handlers. A core that takes the lock is guaranteed to reach the release.

## Suggested implementation steps

1. The ring struct and its initialization, taking a starting capacity
   and allocating from 203.
2. The spin lock itself, built on 201's now-defined atomics — the
   simplest correct form first, with the fairness question below left
   open until there is something to measure.
3. Push and pop, both taking the lock, both operating on the indices.
   Pop returns nothing when empty rather than waiting; the sleeping
   decision belongs to 206.
4. The growth path inside push. Seed the test with a ring whose
   contents have already wrapped, because the unwrap is the part that
   will be wrong first.
5. Record the highest occupancy ever reached and the number of times
   the ring grew. Both are diagnostics somebody will want long before
   phase 7, and both are free to keep.
6. A test with all four cores pushing and popping continuously,
   asserting nothing is lost, duplicated, or reordered.

## Open questions

- *One ring for four cores, or one ring per core?* One ring means all
  four cores take the same lock on every push and every pop, which is
  the single most contended point in the system by construction. A ring
  per core with work-stealing removes that, at the cost of a stealing
  policy and a much harder answer to "is there any work anywhere". The
  other project runs one ring across many more threads than four, which
  is evidence the simple answer holds — but it runs on a machine with a
  different lock. Build one ring, measure, and keep the question open.
- *Which kind of spin lock?* The simplest kind lets a core that just
  released the lock immediately re-take it, starving a core that has
  been waiting. A ticket lock hands it over in arrival order at a small
  extra cost. Worth measuring rather than assuming, and the measurement
  wants 215's load.
- *Does growth need a ceiling?* On a device with fixed memory, a ring
  that keeps doubling is a program that is falling behind, and doubling
  is absorbing the evidence. A ceiling that reports rather than grows
  would turn a slow memory leak into a loud message — but it also
  reintroduces "what does a full ring do", which growth exists to
  answer.

### Proposed answers (UNVERIFIED)

1. *One ring or one per core?* **Measured on the twin:** the endurance
   demo runs about 1.9–2× as many box runs per second on four cores as
   on one (see the metrics pages for the current number). A four-core
   machine with no shared bottleneck would approach 4×, so the one ring
   is costing roughly half the machine on engine-bound work. Proposed:
   keep one ring until the device's own number exists, then try a ring
   per core with stealing if the device agrees.
2. *Which spin lock?* A ticket lock — built, because it hands the lock
   over in arrival order and costs one extra word.
3. *A ceiling on growth?* No ceiling; report instead. The high-water
   mark and growth count are in every endurance report, and a program
   falling behind shows as a high-water mark that keeps climbing.

## Blocked by

201, 202, 203.

## Blocks

205, 206, 211.

## Related

- [205 — Workers and the run loop](205-workers-and-the-run-loop.md),
  which pops from this
- [206 — Sleeping and waking](206-sleeping-and-waking.md), what a core
  does when the pop comes back empty
- [211 — The delivery walk](211-the-delivery-walk.md), which pushes
