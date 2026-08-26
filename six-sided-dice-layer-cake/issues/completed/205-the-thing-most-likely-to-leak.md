# 205 — The thing most likely to leak

Produces `src/017-seal-and-bond.md`.

## Current behavior

**Done.** `src/017-seal-and-bond.md` exists, and the first useful output was the
count: **a hundred and sixty-six joints**, ninety-six of which exist only because
`014` chose to cross the cold plate rather than route around it.

**The tolerance-against-compression constraint failed twice before it held**, and
the sequence is kept in the blueprint because it is what the notation is for. A
one millimetre cord takes up a hundred and fifty microns; four plates accumulate
a hundred and sixty. Then `018` found the face bows forty-five microns when hot,
so the flatness allowance was never real, and the loop went to three hundred. The
cord is two and a half millimetres now and the seventy microns of travel it needs
came out of `014`'s plenum. None of those three numbers could have been chosen
first.

Six constraints, five holding. The sixth waits on the reservoir volume in `027`.

**The elastomer is not established.** Twenty per cent compression set over a
hundred thousand cycles is plausible and has no source behind it, and it
multiplies the whole seal life.

## Intended behavior

**Every joint in the machine that separates coolant from something that must stay
dry, with a pressure rating, a compression range, a material, and a leak rate.**

This ticket is written first among the sealing work because it is the honest
answer to *what kills this machine*. Water at two bar, a hundred and fifty microns
from live silicon at three quarters of a volt. One drop in the wrong place and the
cube is scrap — not damaged, scrap, because nothing inside it can be reached.

### The joints

| joint | count | length or area | what it separates |
|---|---|---|---|
| face plate to edge rail | 24 | 60 mm each | coolant plenum from the outside |
| edge rail to corner block | 24 | a circumference each | rail to chamber |
| supply chamber to return chamber | 8 | a shared wall | the two networks |
| cold plate to interposer, around each via island | 96 | a small perimeter | water from conductors |
| cold plate cover bond | 6 | 52 mm square perimeter | channels from the die stack |
| external fitting to corner block | 8 | a thread | the loop from the room |

Ninety-six via island seals is not a typo. Sixteen islands per plate, six plates,
each one a small ring of bond around a hole through a pressurised channel field —
and each one is a place where a conductor passes within a hundred microns of
water. `202` created these when it decided to cross the cold plate. That decision
should be re-examined here with the seal count in front of it, because a hundred
and sixty-eight seal features is a very different reliability proposition from
seventy-two.

### The two regimes

**Permanent bonds** — the cold plate cover, the via islands. These are made once,
at wafer scale, and are never serviced. Direct silicon bonding or a metallic
diffusion bond. Leak rate measured as a helium rate at proof pressure, not as
"does it drip".

**Compression seals** — the face plates, the rails, the fittings. These are made at
assembly and can in principle be remade. Elastomer, in a groove, with a defined
compression set over the machine's life. **The compression range is what `201`'s
tolerance stack has to fit inside**, and that is the coupling that makes this
ticket hard: a seal wants a lot of compression and a stack of six plates around a
closed loop wants to give it very little.

### The pressures

Working pressure comes from `024` and is under a bar. Proof pressure should be
three times working and burst five, which are ordinary multipliers and should be
stated as symbols so the whole set can be raised together. The number that matters
more than any of them is the **thermal cycle count**: a hundred thousand cycles
between twenty-five and a hundred and five degrees, which is what `086` requires,
and which is far harder on an elastomer than pressure ever is.

## Symbols this must publish

Working, proof and burst pressures. Seal groove geometry and the compression range
it produces. Allowable leak rate per joint and in total. Elastomer compression set
at temperature over the cycle count. Bond strength for the permanent joints. Total
seal line length and total seal feature count.

## Constraints this must assert

- The tolerance stack from `201`, taken around a closed loop of four plates, lands
  inside the compression range. **This is expected to fail on the first attempt**
  and the resolution will be either tighter flatness or a more compliant seal.
  A constraint that fails is doing its job.
- Wall thickness everywhere exceeds burst pressure with the material strength from
  `011`.
- Total allowable leak, summed over every feature, is below what the reservoir in
  `027` can lose over the service interval without the level sensor tripping.
- The inter-chamber wall in `203` meets proof pressure as a flat plate.

## Suggested implementation steps

1. Enumerate the joints. The count is the first useful output and it is larger
   than anybody expects.
2. Pick the two regimes and the material for each.
3. Set the pressure multipliers as symbols.
4. Do the closed-loop tolerance-versus-compression check and let it fail.
5. Resolve it, and record in `docs/balance-updates.md` which side gave.
6. Sum the leak budget and hand it to `027`.

## Blocks

`306`, `308`, `1202`, `1206`.

## Blocked by

`201`, `202`, `203`, `204`.

## Related documents

`005` names this as the likeliest single point of failure. `009` entry B2 is the
question of whether the fluid should be water at all, and it is really a question
about this ticket.
