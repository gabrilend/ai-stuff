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
| 207 | the station table | shelves, indices, immutable destination arrays |
| 208 | what an input port is | three tags, per-cell states, growth by adding a page |
| 209 | the readiness check and the claim | the engine's one rule, taking no lock |
| 210 | the task | one allocation sized for its box, from per-core block lists |
| 211 | the delivery walk | the central path: returned value to next task |
| 212 | maps built by hand | place, configure, wire — the surface the loader will call |
| 213 | asked to stop, and parking | ending on purpose; parked memory released but remembered |
| 214 | when a box removes itself | errors counted in place; a broken box unwires itself |
| 215 | phase 2 demo: the endurance test | the capstone, blocked on all of the above |

## Completed issues

None yet.

## Open issues

All of 201 through 215, plus 201a.

## Open questions still to work through

Every issue carries its own. The ones that reach beyond a single issue:

| question | lives in | why it matters beyond its issue |
|---|---|---|
| does this chip's exclusive monitor arbitrate across all four cores? | 201 | the whole engine rests on it and the failure is silent |
| one task ring for four cores, or one each? | 204 | the single most contended point in the system by construction |
| how coarse should a box be? | 212, 215 | it is a rule the whole project follows, and 215 is where it gets a number |
| how does the engine know which stations belong to one program? | 213, 214 | parking and error reporting both need the answer |
| how large is a worker's stack? | 202 | the delivery walk runs on it and fan-out is unbounded |

## Phase demo

`issues/completed/demos/phase-2/run.sh` will exist once the phase
closes. It builds and flashes the image, assembles an endurance map out
of the starter box library, streams per-core numbers out the USB serial
line while drawing the running totals on the bottom screen, and reports
pass or fail. It passes when the sink's count and sum match the
closed-form expected values exactly, every core drained roughly its
share, and the growth counters go flat after warm-up.
