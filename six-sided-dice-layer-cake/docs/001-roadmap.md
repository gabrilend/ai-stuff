# 001 — Roadmap

## What is being delivered

**A blueprint set that a materials engineer can build from.** Not a simulation,
not a prototype, not a paper. A directory of blueprints in which every dimension
is either given or derived from something given, every derivation is written in a
form a program can evaluate, and every constraint the design must satisfy is
written next to the thing it constrains.

The test of the deliverable is `104`: it loads all ninety blueprints, resolves
every symbol, evaluates every constraint, and prints which ones hold. A blueprint
set that does not check is not finished, and a blueprint set that checks may still
be wrong — but it is at least wrong consistently, in one place, where an engineer
can find it.

## How the work is cut

Fourteen phases, **one per component of the machine**. They are not a schedule.
Nothing here is time-gated, and the last blueprint written will very likely be an
early-phase one, because the early phases hold the numbers everything else leans
on and those numbers move as the later phases discover what they need.

Lower numbers are more foundational in the sense that more things depend on them.
Phase 1 is the frame of reference; if it moves, everything moves. Phase 13 is the
capstone and depends on all twelve before it. Phase 14 is numbered last and built
first, for the same reason a workshop gets its lathe before its furniture.

| Phase | Name | What it settles |
|---|---|---|
| 1 | **Datum** | the coordinate frame, the materials, the master dimensions |
| 2 | **The Body** | the cube as a mechanical object: envelope, stack, corners, seals |
| 3 | **The Corners** | where the heat goes, and the plumbing that takes it |
| 4 | **The Rails** | where the current comes from, and how it reaches the middle |
| 5 | **The Yolk** | the block of shared memory at the centre |
| 6 | **The Faces** | one compute face, six times |
| 7 | **The Sieve** | the six radial links, and the pipeline that runs on them |
| 8 | **The Feed** | the outward port field, and the storage lines that populate it |
| 9 | **The Spout** | the face that became a tube of wire |
| 10 | **The Metronome** | clock, reset, and getting six faces to agree on when |
| 11 | **The Recipe** | how a language model is cut up and poured through |
| 12 | **The Kiln** | making it, bonding it, testing it, waking it up |
| 13 | **The Whole Cake** | integration, bill of materials, the specification sheet |
| 14 | **The Instruments** | the programs that read blueprints and check them |

## The phases, one at a time

### Phase 1 — Datum

Three blueprints and everything else stands on them.

`010` fixes the coordinate frame: which way is up in a shape with no up, what the
six faces are called, which corner is the origin, and the sign conventions for
flow and current. Every later drawing is read in this frame or it is read wrong.

`011` is the material property table — conductivity, expansion coefficient,
density, modulus, permittivity — for the eleven materials the machine is made of.
It is one file because a project with copper's conductivity written down in four
places has three chances to be out of date.

`012` is the master dimension set: the small number of lengths that are *chosen*
rather than derived. There are eleven of them. Every other length in the machine
is an expression over these, which means the cube can be resized by editing one
file and rerunning the checker, and it means the checker can tell you which
constraint breaks first when you do.

### Phase 2 — The Body

The cube as a thing with mass that has to survive being made, bolted down, heated
to a hundred degrees and cooled again a hundred thousand times.

`013` draws the envelope and the tolerance stack. `014` is the layer-by-layer
material stack of one face assembly, from the outward connector surface through
the interposer and the dies to the cold plate. `015` is a corner manifold block —
the part that turns three edge rails into one port. `016` is an edge rail. `017`
is how two face assemblies meet along an edge and stay sealed against coolant at
pressure. `018` is the stress analysis: what the mismatch between silicon and
copper does over temperature, and how much warpage the bonds can take before they
open. `019` is how the finished cube attaches to something else and how it comes
apart for service, which is a real question because a sealed cube with a coolant
loop through it cannot be pulled like a card.

### Phase 3 — The Corners

The largest phase, because this is the part most likely to kill the machine.

`020` is the heat budget: sixteen hundred and fifty watts, itemised. `021` picks
the working fluid and says why. `022` is the microchannel field bonded to the
back of each face — the part that actually removes heat, as opposed to the part
the vision document names. `023` is the corner parity plumbing, which is the
prettiest idea in the project and comes free from the cube's own geometry. `024`
solves the flow network: how much goes down each of the twelve channels and what
the pump has to supply. `025` is the thermal resistance chain from a transistor
junction to the outside of the radiator, resistance by resistance. `026` is what
happens on a load step, when sixteen hundred watts appear in a microsecond and
the coolant has not heard about it yet. `027` is everything outside the cube:
pump, radiator, reservoir, filters, sensors, and the interlock that shuts the
machine down before it cooks.

### Phase 4 — The Rails

`028` is the power budget and `029` the voltage domains: how many there are, what
each supplies, and which ones can be collapsed. `030` is the delivery network. Its
central decision is that **no current passes through a corner or an edge** —
every face brings in its own power through its own outward port field and sends
one sixth of the core's share inward through the same interface the data uses. The
corners stay purely hydraulic, which is what lets phase 3 treat them as a clean
fluid problem. `031` is decoupling and the impedance target the network has to
hold across frequency, and it is a floorplan constraint rather than a component
list: a matrix engine can demand seventy-six amperes in a nanosecond.
`032` is current density and electromigration, which sets the minimum width of
every conductor in the machine. `033` is the sequencing: what powers up in what
order, and what happens on a brownout.

### Phase 5 — The Yolk

The block of shared memory at the centre. `034` is its organisation and capacity.
`035` is the bitcell and the memory macro built from it. `036` is one tier and how
thirty-two of them stack with cooling laminae between. `037` is the arbitration
that lets six faces reach the same store without fighting. `038` is the address
map — what lives where, including the two regions with special meaning: the sieve
staging buffers and the pane the spout reads. `039` is the ordering model, which
is the contract the six faces rely on and the one thing here that is a *rule*
rather than a mechanism. `040` is error correction and row repair.

