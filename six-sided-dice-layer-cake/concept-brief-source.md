---
title: "Six-Sided Dice Layer Cake"
subtitle: "A memory-first machine for language model inference --- concept brief"
date: "28 August 2026"
geometry: margin=1in
fontsize: 11pt
linestretch: 1.15
colorlinks: true
---

## In one paragraph

Running a language model is a memory problem wearing a compute problem's clothes.
A modern accelerator has enormous arithmetic and spends most of it waiting for
weights to arrive. The industry's answer has been to stack memory closer to the
processor. This design inverts the arrangement instead: a sixty-millimetre cube
with six processors on its six faces, all looking inward, and at the geometric
centre a solid block of static memory holding every weight of the model. The
weights never move. There is no DRAM, no memory bus, and no off-chip traffic for
weights at all.

## The trade, stated plainly

Against a current accelerator with stacked memory, this design's own model puts
it at **11.4 times the memory bandwidth at 0.51 times the capacity.**

That is the whole proposition. Half the memory, eleven times the speed of reading
it. It is a machine for a model that fits, run very fast --- not a machine for the
largest model that exists.

It is also explicit about its edge. Past its capacity the machine refuses rather
than degrading: it offers a shorter context instead of quietly paging and getting
slow. A hard ceiling is a narrower market and an honest one.

## What it is, physically

A cube sixty millimetres on a side, weighing a little over a kilogram wet.

Six compute faces, one per side, each owning a consecutive run of the model's
layers. A token falls through the six of them in sequence, the way grain falls
through a stack of sieves. There are no face-to-face wires; everything passes
through the centre.

The centre is forty millimetres of solid state: twenty-four tiers of static
memory, laminated with twenty-four copper-molybdenum plates that carry the heat
out sideways. Coolant enters at four corners of the cube and leaves at the other
four, which is not a convenience --- it is the only arrangement in which no supply
channel joins two feed points, and every one of the twelve edge channels carries
flow toward a load.

One of the six faces is not a processor. It is spent entirely on wire: sixteen
million conductors, so that whatever the centre is holding can be somewhere else
in thirty-four microseconds.

The name is the shape rather than a joke. A layer cake is the core --- twenty-four
tiers laminated with twenty-four plates --- and a six-sided die is the six faces.
A cube has three pairs of opposite faces, and a token visits all six in order:
three of its five steps land on the face opposite the one just used, which is the
most a cube permits, since an ordering has to cross between opposite-pairs twice
and a crossing is always to a neighbour.

## Specification

Every figure below is derived from the design's own geometry and physics rather
than measured, and is regenerated from the blueprint set rather than typed.

### Physical

| | |
|---|---|
| edge | 60 mm |
| volume | 216 cm^3 |
| mass, wet | 1.13 kg |

### Power and cooling

| | |
|---|---|
| input | 48 V at 39.4 A |
| dissipation, design point | 1891 W |
| dissipation, idle with a model resident | 248 W |
| coolant | water, 3.52 L/min at 0.46 bar |
| inlet temperature | 298 K |
| junction, hottest point, worst-served face | 319 K |
| margin to the silicon's limit | 59 K |

### Memory and compute

| | |
|---|---|
| usable capacity | 71.9 GB |
| largest model resident | 36.4 GB of weights |
| aggregate read bandwidth | 38.4 TB/s |
| arithmetic, eight-bit | 4404 Tflop/s |
| model load, from storage | 34.1 ms |

### Performance

| | |
|---|---|
| tokens a second, one sequence | 1021 |
| tokens a second, aggregate at the design batch | 19490 |
| prompt tokens a second | 25595 |
| whole core out through the wire face | 34.3 us |

**Note the ratio between the two token rates.** Single-sequence and aggregate are
about twenty apart, and that governs how this machine should be used. Below a
batch of roughly twenty it is latency-bound and the arithmetic idles; above it,
the machine is saturated and every additional sequence is nearly free. It is a
serving machine, not a workstation.

## The hard part, and why it is solved

Nineteen hundred watts inside two hundred and sixteen cubic centimetres is the
problem that decides whether any of this is real.

It is removed by microchannel fields etched into six silicon cold plates, one per
face, fed and drained through the eight corner blocks. The cold plates are silicon
rather than copper so that they expand at the same rate as the dies bonded to
them; the choice buys exactly zero expansion mismatch at that interface.

Two results are worth an investor's attention because they are counter-intuitive
and they de-risk the design.

**Halving the coolant flow does not halve the cooling.** In laminar flow the
convection coefficient does not depend on velocity at all --- only the coolant's
own temperature rise doubles, and that rise is a fifth of the chain. A pump at
half speed costs about four kelvin of junction temperature out of fifty-nine of
margin. Partial pump failure is therefore graceful rather than catastrophic, and
the redundancy design is built on that.

**The coolant divides exactly evenly between the six faces.** Not nearly ---
exactly. Of the sixty-four legal ways to connect twelve coolant rails to six
faces, sixteen have a threefold rotational symmetry about a body diagonal that
makes all six faces equivalent, and the flow through them cannot differ. The other
forty-eight starve one face by five or six per cent. That was found by solving the
fifty-branch hydraulic network for every legal arrangement, and the thermal budget
is nonetheless built on the *worst* legal arrangement, so the design does not
depend on the plumbing being assembled to the drawing rather than merely to the
rules.

