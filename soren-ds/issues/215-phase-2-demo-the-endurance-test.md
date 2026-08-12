# 215 — Phase 2 demo: the endurance test

## Current behavior

**Issues 201 through 214 produce a working engine and nothing puts it
under load.**

Every one of them ends with tests that prove a piece. None of them
proves the pieces survive each other, running for a long time, on all
four cores, on the actual device.

## Intended behavior

**A map built by hand that runs for as long as somebody lets it, and
reports what it did.**

Not a torture test. The distinction matters: a torture test asks
whether the thing breaks under abuse, and gets an answer about abuse.
An endurance test asks whether it stays correct and stays fast while
doing ordinary work for a very long time, which is the question a
device that runs for days actually poses.

```
   constant ──→ ┌─ increment ─→ increment ─→ ... ─→ ┐
                ├─ increment ─→ increment ─→ ... ─→ ┤
   (a static)   ├─ increment ─→ increment ─→ ... ─→ ├──→ discard
                └─ increment ─→ increment ─→ ... ─→ ┘

   fan out to at least one chain per core, so every core has
   something to chew on, then rejoin at a sink that counts.
```

### What it measures, and what a failure of each looks like

| measured | how | a failure reads as |
|---|---|---|
| nothing lost | the sink counts what it consumed | count below expected — a claim that dropped a value |
| nothing wrong | the sink sums what it consumed | sum wrong, count right — a torn copy or a stale read |
| nothing doubled | count above expected | two cores claimed one cell — 201's exclusives are not arbitrating |
| every core busy | per-core completed counts | one core far behind — a scheduling or false-sharing problem |
| progress never stalls | the count keeps climbing | a flat count with cores awake is the livelock 209 guards against |
| memory is stable | ring growths, port growths, pages held | numbers that keep climbing after warm-up mean something leaks |
| **cost per run** | total runs ÷ wall clock | the number every later phase is paced against |

### The measurement that settles a design question

The same total work, arranged two ways:

| arrangement | runs | what is being paid |
|---|---|---|
| a long chain of `pass` | many | almost entirely engine |
| one `chew` doing all of it | one | almost entirely work |

The ratio between them is how expensive one run of one box is, in units
of real work — and therefore how coarse a box ought to be. This
device's engine touches shared memory only when a task starts and when
a value is delivered, and on a machine where that memory is expensive,
the answer may well be "coarser than you think". Getting a number here
turns a design instinct into a design rule that the rest of the project
can follow.

### It also exercises the things that are not the hot path

- **Park and restart.** Halfway through, park the map, confirm the
  cores go idle and draw down, restart it, and confirm the counts
  resume from where they were rather than from zero.
- **A box removing itself.** One chain contains a box rigged to refuse
  after N values. The demo confirms that chain stops, the other chains
  do not, the error slot reads a count, and rewiring the input brings
  it back.
- **Growth.** One station is fed unevenly on purpose so its port grows,
  and the reported growth count is checked against the imbalance.

### Reported where somebody can see it

Numbers stream out the USB serial line as the run proceeds, and the
running totals are drawn on the bottom screen — phase 1 lit both
screens and there is no reason for phase 2's results to be visible only
to a laptop. A device sitting on a desk overnight should be able to
answer "how did it go" by being looked at.

A script at `issues/completed/demos/phase-2/run.sh` builds the image,
flashes it, opens the serial stream, and reports pass or fail with the
per-core numbers. It follows the project convention: a hard-coded
`${DIR}` at the top, overridable as the first argument, every path
relative to it.

## Suggested implementation steps

1. The map, assembled with 212's three operations, with the chain
   length and fan-out as constants at the top of one file.
2. The counters and the sink, and the closed-form expected values, so
   the assertion is arithmetic rather than a recorded golden number.
3. The serial report, then the on-screen report.
4. The `pass` versus `chew` comparison as its own scene, run before the
   endurance loop so the number is available even on a short run.
5. Park, restart, refuse and rewire as three scripted interruptions
   partway through.
6. The shell script.
7. Run it overnight before calling the phase closed, and record what
   the numbers were — not in this file, where they would go stale, but
   as output the script produces on demand.

## Open questions

- *How long is long enough?* An overnight run catches things an hour
  does not, and a week catches things overnight does not. The honest
  answer is that the demo should be runnable for any duration and
  report continuously, so the question becomes how long anybody chose
  to run it rather than a number baked in here.
- *What does it do about the clock?* Timing anything means reading a
  counter, and 201a's work may be changing the clock underneath these
  measurements. Any number recorded here has to say what the core was
  running at when it was taken.
- *Should it run with one core to compare?* Four-cores-versus-one is
  the cleanest possible statement of whether the engine actually
  parallelises, and it costs one boot argument. Almost certainly yes.

## Blocked by

Everything in phase 2: 201, 201a, 202 through 214. This is the
capstone, and it cannot be built until the engine underneath it is
finished.

## Closes

Phase 2.

## Related

- [212 — Maps built by hand](212-maps-built-by-hand.md), which builds
  the map
- [204 — The task ring](204-the-task-ring.md) and
  [208 — What an input port is](208-what-an-input-port-is.md), whose
  growth counters this reads
- [002 — Roadmap](../docs/002-roadmap.md)
