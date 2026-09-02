# Open Questions

Everything the design has raised and not settled. These are not decoration and
they are not a closing section. Each one gets asked and worked through before
the phase it belongs to can be called finished, and a phase holding an
unanswered question is in progress, not done.

Questions are marked **ASKED** once they have been put to the user, and
**SETTLED** with the answer written into the document it belongs in.

---

## Q-01 — How big is a face? — *next*

Sets every other number in the plant. A face ten centimetres on a side and a
face a metre on a side are not the same machine scaled: the electroplating
current scales with area, the vapour transport gas flow scales with area, the
bubble front in delamination has to travel across the whole face without
tearing anything and that distance scales with the linear dimension.

It also decides the product. The largest sheet the factory can make is the size
of a face, and everything smaller comes from cutting.

**Phase.** 2 — The Block.
**Blocks.** All of Phase 3, because all three release designs need it.

## Q-02 — What holds the sheet while the copper is gone?

Invariant I-13 says the sheet must never be unsupported. The laboratory answer
is a spun-on PMMA film, which works and leaves a residue that dopes the sheet
and never fully washes off. Trading a consumable copper foil for a consumable
polymer film is not obviously an improvement, and the whole premise of this
factory is that consumables are the enemy.

Is there a carrier that is itself reusable? Or a release that hands the sheet
directly to its final substrate with nothing in between?

**Phase.** 4 — The Carrier and the Landing.

## Q-03 — Does returned copper come back as Cu(111)?

The closure invariant, I-21. Ordinary deposition gives fine-grained randomly
oriented copper, which is the opposite of what growth needs. Two candidate
answers, possibly both: anneal it back into orientation using heat the furnace
is already spending, or take such a shallow bite that an intact single-crystal
template is always left behind for the new copper to continue.

If neither works, the factory has a shelf life measured in cycles.

**Phase.** 2 — The Block, and 3 — The Release Slot.

## Q-04 — Does the block ever cool?

Station 4 is the wrinkle hazard: copper contracts about one and a half percent
between growth temperature and room temperature and graphene does not contract
at all, so the sheet buckles.

A release that works hot never creates that strain. Of the three candidates
only vapour transport can work hot; the two wet ones need the block cold. So
this question may quietly decide the comparison before the comparison is run,
which is a reason to be careful about asking it too early and answering it too
confidently.

**Phase.** 3 — The Release Slot, and 6 — The Comparison.

## Q-05 — How many faces are in production at once?

A block with one working face has five idle. A block with all six on a rotating
schedule is a carousel, and a carousel is a very different machine with very
different plumbing, because six faces at six different stages of the cycle need
six different environments at the same time.

**Phase.** 2 — The Block.

## Q-06 — What does an edge do to a growing sheet?

A sheet growing across a face eventually reaches the edge of the face. Does it
stop there, wrap around the corner, or terminate raggedly? A wrapped sheet is
one that cannot be lifted off flat. This may argue for faces recessed below
their edges, or for a mask, or for a block shape with no sharp edges at all.

**Phase.** 2 — The Block.

## Q-07 — How is film continuity seen inside a sealed furnace?

Invariants I-09, I-10, and I-11 are established at 1000 C behind a wall and
conventionally checked by Raman spectroscopy after cool-down. Finding out that
the film had holes only after tearing it during transfer means discovering
defects by paying for them.

**Phase.** 5 — Measurement.

## Q-08 — How is crystal orientation read fast enough to not be the bottleneck?

Invariant I-21 needs the orientation of a surface, and the laboratory
instrument for that wants vacuum, a polished sample, and a slow scan. None of
those describe a hot block between cycles.

A possible dodge: guarantee it by construction instead of measuring it. If the
bite is shallow enough that the template is never destroyed, orientation cannot
drift, and there is nothing to check.

**Phase.** 5 — Measurement.

## Q-09 — Where in the line does the cut belong?

Three places, in increasing order of elegance and decreasing order of
proven-ness: cut the substrate after landing, cut the carrier before landing,
or pattern the copper face so the sheets grow already separated and never need
cutting at all.

**Phase.** 4, or 2 if the answer is patterning.

## Q-10 — Where does the carbon come from, and where does the hydrogen go?

Methane is the feedstock. Natural gas, biogas, and synthesised methane are not
the same input in purity or in what the plant's carbon accounting looks like.

Separately: cracking one methane molecule liberates four hydrogen atoms, and
the plant is already consuming hydrogen for reduction and for etching. Whether
the liberated hydrogen is captured and fed back or vented changes the gas train
substantially.

**Phase.** 1 — The Spine.

## Q-11 — What does the product ship as?

Graphene on a target substrate, or graphene as a free-standing film? These are
different products with different customers, and the answer decides whether
Stations 6 through 8 end with a landing or with a release into nothing.

**Phase.** 4 — The Carrier and the Landing.

## Q-12 — Is chlorine compatible with the rest of the reactor?

Specific to the vapour transport candidate. A gas that carries copper by
reacting with it will also react with other metals, and a furnace has fittings,
thermocouples, and heating elements in it. Either the chlorine is confined to a
zone or the whole reactor is built from things chlorine ignores.

**Phase.** 3 — The Release Slot.
