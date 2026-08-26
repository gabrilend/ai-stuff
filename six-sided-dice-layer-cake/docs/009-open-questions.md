# 009 — Open questions

Every question this design has raised and not settled, in one place. A question
leaves this document only by being answered, and the answer is written here beside
it rather than only in the blueprint that acts on it, so that the reasoning stays
findable.

**Nothing in this project is finished while this page has entries in its first
two sections.** A phase whose blueprints all check but whose questions are still
open is in progress, not done.

---

## Blocking — these change work that has already been done

### B1. Is this machine for inference only?

Everything specified assumes generation: weights are read and never written, there
are no gradients, no optimiser state, and no all-reduce between faces. Training a
seventy billion parameter model needs roughly three times the memory for optimiser
state and a completely different traffic pattern between the faces — face-to-face
rather than face-to-core, which the topology in `050` explicitly refuses to
provide.

If training is wanted, `050` is wrong, the core capacity in `034` is wrong, and
the sieve schedule in `053` is wrong. If it is not, nothing here changes and the
question closes.

**Assumed for now:** inference only. Stated wherever it matters.

### B2. Water, or a dielectric?

`021` currently selects water because it moves heat better than anything else that
is liquid at these temperatures — about four times the heat capacity of a
fluorocarbon and six times the conductivity. The microchannel field is a
hundred and fifty microns from live silicon.

A leak with water is a short circuit and a dead cube. A leak with a dielectric is a
mess. The fluorocarbon costs roughly a factor of four in thermal performance,
which the design currently has the margin to absorb — junction temperature would
go from about forty-five degrees to about sixty, still well inside limits.

This is a reliability judgement rather than a thermal one, and it is not the
thermal engineer's to make.

**Assumed for now:** water, with the margin noted, and `021` written so the fluid
is a parameter rather than an assumption.

### B3. One cube, or cubes that gang?

The output tube's most natural use is another cube. If cubes are meant to be
joined — two of them sharing a bonded spout, or eight of them in a ring — then
`069` needs an addressing scheme, `039` needs a memory model that spans cubes, and
`080` needs a scaling curve. None of that is written.

If a cube is always a single machine with a host attached, the spout is an output
device and `067`'s cabled grade is the important one.

**Assumed for now:** a single cube with a host. The bonded grade is specified but
treated as a future.

### B4. Is the reference model the right one?

Every capacity, bandwidth and timing number in this project is anchored to one
model: seventy billion parameters, eighty layers, hidden width eight thousand one
hundred and ninety-two, four-bit weights, thirty-five gigabytes. It sets the core
size, which sets the cavity, which sets the cube. It sets the layer size, which
sets the face slice, which sets the die, which also sets the cube.

`012` holds it as eleven given numbers so it can be changed, and `104` will report
what breaks. But the *shape* of the answer — six faces, a solid core, a slice per
face — was chosen with this model in mind.

**Assumed for now:** as stated. `078` carries the sensitivity.

---

## Open — these are being carried

### Phase 3, the corners

**T1. Is the hot spot term fifteen kelvin?** It is the largest number in the whole
thermal chain and it is the only one carried as a `target` rather than a
derivation, because it depends on a matrix engine floorplan `045` has not
finished. If it turns out to be forty, the sixty kelvin of margin is gone and the
clock comes down. Highest-value open question in the project.

**T2. How many channels can block before the die above them cooks?** A hundred and
seventy-three channels per face at a hundred and fifty microns, in a loop with a
pump and a radiator. One particle stops one channel and its neighbours take the
load. Nobody has run the case. The filtration specification in `027` is currently
a guess written in the imperative mood.

**T3. What is the actual fin efficiency?** `022` derives about seventy-four per
cent for a one millimetre silicon fin. It multiplies the whole convection term and
it is the entire price of choosing silicon over copper in `202`, so it deserves a
better treatment than a one-dimensional fin formula.

**T4. The core is not in the flow network.** `024` solves six face fields, twelve
rails and eight corner blocks. The core's thirty-two cooling laminae need a
hundred and ninety watts of flow through the cage and they appear in no branch of
that network. A known omission rather than an open question, recorded here so it is
not discovered by somebody adding up the flows.

### Phase 4, the rails

**P1. Five volts, or twelve, as the intermediate?** Twelve halves the current in
the interposer planes and makes the second conversion stage harder. The answer
changes plane thickness in `014`, which changes face thickness, which changes the
cube.

**P2. What happens on a brownout?** `033` sequences power up and says nothing
about losing it mid-token. A machine that loses sixty-four gibibytes of resident
model on a flicker reloads in thirty milliseconds, which is fine. A machine that
loses it *silently and half way* is not, and nothing currently detects that.

### Phase 5, the core

**M1. Should the core be error-corrected per word or per line?** `040` currently
specifies per line, which is cheaper in check bits and worse in latency for the
small reads the sequencer makes. The trade has not been priced.

