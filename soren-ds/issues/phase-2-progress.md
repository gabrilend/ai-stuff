# Phase 2 progress — the ceramic core engine

Phase 2 builds the substrate every soramech map runs on, and it builds
all of it. By the end of the phase the device turns its caches on, wakes
its other three cores, gives each one memory it owns, and runs a map
that somebody wrote by hand — values moving between stations with no
lock anywhere on the path they travel.

This is the most important phase in the project. Everything above it is
composition of what phase 2 lands.

## The design changed, and these issues are new

The original phase 2 was written against an older soramech design: a
per-box gathering atomic that decided when a box could fire, a unique
return slot per fire, and an issue devoted to auditing memory ordering.
That design has been superseded by the one in
`/home/ritz/programming/ai-playground/minimal-soramech/`, and these
issues are written against the new one from scratch rather than
migrated.

The eleven old issues are kept in `issues/superseded/` — see the note
there for what changed and why.

| the old design said | the new design says |
|---|---|
| a box, with an atomic gating its firing | a **station** — one placement of a box — with no lock on the path at all |
| one gathering critical section per box | a claim that walks ports in a fixed order and rolls back |
| a unique return slot per fire | no return slot; the core that ran the box delivers the value itself |
| a box descriptor table | a station table that grows in shelves, plus a catalogue that phase 3 generates |
| a slot's ring buffer with head and tail | cells that each carry their own state, and growth that adds a page |
| release/acquire tagged across the whole core | one rule: build a thing completely, then publish it |
| the program ends when work runs out | programs end because they were **asked** to |

## And then a station became removable

These issues were written with one restriction stated in five places
across this project: **a station cannot be removed.** The reasoning was
that an index is a position, so reclaiming one means either a hole every
walk learns to skip or a renumbering that invalidates every wire at once.

The parent project overturned it, into something stronger rather than
weaker, and the whole argument is one observation: **a wire exists only as
a destination record on some station's output port.** So cutting every wire
that names a station is a single walk of the table, and once none is left
nothing stale survives to be followed. No wire needs a generation tag, and
delivery pays nothing — the alternative was four bytes on every wire and a
comparison on every single delivery, forever, to guard against a situation
this order of operations makes impossible.

Two things surfaced in building it that the reasoning had not seen. **A
removed place is not immediately a free place**: a task is assembled from a
station's slot count, return size and call site *after* the readiness check
releases the mutex, so the record has to stay intact behind a
not-starting flag until the sweep says nobody can be inside a task that
needs it. And **a value already in flight toward a removed station is
discarded**, because a worker reads a port's destination list once and then
visits the entries.

This device needs no new machinery for it. 207 already files old
destination arrays in a scrapyard and already has the per-core odd/even
counter sweep that decides when nobody can be inside one; removal is that
same scrapyard used a second way.

Where it lands: **411** replaces a box by removing the old station instead
of leaving it unwired forever, **909** gets an app's stations' places back
at close instead of accumulating one dead station per station per app over
a day, and **410** reaches a third kind of reclaimable code — a box whose
every station has gone. The *no source* state still exists and is still
what **213** parks with and what **214** uses when a box takes itself out
of service; those want a station that stops running and stays.

## The story of the phase

Read them in order for a walkthrough of how the engine comes together.

| # | issue | what it lands |
|---|---|---|
| 201 | the memory map that turns the caches on | the table that makes compare-and-swap defined and the caches usable |
| 201a | run the CPU at its rated speed | the clock, the secondary lever behind the caches |
| 202 | waking the other cores | four cores, four stacks, one starting gate |
| 203 | memory each core owns | striped allocator arenas, so allocating needs no lock |
| 204 | the task ring | the one channel between finding work and doing it |
| 205 | workers and the run loop | take, run, deliver, free, repeat |
| 206 | sleeping and waking | park the silicon; wake on an event or a deadline, with no handler |
| 207 | the station table | shelves, indices, immutable destination arrays, and a station that can be removed with its place reused |
| 208 | what an input port is | three tags, per-cell states, growth by adding a page |
| 209 | the readiness check and the claim | the engine's one rule, taking no lock |
| 210 | the task | one allocation sized for its box, from per-core block lists |
| 211 | the delivery walk | the central path: returned value to next task |
| 212 | maps built by hand | place, configure, wire — the surface the loader will call |
| 213 | asked to stop, and parking | ending on purpose; parked memory released but remembered |
| 214 | when a box removes itself | errors counted in place; a broken box unwires itself |
| 215 | phase 2 demo: the endurance test | the capstone, blocked on all of the above |

