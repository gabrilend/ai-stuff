# 009 — Open questions

Every question this design has raised, in one place. A question leaves the open
sections only by being answered, and the answer is written here beside it rather
than only in the blueprint that acted on it, so the reasoning stays findable.

**Nothing in this project is finished while this page has entries in its first two
sections.** Every blueprint checks and every constraint holds; that is
consistency, not completeness. `./run-checks` prints the counts, and this page
does not, because a count written into prose is a count that goes stale.

As of the network solve there are **no `target` symbols left** — no place where
the design states a goal it cannot produce. That is a different and weaker claim
than being finished, and the sections below are why.

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

### Should the coolant circulate, or slosh? — **would halve the plumbing**

Every rail in `016` carries two channels, a supply and a return, side by side.
That is what a loop needs: fluid leaves the pump, crosses the machine, and comes
back by a different path. Twenty-four channels for twelve edges, and the pair of
them is what sets a rail's four-millimetre section, which in turn is a real part
of the cube's edge.

**A reciprocating loop needs one channel, not two.** Drive the fluid one way for
half a cycle and the other way for the other half. The column never completes a
circuit; it moves back and forth. While one end of it is outside the machine
losing heat to a radiator, the other end is inside picking heat up, and then the
stroke reverses and they trade jobs. Two small pumps, one at each end, and no
return path anywhere.

**What it would buy.** One channel per rail instead of two. `016` sizes the rail
around two stacked channels plus the web between them and the wall around them;
removing one of them is the largest single reduction available to the cube's
edge, and the edge is the dimension every other dimension in the project hangs
from.

**What it would cost.** The junction temperature stops being flat. In the loop, a
face sees fluid at a steady inlet temperature; in a reciprocating column it sees
fluid that has just come from the radiator at the start of a stroke and fluid
that has been absorbing heat all the way across by the end of one. The
temperature ripples at the stroke frequency — a heartbeat rather than a level —
and the amplitude of that ripple comes straight out of the stroke period against
the thermal time constant in `026`. That constant is about three milliseconds for
a die's multiplier region, so a stroke fast enough to keep the ripple small is a
stroke measured in milliseconds, which is a lot of reversals over the ten years
`086` is claiming.

**What nobody has computed.** The ripple amplitude, and therefore whether the
fifty-nine kelvin of margin absorbs it. The pumping power of accelerating and
stopping a fluid column twice per stroke against the steady loss of a circuit.
Whether valves are needed at all or whether the two pumps suffice. And the
fatigue consequence of cycling every bond in the machine at the stroke frequency,
which is the question `018` would have to answer and which is likely the one that
decides it.

This is a whole-design alternative rather than a tweak, and it arrived from
outside the project. It is recorded here rather than acted on, because acting on
it means re-deriving the rail, the corner block, the cube edge and the thermal
transient, and the case for doing that starts with the ripple amplitude — which
is an afternoon's work with `102` already holding the network.

### T2. How many channels can block?

A hundred and seventy-three channels per face at a hundred and fifty microns, in a
loop with a pump and a radiator. One particle stops one channel and its neighbours
take the load. Nobody has run the case, and `027`'s filtration specification is a
requirement written in the imperative mood rather than one derived from a blockage
model. Fouling is not modelled at all.

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

### A hundred-odd orphan symbols — **a first pass done, most of it left**

Declared and referenced by nothing. Each is either a hole where a constraint
should be or a line that should be deleted. `./run-checks` lists them and the
count moves as constraints are added, which is why it is not written here.

The material properties were the largest single cluster and have been through,
and the pass was worth more than tidying — **four of the twelve were genuine holes
rather than spare parts.**

The copper-molybdenum the core's cooling plates are made of had never had its
conductivity read by anything: a material chosen for how well it conducts, in a
design that had only ever counted the water film and not the metal between the
memory and the water. That term exists now, and it turns out the lamina is twenty
times the silicon's resistance because it is thirty times thicker — the opposite
of what choosing the material suggests, and still a fiftieth of a kelvin, so the
film governs by a factor of twelve.

The glass interposer's poor conductivity was described as not mattering "because
heat leaves the other way", and that sentence now has a hundred and fifty under
it. The steel's conductivity was unused, and the design's assumption that every
watt reaches the coolant is now measured rather than assumed — the four mounting
bolts carry about a two-thousandth. Tungsten's resistivity was unused, and the
argument for making the through-stack vias copper instead is now a requirement
that would fail if a process change ever made tungsten fast enough.

Copper's density and heat capacity were unused, and are now read by a thermal
diffusivity — the same trick the Prandtl checks in `011` use, where a fourth
well-known quantity relating three transcribed numbers catches a transcription
error in any of them. Two of the three solids now carry one.

**What that suggests about the rest.** A third of the first cluster hid a missing
term, and there is no reason to expect the other clusters to be cleaner. The
remaining orphans are worth walking rather than deleting.

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

### The instruments had no companion pages — *2026-08-27*

**Closed, and the sweep found the interface was forty per cent undocumented.**

