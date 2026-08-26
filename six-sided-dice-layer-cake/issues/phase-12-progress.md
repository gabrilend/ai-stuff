# Phase 12 — The Kiln: progress

**Making it, bonding it, testing it, waking it. Complete — and the whole
blueprint set now resolves.**

| ticket | blueprint | state |
|---|---|---|
| `1201` | `081-process-and-node` | done |
| `1202` | `082-assembly-order` | done |
| `1203` | `083-known-good-die` | done — **closes `009` entry K1** |
| `1204` | `084-test-access` | done — **closes `009` entry K2** |
| `1205` | `085-bring-up` | done |
| `1206` | `086-reliability-and-lifetime` | done |

## Five hundred and eight of five hundred and eight

**Nothing unevaluated. No structural errors. No dimension mismatches. No
failures.**

Eighty blueprints, one thousand three hundred and twenty-five symbols, five
hundred and eight constraints, all resolving from eleven chosen lengths and a
table of material properties. The set has never been complete before; every
earlier phase left constraints reaching for blueprints that did not exist.

What remains is honest and reported on every run: **two `target` symbols** — a
cube swap time waiting on a procedure to be timed, and a worst-served flow
fraction waiting on a network solver the notation does not have — and **a hundred
orphan symbols** that nothing references.

## The ladder that broke on its first run

`082` asserts that every bonding temperature must be cooler than the one before
it, or an earlier bond reflows while a later one is being made. Four constraints
on five temperatures that are obviously in the right order.

**One was not.** `066`'s spout bond was hotter than the bond that put the faces
on, so making it would have reflowed them. It came down forty kelvin, which needs
surface activation to reach and is now a process requirement.

The ladder also produced an argument for byte mode that `068` does not make for
itself: **ordinary microbumps attach at a temperature the assembled cube does not
care about**, so `068` sidesteps the tightest rung entirely.

## Two yields, kept apart

Conflating die yield with assembly yield is the ordinary way to be wrong about
this by an order of magnitude. A bad die is discarded before assembly and affects
only the cost per known-good part; assembly yield is what fraction of cubes built
from good parts survive.

`083` derives them separately, and answers the question the ticket asked: **the
bonds dominate.** Sixty-one dice against twenty million bonds is not a close
contest, and the spare fractions in `051` and `063` are therefore the most
important numbers in the phase — both of which are still `given` figures those
blueprints asked this one to set.

## Constraints asserted in the direction of alarm

Four now, and they are becoming a pattern worth naming. A constraint that will
always hold, asserted so that a reader meets a number rather than a claim:

- twenty-four tiers with no redundancy lose more than one stack in seven
- the radial bonds with no spares **fail more often than they work**
- at the transistor's own voltage the machine would draw over a kiloampere
- at least four properties must be named as untestable

The last is the strangest and the most useful: **a test blueprint that implies
complete coverage is worse than one that says where it stops.**

## What is still open

**Two substantial pieces of software are assumed and not specified.** `058`'s
packer, which quantises a model and writes the media layout, and `085`'s reference
implementation, which rung nine compares against bit for bit. **`085` needs both
on day one.**

**Six of nine failure mechanisms have no derived number** (`086`). Named,
allocated, not computed — and bond fatigue is the largest gap, because `018`
counts three thermal swings and turns none into cycles to failure.

**The spout is not covered by test access** (`084`). `066` needs to know which
bonds failed and the only opportunity is after the bond.

**Stitching is named and not designed** (`081`), and its yield cost is not
charged for in `083`.
