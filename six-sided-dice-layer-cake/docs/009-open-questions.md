# 009 — Open questions

Every question this design has raised, in one place. A question leaves the open
sections only by being answered, and the answer is written here beside it rather
than only in the blueprint that acted on it, so the reasoning stays findable.

**Nothing in this project is finished while this page has entries in its first two
sections.** Eighty-four blueprints check and five hundred and thirty-two
constraints hold; that is consistency, not completeness.

**Identifiers never move.** A question keeps its label when it is answered and
when its neighbours are answered around it, so the lists below have gaps in them.
A label that shifted would silently redirect every reference in ninety tickets to
the wrong question.

---

## Blocking — these would change work already done

### B2. Water, or a dielectric?

`021` selects water because it moves heat about ten times better than anything
non-conducting that is liquid at these temperatures. The microchannel field runs a
hundred and fifty microns from silicon at three quarters of a volt, and `017`
counts **a hundred and sixty-six joints** between the two.

A leak with water is a short circuit and a dead cube. A leak with a fluorocarbon
is a mess. The substitution costs about eleven kelvin of junction temperature
against fifty-nine of margin, and about ten times the pumping power.

**The design survives either**, which is the useful finding and is only available
because there is margin. So this is a reliability judgement rather than a thermal
one, and it belongs to whoever owns the failure consequences.

*A note on the word: coolant is a role, not a substance. Water is a coolant. The
question is water against a liquid that does not conduct.*

**Assumed:** water. `021` carries both fluids and a switch, so changing it is one
edit and a rerun.

### B4. Is the reference model the right anchor?

`078` fixes one shape and **every capacity, bandwidth and timing number in the
project is anchored to it.** It sets the core size, which sets the cavity, which
sets the cube; it sets the layer size, which sets the slice, which sets the die,
which also sets the cube.

`012` draws that chain explicitly and nobody has run it backwards. **A model half
this size would let the cube shrink**, and by how much is an afternoon's work.

**Assumed:** as stated. `080` carries the sensitivity.

---

## Open — carried, with the phase that owns each

### The thermal margin is claimed twice

**The clearest unresolved conflict in the project.** `074` publishes what fifty-nine
kelvin of margin would buy in clock frequency. `027` publishes what the same
margin would buy by removing a refrigeration plant — a fifty degree inlet needs a
radiator and a fan where a twenty-five degree inlet needs a compressor.

**Both stake a claim on it and neither knows about the other's.** No blueprint can
settle it: it is a decision about whether these are sold fast or sold cheap, and
it would produce two specification sheets where `089` has one.

### M4. Where does non-volatile state live? — **four dependents**

Nothing inside this cube survives a power cycle, and four blueprints need
something that does:

- `040`'s runtime repair map, **abandoned** because of it
- `033`'s brownout fault record, which is written into memory that is losing its
  rail
- `069`'s per-conductor failure record, which `063`'s spare remap acts on
- `073`'s boot step five, which has to re-derive or be re-supplied the spare
  assignment at every start

Four dependents on one gap is enough that this should stop being a question and
become a ticket. The options are a small fuse array per tier, a region on the
storage lines rewritten at shutdown, or accepting that all four capabilities are
lost.

### X2. Nothing has a tolerance — **the largest omission**

Every number in this project is a point value. `090` puts it first in the handoff
package's omissions list because a materials engineer will ask about the cube edge
on the first day.

It is a change to the **notation** rather than to any blueprint: `091` would grow
an interval arithmetic mode and every `measured` value a spread. That is X1.

### The notation cannot hold a list — **five dependents**

`087` names this as the largest single improvement available to the instruments.
Five constraints count where they should name, and each could pass while comparing
two different sets of the same size:

- `072`'s enumeration of where two faces interact, against `039`'s
- `077`'s count of exactly-specified operations, against `043`'s
- `080`'s performance counters, against `049`'s
- `085`'s rungs against their pass criteria
- `087`'s own seam register

`C-087-5` holds the ceiling at five rather than fixing it.

### Two pieces of software are assumed and not specified

**`058`'s packer** — something outside this machine that quantises a trained
model, fits the expansion tables, computes the rotations and writes the media
layout. **`085`'s reference implementation** — what rung nine compares a token
against, bit for bit.

`085` needs both on day one and neither is described anywhere.

### T2. How many channels can block?

A hundred and seventy-three channels per face at a hundred and fifty microns, in a
loop with a pump and a radiator. One particle stops one channel and its neighbours
take the load. Nobody has run the case, and `027`'s filtration specification is a
requirement written in the imperative mood rather than one derived from a blockage
model. Fouling is not modelled at all.

### The flow network is not solved

`024`'s worst-served fraction is one of two remaining `target` symbols and the
checker reports it on every run. Twenty branches across eight nodes wants a linear
solve the notation cannot express. Until then `025`'s junction temperature rests
on an estimate — and `023`'s rail-to-face assignment is not enumerated either, so
there is no network to solve even if there were a solver.

### P1. Five volts or twelve as the intermediate?

Twelve quarters the current in the interposer planes and makes the second
conversion ratio harder. It changes `014`'s stack, which changes `012`'s face
thickness, which changes the cube. **It should not stay open long.**

### F2. Should a face hold three layers rather than two?

A third buffer would let the prefetch run further ahead and absorb contention. It
costs a layer's worth of slice, which does not fit on this die, and the larger die
has not been costed. **The number that would decide it does not exist**: `060`'s
stall probability, `047`'s bank conflict probability and `038`'s interleaving are
three guesses stacked, and `049`'s counters are the only thing that will settle
them.

