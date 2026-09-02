# The Material Walk

One pass through the factory, from the gas bottle to a cut sheet. Each station
says what enters, what physically happens inside it, what leaves, and what must
have become true before the material is allowed to move on.

Invariants are numbered so other documents can point at them. The full list
with failure consequences lives in [the invariant ledger](002-the-invariant-ledger.md).

Numbers below are marked either **(nature)** for physical constants that will
never change, or **(setpoint)** for process choices this design has not yet
pinned down. Setpoints get fixed once the three release mechanisms are designed
and their requirements can be compared against each other.

---

## Station 0 — The Gate

**Intake.** Four gases, one solid, one liquid, and power.

| What            | Why it is here                                                   |
|-----------------|------------------------------------------------------------------|
| Methane, CH4    | The carbon. This is the only thing that becomes product.          |
| Hydrogen, H2    | Two jobs, described at Station 2. Both essential, both opposed.   |
| Argon, Ar       | Inert. Fills the tube so nothing else can, and flushes it.        |
| Trace oxygen    | Deliberate, in parts per million. Explained at Station 3.         |
| The copper block| Apparatus, not stock. Arrives once. Never consumed on purpose.    |
| Target substrate| Whatever the graphene is going to live on afterwards.             |
| Cooling water   | Carries away the furnace's heat and the condenser's heat.         |

**What happens.** Nothing chemical. This station is a filter and an assay. Gas
is passed through purifiers and its composition is measured before it is
allowed into the tube.

**Why the purity matters, at the atom.** The growth reaction happens on the
copper's outermost atomic layer and nowhere else. Anything that sticks to that
layer takes a site out of service. Sulfur is the worst offender: a sulfur atom
adsorbs onto copper and holds on hard, and a surface with adsorbed sulfur will
not crack methane. A few parts per million of hydrogen sulfide in the methane
supply can poison a face. Water is nearly as bad, because at 1000 C water
oxidises copper faster than hydrogen can reduce it back.

**Discharge.** Metered gas streams into Station 1. Rejected gas to vent.

**Invariants to pass.**

- **I-01** Sulfur in the methane below the poisoning threshold **(setpoint)**.
- **I-02** Water vapour below the oxidation threshold, expressed as a dew point
  **(setpoint)**.
- **I-03** Oxygen present at a *specified* concentration, not merely at a low
  one. Oxygen is a controlled ingredient here, not a contaminant.

---

## Station 1 — Load and Seal

**Intake.** The copper block, and the gas streams from Station 0.

**What happens.** The block is placed in the reactor and the reactor is closed,
evacuated, and back-filled with argon. This is repeated until the residual
atmosphere is gone.

**Why it cannot be skipped.** Copper oxidises readily, and it oxidises much
faster hot than cold. If the tube still holds air when the ramp starts, the
block grows a layer of cuprous oxide during heat-up, and the anneal at Station
2 then has to spend itself reducing that oxide instead of doing the job it
exists for.

**Discharge.** A sealed reactor holding a block and an inert atmosphere.

**Invariants to pass.**

- **I-04** Leak rate below spec, measured with the pumps valved off and the
  pressure watched **(setpoint)**.
- **I-05** Residual oxygen and water below the Station 0 thresholds, measured
  inside the tube rather than assumed from the supply.

---

## Station 2 — The Anneal

**Intake.** A sealed reactor and a flow of hydrogen diluted in argon.

**What happens.** The block is ramped to just under 1000 C and held. Copper
melts at 1085 C **(nature)**, so the whole process lives in a narrow band below
that, close enough to melting that atoms move freely and far enough that the
block keeps its shape.

Three things happen at once during the hold, and all three are necessary.

**One, the oxide comes off.** Hydrogen strips the native oxide:

    Cu2O + H2  ->  2 Cu + H2O

The water leaves with the gas flow. This is why hydrogen is in the mix from the
beginning rather than being introduced with the methane.

**Two, the grains grow.** Copper at this temperature recrystallises. Small
crystal grains left over from rolling or casting are consumed by their larger
neighbours, because a large grain has less boundary area per unit volume and
grain boundaries cost energy. Grains that started microns across end up
millimetres or centimetres across. This is the same process that makes annealed
copper soft.

