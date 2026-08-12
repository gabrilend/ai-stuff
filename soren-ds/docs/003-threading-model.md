# Threading model

Everything above the C layer is a soramech map running across four
cores. This document describes the machinery that makes that safe on
this chip, and the words it uses.

It is the design built and measured in
`/home/ritz/programming/ai-playground/minimal-soramech/`, mapped onto a
device with no operating system underneath it.

## Two words that were one word

| word | what it is | how many |
|---|---|---|
| **box** | the code — a C function, its parameter types, its name | one per source file |
| **station** | one placement of a box: its own inputs, its own wires, its own lock | as many as anyone places |

There is no separate "map" object. **A map is whichever stations
currently exist and are wired to each other.** Four apps, the
compositor and the input router all live in one station table at once;
what separates them is the wiring, not the storage.

## The one rule

> A station runs when, and only when, every one of its input ports
> holds a value.

Everything below is machinery for deciding that cheaply and safely.

**Nothing polls.** The check runs as the tail end of a write, on
exactly one station — the one just written to. A station whose inputs
have not changed cannot have become ready, so there is nothing else to
look at. There is no scheduler thread and no scan anywhere in the
engine: the act of finishing is the act of scheduling.

## The path a value takes

```
  a core has just run a box.  its return value is in the task.

  choose an exit          the station's kind decides.  one table lookup.
       │
  read the destinations   one pointer read. the array is immutable.
       │
  for each {station, port}:
       │
       ├─ take an empty cell         one compare-and-swap
       ├─ copy the value in          elem_size bytes, no allocation
       ├─ mark it ready              one compare-and-swap
       ├─ run the readiness check    walk that station's ports
       └─ if ready: claim, build a task, push it

  then free your own task and go back for more work.
```

**No lock is taken anywhere on that path.** The station's lock still
exists, and it is held for exactly four rare structural things:
growing a port, rewiring, writing a static, and changing a port's
source.

## Input ports

| tag | how it is read | how it is written | holds up readiness |
|---|---|---|---|
| **ring** | consumed — one value taken per run | queued behind whatever waits | **yes** |
| **static** | peeked — every run reads the same value | replaces what was there | no; always full |
| **none** | never; a station holding one cannot run | by being given a source | **yes**, permanently |

A ring port is a stream; a static port is a dial.

**Writing a static is an event.** It runs the ordinary readiness check
on its station, which is how a chain of stations wired through statics
recalculates — and how a program starts at all, since the writes that
build a program are the writes that set it going.

**None is a state, not a value.** Nothing is ever handed to a box. It
is what lets a program be assembled a piece at a time, and it turns out
to be the mechanism for two other things as well: a parked program's
tail, and a box that has taken itself out of service.

## Every cell carries its own state

| state | meaning | who may touch it |
|---|---|---|
| empty | nothing here | a writer, by taking it |
| reserved | a writer owns it and is copying in | that writer only |
| ready | the bytes have landed | a reader, by taking it |
| claimed | a reader owns it and is copying out | that reader only |

Every transition is one compare-and-swap. That is the whole of the
mutual exclusion, and it is per cell rather than per station.

**The state lives on the cell, not in a separate array**, because an
array of states puts every cell's state in one or two cache lines, and
a writer at one end would take the line away from a reader at the other
on every flip — a hardware cost no lock can remove, since nothing is
racing.

## The claim

**Walk the ports in ascending order.** Claim a ready cell at each ring
port; skip statics, which are peeked rather than consumed. Reach the
end and the run is real. Meet a port with nothing ready, walk back
releasing what you took, and give up.

**The fixed order is what prevents livelock.** Without it, two cores at
a two-input station can each claim one port, each fail on the other's,
each release, and retry into the same interleaving forever — nobody
blocked, nobody progressing, and a complete input set sitting there the
whole time.

**The claim is what lets two runs of one station happen at once.** By
the time a core has claimed, its values are copies inside a task
nothing else can see. Which is also why **a box may not remember
anything between calls**: the box function runs long afterwards, on
whichever core picks the task up, and two cores can be inside the same
function at the same instant. Nothing enforces this.

## What this chip requires

**The caches must be on, and that means the MMU must be on.** With no
translation table loaded, every data access is Device memory: nothing
is cached, unaligned accesses fault, and — the part that stops
everything — the exclusive instructions that build a compare-and-swap
are undefined there. They may fault, or succeed on each core
independently without arbitrating. Issue 201 is the flat identity map
that fixes this; phase 9 reuses the same table for protection.

**False sharing is a cost no lock removes**, and it appears three times
in this design at three scales:

| what | must not share a cache line |
|---|---|
| the allocator's bitmap (203) | two cores' page bits |
| a worker's context (205) | two cores' counters |
| a port's cells (208) | a writer's cell and a reader's cell |

**Sleeping is an instruction, not a system call.** A core with nothing
to do waits for an event; a core that pushes a task sends one. The
event register makes this safe without a lock: sending an event sets a
bit in every core, so a core arriving at the wait afterwards finds the
bit already set and does not wait at all. The window that is the
classic lost-wakeup bug is closed by hardware.

**Nothing interrupts the engine.** Input is polled off a 60 Hz frame,
not delivered by handlers, so no core is ever interrupted while holding
a lock and no handler ever touches a station. A core still wakes on
time: waiting for an interrupt returns when one becomes pending even
with interrupts masked, so the timer wakes the core and no handler runs.

## Endings

**All four cores asleep is not completion.** On a workstation it means
the program is finished. Here it means the user has not pressed
anything yet.

Programs on this device end because they were **asked** to. A pipeline
ends in a station that will not run again until somebody restarts it —
its input given no source. A parked program's buffers go back to the
allocator with a checksum remembered, so restarting resumes in place if
nobody needed the pages and rebuilds loudly if somebody did.

## Errors

**A box that cannot continue takes itself out of service and everything
else keeps running.** Its inputs are set to no source, so it can never
become ready. Nothing is deleted; the hole is visible when the running
set is written back out.

Errors are recorded **in place and counted, never appended** — one
fixed slot per station, so the same failure a million times is one slot
reading a million rather than a million records. The first one goes out
the serial line; the count is for the rest.

## What every layer above this inherits

Drivers are boxes. The compositor is boxes. Apps are boxes. The shape
of the rule above is the shape of how everything in the userland thinks
about concurrency, and two of its consequences are worth stating to
anybody who will write one:

- **A box may not remember anything between calls.** State lives on the
  wires. To count, route a box's output back into its own input.
- **A box must never block.** Nothing may wait on a value, a lock, or a
  device. A core that cannot progress is a core not running the ten
  things that are ready.

Neither is enforced. A box with a counter inside it, or a blocking
read, will be wrong under load and nothing will say so.

## Related

- `issues/phase-2-progress.md` — the issues that build this
- `docs/007-memory-model.md` — the flat address space this runs in
- `docs/012-soramech-runtime.md` — the runtime above it, **which still
  describes the older design and needs rewriting when phase 3 starts**
