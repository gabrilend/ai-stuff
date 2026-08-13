# 309 — The two doors

## Current behavior

**A program has no outside.**

Values get in exactly one way: somebody who already knows the program's
insides names a station and a port and writes to it. Values get out
only as side effects — a box that draws to a surface, writes a file, or
says something down the serial line. Nothing anywhere is designated as
*where this program's arguments arrive* or *where its results come
from*.

Three things follow, and the third is the expensive one:

| | |
|---|---|
| **a program cannot be composed** | a parent has to reach in and name a station by whatever its author called it. Rename that station and every parent breaks. |
| **a program cannot take arguments** | nothing corresponds to a parameter list; running one with a different input means editing its file |
| **a leaf box and a composite do not look alike** | a C function announces what it takes and returns in its signature. A program announces neither, so "a program can be used as a box" is aspiration rather than fact. |

## Intended behavior

**A program's doors are ordinary stations, designated.**

Not a new kind of thing, not a splice, not a flattening pass. Same
shape as any station — input ports, one output port, and a box that may
or may not be there. What makes one a door is the designation.

```
   ┌─ the program ────────────────────────────────────┐
   │                                                  │
  ─┼─→ [ way in ] ──→ ... ──→ ... ──→ [ way out ] ────┼─→
   │   designated                     designated      │
   └──────────────────────────────────────────────────┘

   a parent wires to those two exactly as it would wire
   to any station, and cannot tell what is between them.
```

| the door in | the door out |
|---|---|
| its **input ports** are the program's input ports | its **output port** is the program's output port |
| says which ports the outside is allowed to deliver to | says where results come from |
| a box here may check or reshape arguments on the way in | a box here may shape results into whatever a caller wants |
| with no box: one input, one output, the value crosses unchanged | with no box: the same |

**The one rule a designation actually adds** is at the door out: when
nobody is wired beyond it, the values are **held** rather than
discarded. Everywhere else in the engine an exit wired to nothing
discards, which is right for an unwired comparator branch. Discarding a
program's results would mean the program did nothing.

**The readiness check applies to a door exactly as it applies
anywhere.** Nothing crosses to the output port until every input port
holds a value, and then one is taken from each. So a program's results
cannot come out of step: three values waiting on one input and one on
another means one complete set moves and two stay behind. That falls
out of the ordinary rule rather than being arranged for.

**One output port, so one door per argument group.** A box returns one
value, so a station has one output port, so a program taking several
unrelated arguments has several doors in rather than one door with
several outputs. The alternative needs a C function returning several
values, which does not exist — and faking it with a struct that
something downstream takes apart means writing a function to satisfy
the engine, which is the thing nobody adopting this should ever have to
do.

Fan-out is not the same thing and is already free: one door's single
output port may feed as many interior stations as you wire it to.

### Composition needs no mechanism at all

**A map is a box.** Once a program says where its arguments arrive and
where its results come from, placing one inside another is wiring to
those two stations. There is no encapsulation pass, no prefix-renaming
of a sub-map's stations into a parent's namespace, no rewriting of
boundary wires, and no "finished" to detect.

The old design had all of that because it had two kinds of thing to
reconcile — a map object and a parent map object. There is one station
table and a program is only whichever stations are wired together, so
there is nothing to fold into anything.

| the old splicer did | what replaces it |
|---|---|
| recursively load the sub-map as its own object | load its stations into the one table, like any load |
| prefix-rename every id | give the stations names; two copies need two sets of names |
| find external read boxes, delete them, rewrite every wire that targeted them | wire to the door in |
| find external write boxes, add their outputs to the parent's list | wire from the door out |
| iterate until no sub-maps remain, with a cap against pathological nesting | a program that places itself never terminates, so the cap stays |

### The trap the doors open onto

**Two values delivered to two ports of the same station are not a
pair.** A door with an object port and a colour port, fed by two
callers who each want their own object painted their own colour, will
pair them arbitrarily — the first caller's object with the second
caller's colour is a perfectly legal outcome.

The reason is already written down: values may leave a port in a
different order than they arrived, because a reader takes the first
ready cell its scan finds and a rolled-back claim opens gaps wherever
it happens. If order within one port is not promised, correspondence
across two ports certainly is not.

**So anything that must arrive as a unit is one struct on one port.**
The engine supports this all the way down — the generator emits a field
table per struct, and the reader turns brace text into correctly
laid-out bytes using offsets the compiler computed. The object and its
colour become one value, indivisible by anything the scheduler does.

## Suggested implementation steps

1. The two designations, as lines in a map file and as arguments to the
   operations a person calls.
2. The hold-rather-than-discard rule at the door out, which is the only
   behaviour either designation adds.
3. Placing a program inside another: load it, wire to its doors.
4. The naming question below, settled before two copies of one
   sub-program exist in the same table.
5. A test that a program placed twice produces two independent copies
   that do not interfere.
6. A test that a door with two ports, fed by two callers, pairs
   arbitrarily — written deliberately, because it is the trap, and a
   test that pins it is how somebody later finds a decision rather than
   a bug.
7. A test that writing the running program back out and reading it in
   gives the same program.

## Open questions

- *How do two copies of one sub-program get distinct station names?* A
  prefix is the obvious answer and it is the one piece of the old
  splicer worth keeping. Whether the prefix is visible in error
  messages decides whether the same sub-program's failure reads
  differently in two parents, which is probably right and should be a
  decision rather than a side effect.
- *What records that a group of stations came from one file?* Nothing
  does, so "replace this sub-program with a newer version" has nothing
  to grab. Parking a program (213) and scoping names in the loader
  (306) both wanted the same answer, which is now three places asking
  for one mechanism.
- *Can a program have more than one door out?* Several doors out
  offering the same results in different shapes is genuinely useful —
  choosing between them would be rewiring — and it costs nothing except
  deciding what "the program's output" means when there are two.

## Blocked by

305, 306.

## Blocks

312, and phase 6's apps, which are programs composed of programs.

## Related

- [306 — The loader](306-the-loader.md), whose recursion places a
  sub-program
- [208 — What an input port is](208-what-an-input-port-is.md), whose
  lost arrival order is why the pairing trap exists
- [213 — Asked to stop, and parking](213-asked-to-stop-and-parking.md),
  which wants the same "which stations belong together" answer
