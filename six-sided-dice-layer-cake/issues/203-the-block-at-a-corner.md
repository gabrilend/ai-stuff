# 203 — The block at a corner

Produces `src/015-corner-manifold-block.md`.

## Current behavior

Nothing. `005` describes what the corners do and no corner has been drawn.

## Intended behavior

**One part, made eight times, in two variants that differ only in which port is
fitted.** A corner manifold block is the piece that joins the three edge rails
meeting at a vertex of the cube, and it does four jobs at once:

**It joins three supply channels to each other, and separately three return
channels to each other.** Two chambers in one block, never connected. This is the
whole hydraulic content: it is a tee with three legs, twice, in a solid.

**It carries the external fitting** on the four corners that have one. Four blocks
get an inlet, four get an outlet, chosen by the parity rule from `010`. The other
four are blank — the chambers still join their three rails, they just have no
opening to the outside. **The blank and the ported block must be the same casting
with a different final operation**, or the bill of materials in `088` has two
parts where it should have one.

**It is the stiffest point of the cube** and therefore where the mounting load
goes. `207` bolts to four of them.

**It closes the corner of the envelope**, meeting three edge rails and three face
plates along nine seal lines. This is the hardest sealing geometry in the machine
and `205` has to solve it here rather than along the edges, where it is easy.

## What the hydraulics have to do

Three and a half litres a minute enter across four inlet blocks, so a little under
nine tenths of a litre a minute per block, dividing three ways into the rails. The
numbers are undemanding — the pressure lost in a corner block should come out
under a hundred pascals against about eleven thousand in the microchannel fields —
and that ratio is the point. **A manifold that is a significant restriction stops
being a manifold and becomes a flow divider**, and the whole balance argument in
`023` assumes the corners are transparent.

So the constraint here is not that the block works. It is that the block is
negligible, and the blueprint has to prove that rather than assume it.

## Symbols this must publish

Chamber volumes and cross-sections, the port thread and its bore, the block's
outer geometry, the three rail interfaces, the loss coefficient for the three-way
division, the resulting pressure drop at design flow, the bolt pattern on the
mounting variant, and the mass.

## Constraints this must assert

- Pressure lost in a corner block is under one per cent of the total loop loss.
  The transparency requirement, stated as arithmetic.
- The supply chamber and the return chamber share no wall thinner than the
  proof-pressure wall thickness from `205`. A leak between them short-circuits the
  whole cooling loop while showing nothing on any external sensor, which makes it
  the most dangerous single failure in the machine and worth a constraint of its
  own.
- The block's outer geometry closes the cube corner exactly: three rail widths and
  three plate thicknesses meet without interference or gap.
- Four blocks carry ports and four do not, summing to eight.

## Suggested implementation steps

1. Draw the block in three views and one section that shows both chambers.
2. Work the division loss from the geometry, not from a handbook coefficient — the
   geometry is simple enough for a first-principles estimate and a handbook
   coefficient is a number nobody can change later.
3. Establish the inter-chamber wall thickness against proof pressure.
4. Draw the nine-seal-line corner and hand the result to `205`.
5. Put the bolt pattern on and hand it to `207`.

## Blocks

`204`, `205`, `207`, `305`.

## Blocked by

`101` for the parity rule, `201` for the envelope, `102` for the material.

## Related documents

`005` for what corners are for. `023` for the parity argument that decides which
four are fed.
