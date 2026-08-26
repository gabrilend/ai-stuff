# 1204 — Reaching a die that is sealed inside a cube

Produces `src/084-test-access.md`.

## Current behavior

Nothing. `009` entry K2 names the problem and says it is unsolved.

## Intended behavior

**How every piece of silicon in this machine is tested, at each stage of assembly,
including the stages where it cannot be touched.**

### The three stages

**Before assembly.** Ordinary wafer and package test with probes on pads. Full
coverage, cheap, and this is where nearly all defects must be caught, because
`1202` says everything after step six costs a cube.

**During assembly.** After each of `1202`'s gates. Partial access — a stack of
tiers can still be probed on its top surface, a face assembly still has its port
field exposed. The blueprint must say what each gate can actually reach.

**After sealing.** No probes, no pads, no access except through the port fields on
six outward faces. Everything inside is reachable only by something inside talking
outward.

### The mechanism for the third stage

A **scan and boundary chain** threaded through every die, reachable from any port
field, so that a sealed cube can be told to shift a pattern through itself and
report what came back. Ordinary practice, with two things that are not:

**It has to cross the radial bonds.** The chain runs from a port field, through a
face, across five and a quarter million connections to the cage, and into the
core. If those bonds are the thing being tested, the chain that tests them cannot
depend on them — so there must be a **separate, small, robust path** for the chain
itself, and the blueprint must specify it as such rather than sharing the data
interface.

**It has to work when the machine will not boot.** `1004`'s ten steps each set a
fault bit, but a cube that fails at step three cannot report through anything that
step four brings up. The chain must be alive as soon as the auxiliary domain is,
which is the first thing `406` powers.

### Coverage, which `1203` is waiting for

`1202`'s step five needs a coverage fraction and `1203`'s yield model needs the
same number. This blueprint must produce it honestly: what fraction of defects a
face assembly test actually finds. **The gap between that and one hundred per cent
is the fraction of cubes that fail after the point of no return**, and it is
probably the largest single cost driver in the machine.

### What cannot be tested and must be admitted

Some things only appear at temperature, at speed, under load, or after a thousand
hours. The blueprint should list them rather than implying complete coverage:
marginal timing at the slow corner, thermal behaviour under a real power map,
coolant flow distribution, and anything that wears.

## Symbols this must publish

Access available at each stage. Scan chain topology, length and shift rate. Time
to shift a full pattern. Auxiliary-domain-only path specification. Coverage
fraction per stage. The list of untestable properties. Test time per unit.

## Constraints this must assert

- The scan path from a port field to the core does not depend on the radial data
  bonds it is used to test.
- The chain is functional on the auxiliary domain alone, before `1004`'s step
  three.
- Coverage at `1202`'s step five equals what `1203` assumed.
- Full-pattern shift time is under a stated production test budget, which is a
  real constraint at this scale — a chain through fifty-six dice is long.

## Suggested implementation steps

1. Enumerate access by stage.
2. Specify the independent scan path and justify its separation.
3. Tie it to the auxiliary domain and to `1004`'s fault bits.
4. Produce the coverage fraction honestly and hand it to `1203`.
5. List what cannot be tested.

## Blocks

`1202`, `1203`, `1205`.

## Blocked by

`406`, `609`, `702`, `1004`.

## Related documents

`009` entry K2, which this closes.
