# Phase 2 — The Body: progress

**The cube as a mechanical object. Complete, and it moved five numbers in other
people's blueprints on the way.**

| ticket | blueprint | state |
|---|---|---|
| `201` | `013-cube-envelope` | done |
| `202` | `014-face-assembly-stack` | done |
| `203` | `015-corner-manifold-block` | done |
| `204` | `016-edge-rail` | done |
| `205` | `017-seal-and-bond` | done |
| `206` | `018-thermomechanical-stress` | done |
| `207` | `019-mount-and-service-frame` | done |

Fifty-eight constraints hold across the ten blueprints written so far. Fifteen
more are written and waiting on phases 3, 5 and 8.

## The decision the phase existed to make

**The dies face inward and are cooled from behind.** Cooling from the inward side
would put a water-filled plate between the dies and the switch shell, and that
interface is over five million connections. The port field can cross a cold plate
— forty-eight volts and a few thousand pairs is thousands of feedthroughs — so
sixteen small islands carry it, at five per cent of the wetted area and
**ninety-six new places for water to meet a conductor**.

## The three things that failed and were not quietly fixed

**The corner block did not contain its own chambers.** Two chambers, a wall
between and a wall around wanted fifteen millimetres inside eight. The block grew
to twelve.

**The manifold cannot be transparent.** The design intended rails and corners
together to cost under five per cent of the loop, so that flow distribution would
be insensitive to how well the manifold was built. A four millimetre rail
carrying a sixth of the machine's flow runs at over two metres a second and costs
a third of the loop on its own. The claim was withdrawn rather than the threshold
adjusted, and the consequence lands on `024`, which must now solve the network
properly.

That is the better outcome. What balances this design was never the manifold
being invisible; it is the parity topology — every point of the supply mesh
within one edge of a feed — and leaning on the weaker argument would have hidden
that.

**The silicon does not survive its own assembly with an ordinary edge.**
Tier-to-lamina interfaces carry a hundred and nine megapascals, and two thirds of
that is residual frozen in at bonding rather than anything the machine does while
running. A sawn edge fractures at a hundred and fifty. **Plasma dicing is now a
requirement on `1201`**, not a preference.

## The cascade worth remembering

Five numbers moved in sequence and none could have been chosen first.

```
   the face assembly bows 45 µm when hot          (018, found)
        ↓
   15 µm of flatness was never a real figure      (013, 15 → 50 µm)
        ↓
   four plates now accumulate 300 µm              (013, derived)
        ↓
   a 1 mm seal cord takes up only 150 µm          (017, 1.0 → 2.5 mm)
        ↓
   which needs 400 µm of travel, not 330          (014, plenum 1.20 → 1.13 mm)
```

A specification written as prose would have carried fifteen microns of flatness
in four documents and discovered the bow when a machine leaked.

## What is still open

**The bow coefficient has no source** (`018`). It is a `measured` figure with a
plausible value and it decided all five numbers above. It wants a layered-beam
calculation from `014`'s actual stack.

**The better answer to the bow was not taken.** Reordering the face stack to
balance its neutral axis would stop it bowing and give back the seventy microns
of plenum. Nobody tried.

**Fatigue life is not computed** (`018`). Three thermal swings are counted, none
turned into cycles to failure, and `086` is relying on it.

**The nine-seal corner is not drawn** (`015`), and it is the hardest sealing
geometry in the machine.

**Which mounting orientations are permitted is not enumerated** (`019`). The rule
is written; the six cases are not checked.