**M2. Can the pane move while the core is being written?** As specified, aliasing
the pane and generating tokens are mutually exclusive for as long as the read
takes — fifty-four nanoseconds per pane, one and three quarter milliseconds for
the whole core, long enough to stall a token. Whether a coherent snapshot is
required, or whether the spout may read a torn view, is an ordering question `039`
has not answered. `506` recommends exclusion and should close this.

**M3. Is one and a half megabytes per square millimetre real?** The core's whole
capacity rests on it and it is **the most optimistic number in the project**. It is
defensible only for a dedicated array tier carrying bit cells and local decode and
nothing else, with sense amplifiers, redundancy, correction and interface all on a
separate logic lamina beneath. A conventional cache achieves a third of it. If the
true figure is one megabyte per square millimetre, usable capacity falls from
sixty-four gibibytes to forty-one, the reference model no longer fits, and the
machine's central claim goes with it. `502` must derive rather than quote it.

**M4. Where does the runtime repair map live?** `507` wants to retire a line that
fails repeatedly and remap its address. The map has to survive power loss and
nothing in the design provides non-volatile storage anywhere inside the cube. The
options are a small fuse array per tier, a region on the storage lines rewritten at
shutdown, or abandoning runtime repair and relying on test-time spares alone. This
is a real gap rather than an unmade decision.

**M5. How do the two end faces reach the deep tiers?** Four faces look at the
stack's sides where every tier's edge is exposed. Two look at its ends, where only
the outermost tier is. Either a through-stack via forty millimetres long — which at
one point two gigahertz is a transmission line, not a via — or a redistribution
route around the outside of the stack. The two cost very differently in area and
power, and whichever is chosen, `504` must still be able to give any face the whole
bandwidth, so an answer that privileges the four side faces is not an answer.

### Phase 6, the faces

**F1. Should the group scale be sixteen bits or eight?** A hundred and twenty-eight
weights share one scale. Sixteen bits costs an eighth of a bit per weight on the
read that dominates everything. Whether eight would cost measurable accuracy is a
`077` question nobody has run.

**F2. Should a face hold three layers rather than two?** A third buffered layer
would let the core read run further ahead and smooth contention between faces. It
costs four hundred and thirty-seven megabytes of slice, which does not fit on the
current die.

**F3. Where does the sampler run?** `043` puts it on face five's scalar core. It
could equally be in the cage, which would let a sequence be routed to whichever
face is free. Nobody has argued it either way.

### Phase 7, the sieve

**S1. What happens to a sequence that ends mid-pipeline?** Six microbatches in
flight, one of them just produced an end marker. `053` lets the bubble propagate
and wastes a sixth of a step. Whether a face may pull work forward to fill it
interacts with `039` in a way nobody has traced.

### Phase 9, the spout

**O1. What is on the other end?** Everything in phase 9 specifies a transmitter.
The only receiver assumed is another cube — see B3. If the far end is a host, the
thing that turns two mebibytes in a nanosecond into something a host bus can
absorb is not designed. **This is the largest unspecified block in the project.**

**O2. Should the last projection live on face five at all?** It is the single
largest matrix in the model, read once per token, and all but one row of its
output is discarded. A face that could compute only the rows it needs would read a
fraction of it. Whether the sampler can name those rows in advance is unknown, and
the answer moves face five's residency budget by more than a gigabyte.

### Phase 11, the recipe

**R1. Does the layer assignment need to be uneven?** `075` gives face zero and
face five thirteen layers each because they also carry the embedding table and the
output projection. Whether that balances the *time* rather than the *layer count*
has not been checked against `080`.

### Phase 12, the kiln

**K1. What is the yield of a thirty-two tier stack?** `083` is the whole issue and
it has no number in it yet. If a tier yields at ninety-nine per cent, a stack
yields at seventy-three, and the cost of a cube is dominated by the ones that do
not work. Redundant tiers help and are specified; how many are needed is arithmetic
nobody has done.

**K2. How is a die tested after it is sealed inside a cube?** `084` names the
problem. It does not solve it.

### Project-wide

**X1. Should `libs/` hold anything?** The instruments in phase 14 currently have no
dependencies beyond the language. If the constraint evaluator grows an interval
arithmetic mode — which `104` would benefit from, since every `measured` value has
a tolerance nobody is propagating — that is a library.

**X2. Are tolerances being propagated at all?** They are not. Every number in this
project is a point value. A materials engineer will ask what the tolerance on the
cube edge is and the honest answer today is that nobody wrote one down. This
should probably become a phase 1 change to the notation itself.

---

## Answered

*Empty. Nothing has been settled yet — the design is one day old.*

When a question closes, it moves here with the answer, the date, and what changed
because of it. The reason for keeping them rather than deleting them: the next
person to have the same idea should be able to find out it was already considered
and why it went the way it did.