## What it costs to run

The figures a buyer optimises are not the ones a user notices. Dividing the
design's own numbers by each other:

| | |
|---|---|
| tokens per second, per watt | 10.3 |
| tokens per second, per litre | 90,231 |
| tokens per second, per kilogram | 17,303 |
| gain from serving many sequences at once | 19 times |

The per-litre figure is the one the geometry earns. A conventional part spends
most of its volume getting memory near the processor; this spends its volume on
being memory near the processor.

The last row is the honest caveat. **Serving a single user, this machine wastes
most of what it is.** It wants load, which makes it infrastructure rather than a
desktop product, and narrows who it is for.

## If the arrangement is better, why does it not exist?

This is the sharpest question available and it has three answers, none of which
is comfortable.

**Static memory costs far more per bit than DRAM.** The trade only pays if you
want bandwidth more than capacity. That is a bet about what inference workloads
look like --- the central bet in this design, and not a fact it rests on. If
capacity turns out to matter more than bandwidth, this is the wrong machine and no
amount of engineering rescues it.

**Nineteen hundred watts in two hundred and sixteen cubic centimetres cannot be
air-cooled.** It needs liquid driven through the structure, so cooling is not a
component bolted on afterwards --- it is the frame, and it constrains every other
decision in the design.

**Nobody has a line for this.** Six faces bonded around a sealed liquid loop, with
a nine-step bonding sequence that has to run in descending temperature order, is a
packaging problem rather than a silicon one. Finding out what such a line would
cost is a large part of what the next step buys.

Those are the barriers and they are the only defensibility identified so far.
**No patent position is claimed.** Difficulty is a weaker moat than a patent and a
real one, and it is worth knowing which of the two is on offer.

## The design as an asset

This is the part that is unusual and is worth understanding before valuing
anything else.

The design is not a document describing a machine. It is written in a notation a
program reads. Every dimension is either a number a person chose --- there are
eleven of those --- or an expression over numbers that were. Alongside them sit
**570 engineering requirements**, each carrying the author's own sentence saying
why it must hold, and a checker evaluates every one of them in about a second.

All 570 currently hold. None of the design's own goals is unresolved: the notation
has a category for a number the design wants and cannot yet produce, and the
checker refuses to call the set finished while one exists.

For diligence, this means an engineer does not have to take the specification on
faith. They can change an assumption and watch what breaks.

### What that has already caught

Every one of these was found by the checker rather than by review, and each would
have been an expensive discovery later:

- a corner manifold block that could not physically contain the chambers drawn
  inside it
- a die power grid four times too thin, found by the voltage droop it implied
- a bonding step hotter than the bond it was standing on, which would have reflowed
  the joint underneath it during assembly
- a memory stack that had to fall from thirty-two tiers to twenty-four once
  somebody derived the bitcell density instead of choosing a round number
- twenty-seven hand-written unit conversions inside derivations, three of which had
  produced visibly wrong answers and one of which was silent because two errors
  cancelled
- a cooling plate material chosen specifically for its thermal conductivity, in a
  design that had never once read that number
- a table of the six faces claiming every step of the pipeline landed on the
  opposite face, which is not a thing a cube permits --- found only when somebody
  drew it, because an ordering is a list and the notation holds numbers

## What is not known

Stated directly, because it is the part that decides what the next spend is.

**Nothing has been fabricated.** Not a die, not a cold plate, not a coupling.
Every figure in this brief is derived from geometry and physics. That is a
stronger position than a slide deck and a weaker one than a prototype.

**There is no price.** The bill of materials gives cost as ratios --- silicon is
77 per cent of it, and memory tiers are two thirds of the silicon --- and
deliberately refuses a currency figure. With no volume, no supplier and no year, a
number would be fiction.

**Yield is the exposed flank.** A memory tier is large enough that only about
sixty-four per cent of them come off a wafer good. The design's own note is that
making the tiers smaller would save more than any assembly improvement, and that
nobody has yet asked whether a tier has to be one piece.

**Two decisions remain open.** Whether the coolant is water or a dielectric: water
cools about ten times better, and a leak with water across a hundred and sixty-six
joints is a dead cube rather than a mess. The substitution costs about eleven
kelvin of the fifty-nine available, so the design survives either --- which makes
it a reliability judgement for whoever owns the failure consequences rather than a
thermal one. And whether the model it is sized around is the right anchor, since
that model sets the core, which sets the cavity, which sets the cube. A model half
the size would let the whole machine shrink, and nobody has run that backwards.

**Sixteen further questions are carried openly**, each naming the part of the
design that owns it and what it would change.

## What it is ready for

An engineering review, not a fabrication run.

The most valuable next expenditure is somebody with process and packaging
experience reading the fabrication and assembly sections and saying which of the
566 requirements they do not believe. The design is built to make that a cheap
conversation: every requirement names its own reason, and changing an assumption
and re-running takes a second.

\vspace{1em}

---

\vspace{0.5em}

*All figures generated from the blueprint set. Regenerate with* `./run-checks`
*for the requirement status and* `luajit src/097-spec-report.lua` *for the
specification. Nothing in this brief is entered by hand except its prose.*
