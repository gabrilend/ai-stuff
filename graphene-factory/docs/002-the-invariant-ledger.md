# The Invariant Ledger

Every condition the factory depends on, in one place.

An invariant is not a target and not a quality metric. It is a statement that
is either true or false at a particular boundary in the line, and if it is
false the next machine does not degrade gracefully — it fails, or it destroys
the material, or it produces something that only looks like product.

Each entry records **where it is made true**, **where it is relied on**, and
**what actually goes wrong** when it does not hold. The gap between the first
two columns is the interesting part: an invariant established at Station 2 and
not consumed until Station 9 has to survive seven stations of handling in
between, and every one of those stations is an opportunity to break it without
noticing.

## The ledger

| ID   | Statement | Established at | Relied on at | Failure |
|------|-----------|----------------|--------------|---------|
| I-01 | Sulfur in the methane below threshold | 0 Gate | 3 Growth | Sulfur adsorbs on copper and holds. Poisoned sites will not crack methane, so the film grows with holes, and I-09 fails downstream. |
| I-02 | Water vapour below dew point spec | 0 Gate | 2 Anneal | Water oxidises hot copper faster than hydrogen reduces it. The anneal never wins and the face never becomes clean metal. |
| I-03 | Oxygen present at a specified concentration | 0 Gate | 3 Growth | Too little and nucleation density climbs, giving many small domains. Too much and the copper oxidises. This one fails in both directions. |
| I-04 | Reactor leak rate below spec | 1 Load | 2 Anneal | Air enters during the ramp. The block oxidises on the way up to temperature. |
| I-05 | Residual oxygen and water below threshold, measured in the tube | 1 Load | 2 Anneal | Same as I-04, but from a bad purge rather than a bad seal. Listed separately because the two have different fixes. |
| I-06 | Working face is Cu(111) | 2 Anneal | 3 Growth | Islands nucleate at random rotations, meet misaligned, and stitch with pentagons and heptagons instead of hexagons. The sheet becomes a quilt of domains separated by defect lines. |
| I-07 | Working face has no grain boundaries | 2 Anneal | 3 Growth | Each copper grain templates its own graphene orientation, so copper grain boundaries print themselves through into graphene grain boundaries. |
| I-08 | Surface roughness below spec | 2 Anneal | 3 Growth | Bumps and scratches are preferential nucleation sites. Roughness converts directly into domain count. |
| I-09 | Film is continuous, no bare copper | 3 Growth | 5 Release | A hole is a place where the sheet has an edge. When the copper support leaves, tearing starts at edges. |
| I-10 | Film is a single layer | 3 Growth | 7 Landing | Stacked islands do not conform to the substrate the way a single layer does, and behave differently, electrically. |
| I-11 | Domain count near one | 3 Growth | product | Not a failure of the machine, a failure of the product. Grain boundaries scatter electrons, so a many-domain sheet conducts far worse than its area promises. |
| I-12 | Wrinkle density below spec | 4 Cool-down | product | Copper contracts about 1.5% on the way down from 1000 C; graphene does not contract at all. The sheet is compressed into a smaller space than it wants and buckles. Permanent. |
| I-13 | Sheet supported before, during, and after copper leaves | 5 Release, 6 Carrier | 5 Release | An unsupported one-atom membrane folds onto itself, and graphene stuck to graphene does not come apart. Total loss of the sheet. |
| I-14 | No copper crosses the machine boundary | 5 Release | 9 Return | Copper that leaves cannot come back. Mass balance opens and I-20 fails. |
| I-15 | Carrier grips harder than copper does | 6 Carrier | 5 Release | The sheet stays on the block. |
| I-16 | Carrier releases more easily than the substrate grips | 6 Carrier | 7 Landing | The sheet leaves with the carrier instead of staying on the target. |
| I-17 | No trapped gas between sheet and substrate | 7 Landing | product | A trapped bubble is permanent and the sheet over it is unsupported and eventually ruptures. |
| I-18 | Substrate clean, wettability specified | 7 Landing | 7 Landing | Contact is partial. The sheet adheres in patches. |
| I-19 | Carrier residue below spec, measured as doping shift | 8 Cleaning | product | Residue is a dopant. It shifts the Fermi level, so the sheet's electrical behaviour is not the behaviour that was specified. |
| I-20 | Block mass returned to starting value | 9 Return | 2 Anneal | The block thins every cycle. Eventually the geometry no longer fits the fixture. |
| I-21 | Working face restored to single-crystal Cu(111) | 9 Return | 2 Anneal | **The closure invariant.** See below. |
| I-22 | Working face flatness restored | 9 Return | 3 Growth | I-08 fails on the next cycle, and every cycle after. |
| I-23 | Cut damages nothing outside its kerf | 10 Cut | product | Yield loss proportional to the number of cuts, which means small sheets cost disproportionately more than large ones. |

## The closure invariant

I-21 is different in kind from the rest.

Every other invariant on this list, if it fails, ruins one batch. I-21 is the
only one that, if it fails, ruins **every subsequent batch**, and it does so
gradually enough that nobody notices for a while.

The mechanism is simple. Station 3 grows good graphene only on a single-crystal
(111) face. Station 9 puts copper back. If the copper that comes back is not
(111), or is (111) in patches with boundaries between them, then the next
cycle's face is slightly worse than this cycle's. That next cycle grows
slightly worse graphene *and* leaves behind a slightly worse face. The error
compounds.

This turns a materials question into an economic one. A factory whose block
degrades has a shelf life measured in cycles. A factory whose block does not
degrade runs on carbon and electricity indefinitely. Nothing else in the design
has that character, so I-21 is the first thing each of the three release
mechanisms will be measured against.

## Invariants that are not yet measurable

Several of these can be stated but not currently checked at the point they need
to be checked, which means the factory as designed would be flying blind at
exactly the moments that matter.

- **I-09, I-10, I-11** are established inside a sealed furnace at 1000 C and
  are conventionally verified by Raman spectroscopy after cool-down. A factory
  that only learns its film was discontinuous after it has already destroyed
  the sheet trying to transfer it is a factory that discovers its defects by
  paying for them.
- **I-21** requires knowing the crystal orientation of a surface. The
  laboratory instrument for that is electron backscatter diffraction, which
  wants a vacuum and a polished sample and a slow scan. Doing it on a hot block
  between cycles, fast enough not to be the bottleneck, is not currently a
  thing anyone does.

Both are recorded as open questions rather than solved, because pretending
otherwise would put a measurement in a blueprint that does not exist.