**Three, the surface flattens.** Copper atoms on the surface are mobile enough
at this temperature to hop, and they hop preferentially from bumps into dips,
because an atom at a bump has fewer neighbours holding it. Rolling marks and
scratches heal.

**The invariant this station exists to establish.** The face that will grow
graphene must be **Cu(111)**, and it must be one continuous crystal across the
whole face.

**Why (111) and not any other face.** Copper is face-centred cubic. Slice that
crystal along the (111) plane and the exposed atoms sit in a triangular
lattice, each atom 2.556 angstroms from its nearest neighbour **(nature)**.
Graphene is a hexagonal lattice with a lattice constant of 2.46 angstroms
**(nature)**. Those two numbers are about four percent apart, and both lattices
have sixfold symmetry.

The consequence is alignment. A graphene island nucleating anywhere on a (111)
face finds the same low-energy rotational orientation as every other island on
that face, because they are all reading the same underlying template. When two
islands grow into each other they are already lined up, and their edges stitch
together into continuous lattice. The seam disappears.

Slice the same copper along (100) instead and the surface atoms form a square
lattice. A hexagon has no preferred way to sit on a square grid, so islands
nucleate at whatever rotation they happen to land in. When those islands meet
they are misaligned, and the carbon atoms at the join cannot form a clean
hexagonal ring. They form pentagons and heptagons instead — a grain boundary.
Grain boundaries scatter electrons, so a sheet made of misaligned domains
conducts far worse than its area suggests, and it tears preferentially along
those lines.

So the difference between (111) and (100) is not a matter of degree. It decides
whether the product is one crystal or a quilt.

**Discharge.** A hot block with a clean, flat, single-crystal (111) working
face.

**Invariants to pass.**

- **I-06** The working face is Cu(111).
- **I-07** The working face contains no grain boundaries.
- **I-08** Surface roughness below spec **(setpoint)**. Roughness raises
  nucleation density, and Station 3 wants nucleation density as low as it can
  possibly be.

---

## Station 3 — Growth

**Intake.** A hot annealed block, and methane added to the hydrogen and argon
already flowing.

**What happens, step by step at the surface.**

A methane molecule strikes the copper and sticks. The copper's job is to weaken
the carbon-hydrogen bonds so they break one at a time:

    CH4  ->  CH3*  ->  CH2*  ->  CH*  ->  C*    (each * is bound to the surface)

The freed hydrogen atoms pair up and leave as H2. The carbon atom stays.

**Why copper and not a better catalyst.** Nickel cracks methane far more
readily than copper does. Nickel is also useless here, and for one reason:
carbon dissolves in it. At 1000 C nickel takes several atomic percent of carbon
into its bulk, and on cooling that dissolved carbon comes back out and
precipitates at the surface as however many layers it feels like. The result is
uncontrolled and multilayer.

Carbon's solubility in copper is roughly a thousand times smaller — well under
a hundredth of an atomic percent at growth temperature **(nature)**. Carbon
that lands on copper has nowhere to go but sideways. The entire process is
confined to two dimensions by a solubility limit. Copper was chosen for being a
mediocre catalyst that is a superb barrier.

Carbon atoms skate across the surface until they meet others and **nucleate**
an island. Islands grow by capturing more carbon at their edges. Islands expand
until they touch, and merge.

**Where the process stops itself.** Cracking methane requires bare copper.
Once graphene covers the face there is no bare copper left, so the cracking
stops, so growth stops. Nothing times this and nothing measures it. The
catalyst buries itself under its own product and switches itself off. This is
why the sheet is one atom thick — not because the process is controlled well,
but because the second layer has no way to begin.

**The two knobs.**

*Nucleation density.* Every nucleus becomes a domain, and every place two
domains meet is a defect line. So fewer nuclei is strictly better: the ideal is
a single nucleus that grows to cover the entire face. Nucleation density falls
with smoother copper, cleaner copper, lower methane partial pressure, and
higher temperature. It also falls with **trace oxygen**, which is the reason
oxygen appears as a deliberate ingredient back at Station 0. Adsorbed oxygen
occupies the surface's most reactive sites — exactly the sites where a nucleus
would otherwise form — and passivates them. Carbon then has to travel further
before it finds somewhere to nucleate, so fewer nuclei form and each one grows
larger. Oxygen is a poison used as a tool.

