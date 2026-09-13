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

**A door is a port, not a station.** A mark on an input port says the
outside delivers argument *N* here; a mark on an output port says result
*N* leaves here. No station is special, and no station has to exist for
an argument to.

```
   ┌─ the program ──────────────────────────────────────┐
   │                                                    │
  ─┼─→ 0$ [ some station ] ──→ ... ──→ [ another ] 0$ ──┼─→
   │      a marked input port          a marked output  │
   └────────────────────────────────────────────────────┘

   a parent wires to those ports exactly as it would wire
   to any port, and cannot tell what is between them.
```

In a map file the mark is a `$` on the port's own line, the `in` or `out`
keyword carrying the direction (305):

```
   station check (boxes/arg.c:in_range)
     in 0 - 0$            argument 0 arrives here
     out 0 - work.0

   station finish (boxes/shape.c:as_bytes)
     in 0 - work.0
     out 0 - 0$           result 0 leaves here
```

### An argument stops costing a station

This is the change, and on this device it is not a tidiness argument.

A designated *station* means every argument pays for a station running
the identity function: a station record, a mutex, a ring buffer, and then
**per value** a task allocated, a dispatch through the pool, a call that
returns its own argument, a readiness check, and a second delivery. All
of it to move a value one hop for no reason.

A designated *port* pays none of that. The value the outside delivers
lands directly in the port of the station that wanted it. Four cores and
3 GB is exactly the machine where a per-argument station is worth
removing, and a box that genuinely wants to check or reshape an argument
is still free to be the first station — it is now a choice rather than
the mechanism.

### Which argument a port is, is stated rather than positional

**The mark carries a number, and that number is the argument's
identity** — chosen by whoever wrote the line, not derived from where the
line sits. Reordering every line in the file changes nothing.

A gap or a repeat in the numbering is **refused when the program is
brought up**, on the argument side and the result side both. A scheme
that took the order from wherever the stations happened to land in the
table cannot even detect that: moving two lines in a sub-program would
silently swap two of the parent's arguments.

### Being an argument is derived, not stored

**A port is an argument slot when it is marked and nothing feeds it.** A
port that is both marked and wired is fed both ways and simply is not
one.

That replaces the idea of closing a door when an enclosing program wires
in. There is nothing stored, so nothing can go stale, and no bookkeeping
happens at the moment of wiring. It also makes the numbering checks safe
under composition, where one description placed twice puts two ports in
the table both marked argument zero — and fan-in from outside and inside
at once stays legal, which it would not if a door were a thing that
closed.

**The unfed-port report is unaffected.** Bring-up reports a station with
queued inputs that no arrow feeds, and a marked port is exempt. It is the
explicit mark that buys the exemption, never the mere absence of a wire,
so a genuinely forgotten wire stays distinguishable from a deliberate
door.

**A station may hold ports of both kinds.** A station with an argument
port and a result port is an ordinary station. The refusal that would
have made it a mistake only made sense while the mark was on the station,
because a station is one thing and a port is a smaller one.

**The one rule a mark actually adds** is at the result end: when nobody
is wired beyond a marked output port, the values are **held** rather than
discarded. Everywhere else in the engine an exit wired to nothing
discards, which is right for an unwired comparator branch. Discarding a
program's results would mean the program did nothing.

**The readiness check applies to a marked port exactly as it applies
anywhere.** A station holding a marked input port does not run until
every one of its input ports holds a value, and then one is taken from
each. So a program's results cannot come out of step: three values
waiting on one input and one on another means one complete set moves and
two stay behind. That falls out of the ordinary rule rather than being
arranged for.

**Several arguments are several marked ports, and they need not be on one
station.** With the mark on the port, "one door per argument group" stops
being a constraint at the entrance — `0$` and `1$` may sit on two ports of
one station, or on ports of two stations that never meet. What is still
true is at the *exit*: a box returns one value, so a station has one
output port, so several results are several marked output ports. Faking
several returns with a struct that something downstream takes apart means
writing a function to satisfy the engine, which is the thing nobody
adopting this should ever have to do.

Fan-out is not the same thing and is already free: one marked port's
value may feed as many interior stations as you wire it to.

### Composition needs no mechanism at all

**A map is a box.** Once a program says where its arguments arrive and
where its results come from, placing one inside another is wiring to
those marked ports, addressed by their numbers. There is no encapsulation
pass, no prefix-renaming of a sub-map's stations into a parent's
namespace, no rewriting of boundary wires, and no "finished" to detect.

The old design had all of that because it had two kinds of thing to
reconcile — a map object and a parent map object. There is one station
table and a program is only whichever stations are wired together, so
there is nothing to fold into anything.

**Placing a program hands back the same thing placing a box does.** A
caller gets one receipt either way and asks it for door *N*, so nothing
above has to know which kind it placed — which is what makes "a map is a
box" a fact rather than an aspiration.

| the old splicer did | what replaces it |
|---|---|
| recursively load the sub-map as its own object | load its stations into the one table, like any load |
| prefix-rename every id | give the stations names; two copies need two sets of names |
| find external read boxes, delete them, rewrite every wire that targeted them | wire to the marked input port, by its number |
| find external write boxes, add their outputs to the parent's list | wire from the marked output port, by its number |
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

1. **The mark on the port record**, as a number: not-a-door, or door *N*.
   One field on the input port and one on the output port.
2. The `$` spelling on `in` and `out` lines (305), and the port-level
   call a person makes by hand.
3. **The numbering check at bring-up** — a gap or a repeat refused, on
   the argument side and the result side both.
4. **Being an argument slot derived rather than stored**: marked and
   unfed. Outside delivery accepts a station-and-port whose port carries
   a mark; the walk that fills arguments from outside takes marked ports
   in number order and skips one a wire also feeds.
5. The hold-rather-than-discard rule at a marked output port, which is
   the only behaviour a mark adds.
6. Placing a program inside another: load it, wire to its marked ports by
   number, and hand the caller the same receipt placing a box hands back.
7. The naming question below, settled before two copies of one
   sub-program exist in the same table.
8. A test that a program placed twice produces two independent copies
   that do not interfere, both of whose port marks say zero.
9. A test that two marked ports on one station, fed by two callers, pair
   arbitrarily — written deliberately, because it is the trap, and a test
   that pins it is how somebody later finds a decision rather than a bug.
10. A test that a marked port with a wire into it is not an argument
    slot.
11. A test that arguments renumber by editing marks rather than by moving
    lines.
12. A test that writing the running program back out and reading it in
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
- *Answered by moving the mark onto the port: can a program have more
  than one door out?* Yes, and it needed no deciding. Several marked
  output ports offering the same results in different shapes are just
  several numbered results; what "the program's output" means when there
  are two is *result 0 and result 1*, and a caller asks for the one it
  wants by number. The question only looked hard while a door was a
  station, because then two doors out meant two stations each claiming to
  be the end.

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
