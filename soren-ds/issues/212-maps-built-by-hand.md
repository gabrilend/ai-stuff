# 212 — Maps built by hand

## Current behavior

**The engine can run a map and nothing can express one.**

There is no file format, no build path that reads box sources, and no
catalogue of boxes. All three arrive in phase 3. Until they do, a map
has to be assembled by calling into the engine directly — and that
scaffolding is not a temporary hack to be thrown away, because it is
the same surface the loader will call later.

## Intended behavior

**Three operations, and everything that builds a program uses them.**

| operation | what it does |
|---|---|
| **place** a station | names a box, allocates its ports and exits, returns its index |
| **configure** a port | names a station, a port, a source (ring, static, or none) and — for a static — a value |
| **wire** an exit | names a station, an exit, and the destinations it now has |

The loader in phase 3 calls these while reading a file. The editor in
phase 6 calls these when somebody drags a wire. A debugger over the
serial line calls these. There is **one** way a station comes into
existence and one way a port gets a source, so there is no second path
that can reach a state the first would have refused.

**Wiring happens in batches**, because an exit's destinations are one
immutable array swapped whole (207). Drawing three arrows out of one
station is one operation that builds one array, not three that build
three.

**Building a program is the same act as running it.** There is no
separate "start". The last thing construction does is write the
statics, and writing a static runs the readiness check on its station
(209), which builds the first tasks, which the cores were already
waiting for.

```
   place ──→ place ──→ place        stations exist, nothing runs
     │
   wire  ──→ wire                   arrows drawn, nothing runs
     │
   configure the static  ─────────→ ✦ the program is running.

   there is no fourth step.
```

### A starter library of boxes

Phase 3 builds the catalogue automatically from box sources. Until
then, a small set written by hand, chosen so the engine can be
exercised and measured without needing anything above it:

| box | inputs | out | what it is for |
|---|---|---|---|
| `constant` | one static | the value | the thing that starts a chain |
| `pass` | one | the same value | the cheapest possible box; measures engine overhead alone |
| `increment` | one number | it, plus one | a known arithmetic progression |
| `add` | two numbers | their sum | the two-input case, which is where claiming gets interesting |
| `countdown` | one number | it minus one, or nothing if zero | terminates a chain without an external signal |
| `discard` | one | nothing | a sink that counts and sums what it consumed |
| `say` | one | nothing | writes a value out the serial line |
| `chew` | one block | a checksum of it | deliberately substantial — see below |

**`chew` exists to measure the design stance.** The engine touches
shared memory only when a task starts and when a value is delivered, so
the cost of the engine is paid per run, not per unit of work. That
argues for boxes that do more per run — a few substantial C functions
rather than many small ones wired together. `pass` and `chew` are the
two ends of that measurement: `pass` is all engine and no work, `chew`
is mostly work. The ratio between them at 215 is the number that says
how coarse a box ought to be.

```
   the two shapes, same total work:

   fine:   [inc]→[inc]→[inc]→[inc]→[inc]→[inc]→[inc]→[inc]
           8 runs, 8 claims, 8 deliveries, 8 tasks

   coarse: [────────────── chew ──────────────]
           1 run, 1 claim, 1 delivery, 1 task
```

## Suggested implementation steps

1. The three operations, with placement taking a box's shape — its
   parameter sizes and count — from wherever the box is described.
   In this phase that is a hand-written record next to the function;
   from phase 3 it is generated.
2. Refusals: an unknown box, a port index that does not exist, a
   destination naming a station that does not, a static value the wrong
   size for its port. Each names what was wrong and where — see 214 for
   what happens next.
3. The starter box library, one C function each, with `chew` sized so
   its run time is comfortably above the engine's per-run cost.
4. A helper that assembles a chain of N stations of a given box, since
   every test below wants one.
5. A test that a program built by these calls runs, and that the same
   program built in a different order — all wiring first, or all
   placement first — produces the same result.
6. A test that a station placed but never wired simply never runs, and
   costs nothing while not running.

## Open questions

- *Where does a box's shape live before phase 3 generates it?* A
  hand-written record beside each function is the obvious answer and
  it is also the thing phase 3 exists to delete. Writing it in the
  shape the generator will emit means phase 3 replaces a file rather
  than a design.
- *Should placement take a name?* Writing the running set back out as
  something readable needs one, and so does any error message worth
  reading. It costs one pointer per station. The other project
  discovered it had thrown names away and had to put them back; this is
  the cheap moment to not repeat that.
- *What refuses a wire whose types do not match?* Nothing here — a
  hand-built map is built by somebody who knows both ends. From phase 3
  the catalogue knows every box's types and the check becomes real. It
  is worth knowing that this phase's maps are trusted in a way later
  ones are not.

## Blocked by

207, 208, 209, 210, 211.

## Blocks

213, 214, 215.

## Related

- [207 — The station table](207-the-station-table.md), which these
  operations grow
- [214 — When a box removes itself](214-when-a-box-removes-itself.md),
  which uses the same configure operation in reverse
- [215 — Phase 2 demo](215-phase-2-demo-the-endurance-test.md), which
  is built entirely out of this