*The hydrogen-to-methane ratio.* Hydrogen does not merely reduce oxide. It also
etches graphene, attacking carbon at the edges of an island where atoms have
unsatisfied bonds. So growth is a race: methane deposits carbon and hydrogen
removes it. Set the ratio too high and nothing survives. Set it too low and
amorphous carbon and stacked islands survive alongside the good lattice. Set it
right and hydrogen becomes a purifier — weakly-bound junk is etched away faster
than well-formed lattice, so the film that survives is the film that was built
correctly.

**Discharge.** A block whose working face carries a continuous single layer of
graphene. Spent gas: unreacted methane, hydrogen, and the hydrogen liberated
from cracking.

**Invariants to pass.**

- **I-09** The film is continuous. No bare copper anywhere on the working face.
  A hole in the film becomes a tear the moment the copper leaves.
- **I-10** The film is a single layer. Stacked islands transfer badly and
  behave differently, electrically, from single-layer graphene.
- **I-11** Domain count as near to one as the process allows **(setpoint)**.

**The measurement problem.** None of I-09 through I-11 can be seen through the
wall of a hot furnace. In the laboratory they are checked afterwards by Raman
spectroscopy: the shape and height of the 2D peak reveals how many layers there
are, and the presence of a D peak reveals defects. A factory cannot afford to
find out after the fact. Turning these three into something measurable while
the block is still in the chamber is an open question and is recorded as one.

---

## Station 4 — Cool-down, and Why It Is Dangerous

**Intake.** A hot block wearing a finished sheet.

**What happens, and why this station is a hazard rather than a formality.**

Copper expands when heated and contracts when cooled, at roughly 16.5 parts per
million per kelvin **(nature)**. Graphene does the opposite: over a wide range
its in-plane thermal expansion coefficient is *negative*, around minus 7 parts
per million per kelvin **(nature)**. It grows slightly as it cools.

The sheet was laid down flat on copper at 1000 C. Bring both down to room
temperature and the copper underneath shrinks by about one and a half percent
of its length while the sheet on top does not shrink at all. The sheet is
therefore squeezed into a space smaller than it wants, and since a one-atom
membrane has essentially no resistance to bending, it does the only thing it
can: it buckles.

Those buckles are **wrinkles**, they are permanent, and they scatter electrons
for the rest of the sheet's life.

This is the strongest argument in the whole design for a release mechanism that
works hot. A process that never cools the block never creates this strain in
the first place. It is the reason halide vapour transport is worth taking
seriously despite being the least mature of the three candidates: it is the
only one that could let the sheet leave before the temperature falls.

**Discharge.** A block and a sheet at whatever temperature the chosen release
mechanism needs.

**Invariants to pass.**

- **I-12** Wrinkle density below spec **(setpoint)**, or the strain path
  managed so wrinkles never form.

---

## Station 5 — The Release Slot

**Intake.** A block wearing a sheet.

**What happens.** This is the slot the three candidate machines drop into.
Whichever occupies it, all three must accomplish exactly the same three things:

1. Break the adhesion between graphene and copper. That bond is van der Waals,
   around 0.7 joules per square metre **(nature)** — weak per unit area, but a
   face has a great many square metres of it, so the total is not small.
2. Do it without tearing the sheet.
3. Leave the block in a state Station 9 can restore.

Their designs live in their own documents once written. What matters to this
walk is that the slot's boundary conditions are identical for all three, which
is what makes them comparable at all.

**Discharge.** A sheet no longer bound to the block, and a block missing some
copper or missing none.

**Invariants to pass.**

- **I-13** The sheet is mechanically supported before, during, and after the
  copper stops supporting it. There is no instant at which a free unsupported
  membrane exists.
- **I-14** No copper leaves the machine's boundary. Whatever is removed is
  captured for Station 9.

---

## Station 6 — The Carrier

**Intake.** A sheet being released.

**What happens.** Something has to hold the sheet. Graphene one atom thick has
almost no bending stiffness, so unsupported it folds onto itself and sticks,
and graphene folded onto graphene does not come apart.

The standard laboratory answer is to spin a film of PMMA on top of the graphene
before the copper goes, let it harden, and let it act as a stiff backing. It
works, and it introduces this process's most persistent wound: PMMA never comes
entirely off. Acetone dissolves most of it, but a residue of a few nanometres
stays behind, and that residue dopes the graphene and changes what it does
electrically.