### F3. Where does the sampler run?

`043` puts it on face five's scalar core. It could live in the cage, which would
let a sequence be routed to whichever face is free. Nobody has argued it either
way.

### O2. Should the output projection live on face five at all?

It is the largest single matrix in the model, read once per token, and all but one
row of its output is discarded. A face computing only the rows the sampler will
want would read a fraction of it — and whether the sampler can name them in
advance is unknown. The answer moves face five's residency by more than a
gigabyte and would change `075`'s cut.

### The memory mode's bandwidth is not budgeted

`055` budgets the spout at one pane a millisecond. `069b` has a host taking a
hundred thousand a second. **Neither blueprint has reconciled with the other**, and
`C-055-5` would be the first thing to notice.

### Attention's own arithmetic is not counted

`076` counts weight reads and cache reads. The attention operation itself scales
with context rather than with parameter count, so at long context `080`
understates the arithmetic side and `079`'s crossover is optimistic.

### Six of nine failure mechanisms have no number

`086` names, allocates and does not compute: electromigration, seal compression
set, dielectric breakdown, fouling, pump wear. **Bond fatigue is the largest gap**
— `018` counts three thermal swings and turns none into cycles to failure.

### A hundred and ten orphan symbols

Declared and referenced by nothing. Some are material properties nothing needed;
some are quantities a blueprint published for a reader rather than for a
derivation. Each is either a hole where a constraint should be or a line that
should be deleted, and nobody has been through them.

### Smaller, and worth recording

**Two mappings are rules rather than permutations** (`063`, `068`): bit to pad and
bit to conductor, both stated as requirements, and `069`'s receiver needs them.
**No serial standard is named** for either the storage line or the cabled spout.
**Stitching is named and not designed** (`081`), and its yield cost is not charged
for. **`087`'s seam count is a hand count** of the thing it most wants to derive.
**The ownership table is missing from `090`** — which blueprint a question goes to.
**The site's interactive half is not built** (`099`): a slider on the eleven given
lengths, re-resolving in the browser.

---

## Answered

A question moves here with the answer, the date, and what changed because of it.
They are kept rather than deleted so that the next person to have the same idea
finds out it was considered and which way it went.

### B1. Does this machine ever train? — *2026-08-26*

**Whatever the hardware naturally supports** — and working out what that is
overturned an assumption the project had been carrying. `701` had said training
was foreclosed by the topology. It is not: cutting a model into six runs of layers
is pipeline parallelism, and a backward pass moves gradients stage to stage, the
same handoff in the other direction. The all-reduce belongs to data parallelism
across replicas and tensor parallelism inside a layer, and this machine does
neither.

**What limits it is memory, and it is a cliff.** Training every parameter needs
about twelve bytes each — out of reach by a factor of fifteen, which `076a` asserts
in the failing direction on purpose. **Low-rank adapter training fits
comfortably.**

Changed: `701` corrected; `076a` written; `045` acquired a transposed-multiply
requirement, resolved by streaming differently; `038` acquired reverse staging
buffers.

### B3. One cube, or cubes that gang? — *2026-08-26*

**Neither, with a translation unit in between.** The far end of the spout is a
companion part fluent in panes on one side and whatever the receiver speaks on the
other. The cube is built once and adapters many times, which is the right way
round because host interfaces change every few years and a cube does not.

The suggestion that came with it was better than the question: **treat the cube as
memory an ordinary computer reads from** (`069b`). The design already had the three
properties that makes plausible.

It also reframed the spout: **not a fast output but a zero-cost one.** `C-069a-2`
puts the cube's occupancy at under a thousandth of a whole handover.

### T1. Is the hot spot fifteen kelvin? — *2026-08-26*

**About ten**, once `041` produced a floorplan and `025` derived it. Still the
largest term in the chain by a factor of five, and still resting on an array
layout `045` has not detailed.

**The mechanism is not what the name suggests.** Heat does not travel sideways to
reach cooling; the cold plate covers the whole die back. Only the channels *above
the array* are available to it — a tenth of the wetted area carrying seventy per
cent of the heat.

And **lateral spreading does not work at all**: moving one tile's share two
millimetres through a hundred micron die costs over a hundred kelvin. `C-041-5`
records that in the failing direction because it is a reasonable expectation
somebody will have again.

### T3, T4, M1, M2, M3, M5, P2, S1, R1, K1, K2 — *2026-08-26*

Answered in the phases that owned them and recorded in their progress files.
Briefly: fin efficiency is derived at about seven tenths for silicon; the core was
missing from the flow network and is in it; correction is per line at two hundred
and fifty-six data bits, which took the overhead from twelve and a half per cent
to under four; the pane excludes writes rather than tearing, at a cost of parts
per hundred thousand; areal density is built from a bit cell upward and comes out
near two megabytes per square millimetre; deep tiers are reached by seven micron
copper through-stack vias, three and five having been too slow; a brownout holds
the array rail up on stored charge so the model survives; a sequence ending
mid-pipeline lets its bubble propagate; the layer cut balances bytes rather than
counts; and both yield questions have numbers now.

### F1. Sixteen-bit group scale, or eight? — *2026-08-26, provisionally*

`077` measures an eight-bit scale at under five per cent more error for three per
cent less read on the traffic that dominates everything. **If the figures hold the
scale should shrink** — and they are `measured` entries with no source, so this is
an answer that needs checking rather than one that is settled.

### O1. What is on the other end of the spout? — *2026-08-26*

`069a`. Closed by B3.
