# 071 — Getting the beat everywhere

```meta
phase  | 10
issues | 1002
```

## What is different about a cube

```drawing
three levels, and the middle one is unusual [not-dimensioned]

   within a die      ── a balanced tree, ordinary, and where the tight number is

   across a face     ── four dies a millimetre apart, ordinary and short

   between faces     ── a star from the cage with six equal arms, because
                        there is no path between two faces that does not
                        pass through the middle
```

The third level looks like the hard one and is the easy one. The cage is
equidistant from all six faces **by construction** — it is the property `000`
claims as a reason for the cube's shape — so the inter-face distribution is a
star with equal arms, which is the simplest topology there is.

## Where the skew actually comes from

Not the arm lengths, which are equal. It comes from process variation between six
separately manufactured faces, from **temperature differences between them**, and
from each face having its own regulator.

The temperature term is one this project creates for itself: under the sieve, one
face is hot and five are not. `026` found that a face's thermal time constant is
twenty times a pipeline stage, so the swing within a token is small — which means
the term here is the *steady* difference between a busy face and an idle one
rather than the walking excursion, and it is much smaller than it first appeared.

## The honest answer to the hard case

Holding six faces to a common edge across the whole cube at gigahertz rates is a
poor use of effort, because **nothing in this machine needs it.** `072`
establishes that faces need to agree about *cycles*, not about edges, and the
handoff between them goes through memory with barriers rather than through a
timing path.

So the arrangement is **mesochronous** — same frequency, unknown phase — and
`072` handles the rest. Insisting on synchrony would cost a great deal of power
for a guarantee nothing consumes.

## Symbols

```symbols
n_tree_level  | 1 | given | 3      | levels of distribution: within a die, across a face, between faces
skew_die      | ps | given | 12.0  | skew within one die's balanced tree, which is where the tight number is
skew_face     | ps | given | 6.0   | skew across the four dies of a face
skew_proc     | ps | given | 20.0  | skew between two faces from process variation alone
skew_temp_k   | ps/K | given | 0.4 | timing shift per kelvin of steady temperature difference between two faces
dT_face_diff  | K | given | 12.0   | steady temperature difference between a busy face and an idle one
P_clocktree   | W | given | 22.0   | all three levels together
mesochronous  | 1 | given | 1       | whether faces share a frequency but not a phase. They do, and it is written as a value so that a blueprint assuming a common edge fails outright

skew_temp     | ps | derived | skew_temp_k * dT_face_diff        | the temperature term between two faces
skew_supply   | ps | derived | psrr_mult * dV_droop_logic / V_logic * t_cycle_face | the supply term, each face having its own regulator
skew_face_all | ps | derived | sqrt(skew_proc^2 + skew_temp^2 + skew_supply^2) | skew between two faces, the three independent sources in quadrature
skew_intra    | ps | derived | skew_die + skew_face              | skew a face's own timing closure must absorb, which is what 074 budgets
L_arm         | mm | derived | t_face                            | length of one arm of the inter-face star; equal for all six by construction
f_skew_cycle  | 1 | derived | skew_intra / t_cycle_face          | the intra-face skew as a share of a cycle
```

## Constraints

```constraints
C-071-1 | f_skew_cycle < 0.06         | skew a face must absorb in its own closure has to stay under a sixteenth of a cycle, which is what 074 allocates
C-071-2 | skew_face_all < t_cross_face | skew between two faces must be small against a domain crossing's own latency, which is the loose bound mesochronous operation permits -- and it is two orders of magnitude looser than a common edge would have needed
C-071-3 | mesochronous == 1           | faces share a frequency and not a phase. Asserted as a value so that a blueprint deriving something from a common edge fails rather than being quietly wrong
C-071-4 | L_arm ~= t_face             | every arm of the star is one face thickness, which is what makes all six equal. It is the cube's geometry doing the work, and a change that moved the cage off centre would break it here
C-071-5 | P_clocktree < P_load / 50    | the whole distribution must cost under a fiftieth of the machine. Insisting on synchrony between faces is what would break this
C-071-6 | skew_temp < skew_proc       | the temperature term must be smaller than process variation, or the thermal design is what limits the clock
```

## What is still open

**The temperature coefficient is a `given`.** Four tenths of a picosecond per
kelvin is a plausible figure for a buffered tree and it multiplies a temperature
difference that `025` derives, so the product is half-derived and half-assumed.

**Nothing budgets the clock's own power against where it goes.** Twenty-two watts
across three levels is entered as one number; which level spends it is not said,
and the within-die tree is almost certainly most of it.
