# 214 — When a box removes itself

## Current behavior

**There is no error path, and the one this design inherits does not fit
a handheld.**

The engine this follows has a single rule: any invalid operation stops
the program, having first said everything it can about what went wrong.
No fallbacks. On a workstation that is right — the process exits, the
person reads the message, fixes the file, and runs it again.

This device cannot exit. There is nothing to exit *to*. And the person
who made the mistake is very often sitting there holding it, halfway
through writing the box that just failed, with everything else on the
device still doing useful work.

## Intended behavior

**A box that cannot continue takes itself out of service, says so, and
everything else keeps running. Then you write it better, and it stops
taking itself out of service.**

### Removing itself is one field write

Nothing is deleted. The station stays exactly where it is — its index
is a position and positions are permanent (207). Its **inputs are set
to no source**, which means it can never become ready, which means it
never runs again.

```
   before   parse-header.0 ←── length-of        runs on every arrival
   error    parse-header.0 ←── (no source)      never becomes ready
   fixed    parse-header.0 ←── length-of        runs again
```

The cost while removed is nothing: no delivery arrives, no core looks
at it, no check runs. And the absence is **visible** — writing the
running set back out shows that station with its input unwired, so the
hole is a thing you can look at rather than a message that scrolled
past.

Everything downstream simply stops receiving, and stops becoming ready,
and stops running. No cascade is needed because there is nothing to
cascade: a station starved of input is already the ordinary state of a
station nobody has wired yet.

### The error record: written in place, counted, never appended

**One fixed slot per station, sized at boot, never growing.** The same
error happening a million times increments a count. It does not produce
a million records, or a million serial lines, or a growing buffer that
eventually becomes the actual problem.

| field | type | meaning |
|---|---|---|
| kind | small integer | what went wrong (see below) |
| count | `int` | how many times, since this slot was last read |
| detail | one word | whatever the kind needs — a bad index, a size |

| kind | what happened |
|---|---|
| refused | the box itself decided it could not proceed |
| bad wiring | a wire named a station or port that does not exist |
| wrong size | a static's bytes did not match its port's type |
| no memory | an allocation could not be satisfied |
| trapped | the box faulted (see below) |

```
   the same error, a million times:

   ┌──────────────────────────────────────┐
   │ station 12 │ refused │ count 1000000 │   ← one slot.
   └──────────────────────────────────────┘     bounded by construction.
```

**In RAM, and only in RAM, unless somebody asked otherwise.** A debug
build adds a timestamp to each record and writes them to disk. The disk
half needs a filesystem and therefore waits for phase 4; the timestamp
and the flag belong here so that phase 4 is a destination rather than a
redesign.

**The serial line gets the first one.** The count is for the ones after
it. Somebody watching the stream sees the failure the moment it
happens, once, with the station named — and does not then lose the
stream to a repeat of it.

### About faults, honestly

With phase 2's flat identity map, **a box that computes a wrong address
usually does not trap.** Every address maps to itself and nothing is
marked unreachable, so the write lands on real memory and succeeds. The
value it destroyed belonged to another program, or to a port's cells,
or to the allocator's bitmap, and the damage appears somewhere else,
later, as a wrong answer nobody can trace back.

That is the honest limit of what this phase can promise, and it is
worth writing down rather than discovering. Phase 9's protection work
is precisely the machine that converts that silence into a trap: give
each program a region, mark everything else unreachable *from it*, and
a wrong number faults at the moment it is wrong.

**A trap that does happen is survivable only in a debug build.** The
core would have to know where to return to, which means saving a
snapshot of itself before every call into a box — a cost paid on every
single run to catch something that, in this phase, is rare. So:

| build | before calling a box | on a trap |
|---|---|---|
| ordinary | nothing | panic: LED code, message, park |
| debug | save where to return to | name the station from the core's `inside` field, remove it, restore, carry on |

The debug build is the one somebody is running while authoring on the
device, which is exactly when a crashing box is expected and exactly
when losing the session is expensive. The ordinary build is the one
shipping, where a trap means something has gone wrong far below the
level a box could have caused.

## Suggested implementation steps

1. The error slot table, one per station, allocated with the station
   table and never grown.
2. Recording: find the slot, and either fill it or bump its count.
   First occurrence also writes one line out the serial port.
3. The removal itself, calling 212's configure operation to set every
   input to no source — the same operation, used in reverse.
4. A box-facing way to refuse, so a box author can say "not this
   value" without inventing a sentinel return.
5. The debug build's timestamp field and the snapshot-before-call, both
   behind one build flag so the ordinary build carries neither.
6. A test that a box refusing once removes itself, that the rest of the
   program keeps running, and that rewiring its input brings it back.
7. A test that a box refusing a million times produces one slot, one
   serial line, and a count of a million.

## Open questions

- *How does the count get cleared?* If nothing clears it, the slot
  reads "a million" forever and a second million is indistinguishable
  from the first. Reading it should probably clear it, which makes the
  reader responsible for the number — fine when the reader is a
  diagnostic, awkward when there are two readers.
- *Should removing itself also remove what it fed?* No cascade is the
  answer above, and it is right mechanically. But a person looking at
  five stations that stopped will want to know that four of them
  stopped *because of* the fifth, and nothing currently says so.
  Following the wiring backwards from a starved station would answer
  it, at the moment somebody asks rather than continuously.
- *What clears the record when the box is fixed?* Rewiring the input is
  the act that brings it back; it is probably also the act that should
  reset the slot. Worth being deliberate, because a stale count on a
  box that now works is worse than no count.
- *Is refusing something a box does, or something the engine does to
  it?* Both appear above — the box refuses, and the engine removes it
  for bad wiring. They share a record but they are not the same event,
  and the shared table may be hiding a distinction worth keeping.

## Blocked by

207, 212.

## Blocks

215.

## Related

- [208 — What an input port is](208-what-an-input-port-is.md), whose
  *none* state does the removing
- [212 — Maps built by hand](212-maps-built-by-hand.md), whose configure
  operation this calls
- [213 — Asked to stop, and parking](213-asked-to-stop-and-parking.md),
  the same mechanism one scale up
- [205 — Workers and the run loop](205-workers-and-the-run-loop.md),
  whose `inside` field names the station on a trap
- [015 — LED diagnostic codes](../docs/015-led-diagnostic-codes.md),
  what a panic looks like from outside
