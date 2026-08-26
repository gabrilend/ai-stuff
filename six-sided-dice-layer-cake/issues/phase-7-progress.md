# Phase 7 — The Sieve: progress

**Six radial links and the pipeline that runs on them. Five done, one honest
about being incomplete.**

| ticket | blueprint | state |
|---|---|---|
| `701` | `050-sieve-topology` | done |
| `702` | `051-radial-link-physical` | done |
| `703` | `052-link-protocol` | done |
| `704` | `053-sieve-schedule` | done |
| `705` | `054-flow-control-and-deadlock` | **written; the proof is prose** |
| `706` | `055-sieve-bandwidth` | done |

**Two hundred and seventy-one constraints hold across forty-six blueprints.**
Thirty-four wait on phases 8 through 11.

## The claim, now checked

`C-055-1` reduces the architecture's central argument to one number that must be
one: **a single face gets the whole aggregate bandwidth of the memory when the
other five are idle.**

`008` entry 5 says that passing tokens through six faces in series costs almost
nothing, because the faces would have been contending for the same memory anyway.
That is true only if this holds. Three separate blueprints have to permit it —
the crossbar routing the whole array to one port, the link carrying it inside its
power allocation, the slice absorbing it — and any one failing would have left
every other blueprint still checking while the machine ran six times slower than
advertised.

## Counting pads gives the wrong answer

The radial interface has over five million positions. Counting them gives
petabits a second. Counting picojoules gives hundreds of watts for the same
traffic. **Power binds by more than an order of magnitude**, and a constraint now
asserts that ratio explicitly so a reader who sizes the interface by pad count
finds out from the checker rather than from a thermal failure.

The same mistake is available in `062` at eight times the width, which is why
both blueprints open by naming which budget binds.

## What was closed

**`009` entry S1.** A sequence ending mid-pipeline lets its bubble propagate. The
arithmetic says why that is the right answer rather than the lazy one: at the
batch sizes this machine is for it costs under a per cent, and the alternative —
letting a face pull work forward — interacts with `039`'s ordering in a way
nobody has traced.

## The ticket that is not finished

`705` produced a blueprint and did not produce a proof. The dependency graph is
drawn, both cycles are identified and both are broken by a stated rule. But
`C-054-1` asserts that there are two channels, not that they share no queue;
`C-054-2` asserts a ring break exists, not that it is where it is claimed.

The notation cannot hold a dependency graph, so **the acyclicity argument is
checked by a reader** — which is exactly the kind of reliance this project set
out to remove. On a machine with no operating system, where a deadlock is a cube
that stops and cannot be diagnosed, that gap is worth naming rather than
counting as done.

## What is still open

**The spout's average traffic is a use assumption** (`055`). A pane every
millisecond is ordinary; a machine being used as memory through `069b` takes them
far more often, and nothing has budgeted the bandwidth for that mode.

**Nothing covers a request being refused rather than delayed** (`054`, `037`).
Every bound assumes a client is eventually served.

**Timeouts have no defined recovery** (`054`). They raise a fault; what happens
next is not written, and the honest answer on this machine may be that there is
nothing to do but halt.

**Errors are corrected and not counted** (`052`). How often a line needed
correcting per link is the only signal that would show a conductor failing
slowly, and `051` has no other way to know which to remap.

**The stage-equality tolerance is a `given` and `075` has not been told** (`053`).