Every source file here is supposed to have a page beside it saying what it
offers. `096` generates one for each of the eighty-four blueprints; nothing did it
for the programs, and the two hand-written ones were worse than none, because they
established a format nine files silently did not follow.

`104` generates them now, and what makes that possible is a convention adopted for
an unrelated reason. Lua does not state what a module exports, and finding out
normally means running the file or parsing the language. But every function in
this project is wrapped in a vimfold that opens with a comment carrying its name,
followed by prose, followed by the definition — a name, a description and a
signature, in a fixed shape, on consecutive lines. **The fold convention was
adopted so a long file collapses neatly in an editor, and it turns out to be a
machine-readable interface declaration.** Every page says so at the bottom.

Because the method depends on the convention, the generator also enforces it: a
fold with no definition under it, a fold whose name disagrees with the definition
it opens, and a public name with nothing said about it anywhere are each reported.

**Of fifty-six public entry points, twenty-three had no description at all** —
including `094`'s `load`, which is the ledger's entire interface and the thing
every other program calls. All fifty-six have one now, and the count is zero on
every run.

Two of the generator's own findings were the generator being wrong rather than the
source being thin, and both are worth recording because a documentation tool that
cries wolf gets ignored. Most modules define a function privately and assign it to
the module table at the bottom, so the first version reported nine of `102`'s
twelve exports as undocumented when their descriptions were sitting on the private
names. And a public constant has no fold at all, so its description is whatever
comment sits directly above it. Both are followed now.

### The flow network — *2026-08-26*

**Solved, and it changed a design decision.**

The question was how evenly the coolant divides between six faces, and the
blocker was that nobody had said which of the twelve edge rails feeds which face.
Both wanted the same missing thing — a program holding the cube as data rather
than as prose — and `102` is it.

*The network is two and a half times the size the ticket estimated.* Twenty
branches across eight nodes was the guess, and it was the cube's own edges and
corners rather than its plumbing: fifty branches across twenty-nine nodes, because
supply and return are separate networks sharing a geometry, every rail carrying a
plenum is two rails with a tap between them, and the corner blocks are branches.

*Sixteen of the sixty-four legal rail assignments distribute the coolant exactly
evenly and the other forty-eight leave one face five or six per cent short.* The
sixteen have a threefold rotation about a body diagonal — one fed corner with all
three of its channels tapped — which is the symmetry that makes all six faces the
same face. **Nothing in `023`'s argument predicted this**, because that argument is
about the supply network reaching everywhere and this is about where the plenums
hang on it.

*The thermal chain was moved onto the worst legal wiring rather than the best.*
Building the junction temperature on a perfect distribution would make the whole
thermal budget depend on the plumbing being assembled to the drawing rather than
merely to the rules. `025` is given the five and a half per cent shortfall of the
least even legal arrangement. This is the substantive design change, and it makes
the design more conservative.

*The hand-summed loop overstates the circuit by a quarter*, because it charges one
path for two whole rails where the real manifold delivers to each plenum from both
ends at once. The estimate was the conservative one, which is the right way round.

### The last target — *2026-08-26*

**Closed.** `019`'s cube-swap time was the final `target` in the project: a number
the design stated as a goal and could not produce, waiting on a service procedure
that had never been written.

The procedure is written. Nine steps — stop the machine, hold with the pump
running until it is cool, shut the valves, part sixteen couplings, undo four
bolts, lift out and in, seat against three rigid mounts and one compliant, do the
bolts up, make the couplings, fill and purge — each a number somebody can argue
with on its own. A service event comes to a little over three hours, and two of
those are `085` testing the replacement rather than anybody touching it.

One of the nine is not a guess. The cooling hold falls out of the machine's own
heat capacity and its own thermal resistance, and it is **seventeen seconds**: a
cube holds ten kilojoules above ambient while its coolant carries away nearly two
thousand watts. It is cool enough to handle before the isolation valves are shut.

The step times are all `given`, which is the honest label — nobody has done this
with a stopwatch. What changed is that the claim is a sum of nine things rather
than one number nobody could take apart.

### The notation had nowhere to put a computed answer — *2026-08-26*

**Answered with a fifth kind.** `given` is a decision, `measured` is the world,
`derived` is an expression, `target` is a goal. A solver's output is none of them,
and writing it as a decision would invite a reader to change it by preference and
let it go stale in silence the first time an input moved.

`solved` is a bare number whose declaration names the program that produced it,
and **the checker re-runs that program on every pass and fails the run if the copy
has drifted by more than a part in a thousand.** It reports in both directions: a
declaration naming a program that will not answer for it, and a program answering
for a symbol nobody declared.

It found a defect immediately. `087` and `090` carried the size of the blueprint
set as hand-typed numbers, and every one was wrong — eighty blueprints offered
where there were eighty-four, five hundred and eight requirements where there were
five hundred and forty-four. The documents were describing an earlier version of
themselves. `103` counts now.

This does **not** fix the notation's inability to hold a list, which is still open
above. A program answering with one number is not the same as the notation holding
a set — and `102` is the demonstration of what that costs: to check that twelve
edges cross a parity, a whole program had to be written and its answer copied back
in as a scalar.

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