Substituting a consumable copper foil for a consumable polymer film is not
obviously progress, so the carrier choice is a first-class design question here
rather than an afterthought. It is recorded as an open question.

**Discharge.** A sheet held flat by something.

**Invariants to pass.**

- **I-15** The carrier grips the sheet harder than the copper does, or the
  sheet stays behind.
- **I-16** The carrier releases the sheet more easily than the target substrate
  will grip it, or the sheet never lands.

I-15 and I-16 are a squeeze. The carrier's adhesion has to sit strictly between
two other adhesions, and the window between them is what makes carrier
selection hard.

---

## Station 7 — Landing

**Intake.** A carried sheet, and a target substrate.

**What happens.** The sheet is brought into contact with the substrate and
pressed. Contact has to be initiated at a point or a line and swept, never
made all at once across the whole area, because air trapped between sheet and
substrate has nowhere to escape and becomes a permanent bubble.

**Discharge.** A sheet lying on its substrate, still wearing its carrier.

**Invariants to pass.**

- **I-17** No trapped gas between sheet and substrate.
- **I-18** Substrate surface clean and of specified wettability **(setpoint)**.

---

## Station 8 — Carrier Removal and Cleaning

**Intake.** A landed sheet still wearing its carrier.

**What happens.** The carrier is dissolved, peeled, or heated off, depending on
what it was. Then the residue is attacked — solvent, or a low-temperature
anneal in hydrogen or argon, or both.

**Discharge.** Finished graphene on its substrate. Solvent waste.

**Invariants to pass.**

- **I-19** Residue below spec **(setpoint)**, measured as a doping shift rather
  than as a thickness, because what matters is the electrical effect and not
  the amount.

---

## Station 9 — The Copper Return

**Intake.** Whatever Station 5 took off the block, and the block itself.

**What happens.** The copper is put back. How depends on which machine sits in
the release slot: condensed from vapour, plated from solution, or — in the
bubbling case — never removed, so this station has nothing to do but inspect.

**The invariant that decides whether this factory has a shelf life.**

Copper deposited by ordinary means comes back fine-grained and randomly
oriented. That is the opposite of what Station 2 needs to hand to Station 3.
Two ways out, and they are not exclusive:

*Anneal it back.* The furnace is already at 1000 C for other reasons, and at
that temperature copper recrystallises. Grains grow, orientations compete, and
the survivors are the low-energy ones. This is free in energy terms because the
heat is already being paid for, but it takes time, and time is throughput.

*Grow it on top of the crystal already there.* If the block is itself a single
crystal of copper oriented so the working face is (111), and only a shallow
layer was ever removed, then the returning copper atoms land on an intact (111)
template and continue it. The old crystal dictates the new. This is homoepitaxy
and it is by far the cleaner answer, and it argues that the block should be a
single-crystal copper billet rather than a cast or rolled one, and that the
release mechanism should be chosen partly on how *shallow* a bite it takes.

**Discharge.** A block ready to re-enter Station 2.

**Invariants to pass.**

- **I-20** Block mass returned to its starting value, within tolerance
  **(setpoint)**.
- **I-21** Working face restored to Cu(111), single crystal — that is, I-06 and
  I-07 hold again.
- **I-22** Working face flatness restored, so I-08 holds again.

**I-21 is the closure invariant, and it is the one the whole design turns on.**
If it holds, the loop is closed and the factory runs forever on carbon and
power. If it holds only approximately, the block degrades a little each cycle,
the graphene gets worse each cycle, and the factory has a shelf life measured
in cycles rather than years. Every one of the three release mechanisms will be
judged first on this.

---

## Station 10 — The Cut

**Intake.** Finished graphene on substrate.

**What happens.** Sheets are separated to the size asked for. Where in the line
this belongs is genuinely undecided: cutting the substrate afterwards is
simplest, cutting the carrier before landing is gentler on the sheet, and
patterning the copper face so the graphene grows already-separated is the most
elegant and the least proven.

**Discharge.** The product.

**Invariants to pass.**

- **I-23** The cut does not damage sheet outside its kerf.

---

## The loop, in one line

Gas and power in; carbon becomes sheet; sheet leaves on a carrier; copper goes
home; block starts again.

The only things genuinely consumed are methane, some hydrogen, the carrier, the
target substrate, and electricity. The copper is furniture.
