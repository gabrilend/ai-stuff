# What This Factory Is

A plant that takes methane, hydrogen, and electricity in at one end and puts
sheets of graphene out at the other, cut to whatever size is asked for.

It is a paper facility. Nothing here is simulated and nothing here is code.
Each machine is specified by four things and no others:

| Field       | Meaning                                                     |
|-------------|-------------------------------------------------------------|
| Intake      | What crosses the machine's boundary going in.               |
| Discharge   | What crosses it going out, including waste and heat.        |
| Invariants  | What must already be true for the machine to work at all.   |
| Footprint   | The floor it stands on, and the clearance it needs around it.|

The invariants are the point. A machine that is handed material failing its
invariants does not produce bad output, it produces no output and damages the
material. The whole design is a chain of conditions, each one established by
the station before it, and the factory is correct exactly when every link
holds.

## The one unusual thing about this plant

Every existing CVD graphene process destroys its copper.

The standard sequence grows graphene on a copper foil, glues a polymer on top,
and then dissolves the foil away in acid. The copper leaves as ions in
solution. The foil is roughly 25 micrometres thick and the graphene is 0.335
nanometres thick, so about seventy-five thousand atomic layers of copper are
consumed to harvest one atomic layer of carbon.

That plant is not a graphene factory. It is a copper-destroying factory that
happens to emit graphene.

This plant treats the copper as apparatus rather than as stock. A block of
copper is installed once and stays. Graphene is grown on a face of it, that
face's outermost copper is taken away just far enough to let the sheet go, the
sheet is carried off, and the copper is put back. The block ends every cycle
with the mass and the shape and the crystal orientation it started with.

The copper is skimmed, not spent.

## Three ways to skim it

The step that separates sheet from block is the only step where the three
candidate designs disagree. Everything before it and everything after it is
shared. So the line has a **release slot** in the middle of it, and three
different machines are designed to drop into that slot:

- **Halide vapour transport.** Copper is carried off as a gas and deposited
  back somewhere cooler, driven by nothing but a temperature difference.
- **Reversed electric current.** Copper is dissolved into an electrolyte at one
  polarity and plated back at the other.
- **Bubbling delamination.** No copper is removed at all. Hydrogen gas is
  generated in the gap between metal and sheet and pries the sheet off.

They are designed side by side on purpose. Each one is strong exactly where
another is weak, and the comparison is expected to teach more than any single
design would. What is learned from each gets folded back into the others.

## Where to read next

- [The material walk](001-the-material-walk.md) follows one batch of methane
  from the gas bottle to a cut sheet, station by station, and states what must
  become true at each boundary.
- [The invariant ledger](002-the-invariant-ledger.md) collects every one of
  those conditions in one place, numbered, with what breaks when it fails.
- [The roadmap](003-roadmap.md) is the order the design gets built in.