### Phase 6 — The Faces

One compute face, six times. `041` is the floorplan. `042` is why a face is four
dies rather than one, which is a reticle limit and not a choice. `043` is the
instruction set — deliberately small, because there is no operating system to
support and no compiler worth the name. `044` is the scalar core that runs it.
`045` is the matrix engine, which is where nearly all the transistors and nearly
all the heat are. `046` is the numeric formats. `047` is the face-local cache
slice. `048` is the sequencer that walks a layer without the scalar core touching
every step. `049` is the control and status registers, which is how anything
outside finds out what a face is doing.

### Phase 7 — The Sieve

`050` is the topology: six radial links, face to centre, no face-to-face wire
anywhere. `051` is the physical layer — through-silicon vias, signalling, what a
link costs in area and picojoules per bit. `052` is the protocol. `053` is the
sieve schedule itself, the six-stage pipeline the whole machine exists to run.
`054` proves it cannot deadlock, which matters because there is no operating
system to notice if it does. `055` is the bandwidth arithmetic that says the
links keep up with the matrix engines, and it is the calculation the machine's
whole performance claim rests on.

### Phase 8 — The Feed

`056` is the port field: the outward surface every face has, identical on all six,
which can be populated as a storage line, an output tube or a host link. Getting
this right is what makes the machine one part built six times rather than two
parts. `057` is the storage line's physical layer. `058` is how a model is laid
out on the media so a face can stream its own slice without reading anyone
else's. `059` is residency — what stays in the core, what stays in a face slice,
what streams. `060` is prefetch and double buffering. `061` is the arithmetic
that says a face never starves, and where it does.

### Phase 9 — The Spout

`062` states the idea and what it costs. `063` is the pad array — the physical
geometry of sixteen million conductors on a fifty-two millimetre square. `064` is
the circuit at each end of one wire, which has to be small enough to fit sixteen
million times. `065` is skew: how conductors of different lengths are made to
arrive together, which is the hard part. `066` is the bonded grade, where the
spout is permanent. `067` is the cabled grade, where it is not, and costs a factor
of four hundred in width to become detachable. `068` is byte mode, the vision's
own retreat, and the one that is most likely to be built. `069` is how the
receiving end knows the pane arrived intact.

### Phase 10 — The Metronome

`070` generates the clock, `071` distributes it through a three-dimensional
object where the longest path is not in a plane, `072` gets six faces to agree
what cycle it is, `073` brings the machine up from cold and gets it into a state
where the first instruction is meaningful, and `074` is the timing budget that
says the whole thing closes.

### Phase 11 — The Recipe

The software-shaped phase, and it is still hardware: these blueprints constrain
what the silicon must support, not what a program should do.

`075` assigns layers to faces. `076` follows a token through. `077` is numerics
and how much accuracy the chosen formats cost. `078` is the capacity arithmetic —
what fits, and exactly where the cliff is. `079` is batching and occupancy, which
is where the factor of six lives. `080` is the end-to-end performance model, and
it produces the two numbers the machine is judged on.

### Phase 12 — The Kiln

`081` picks the process nodes — there are three, because memory tiers, compute
dies and interposers do not want the same one. `082` is the assembly order, which
is nearly forced: once a face is bonded to the core, nothing inside can be
touched again. `083` is known-good-die, which is the yield problem, and stacking
thirty-two tiers makes it the dominant cost. `084` is test access — how you reach
a die that is sealed inside a cube. `085` is bring-up, the procedure someone
follows with a new cube on a bench. `086` is reliability and lifetime.

### Phase 13 — The Whole Cake

The capstone. `087` integrates: every interface between phases, checked in one
place. `088` is the bill of materials. `089` is the specification sheet — the one
page someone reads before deciding whether they want one. `090` is the handoff
package: what a materials engineer actually receives, in what order they should
read it, and the list of things this design does not tell them and they will have
to determine themselves.

### Phase 14 — The Instruments

Numbered last, built first, and none of it ships. These are the programs that
make the rest of the project checkable rather than merely written.

`100` is a units engine — quantities carry dimension vectors and arithmetic
refuses to add a length to a temperature. `101` parses and evaluates the
derivation expressions. `102` reads a blueprint and extracts its declared symbols
and constraints. `103` is the ledger: it loads every blueprint, sorts the symbols
into dependency order, detects cycles, and resolves the lot. `104` evaluates every
constraint and reports. `105` writes the companion page for each blueprint from
the blueprint's own declarations, so those pages cannot drift. `106` produces the
specification report. `107` checks the diagrams — that every part named in a
drawing is a symbol that exists. `108` builds the documentation site.

## Issue names

`{phase}{id}-{description}`, with the id always two digits, read from the right.
So `304` is the fourth issue of phase 3 and `1106` is the sixth issue of phase 11.
A trailing letter marks a sub-issue of the ticket it shares a number with.

There is one issue per blueprint. Where a blueprint is large enough that its
issue would describe two separable pieces of functionality, a second issue points
at the same blueprint rather than the blueprint being split, because a dimension
belongs in exactly one file regardless of how many tickets talk about it.

## The order things will actually be built

Phase 14 first, or nothing can be checked. Then phase 1, because every other
blueprint imports from it. Then phase 3 — the thermal work — ahead of phases 2, 4
and 5, because the heat budget sets the die area, the die area sets the envelope,
and the envelope sets the body. Designing the body first and discovering the
thermals afterward is the standard way to build a machine twice.

After that the order matters much less, and the dependency lines in each ticket
are more reliable than this paragraph.
