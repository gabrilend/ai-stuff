# 211 — The delivery walk

## Current behavior

**A box function returns a value and nothing happens to it.**

## Intended behavior

**The path from "a box just returned" to "another box is queued to run
because of it". This is the central path of the engine; everything else
exists to support it or to set it up.**

```
   a core has just run a box.  the returned value is in the task.

   1  choose an exit  ────────────  the station's kind decides.
            │                       plain has one. a comparator picks
            │                       one of three. an iterator uses the
            │                       one recorded at claim time.
            ▼
   2  read the exit's destination array  ──  one pointer read.
            │                                nobody ever edits it.
            ▼
   for each {station, port}:
            │
            ▼
   3  take an empty cell   ──── compare-and-swap it to reserved
            │
            ▼
   4  copy the value in    ──── elem_size bytes. no allocation.
            │
            ▼
   5  mark it ready        ──── compare-and-swap
            │
            ▼
   6  run the readiness check (209) ── not ready? next destination.
            │
            ▼
   7  build a task (210) and push it (204) ── then next destination.

   when every destination is handled, free your own task
   and go back for more work.
```

**No lock is taken anywhere on this path.** Not on the destination
array, because it is immutable and swapped whole. Not on the cells,
because each carries its own state. Not on the station, whose lock is
now reserved for four rare structural things: growing a port, rewiring,
writing a static, and changing a port's source. On a four-core device
where all four are doing this constantly, that is the difference
between the cores helping each other and the cores queueing.

**Fan-out is not a kind of box.** It is what one exit with several
destinations already does. An exit wired to a hundred places means a
hundred deliveries by this one core before it goes back for more work
— which is right, because each delivery may unblock a station, so the
core is spending its time manufacturing parallelism for everybody else.

**A box that returns nothing is a sink.** Delivery is skipped entirely
and the core goes straight to freeing its task. Writes to hardware,
lines out the serial port, pixels into a framebuffer — none of them
need engine support. They fall out of a function declared to return
nothing.

**An exit wired to nothing discards.** That is right for an unwired
comparator branch, which is the ordinary case, and it is what makes a
map assemblable a piece at a time.

**What the walk costs, in one table**, because this is the path every
future measurement will be against:

| step | work |
|---|---|
| choose an exit | one table lookup on the station's kind |
| read destinations | one pointer read |
| take a cell | one scan from a bookmark, one compare-and-swap |
| copy | `elem_size` bytes, no allocation |
| publish | one compare-and-swap |
| readiness | one walk of the destination station's ports |
| build and push | one block from a free list, one lock on the ring |

The only lock in the whole walk is the ring's, at the very end, and
that is 204's open question rather than this issue's.

## Suggested implementation steps

1. The delivery function, taking a finished task and walking its
   station's exit.
2. Exit selection as its own call with only the plain case
   implemented, so phase 3 adds rows rather than restructuring.
3. Wire it into the run loop between running a task and freeing it.
4. A test of a three-station chain, asserting the value arrives at the
   end and the middle station ran exactly once.
5. A test of one station fanning out to twenty, asserting every
   destination received a copy.
6. A test that a struct larger than a machine word crosses two hops
   byte-identical.
7. A test that a task from a box returning nothing is freed and nothing
   is delivered.

## Open questions

- *Should a core with a hundred destinations push some of them as work
  instead of walking them all?* Walking is simple and keeps the value
  hot in cache. But one core doing a hundred deliveries while three sit
  parked is exactly the shape this engine says it will not tolerate.
  The counter-argument is that turning deliveries into tasks makes
  delivery recursive and needs a task kind that is not a box run, which
  the pool has stayed free of. Worth measuring at a fan-out where it
  could plausibly matter.
- *When two cores deliver into the same station at once, do they both
  run the readiness check?* Yes, and both may succeed if there are two
  complete sets. That is correct and is the parallelism working. It
  also means the check runs more often than there are sets to find, and
  how much more is a measurement nobody has taken.
- *What happens to a value delivered to a station that has just been
  unwired* — by 214, because its box misbehaved? It lands in a cell and
  waits forever, which is harmless but invisible. Whether that should
  be reported, and how, belongs with 214.

## Blocked by

204, 205, 207, 208, 209, 210.

## Blocks

212, 215.

## Related

- [209 — The readiness check and the claim](209-the-readiness-check-and-the-claim.md),
  step 6
- [210 — The task](210-the-task.md), step 7
- [204 — The task ring](204-the-task-ring.md), where step 7 pushes