## Completed issues

The whole engine is built as portable C (`src/engine/`) and proven on
the laptop twin (issue 200, `twin/`). Counts are best read from
`/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua <project> -m`
rather than copied here.

- **200 — the laptop twin.** The seam (`src/engine/025-platform.h`)
  every portable file asks its hardware questions through, the laptop's
  answers, the device's answers (unverified), the build variants, the
  test runner, and the picture and measurement writers.
- **203 — memory each core owns.** Striped page bitmap, one cache line
  per stripe, unowned stripes claimed on demand; foreign frees routed
  home.
- **204 — the task ring.** One ring, ticket lock, doubling. Wakes only
  parked cores.
- **205 — workers and the run loop.**
- **207 — the station table.** Shelves, immutable destination lists,
  removal with the scrapyard sweep.
- **208 — what an input port is.** Per-cell state locks; growth by
  adding pages and, when needed, a longer page list.
- **209 — the readiness check and the claim.** With the lost-set race
  found and closed: one checker per station at a time, nobody waiting.
- **210 — the task.** Exactly sized, copies; size-class blocks with a
  debug-build double-free and write-after-free catcher.
- **211 — the delivery walk.** All six exit kinds are already rows.
- **212 — maps built by hand**, and the starter box library.
- **213 — asked to stop, and parking.** Begin / step / restart;
  checksummed pages released and taken back, or rebuilt out loud.
- **214 — when a box removes itself.** One counted slot per station; a
  faulting box survived in debug builds.

Tests: `scripts/test-twin` runs `twin/tests/048`–`054`, 88 checks.

## Open issues

- **201 — the memory map that turns the caches on.** Written in
  `src/device/044-identity-map.c`; unverified on hardware.
- **201a — the CPU clock.** Untouched.
- **202 — waking the other cores.** Written in
  `src/device/042-platform-device.c` and `043-cores.s`; unverified.
- **206 — sleeping and waking.** Built and proven on the twin; the
  device half uses wait-for-event with the timer's event stream instead
  of wait-for-interrupt, and is unverified.
- **215 — the endurance test.** Passes on the twin
  (`./run-demo 2`); the device run waits on 201 and 202.

## Open questions still to work through

Every issue carries its own. The ones that reach beyond a single issue:

| question | lives in | why it matters beyond its issue |
|---|---|---|
| does this chip's exclusive monitor arbitrate across all four cores? | 201 | the whole engine rests on it and the failure is silent |
| one task ring for four cores, or one each? | 204 | the single most contended point in the system by construction |
| how coarse should a box be? | 212, 215 | it is a rule the whole project follows, and 215 is where it gets a number |
| how does the engine know which stations belong to one program? | 213, 214 | parking and error reporting both need the answer |
| how large is a worker's stack? | 202 | the delivery walk runs on it and fan-out is unbounded |

### Proposed answers (UNVERIFIED — see each issue for the reasoning)

| question | proposed answer |
|---|---|
| does the exclusive monitor arbitrate across all four cores? | assumed yes; the twin's equivalent passes (053); the device probe in 201 is the check |
| one task ring for four cores, or one each? | measured on the twin: four cores give about 1.9–2× one core on engine-bound work, so the single ring costs about half the machine; keep one until the device's number exists, then try per-core rings with stealing |
| how coarse should a box be? | a do-nothing run costs as much core time as a few hundred rounds of chew's work (the current number is on the metrics pages); a box should do at least that much per run |
| how does the engine know which stations belong to one program? | it does not; the caller keeps the list (phase 3's loader keeps one per program) |
| how large is a worker's stack? | 64 KB on the device; measure by stack painting |

## Phase demo

`issues/completed/demos/phase-2/run.sh`, also reached as `./run-demo 2`,
exists and passes **on the laptop twin**. It builds the twin, runs the
endurance program on four cores and on one for the given number of
seconds, checks count and sum against arithmetic in each, and reports
how many times more work four cores did than one. Both runs draw their
totals on the two screens and write them as pictures under
`tmp/shared-memory/demos/phase-2/`; every number goes to
`tmp/shared-memory/metrics/` for the documentation pages.

The device version — flash, run on the handheld's four cores, stream
the numbers over USB, draw them on its bottom screen — waits on 201
and 202.

